package freedesktop

import (
	"fmt"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
	"github.com/godbus/dbus/v5"
)

func (m *Manager) SetIconFile(iconPath string) error {
	if !m.state.Accounts.Available || m.accountsObj == nil {
		return fmt.Errorf("accounts service not available")
	}

	err := m.accountsObj.Call(dbusAccountsUserInterface+".SetIconFile", 0, iconPath).Err
	if err != nil {
		return fmt.Errorf("failed to set icon file: %w", err)
	}

	m.updateAccountsState()
	return nil
}

func (m *Manager) SetRealName(name string) error {
	if !m.state.Accounts.Available || m.accountsObj == nil {
		return fmt.Errorf("accounts service not available")
	}

	err := m.accountsObj.Call(dbusAccountsUserInterface+".SetRealName", 0, name).Err
	if err != nil {
		return fmt.Errorf("failed to set real name: %w", err)
	}

	m.updateAccountsState()
	return nil
}

func (m *Manager) SetEmail(email string) error {
	if !m.state.Accounts.Available || m.accountsObj == nil {
		return fmt.Errorf("accounts service not available")
	}

	err := m.accountsObj.Call(dbusAccountsUserInterface+".SetEmail", 0, email).Err
	if err != nil {
		return fmt.Errorf("failed to set email: %w", err)
	}

	m.updateAccountsState()
	return nil
}

func (m *Manager) SetLanguage(language string) error {
	if !m.state.Accounts.Available || m.accountsObj == nil {
		return fmt.Errorf("accounts service not available")
	}

	err := m.accountsObj.Call(dbusAccountsUserInterface+".SetLanguage", 0, language).Err
	if err != nil {
		return fmt.Errorf("failed to set language: %w", err)
	}

	m.updateAccountsState()
	return nil
}

func (m *Manager) SetLocation(location string) error {
	if !m.state.Accounts.Available || m.accountsObj == nil {
		return fmt.Errorf("accounts service not available")
	}

	err := m.accountsObj.Call(dbusAccountsUserInterface+".SetLocation", 0, location).Err
	if err != nil {
		return fmt.Errorf("failed to set location: %w", err)
	}

	m.updateAccountsState()
	return nil
}

func (m *Manager) GetUserIconFile(username string) (string, error) {
	if m.systemConn == nil {
		return "", fmt.Errorf("accounts service not available")
	}

	accountsManager := m.systemConn.Object(dbusAccountsDest, dbus.ObjectPath(dbusAccountsPath))

	var userPath dbus.ObjectPath
	err := accountsManager.Call(dbusAccountsInterface+".FindUserByName", 0, username).Store(&userPath)
	if err != nil {
		return "", fmt.Errorf("user not found: %w", err)
	}

	userObj := m.systemConn.Object(dbusAccountsDest, userPath)
	variant, err := userObj.GetProperty(dbusAccountsUserInterface + ".IconFile")
	if err != nil {
		return "", err
	}

	var iconFile string
	if err := variant.Store(&iconFile); err != nil {
		return "", err
	}

	return iconFile, nil
}

func (m *Manager) SetIconTheme(iconTheme string) error {
	if err := utils.GsettingsSet("org.gnome.desktop.interface", "icon-theme", iconTheme); err != nil {
		return fmt.Errorf("failed to set icon theme: %w", err)
	}
	return nil
}
