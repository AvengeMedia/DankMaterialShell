package loginctl

import (
	"time"

	"github.com/AvengeMedia/dankgo/dbusutil"
	"github.com/godbus/dbus/v5"
)

func (m *Manager) handleDBusSignal(sig *dbus.Signal) {
	switch sig.Name {
	case dbusSessionInterface + ".Lock":
		m.stateMutex.Lock()
		m.state.Locked = true
		m.state.LockedHint = true
		m.stateMutex.Unlock()
		m.notifySubscribers()

		if m.sleepInhibitorEnabled.Load() && m.inSleepCycle.Load() {
			id := m.sleepCycleID.Load()
			m.lockTimerMu.Lock()
			if m.lockTimer != nil {
				m.lockTimer.Stop()
			}
			m.lockTimer = time.AfterFunc(m.fallbackDelay, func() {
				m.releaseForCycle(id)
			})
			m.lockTimerMu.Unlock()
		}

	case dbusSessionInterface + ".Unlock":
		m.stateMutex.Lock()
		m.state.Locked = false
		m.state.LockedHint = false
		m.stateMutex.Unlock()
		m.notifySubscribers()
		m.prelockedReady.Store(false)

		// Cancel the lock timer if it's still running
		m.lockTimerMu.Lock()
		if m.lockTimer != nil {
			m.lockTimer.Stop()
			m.lockTimer = nil
		}
		m.lockTimerMu.Unlock()

		// Re-acquire the sleep inhibitor (acquireSleepInhibitor checks the enabled flag)
		m.acquireSleepInhibitor()

	case dbusManagerInterface + ".PrepareForSleep":
		if len(sig.Body) == 0 {
			return
		}
		preparing, _ := sig.Body[0].(bool)

		if preparing {
			cycleID := m.sleepCycleID.Add(1)
			m.inSleepCycle.Store(true)

			m.stateMutex.RLock()
			alreadyLocked := m.state.Locked
			m.stateMutex.RUnlock()

			if m.lockBeforeSuspend.Load() && !alreadyLocked {
				m.Lock()
			}

			// QML may lock and send lockerReady before the sleep command, so
			// PrepareForSleep must not wait for a second ready.
			if alreadyLocked || m.prelockedReady.Swap(false) {
				m.releaseSleepInhibitor()
			} else {
				readyCh := m.newLockerReadyCh()
				go func(id uint64, ch <-chan struct{}) {
					<-ch
					if m.inSleepCycle.Load() && m.sleepCycleID.Load() == id {
						m.releaseSleepInhibitor()
					}
				}(cycleID, readyCh)
			}
		} else {
			m.inSleepCycle.Store(false)
			m.prelockedReady.Store(false)
			m.signalLockerReady()
			m.refreshSessionBinding()
			m.acquireSleepInhibitor()
		}

		m.stateMutex.Lock()
		m.state.PreparingForSleep = preparing
		m.stateMutex.Unlock()
		m.notifySubscribers()

	case dbusPropsInterface + ".PropertiesChanged":
		m.handlePropertiesChanged(sig)

	case "org.freedesktop.DBus.NameOwnerChanged":
		if len(sig.Body) == 3 {
			name, _ := sig.Body[0].(string)
			oldOwner, _ := sig.Body[1].(string)
			newOwner, _ := sig.Body[2].(string)
			if name == dbusDest && oldOwner != "" && newOwner != "" {
				m.updateSessionState()
				if !m.inSleepCycle.Load() {
					m.acquireSleepInhibitor()
				}
				m.notifySubscribers()
			}
		}
	}
}

func (m *Manager) handlePropertiesChanged(sig *dbus.Signal) {
	if len(sig.Body) < 2 {
		return
	}

	iface, ok := sig.Body[0].(string)
	if !ok || iface != dbusSessionInterface {
		return
	}

	changes, ok := sig.Body[1].(map[string]dbus.Variant)
	if !ok {
		return
	}

	var needsUpdate bool

	for key, variant := range changes {
		switch key {
		case "Active":
			if val, ok := dbusutil.As[bool](variant); ok {
				m.stateMutex.Lock()
				m.state.Active = val
				m.stateMutex.Unlock()
				needsUpdate = true
			}
		case "IdleHint":
			if val, ok := dbusutil.As[bool](variant); ok {
				m.stateMutex.Lock()
				m.state.IdleHint = val
				m.stateMutex.Unlock()
				needsUpdate = true
			}
		case "IdleSinceHint":
			if val, ok := dbusutil.As[uint64](variant); ok {
				m.stateMutex.Lock()
				m.state.IdleSinceHint = val
				m.stateMutex.Unlock()
				needsUpdate = true
			}
		case "LockedHint":
			if val, ok := dbusutil.As[bool](variant); ok {
				m.stateMutex.Lock()
				m.state.LockedHint = val
				m.state.Locked = val
				m.stateMutex.Unlock()
				if !val {
					m.prelockedReady.Store(false)
				}
				needsUpdate = true
			}
		}
	}

	if needsUpdate {
		m.notifySubscribers()
	}
}
