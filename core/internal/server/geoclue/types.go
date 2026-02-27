package geoclue

import (
	"sync"

	"github.com/AvengeMedia/DankMaterialShell/core/pkg/syncmap"
	"github.com/godbus/dbus/v5"
)

type State struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

type Manager struct {
	state      *State
	stateMutex sync.RWMutex

	dbusConn   *dbus.Conn
	clientPath dbus.ObjectPath
	signals    chan *dbus.Signal

	stopChan chan struct{}
	sigWG    sync.WaitGroup

	subscribers  syncmap.Map[string, chan State]
	dirty        chan struct{}
	notifierWg   sync.WaitGroup
	lastNotified *State
}
