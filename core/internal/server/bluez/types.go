package bluez

import (
	"sync"

	"github.com/AvengeMedia/DankMaterialShell/core/pkg/syncmap"
	"github.com/godbus/dbus/v5"
)

type BluetoothState struct {
	Powered          bool     `json:"powered"`
	Discovering      bool     `json:"discovering"`
	Devices          []Device `json:"devices"`
	PairedDevices    []Device `json:"pairedDevices"`
	ConnectedDevices []Device `json:"connectedDevices"`
}

type Device struct {
	Path          string `json:"path"`
	Address       string `json:"address"`
	Name          string `json:"name"`
	Alias         string `json:"alias"`
	Paired        bool   `json:"paired"`
	Trusted       bool   `json:"trusted"`
	Blocked       bool   `json:"blocked"`
	Connected     bool   `json:"connected"`
	Class         uint32 `json:"class"`
	Icon          string `json:"icon"`
	RSSI          int16  `json:"rssi"`
	LegacyPairing bool   `json:"legacyPairing"`
}

type PromptRequest struct {
	DevicePath  string   `json:"devicePath"`
	DeviceName  string   `json:"deviceName"`
	DeviceAddr  string   `json:"deviceAddr"`
	RequestType string   `json:"requestType"`
	Fields      []string `json:"fields"`
	Hints       []string `json:"hints"`
	Passkey     *uint32  `json:"passkey,omitempty"`
}

type PromptReply struct {
	Secrets map[string]string `json:"secrets"`
	Accept  bool              `json:"accept"`
	Cancel  bool              `json:"cancel"`
}

type PairingPrompt struct {
	Token       string   `json:"token"`
	DevicePath  string   `json:"devicePath"`
	DeviceName  string   `json:"deviceName"`
	DeviceAddr  string   `json:"deviceAddr"`
	RequestType string   `json:"requestType"`
	Fields      []string `json:"fields"`
	Hints       []string `json:"hints"`
	Passkey     *uint32  `json:"passkey,omitempty"`
}

type Manager struct {
	state              *BluetoothState
	stateMutex         sync.RWMutex
	subscribers        syncmap.Map[string, chan BluetoothState]
	stopChan           chan struct{}
	dbusConn           *dbus.Conn
	signals            chan *dbus.Signal
	sigWG              sync.WaitGroup
	agent              *BluezAgent
	promptBroker       PromptBroker
	pairingSubscribers syncmap.Map[string, chan PairingPrompt]
	dirty              chan struct{}
	notifierWg         sync.WaitGroup
	lastNotifiedState  *BluetoothState
	adapterPath        dbus.ObjectPath
	pendingPairings    syncmap.Map[string, bool]
	eventQueue         chan func()
	eventWg            sync.WaitGroup
}
