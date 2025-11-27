package network

import (
	"fmt"
	"sync"
	"time"

	"github.com/godbus/dbus/v5"
)

const (
	iwdBusName               = "net.connman.iwd"
	iwdObjectPath            = "/"
	iwdAdapterInterface      = "net.connman.iwd.Adapter"
	iwdDeviceInterface       = "net.connman.iwd.Device"
	iwdStationInterface      = "net.connman.iwd.Station"
	iwdNetworkInterface      = "net.connman.iwd.Network"
	iwdKnownNetworkInterface = "net.connman.iwd.KnownNetwork"
	dbusObjectManager        = "org.freedesktop.DBus.ObjectManager"
	dbusPropertiesInterface  = "org.freedesktop.DBus.Properties"
)

type connectAttempt struct {
	ssid           string
	netPath        dbus.ObjectPath
	start          time.Time
	deadline       time.Time
	sawAuthish     bool
	connectedAt    time.Time
	sawIPConfig    bool
	sawPromptRetry bool
	finalized      bool
	mu             sync.Mutex
}

type IWDBackend struct {
	conn          *dbus.Conn
	state         *BackendState
	stateMutex    sync.RWMutex
	promptBroker  PromptBroker
	onStateChange func()

	devicePath  dbus.ObjectPath
	stationPath dbus.ObjectPath
	adapterPath dbus.ObjectPath

	iwdAgent *IWDAgent

	stopChan      chan struct{}
	sigWG         sync.WaitGroup
	curAttempt    *connectAttempt
	attemptMutex  sync.RWMutex
	recentScans   map[string]time.Time
	recentScansMu sync.Mutex
}

func NewIWDBackend() (*IWDBackend, error) {
	backend := &IWDBackend{
		state: &BackendState{
			Backend:     "iwd",
			WiFiEnabled: true,
		},
		stopChan:    make(chan struct{}),
		recentScans: make(map[string]time.Time),
	}

	return backend, nil
}

func (b *IWDBackend) Initialize() error {
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		return fmt.Errorf("failed to connect to system bus: %w", err)
	}
	b.conn = conn

	if err := b.discoverDevices(); err != nil {
		conn.Close()
		return fmt.Errorf("failed to discover iwd devices: %w", err)
	}

	if err := b.updateState(); err != nil {
		conn.Close()
		return fmt.Errorf("failed to get initial state: %w", err)
	}

	return nil
}

func (b *IWDBackend) Close() {
	close(b.stopChan)
	b.sigWG.Wait()

	if b.iwdAgent != nil {
		b.iwdAgent.Close()
	}

	if b.conn != nil {
		b.conn.Close()
	}
}

func (b *IWDBackend) discoverDevices() error {
	obj := b.conn.Object(iwdBusName, iwdObjectPath)

	var objects map[dbus.ObjectPath]map[string]map[string]dbus.Variant
	err := obj.Call(dbusObjectManager+".GetManagedObjects", 0).Store(&objects)
	if err != nil {
		return fmt.Errorf("failed to get managed objects: %w", err)
	}

	for path, interfaces := range objects {
		if _, hasStation := interfaces[iwdStationInterface]; hasStation {
			b.stationPath = path
		}
		if _, hasDevice := interfaces[iwdDeviceInterface]; hasDevice {
			b.devicePath = path

			if devProps, ok := interfaces[iwdDeviceInterface]; ok {
				if nameVar, ok := devProps["Name"]; ok {
					if name, ok := nameVar.Value().(string); ok {
						b.stateMutex.Lock()
						b.state.WiFiDevice = name
						b.stateMutex.Unlock()
					}
				}
			}
		}
		if _, hasAdapter := interfaces[iwdAdapterInterface]; hasAdapter {
			b.adapterPath = path
		}
	}

	if b.stationPath == "" || b.devicePath == "" {
		return fmt.Errorf("no WiFi device found")
	}

	return nil
}

func (b *IWDBackend) GetCurrentState() (*BackendState, error) {
	b.stateMutex.RLock()
	defer b.stateMutex.RUnlock()

	state := *b.state
	state.WiFiNetworks = append([]WiFiNetwork(nil), b.state.WiFiNetworks...)
	state.WiredConnections = append([]WiredConnection(nil), b.state.WiredConnections...)
	state.WiFiDevices = b.getWiFiDevicesLocked()

	return &state, nil
}

func (b *IWDBackend) OnUserCanceledPrompt() {
	b.stateMutex.RLock()
	cancelledSSID := b.state.ConnectingSSID
	b.stateMutex.RUnlock()

	b.setConnectError("user-canceled")

	if cancelledSSID != "" {
		if err := b.ForgetWiFiNetwork(cancelledSSID); err != nil {
		}
	}

	if b.onStateChange != nil {
		b.onStateChange()
	}
}

func (b *IWDBackend) OnPromptRetry(ssid string) {
	b.attemptMutex.RLock()
	att := b.curAttempt
	b.attemptMutex.RUnlock()

	if att != nil && att.ssid == ssid {
		att.mu.Lock()
		att.sawPromptRetry = true
		att.mu.Unlock()
	}
}

func (b *IWDBackend) MarkIPConfigSeen() {
	b.attemptMutex.RLock()
	att := b.curAttempt
	b.attemptMutex.RUnlock()
	if att != nil {
		att.mu.Lock()
		att.sawIPConfig = true
		att.mu.Unlock()
	}
}

func (b *IWDBackend) GetPromptBroker() PromptBroker {
	return b.promptBroker
}

func (b *IWDBackend) SetPromptBroker(broker PromptBroker) error {
	if broker == nil {
		return fmt.Errorf("broker cannot be nil")
	}

	b.promptBroker = broker
	return nil
}

func (b *IWDBackend) SubmitCredentials(token string, secrets map[string]string, save bool) error {
	if b.promptBroker == nil {
		return fmt.Errorf("prompt broker not initialized")
	}

	return b.promptBroker.Resolve(token, PromptReply{
		Secrets: secrets,
		Save:    save,
		Cancel:  false,
	})
}

func (b *IWDBackend) CancelCredentials(token string) error {
	if b.promptBroker == nil {
		return fmt.Errorf("prompt broker not initialized")
	}

	return b.promptBroker.Resolve(token, PromptReply{
		Cancel: true,
	})
}

func (b *IWDBackend) StopMonitoring() {
	select {
	case <-b.stopChan:
		return
	default:
		close(b.stopChan)
	}
	b.sigWG.Wait()
}
