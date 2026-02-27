package geoclue

import (
	"fmt"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/pkg/dbusutil"
	"github.com/godbus/dbus/v5"
)

const (
	dbusGeoClueService   = "org.freedesktop.GeoClue2"
	dbusGeoCluePath      = "/org/freedesktop/GeoClue2"
	dbusGeoClueInterface = dbusGeoClueService

	dbusGeoClueManagerPath      = dbusGeoCluePath + "/Manager"
	dbusGeoClueManagerInterface = dbusGeoClueInterface + ".Manager"
	dbusGeoClueManagerGetClient = dbusGeoClueManagerInterface + ".GetClient"

	dbusGeoClueClientInterface       = dbusGeoClueInterface + ".Client"
	dbusGeoClueClientDesktopId       = dbusGeoClueClientInterface + ".DesktopId"
	dbusGeoClueClientTimeThreshold   = dbusGeoClueClientInterface + ".TimeThreshold"
	dbusGeoClueClientTimeStart       = dbusGeoClueClientInterface + ".Start"
	dbusGeoClueClientTimeStop        = dbusGeoClueClientInterface + ".Stop"
	dbusGeoClueClientLocationUpdated = dbusGeoClueClientInterface + ".LocationUpdated"

	dbusGeoClueLocationInterface = dbusGeoClueInterface + ".Location"
	dbusGeoClueLocationLatitude  = dbusGeoClueLocationInterface + ".Latitude"
	dbusGeoClueLocationLongitude = dbusGeoClueLocationInterface + ".Longitude"
)

func NewManager() (*Manager, error) {
	dbusConn, err := dbus.ConnectSystemBus()
	if err != nil {
		return nil, fmt.Errorf("system bus connection failed: %w", err)
	}

	m := &Manager{
		dbusConn: dbusConn,
		stopChan: make(chan struct{}),
		signals:  make(chan *dbus.Signal, 256),
		dirty:    make(chan struct{}),

		state: &State{
			Latitude:  0.0,
			Longitude: 0.0,
		},
	}

	if err := m.setupClient(); err != nil {
		dbusConn.Close()
		return nil, err
	}

	if err := m.startSignalPump(); err != nil {
		return nil, err
	}

	m.notifierWg.Add(1)
	go m.notifier()

	return m, nil
}

func (m *Manager) Close() {
	close(m.stopChan)
	m.notifierWg.Wait()

	m.sigWG.Wait()

	if m.signals != nil {
		m.dbusConn.RemoveSignal(m.signals)
		close(m.signals)
	}

	m.subscribers.Range(func(key string, ch chan State) bool {
		close(ch)
		m.subscribers.Delete(key)
		return true
	})

	if m.dbusConn != nil {
		m.dbusConn.Close()
	}
}

func (m *Manager) Subscribe(id string) chan State {
	ch := make(chan State, 64)
	m.subscribers.Store(id, ch)
	return ch
}

func (m *Manager) Unsubscribe(id string) {
	if ch, ok := m.subscribers.LoadAndDelete(id); ok {
		close(ch)
	}
}

func (m *Manager) setupClient() error {
	managerObj := m.dbusConn.Object(dbusGeoClueService, dbusGeoClueManagerPath)

	if err := managerObj.Call(dbusGeoClueManagerGetClient, 0).Store(&m.clientPath); err != nil {
		return fmt.Errorf("failed to create GeoClue2 client: %w", err)
	}

	clientObj := m.dbusConn.Object(dbusGeoClueService, m.clientPath)
	if err := clientObj.SetProperty(dbusGeoClueClientDesktopId, "dms"); err != nil {
		return fmt.Errorf("failed to set desktop ID: %w", err)
	}

	if err := clientObj.SetProperty(dbusGeoClueClientTimeThreshold, uint(10)); err != nil {
		return fmt.Errorf("failed to set time threshold: %w", err)
	}

	return nil
}

func (m *Manager) startSignalPump() error {
	m.dbusConn.Signal(m.signals)

	if err := m.dbusConn.AddMatchSignal(
		dbus.WithMatchObjectPath(m.clientPath),
		dbus.WithMatchInterface(dbusGeoClueClientInterface),
		dbus.WithMatchSender(dbusGeoClueClientLocationUpdated),
	); err != nil {
		return err
	}

	m.sigWG.Add(1)
	go func() {
		defer m.sigWG.Done()

		clientObj := m.dbusConn.Object(dbusGeoClueService, m.clientPath)
		clientObj.Call(dbusGeoClueClientTimeStart, 0)
		defer clientObj.Call(dbusGeoClueClientTimeStop, 0)

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

				m.handleSignal(sig)
			}
		}
	}()

	return nil
}

func (m *Manager) handleSignal(sig *dbus.Signal) {
	switch sig.Name {
	case dbusGeoClueClientLocationUpdated:
		if len(sig.Body) != 2 {
			return
		}

		newLocationPath, ok := sig.Body[1].(dbus.ObjectPath)
		if !ok {
			return
		}

		if err := m.handleLocationUpdated(newLocationPath); err != nil {
			log.Warn("GeoClue: Failed to handle location update: %v", err)
			return
		}
	}
}

func (m *Manager) handleLocationUpdated(path dbus.ObjectPath) error {
	m.stateMutex.Lock()
	defer m.stateMutex.Unlock()

	locationObj := m.dbusConn.Object(dbusGeoClueService, path)

	lat, err := locationObj.GetProperty(dbusGeoClueLocationLatitude)
	if err != nil {
		return err
	}

	long, err := locationObj.GetProperty(dbusGeoClueLocationLongitude)
	if err != nil {
		return err
	}

	m.state.Latitude = dbusutil.AsOr(lat, 0.0)
	m.state.Longitude = dbusutil.AsOr(long, 0.0)

	m.notifySubscribers()
	return nil
}

func (m *Manager) notifySubscribers() {
	select {
	case m.dirty <- struct{}{}:
	default:
	}
}

func (m *Manager) GetState() State {
	m.stateMutex.RLock()
	defer m.stateMutex.RUnlock()
	if m.state == nil {
		return State{
			Latitude:  0.0,
			Longitude: 0.0,
		}
	}
	stateCopy := *m.state
	return stateCopy
}

func (m *Manager) notifier() {
	defer m.notifierWg.Done()
	const minGap = 200 * time.Millisecond
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

			currentState := m.GetState()

			if m.lastNotified != nil && !stateChanged(m.lastNotified, &currentState) {
				pending = false
				continue
			}

			m.subscribers.Range(func(key string, ch chan State) bool {
				select {
				case ch <- currentState:
				default:
					log.Warn("GeoClue: subscriber channel full, dropping update")
				}
				return true
			})

			stateCopy := currentState
			m.lastNotified = &stateCopy
			pending = false
		}
	}
}

func stateChanged(old, new *State) bool {
	if old == nil || new == nil {
		return true
	}
	if old.Latitude != new.Latitude {
		return true
	}
	if old.Longitude != new.Longitude {
		return true
	}

	return false
}
