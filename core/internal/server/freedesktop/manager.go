package freedesktop

import (
	"context"
	"fmt"
	"os"
	"sync"

	"github.com/AvengeMedia/DankMaterialShell/core/pkg/dbusutil"
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
			Accounts:    AccountsState{},
			Settings:    SettingsState{},
			Screensaver: ScreensaverState{},
		},
		stateMutex:  sync.RWMutex{},
		systemConn:  systemConn,
		sessionConn: sessionConn,
		currentUID:  uint64(os.Getuid()),
	}

	m.initializeAccounts()
	m.initializeSettings()
	m.initializeScreensaver()

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

	m.state.Accounts.IconFile = dbusutil.GetOr(props, "IconFile", "")
	m.state.Accounts.RealName = dbusutil.GetOr(props, "RealName", "")
	m.state.Accounts.UserName = dbusutil.GetOr(props, "UserName", "")
	m.state.Accounts.AccountType = dbusutil.GetOr(props, "AccountType", int32(0))
	m.state.Accounts.HomeDirectory = dbusutil.GetOr(props, "HomeDirectory", "")
	m.state.Accounts.Shell = dbusutil.GetOr(props, "Shell", "")
	m.state.Accounts.Email = dbusutil.GetOr(props, "Email", "")
	m.state.Accounts.Language = dbusutil.GetOr(props, "Language", "")
	m.state.Accounts.Location = dbusutil.GetOr(props, "Location", "")
	m.state.Accounts.Locked = dbusutil.GetOr(props, "Locked", false)
	m.state.Accounts.PasswordMode = dbusutil.GetOr(props, "PasswordMode", int32(0))

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

	if colorScheme, ok := dbusutil.As[uint32](variant); ok {
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

	m.screensaverSubscribers.Range(func(key string, ch chan ScreensaverState) bool {
		close(ch)
		m.screensaverSubscribers.Delete(key)
		return true
	})

	if m.systemConn != nil {
		m.systemConn.Close()
	}
	if m.sessionConn != nil {
		m.sessionConn.Close()
	}
}
