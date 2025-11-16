package loginctl

import (
	"context"
	"fmt"
	"os"
	"sync"
	"time"

	"github.com/godbus/dbus/v5"
)

func NewManager() (*Manager, error) {
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		return nil, fmt.Errorf("failed to connect to system bus: %w", err)
	}

	sessionID := os.Getenv("XDG_SESSION_ID")
	if sessionID == "" {
		sessionID = "self"
	}

	m := &Manager{
		state: &SessionState{
			SessionID: sessionID,
		},
		stateMutex: sync.RWMutex{},

		stopChan: make(chan struct{}),
		conn:     conn,
		dirty:    make(chan struct{}, 1),
		signals:  make(chan *dbus.Signal, 256),
	}
	m.sleepInhibitorEnabled.Store(true)

	if err := m.initialize(); err != nil {
		conn.Close()
		return nil, err
	}

	if err := m.acquireSleepInhibitor(); err != nil {
		fmt.Fprintf(os.Stderr, "sleep inhibitor unavailable: %v\n", err)
	}

	m.notifierWg.Add(1)
	go m.notifier()

	if err := m.startSignalPump(); err != nil {
		m.Close()
		return nil, err
	}

	return m, nil
}

func (m *Manager) initialize() error {
	m.managerObj = m.conn.Object(dbusDest, dbus.ObjectPath(dbusPath))

	m.initializeFallbackDelay()

	sessionPath, err := m.getSession(m.state.SessionID)
	if err != nil {
		return fmt.Errorf("failed to get session path: %w", err)
	}

	m.stateMutex.Lock()
	m.state.SessionPath = string(sessionPath)
	m.sessionPath = sessionPath
	m.stateMutex.Unlock()

	m.sessionObj = m.conn.Object(dbusDest, sessionPath)

	if err := m.updateSessionState(); err != nil {
		return err
	}

	return nil
}

func (m *Manager) getSession(id string) (dbus.ObjectPath, error) {
	var out dbus.ObjectPath
	err := m.managerObj.Call(dbusManagerInterface+".GetSession", 0, id).Store(&out)
	if err != nil {
		return "", err
	}
	return out, nil
}

func (m *Manager) refreshSessionBinding() error {
	if m.managerObj == nil || m.conn == nil {
		return fmt.Errorf("manager not fully initialized")
	}

	sessionPath, err := m.getSession(m.state.SessionID)
	if err != nil {
		return fmt.Errorf("failed to get session path: %w", err)
	}

	m.stateMutex.RLock()
	currentPath := m.sessionPath
	m.stateMutex.RUnlock()

	if sessionPath == currentPath {
		return nil
	}

	m.stopSignalPump()

	m.stateMutex.Lock()
	m.state.SessionPath = string(sessionPath)
	m.sessionPath = sessionPath
	m.stateMutex.Unlock()

	m.sessionObj = m.conn.Object(dbusDest, sessionPath)

	if err := m.updateSessionState(); err != nil {
		return err
	}

	m.signals = make(chan *dbus.Signal, 256)
	return m.startSignalPump()
}

func (m *Manager) updateSessionState() error {
	ctx := context.Background()
	props, err := m.getSessionProperties(ctx)
	if err != nil {
		return err
	}

	m.stateMutex.Lock()
	defer m.stateMutex.Unlock()

	if v, ok := props["Active"]; ok {
		if val, ok := v.Value().(bool); ok {
			m.state.Active = val
		}
	}
	if v, ok := props["IdleHint"]; ok {
		if val, ok := v.Value().(bool); ok {
			m.state.IdleHint = val
		}
	}
	if v, ok := props["IdleSinceHint"]; ok {
		if val, ok := v.Value().(uint64); ok {
			m.state.IdleSinceHint = val
		}
	}
	if v, ok := props["LockedHint"]; ok {
		if val, ok := v.Value().(bool); ok {
			m.state.LockedHint = val
			m.state.Locked = val
		}
	}
	if v, ok := props["Type"]; ok {
		if val, ok := v.Value().(string); ok {
			m.state.SessionType = val
		}
	}
	if v, ok := props["Class"]; ok {
		if val, ok := v.Value().(string); ok {
			m.state.SessionClass = val
		}
	}
	if v, ok := props["User"]; ok {
		if userArr, ok := v.Value().([]interface{}); ok && len(userArr) >= 1 {
			if uid, ok := userArr[0].(uint32); ok {
				m.state.User = uid
			}
		}
	}
	if v, ok := props["Name"]; ok {
		if val, ok := v.Value().(string); ok {
			m.state.UserName = val
		}
	}
	if v, ok := props["RemoteHost"]; ok {
		if val, ok := v.Value().(string); ok {
			m.state.RemoteHost = val
		}
	}
	if v, ok := props["Service"]; ok {
		if val, ok := v.Value().(string); ok {
			m.state.Service = val
		}
	}
	if v, ok := props["TTY"]; ok {
		if val, ok := v.Value().(string); ok {
			m.state.TTY = val
		}
	}
	if v, ok := props["Display"]; ok {
		if val, ok := v.Value().(string); ok {
			m.state.Display = val
		}
	}
	if v, ok := props["Remote"]; ok {
		if val, ok := v.Value().(bool); ok {
			m.state.Remote = val
		}
	}
	if v, ok := props["Seat"]; ok {
		if seatArr, ok := v.Value().([]interface{}); ok && len(seatArr) >= 1 {
			if seatID, ok := seatArr[0].(string); ok {
				m.state.Seat = seatID
			}
		}
	}
	if v, ok := props["VTNr"]; ok {
		if val, ok := v.Value().(uint32); ok {
			m.state.VTNr = val
		}
	}

	return nil
}

func (m *Manager) getSessionProperties(ctx context.Context) (map[string]dbus.Variant, error) {
	var props map[string]dbus.Variant
	err := m.sessionObj.CallWithContext(ctx, dbusPropsInterface+".GetAll", 0, dbusSessionInterface).Store(&props)
	if err != nil {
		return nil, err
	}
	return props, nil
}

func (m *Manager) acquireSleepInhibitor() error {
	if !m.sleepInhibitorEnabled.Load() {
		return nil
	}

	m.inhibitMu.Lock()
	defer m.inhibitMu.Unlock()

	if m.inhibitFile != nil {
		return nil
	}

	if m.managerObj == nil {
		return fmt.Errorf("manager object not available")
	}

	file, err := m.inhibit("sleep", "DankMaterialShell", "Lock before suspend", "delay")
	if err != nil {
		return err
	}

	m.inhibitFile = file
	return nil
}

func (m *Manager) inhibit(what, who, why, mode string) (*os.File, error) {
	var fd dbus.UnixFD
	err := m.managerObj.Call(dbusManagerInterface+".Inhibit", 0, what, who, why, mode).Store(&fd)
	if err != nil {
		return nil, err
	}
	return os.NewFile(uintptr(fd), "inhibit"), nil
}

func (m *Manager) releaseSleepInhibitor() {
	m.inhibitMu.Lock()
	f := m.inhibitFile
	m.inhibitFile = nil
	m.inhibitMu.Unlock()
	if f != nil {
		f.Close()
	}
}

func (m *Manager) releaseForCycle(id uint64) {
	if !m.inSleepCycle.Load() || m.sleepCycleID.Load() != id {
		return
	}
	m.releaseSleepInhibitor()
}

func (m *Manager) initializeFallbackDelay() {
	var maxDelayUSec uint64
	err := m.managerObj.Call(
		dbusPropsInterface+".Get",
		0,
		dbusManagerInterface,
		"InhibitDelayMaxUSec",
	).Store(&maxDelayUSec)

	if err != nil {
		m.fallbackDelay = 2 * time.Second
		return
	}

	maxDelay := time.Duration(maxDelayUSec) * time.Microsecond
	computed := (maxDelay * 8) / 10

	if computed < 2*time.Second {
		m.fallbackDelay = 2 * time.Second
	} else if computed > 4*time.Second {
		m.fallbackDelay = 4 * time.Second
	} else {
		m.fallbackDelay = computed
	}
}

func (m *Manager) newLockerReadyCh() chan struct{} {
	m.lockerReadyChMu.Lock()
	defer m.lockerReadyChMu.Unlock()
	m.lockerReadyCh = make(chan struct{})
	return m.lockerReadyCh
}

func (m *Manager) signalLockerReady() {
	m.lockerReadyChMu.Lock()
	ch := m.lockerReadyCh
	if ch != nil {
		close(ch)
		m.lockerReadyCh = nil
	}
	m.lockerReadyChMu.Unlock()
}

func (m *Manager) snapshotState() SessionState {
	m.stateMutex.RLock()
	defer m.stateMutex.RUnlock()
	return *m.state
}

func stateChangedMeaningfully(old, new *SessionState) bool {
	if old.Locked != new.Locked {
		return true
	}
	if old.LockedHint != new.LockedHint {
		return true
	}
	if old.Active != new.Active {
		return true
	}
	if old.IdleHint != new.IdleHint {
		return true
	}
	if old.PreparingForSleep != new.PreparingForSleep {
		return true
	}
	return false
}

func (m *Manager) GetState() SessionState {
	return m.snapshotState()
}

func (m *Manager) Subscribe(id string) chan SessionState {
	ch := make(chan SessionState, 64)
	m.subscribers.Store(id, ch)
	return ch
}

func (m *Manager) Unsubscribe(id string) {
	if val, ok := m.subscribers.LoadAndDelete(id); ok {
		close(val)
	}
}

func (m *Manager) notifier() {
	defer m.notifierWg.Done()
	const minGap = 100 * time.Millisecond
	timer := time.NewTimer(minGap)
	timer.Stop()
	var pending bool
	for {
		select {
		case <-m.stopChan:
			timer.Stop()
			return
		case <-m.dirty:
			if pending {
				continue
			}
			pending = true
			timer.Reset(minGap)
		case <-timer.C:
			if !pending {
				continue
			}

			currentState := m.snapshotState()

			if m.lastNotifiedState != nil && !stateChangedMeaningfully(m.lastNotifiedState, &currentState) {
				pending = false
				continue
			}

			m.subscribers.Range(func(key string, ch chan SessionState) bool {
				select {
				case ch <- currentState:
				default:
				}
				return true
			})

			stateCopy := currentState
			m.lastNotifiedState = &stateCopy
			pending = false
		}
	}
}

func (m *Manager) notifySubscribers() {
	select {
	case m.dirty <- struct{}{}:
	default:
	}
}

func (m *Manager) startSignalPump() error {
	m.conn.Signal(m.signals)

	if err := m.conn.AddMatchSignal(
		dbus.WithMatchObjectPath(m.sessionPath),
		dbus.WithMatchInterface(dbusPropsInterface),
		dbus.WithMatchMember("PropertiesChanged"),
	); err != nil {
		m.conn.RemoveSignal(m.signals)
		return err
	}
	if err := m.conn.AddMatchSignal(
		dbus.WithMatchObjectPath(m.sessionPath),
		dbus.WithMatchInterface(dbusSessionInterface),
		dbus.WithMatchMember("Lock"),
	); err != nil {
		m.conn.RemoveMatchSignal(
			dbus.WithMatchObjectPath(m.sessionPath),
			dbus.WithMatchInterface(dbusPropsInterface),
			dbus.WithMatchMember("PropertiesChanged"),
		)
		m.conn.RemoveSignal(m.signals)
		return err
	}
	if err := m.conn.AddMatchSignal(
		dbus.WithMatchObjectPath(m.sessionPath),
		dbus.WithMatchInterface(dbusSessionInterface),
		dbus.WithMatchMember("Unlock"),
	); err != nil {
		m.conn.RemoveMatchSignal(
			dbus.WithMatchObjectPath(m.sessionPath),
			dbus.WithMatchInterface(dbusPropsInterface),
			dbus.WithMatchMember("PropertiesChanged"),
		)
		m.conn.RemoveMatchSignal(
			dbus.WithMatchObjectPath(m.sessionPath),
			dbus.WithMatchInterface(dbusSessionInterface),
			dbus.WithMatchMember("Lock"),
		)
		m.conn.RemoveSignal(m.signals)
		return err
	}
	if err := m.conn.AddMatchSignal(
		dbus.WithMatchObjectPath(dbus.ObjectPath(dbusPath)),
		dbus.WithMatchInterface(dbusManagerInterface),
		dbus.WithMatchMember("PrepareForSleep"),
	); err != nil {
		m.conn.RemoveMatchSignal(
			dbus.WithMatchObjectPath(m.sessionPath),
			dbus.WithMatchInterface(dbusPropsInterface),
			dbus.WithMatchMember("PropertiesChanged"),
		)
		m.conn.RemoveMatchSignal(
			dbus.WithMatchObjectPath(m.sessionPath),
			dbus.WithMatchInterface(dbusSessionInterface),
			dbus.WithMatchMember("Lock"),
		)
		m.conn.RemoveMatchSignal(
			dbus.WithMatchObjectPath(m.sessionPath),
			dbus.WithMatchInterface(dbusSessionInterface),
			dbus.WithMatchMember("Unlock"),
		)
		m.conn.RemoveSignal(m.signals)
		return err
	}

	if err := m.conn.AddMatchSignal(
		dbus.WithMatchObjectPath("/org/freedesktop/DBus"),
		dbus.WithMatchInterface("org.freedesktop.DBus"),
		dbus.WithMatchMember("NameOwnerChanged"),
	); err != nil {
		m.conn.RemoveMatchSignal(
			dbus.WithMatchObjectPath(m.sessionPath),
			dbus.WithMatchInterface(dbusPropsInterface),
			dbus.WithMatchMember("PropertiesChanged"),
		)
		m.conn.RemoveMatchSignal(
			dbus.WithMatchObjectPath(m.sessionPath),
			dbus.WithMatchInterface(dbusSessionInterface),
			dbus.WithMatchMember("Lock"),
		)
		m.conn.RemoveMatchSignal(
			dbus.WithMatchObjectPath(m.sessionPath),
			dbus.WithMatchInterface(dbusSessionInterface),
			dbus.WithMatchMember("Unlock"),
		)
		m.conn.RemoveMatchSignal(
			dbus.WithMatchObjectPath(dbus.ObjectPath(dbusPath)),
			dbus.WithMatchInterface(dbusManagerInterface),
			dbus.WithMatchMember("PrepareForSleep"),
		)
		m.conn.RemoveSignal(m.signals)
		return err
	}

	m.sigWG.Add(1)
	go func() {
		defer m.sigWG.Done()
		for {
			select {
			case <-m.stopChan:
				return
			case sig, ok := <-m.signals:
				if !ok {
					return
				}
				if sig == nil {
					continue
				}
				m.handleDBusSignal(sig)
			}
		}
	}()
	return nil
}

func (m *Manager) stopSignalPump() {
	if m.conn == nil {
		return
	}
	m.conn.RemoveMatchSignal(
		dbus.WithMatchObjectPath(m.sessionPath),
		dbus.WithMatchInterface(dbusPropsInterface),
		dbus.WithMatchMember("PropertiesChanged"),
	)
	m.conn.RemoveMatchSignal(
		dbus.WithMatchObjectPath(m.sessionPath),
		dbus.WithMatchInterface(dbusSessionInterface),
		dbus.WithMatchMember("Lock"),
	)
	m.conn.RemoveMatchSignal(
		dbus.WithMatchObjectPath(m.sessionPath),
		dbus.WithMatchInterface(dbusSessionInterface),
		dbus.WithMatchMember("Unlock"),
	)
	m.conn.RemoveMatchSignal(
		dbus.WithMatchObjectPath(dbus.ObjectPath(dbusPath)),
		dbus.WithMatchInterface(dbusManagerInterface),
		dbus.WithMatchMember("PrepareForSleep"),
	)
	m.conn.RemoveMatchSignal(
		dbus.WithMatchObjectPath("/org/freedesktop/DBus"),
		dbus.WithMatchInterface("org.freedesktop.DBus"),
		dbus.WithMatchMember("NameOwnerChanged"),
	)

	m.conn.RemoveSignal(m.signals)
	close(m.signals)

	m.sigWG.Wait()
}

func (m *Manager) Close() {
	close(m.stopChan)
	m.notifierWg.Wait()

	m.stopSignalPump()

	m.releaseSleepInhibitor()

	m.subscribers.Range(func(key string, ch chan SessionState) bool {
		close(ch)
		m.subscribers.Delete(key)
		return true
	})

	if m.conn != nil {
		m.conn.Close()
	}
}
