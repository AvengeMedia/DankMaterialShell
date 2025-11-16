package freedesktop

import (
	"context"
	"fmt"
	"os"
	"sync"

	"github.com/godbus/dbus/v5"
)

func NewManager() (*Manager, error) {
	systemConn, err := dbus.ConnectSystemBus()
	if err != nil {
		return nil, fmt.Errorf("failed to connect to system bus: %w", err)
	}

	sessionConn, err := dbus.ConnectSessionBus()
	if err != nil {
		sessionConn = nil
	}

	m := &Manager{
		state: &FreedeskState{
			Accounts: AccountsState{},
			Settings: SettingsState{},
		},
		stateMutex:  sync.RWMutex{},
		systemConn:  systemConn,
		sessionConn: sessionConn,
		currentUID:  uint64(os.Getuid()),
	}

	m.initializeAccounts()
	m.initializeSettings()

	return m, nil
}

func (m *Manager) initializeAccounts() error {
	accountsManager := m.systemConn.Object(dbusAccountsDest, dbus.ObjectPath(dbusAccountsPath))

	var userPath dbus.ObjectPath
	err := accountsManager.Call(dbusAccountsInterface+".FindUserById", 0, int64(m.currentUID)).Store(&userPath)
	if err != nil {
		m.stateMutex.Lock()
		m.state.Accounts.Available = false
		m.stateMutex.Unlock()
		return err
	}

	m.accountsObj = m.systemConn.Object(dbusAccountsDest, userPath)

	m.stateMutex.Lock()
	m.state.Accounts.Available = true
	m.state.Accounts.UserPath = string(userPath)
	m.state.Accounts.UID = m.currentUID
	m.stateMutex.Unlock()

	if err := m.updateAccountsState(); err != nil {
		return fmt.Errorf("failed to update accounts state: %w", err)
	}

	return nil
}

func (m *Manager) initializeSettings() error {
	if m.sessionConn == nil {
		m.stateMutex.Lock()
		m.state.Settings.Available = false
		m.stateMutex.Unlock()
		return fmt.Errorf("no session bus connection")
	}

	m.settingsObj = m.sessionConn.Object(dbusPortalDest, dbus.ObjectPath(dbusPortalPath))

	var variant dbus.Variant
	err := m.settingsObj.Call(dbusPortalSettingsInterface+".ReadOne", 0, "org.freedesktop.appearance", "color-scheme").Store(&variant)
	if err != nil {
		m.stateMutex.Lock()
		m.state.Settings.Available = false
		m.stateMutex.Unlock()
		return err
	}

	m.stateMutex.Lock()
	m.state.Settings.Available = true
	m.stateMutex.Unlock()

	if err := m.updateSettingsState(); err != nil {
		return fmt.Errorf("failed to update settings state: %w", err)
	}

	return nil
}

func (m *Manager) updateAccountsState() error {
	if !m.state.Accounts.Available || m.accountsObj == nil {
		return fmt.Errorf("accounts service not available")
	}

	ctx := context.Background()
	props, err := m.getAccountProperties(ctx)
	if err != nil {
		return err
	}

	m.stateMutex.Lock()
	defer m.stateMutex.Unlock()

	if v, ok := props["IconFile"]; ok {
		if val, ok := v.Value().(string); ok {
			m.state.Accounts.IconFile = val
		}
	}
	if v, ok := props["RealName"]; ok {
		if val, ok := v.Value().(string); ok {
			m.state.Accounts.RealName = val
		}
	}
	if v, ok := props["UserName"]; ok {
		if val, ok := v.Value().(string); ok {
			m.state.Accounts.UserName = val
		}
	}
	if v, ok := props["AccountType"]; ok {
		if val, ok := v.Value().(int32); ok {
			m.state.Accounts.AccountType = val
		}
	}
	if v, ok := props["HomeDirectory"]; ok {
		if val, ok := v.Value().(string); ok {
			m.state.Accounts.HomeDirectory = val
		}
	}
	if v, ok := props["Shell"]; ok {
		if val, ok := v.Value().(string); ok {
			m.state.Accounts.Shell = val
		}
	}
	if v, ok := props["Email"]; ok {
		if val, ok := v.Value().(string); ok {
			m.state.Accounts.Email = val
		}
	}
	if v, ok := props["Language"]; ok {
		if val, ok := v.Value().(string); ok {
			m.state.Accounts.Language = val
		}
	}
	if v, ok := props["Location"]; ok {
		if val, ok := v.Value().(string); ok {
			m.state.Accounts.Location = val
		}
	}
	if v, ok := props["Locked"]; ok {
		if val, ok := v.Value().(bool); ok {
			m.state.Accounts.Locked = val
		}
	}
	if v, ok := props["PasswordMode"]; ok {
		if val, ok := v.Value().(int32); ok {
			m.state.Accounts.PasswordMode = val
		}
	}

	return nil
}

func (m *Manager) updateSettingsState() error {
	if !m.state.Settings.Available || m.settingsObj == nil {
		return fmt.Errorf("settings portal not available")
	}

	var variant dbus.Variant
	err := m.settingsObj.Call(dbusPortalSettingsInterface+".ReadOne", 0, "org.freedesktop.appearance", "color-scheme").Store(&variant)
	if err != nil {
		return err
	}

	if colorScheme, ok := variant.Value().(uint32); ok {
		m.stateMutex.Lock()
		m.state.Settings.ColorScheme = colorScheme
		m.stateMutex.Unlock()
	}

	return nil
}

func (m *Manager) getAccountProperties(ctx context.Context) (map[string]dbus.Variant, error) {
	var props map[string]dbus.Variant
	err := m.accountsObj.CallWithContext(ctx, dbusPropsInterface+".GetAll", 0, dbusAccountsUserInterface).Store(&props)
	if err != nil {
		return nil, err
	}
	return props, nil
}

func (m *Manager) GetState() FreedeskState {
	m.stateMutex.RLock()
	defer m.stateMutex.RUnlock()
	return *m.state
}

func (m *Manager) Subscribe(id string) chan FreedeskState {
	ch := make(chan FreedeskState, 64)
	m.subscribers.Store(id, ch)
	return ch
}

func (m *Manager) Unsubscribe(id string) {
	if val, ok := m.subscribers.LoadAndDelete(id); ok {
		close(val)
	}
}

func (m *Manager) NotifySubscribers() {
	state := m.GetState()
	m.subscribers.Range(func(key string, ch chan FreedeskState) bool {
		select {
		case ch <- state:
		default:
		}
		return true
	})
}

func (m *Manager) Close() {
	m.subscribers.Range(func(key string, ch chan FreedeskState) bool {
		close(ch)
		m.subscribers.Delete(key)
		return true
	})

	if m.systemConn != nil {
		m.systemConn.Close()
	}
	if m.sessionConn != nil {
		m.sessionConn.Close()
	}
}
