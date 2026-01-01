package network

import (
	"fmt"
	"sync"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/Wifx/gonetworkmanager/v2"
	"github.com/godbus/dbus/v5"
)

const (
	dbusNMPath                 = "/org/freedesktop/NetworkManager"
	dbusNMInterface            = "org.freedesktop.NetworkManager"
	dbusNMDeviceInterface      = "org.freedesktop.NetworkManager.Device"
	dbusNMWirelessInterface    = "org.freedesktop.NetworkManager.Device.Wireless"
	dbusNMAccessPointInterface = "org.freedesktop.NetworkManager.AccessPoint"
	dbusPropsInterface         = "org.freedesktop.DBus.Properties"

	NmDeviceStateReasonWrongPassword        = 8
	NmDeviceStateReasonSupplicantTimeout    = 24
	NmDeviceStateReasonSupplicantFailed     = 25
	NmDeviceStateReasonSecretsRequired      = 7
	NmDeviceStateReasonNoSecrets            = 6
	NmDeviceStateReasonNoSsid               = 10
	NmDeviceStateReasonDhcpClientFailed     = 14
	NmDeviceStateReasonIpConfigUnavailable  = 18
	NmDeviceStateReasonSupplicantDisconnect = 23
	NmDeviceStateReasonCarrier              = 40
	NmDeviceStateReasonNewActivation        = 60
)

type wifiDeviceInfo struct {
	device    gonetworkmanager.Device
	wireless  gonetworkmanager.DeviceWireless
	name      string
	hwAddress string
}

type ethernetDeviceInfo struct {
	device    gonetworkmanager.Device
	wired     gonetworkmanager.DeviceWired
	name      string
	hwAddress string
}

type NetworkManagerBackend struct {
	nmConn          any
	ethernetDevice  any
	ethernetDevices map[string]*ethernetDeviceInfo
	wifiDevice      any
	settings        any
	wifiDev         any
	wifiDevices     map[string]*wifiDeviceInfo

	dbusConn *dbus.Conn
	signals  chan *dbus.Signal
	sigWG    sync.WaitGroup
	stopChan chan struct{}

	secretAgent  *SecretAgent
	promptBroker PromptBroker

	state      *BackendState
	stateMutex sync.RWMutex

	lastFailedSSID string
	lastFailedTime int64
	failedMutex    sync.RWMutex

	pendingVPNSave   *pendingVPNCredentials
	pendingVPNSaveMu sync.Mutex
	cachedVPNCreds   *cachedVPNCredentials
	cachedVPNCredsMu sync.Mutex
	cachedPKCS11PIN  *cachedPKCS11PIN
	cachedPKCS11Mu   sync.Mutex

	onStateChange func()
}

type pendingVPNCredentials struct {
	ConnectionPath string
	Username       string
	Password       string
	SavePassword   bool
}

type cachedVPNCredentials struct {
	ConnectionUUID string
	Password       string
	SavePassword   bool
}

type cachedPKCS11PIN struct {
	ConnectionUUID string
	PIN            string
}

func NewNetworkManagerBackend(nmConn ...gonetworkmanager.NetworkManager) (*NetworkManagerBackend, error) {
	var nm gonetworkmanager.NetworkManager
	var err error

	if len(nmConn) > 0 && nmConn[0] != nil {
		// Use injected connection (for testing)
		nm = nmConn[0]
	} else {
		// Create real connection
		nm, err = gonetworkmanager.NewNetworkManager()
		if err != nil {
			return nil, fmt.Errorf("failed to connect to NetworkManager: %w", err)
		}
	}

	backend := &NetworkManagerBackend{
		nmConn:          nm,
		stopChan:        make(chan struct{}),
		ethernetDevices: make(map[string]*ethernetDeviceInfo),
		wifiDevices:     make(map[string]*wifiDeviceInfo),
		state: &BackendState{
			Backend: "networkmanager",
		},
	}

	return backend, nil
}

func (b *NetworkManagerBackend) Initialize() error {
	nm := b.nmConn.(gonetworkmanager.NetworkManager)

	if s, err := gonetworkmanager.NewSettings(); err == nil {
		b.settings = s
	}

	devices, err := nm.GetDevices()
	if err != nil {
		return fmt.Errorf("failed to get devices: %w", err)
	}

	for _, dev := range devices {
		devType, err := dev.GetPropertyDeviceType()
		if err != nil {
			continue
		}

		switch devType {
		case gonetworkmanager.NmDeviceTypeEthernet:
			if managed, _ := dev.GetPropertyManaged(); !managed {
				continue
			}
			iface, err := dev.GetPropertyInterface()
			if err != nil {
				continue
			}
			w, err := gonetworkmanager.NewDeviceWired(dev.GetPath())
			if err != nil {
				continue
			}
			hwAddr, _ := w.GetPropertyHwAddress()

			b.ethernetDevices[iface] = &ethernetDeviceInfo{
				device:    dev,
				wired:     w,
				name:      iface,
				hwAddress: hwAddr,
			}

			if b.ethernetDevice == nil {
				b.ethernetDevice = dev
			}
			if err := b.updateEthernetState(); err != nil {
				continue
			}
			_, err = b.listEthernetConnections()
			if err != nil {
				return fmt.Errorf("failed to get wired configurations: %w", err)
			}

		case gonetworkmanager.NmDeviceTypeWifi:
			iface, err := dev.GetPropertyInterface()
			if err != nil {
				continue
			}
			w, err := gonetworkmanager.NewDeviceWireless(dev.GetPath())
			if err != nil {
				continue
			}
			hwAddr, _ := w.GetPropertyHwAddress()

			b.wifiDevices[iface] = &wifiDeviceInfo{
				device:    dev,
				wireless:  w,
				name:      iface,
				hwAddress: hwAddr,
			}

			if b.wifiDevice == nil {
				b.wifiDevice = dev
				b.wifiDev = w
			}
		}
	}

	wifiEnabled, err := nm.GetPropertyWirelessEnabled()
	if err == nil {
		b.stateMutex.Lock()
		b.state.WiFiEnabled = wifiEnabled
		b.stateMutex.Unlock()
	}

	if err := b.updateWiFiState(); err != nil {
		log.Warnf("Failed to update WiFi state: %v", err)
	}

	if wifiEnabled {
		if _, err := b.updateWiFiNetworks(); err != nil {
			log.Warnf("Failed to get initial networks: %v", err)
		}
		b.updateAllWiFiDevices()
	}

	b.updateAllEthernetDevices()

	if err := b.updatePrimaryConnection(); err != nil {
		return err
	}

	if _, err := b.ListVPNProfiles(); err != nil {
		log.Warnf("Failed to get initial VPN profiles: %v", err)
	}

	if _, err := b.ListActiveVPN(); err != nil {
		log.Warnf("Failed to get initial active VPNs: %v", err)
	}

	return nil
}

func (b *NetworkManagerBackend) Close() {
	close(b.stopChan)
	b.StopMonitoring()

	if b.secretAgent != nil {
		b.secretAgent.Close()
	}
}

func (b *NetworkManagerBackend) GetCurrentState() (*BackendState, error) {
	b.stateMutex.RLock()
	defer b.stateMutex.RUnlock()

	state := *b.state
	state.WiFiNetworks = append([]WiFiNetwork(nil), b.state.WiFiNetworks...)
	state.WiFiDevices = append([]WiFiDevice(nil), b.state.WiFiDevices...)
	state.WiredConnections = append([]WiredConnection(nil), b.state.WiredConnections...)
	state.EthernetDevices = append([]EthernetDevice(nil), b.state.EthernetDevices...)
	state.VPNProfiles = append([]VPNProfile(nil), b.state.VPNProfiles...)
	state.VPNActive = append([]VPNActive(nil), b.state.VPNActive...)

	return &state, nil
}

func (b *NetworkManagerBackend) StartMonitoring(onStateChange func()) error {
	b.onStateChange = onStateChange

	if err := b.startSecretAgent(); err != nil {
		return fmt.Errorf("failed to start secret agent: %w", err)
	}

	if err := b.startSignalPump(); err != nil {
		return err
	}

	return nil
}

func (b *NetworkManagerBackend) StopMonitoring() {
	b.stopSignalPump()
}

func (b *NetworkManagerBackend) GetPromptBroker() PromptBroker {
	return b.promptBroker
}

func (b *NetworkManagerBackend) SetPromptBroker(broker PromptBroker) error {
	if broker == nil {
		return fmt.Errorf("broker cannot be nil")
	}

	hadAgent := b.secretAgent != nil

	b.promptBroker = broker

	if b.secretAgent != nil {
		b.secretAgent.Close()
		b.secretAgent = nil
	}

	if hadAgent {
		return b.startSecretAgent()
	}

	return nil
}

func (b *NetworkManagerBackend) SubmitCredentials(token string, secrets map[string]string, save bool) error {
	if b.promptBroker == nil {
		return fmt.Errorf("prompt broker not initialized")
	}

	return b.promptBroker.Resolve(token, PromptReply{
		Secrets: secrets,
		Save:    save,
		Cancel:  false,
	})
}

func (b *NetworkManagerBackend) CancelCredentials(token string) error {
	if b.promptBroker == nil {
		return fmt.Errorf("prompt broker not initialized")
	}

	return b.promptBroker.Resolve(token, PromptReply{
		Cancel: true,
	})
}

func (b *NetworkManagerBackend) ensureWiFiDevice() error {
	if b.wifiDev != nil {
		return nil
	}

	if b.wifiDevice == nil {
		return fmt.Errorf("no WiFi device available")
	}

	dev := b.wifiDevice.(gonetworkmanager.Device)
	wifiDev, err := gonetworkmanager.NewDeviceWireless(dev.GetPath())
	if err != nil {
		return fmt.Errorf("failed to get wireless device: %w", err)
	}
	b.wifiDev = wifiDev
	return nil
}

func (b *NetworkManagerBackend) startSecretAgent() error {
	if b.promptBroker == nil {
		return fmt.Errorf("prompt broker not set")
	}

	agent, err := NewSecretAgent(b.promptBroker, nil, b)
	if err != nil {
		return err
	}

	b.secretAgent = agent
	return nil
}

func (b *NetworkManagerBackend) getActiveConnections() (map[string]bool, error) {
	nm := b.nmConn.(gonetworkmanager.NetworkManager)

	activeUUIDs := make(map[string]bool)

	activeConns, err := nm.GetPropertyActiveConnections()
	if err != nil {
		return activeUUIDs, fmt.Errorf("failed to get active connections: %w", err)
	}

	for _, activeConn := range activeConns {
		connType, err := activeConn.GetPropertyType()
		if err != nil {
			continue
		}

		if connType != "802-3-ethernet" {
			continue
		}

		state, err := activeConn.GetPropertyState()
		if err != nil {
			continue
		}
		if state < 1 || state > 2 {
			continue
		}

		uuid, err := activeConn.GetPropertyUUID()
		if err != nil {
			continue
		}
		activeUUIDs[uuid] = true
	}
	return activeUUIDs, nil
}
