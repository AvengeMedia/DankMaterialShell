package freedesktop

import (
	"sync"

	"github.com/AvengeMedia/DankMaterialShell/core/pkg/syncmap"
	"github.com/godbus/dbus/v5"
)

type AccountsState struct {
	Available     bool   `json:"available"`
	UserPath      string `json:"userPath"`
	IconFile      string `json:"iconFile"`
	RealName      string `json:"realName"`
	UserName      string `json:"userName"`
	AccountType   int32  `json:"accountType"`
	HomeDirectory string `json:"homeDirectory"`
	Shell         string `json:"shell"`
	Email         string `json:"email"`
	Language      string `json:"language"`
	Location      string `json:"location"`
	Locked        bool   `json:"locked"`
	PasswordMode  int32  `json:"passwordMode"`
	UID           uint64 `json:"uid"`
}

type SettingsState struct {
	Available   bool   `json:"available"`
	ColorScheme uint32 `json:"colorScheme"`
}

type FreedeskState struct {
	Accounts AccountsState `json:"accounts"`
	Settings SettingsState `json:"settings"`
}

type Manager struct {
	state       *FreedeskState
	stateMutex  sync.RWMutex
	systemConn  *dbus.Conn
	sessionConn *dbus.Conn
	accountsObj dbus.BusObject
	settingsObj dbus.BusObject
	currentUID  uint64
	subscribers syncmap.Map[string, chan FreedeskState]
}
