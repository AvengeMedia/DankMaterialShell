package loginctl

import (
	"fmt"
)

func (m *Manager) Lock() error {
	if m.sessionObj == nil {
		return fmt.Errorf("session object not available")
	}
	err := m.sessionObj.Call(dbusSessionInterface+".Lock", 0).Err
	if err != nil {
		if refreshErr := m.refreshSessionBinding(); refreshErr == nil {
			err = m.sessionObj.Call(dbusSessionInterface+".Lock", 0).Err
		}
		if err != nil {
			return fmt.Errorf("failed to lock session: %w", err)
		}
	}
	return nil
}

func (m *Manager) Unlock() error {
	err := m.sessionObj.Call(dbusSessionInterface+".Unlock", 0).Err
	if err != nil {
		if refreshErr := m.refreshSessionBinding(); refreshErr == nil {
			err = m.sessionObj.Call(dbusSessionInterface+".Unlock", 0).Err
		}
		if err != nil {
			return fmt.Errorf("failed to unlock session: %w", err)
		}
	}
	return nil
}

func (m *Manager) Activate() error {
	err := m.sessionObj.Call(dbusSessionInterface+".Activate", 0).Err
	if err != nil {
		if refreshErr := m.refreshSessionBinding(); refreshErr == nil {
			err = m.sessionObj.Call(dbusSessionInterface+".Activate", 0).Err
		}
		if err != nil {
			return fmt.Errorf("failed to activate session: %w", err)
		}
	}
	return nil
}

func (m *Manager) SetLockedHint(locked bool) error {
	err := m.sessionObj.Call(dbusSessionInterface+".SetLockedHint", 0, locked).Err
	if err != nil {
		if refreshErr := m.refreshSessionBinding(); refreshErr == nil {
			err = m.sessionObj.Call(dbusSessionInterface+".SetLockedHint", 0, locked).Err
		}
		if err != nil {
			return fmt.Errorf("failed to set locked hint: %w", err)
		}
	}
	return nil
}

func (m *Manager) SetIdleHint(idle bool) error {
	err := m.sessionObj.Call(dbusSessionInterface+".SetIdleHint", 0, idle).Err
	if err != nil {
		if refreshErr := m.refreshSessionBinding(); refreshErr == nil {
			err = m.sessionObj.Call(dbusSessionInterface+".SetIdleHint", 0, idle).Err
		}
		if err != nil {
			return fmt.Errorf("failed to set idle hint: %w", err)
		}
	}
	return nil
}

func (m *Manager) Terminate() error {
	err := m.sessionObj.Call(dbusSessionInterface+".Terminate", 0).Err
	if err != nil {
		if refreshErr := m.refreshSessionBinding(); refreshErr == nil {
			err = m.sessionObj.Call(dbusSessionInterface+".Terminate", 0).Err
		}
		if err != nil {
			return fmt.Errorf("failed to terminate session: %w", err)
		}
	}
	return nil
}

func (m *Manager) SetLockBeforeSuspend(enabled bool) {
	m.lockBeforeSuspend.Store(enabled)
}

func (m *Manager) SetSleepInhibitorEnabled(enabled bool) {
	m.sleepInhibitorEnabled.Store(enabled)
	if enabled {
		// Re-acquire inhibitor if enabled
		m.acquireSleepInhibitor()
	} else {
		// Release inhibitor if disabled
		m.releaseSleepInhibitor()
	}
}

// SetLidInhibitorEnabled acquires or releases a block-mode handle-lid-switch
// inhibitor so logind ignores lid close while keep awake is active. logind
// always honors handle-lid-switch locks regardless of LidSwitchIgnoreInhibited.
func (m *Manager) SetLidInhibitorEnabled(enabled bool) error {
	m.lidInhibitMu.Lock()
	defer m.lidInhibitMu.Unlock()

	if !enabled {
		m.releaseLidInhibitorLocked()
		return nil
	}

	if m.lidInhibitFile != nil {
		return nil
	}

	if m.managerObj == nil {
		return fmt.Errorf("manager object not available")
	}

	file, err := m.inhibit("handle-lid-switch", "DankMaterialShell", "Keep awake", "block")
	if err != nil {
		return fmt.Errorf("failed to acquire lid inhibitor: %w", err)
	}

	m.lidInhibitFile = file
	return nil
}

func (m *Manager) releaseLidInhibitor() {
	m.lidInhibitMu.Lock()
	defer m.lidInhibitMu.Unlock()
	m.releaseLidInhibitorLocked()
}

func (m *Manager) releaseLidInhibitorLocked() {
	if m.lidInhibitFile != nil {
		m.lidInhibitFile.Close()
		m.lidInhibitFile = nil
	}
}
