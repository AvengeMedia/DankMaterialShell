package network

import "fmt"

func (b *IWDBackend) GetWiredConnections() ([]WiredConnection, error) {
	return nil, fmt.Errorf("wired connections not supported by iwd")
}

func (b *IWDBackend) GetWiredNetworkDetails(uuid string) (*WiredNetworkInfoResponse, error) {
	return nil, fmt.Errorf("wired connections not supported by iwd")
}

func (b *IWDBackend) ConnectEthernet() error {
	return fmt.Errorf("wired connections not supported by iwd")
}

func (b *IWDBackend) DisconnectEthernet() error {
	return fmt.Errorf("wired connections not supported by iwd")
}

func (b *IWDBackend) ActivateWiredConnection(uuid string) error {
	return fmt.Errorf("wired connections not supported by iwd")
}

func (b *IWDBackend) ListVPNProfiles() ([]VPNProfile, error) {
	return nil, fmt.Errorf("VPN not supported by iwd backend")
}

func (b *IWDBackend) ListActiveVPN() ([]VPNActive, error) {
	return nil, fmt.Errorf("VPN not supported by iwd backend")
}

func (b *IWDBackend) ConnectVPN(uuidOrName string, singleActive bool) error {
	return fmt.Errorf("VPN not supported by iwd backend")
}

func (b *IWDBackend) DisconnectVPN(uuidOrName string) error {
	return fmt.Errorf("VPN not supported by iwd backend")
}

func (b *IWDBackend) DisconnectAllVPN() error {
	return fmt.Errorf("VPN not supported by iwd backend")
}

func (b *IWDBackend) ClearVPNCredentials(uuidOrName string) error {
	return fmt.Errorf("VPN not supported by iwd backend")
}

func (b *IWDBackend) ScanWiFiDevice(device string) error {
	return b.ScanWiFi()
}

func (b *IWDBackend) DisconnectWiFiDevice(device string) error {
	return b.DisconnectWiFi()
}

func (b *IWDBackend) GetWiFiDevices() []WiFiDevice {
	b.stateMutex.RLock()
	defer b.stateMutex.RUnlock()
	return b.getWiFiDevicesLocked()
}

func (b *IWDBackend) getWiFiDevicesLocked() []WiFiDevice {
	if b.state.WiFiDevice == "" {
		return nil
	}

	stateStr := "disconnected"
	if b.state.WiFiConnected {
		stateStr = "connected"
	}

	return []WiFiDevice{{
		Name:      b.state.WiFiDevice,
		State:     stateStr,
		Connected: b.state.WiFiConnected,
		SSID:      b.state.WiFiSSID,
		Signal:    b.state.WiFiSignal,
		IP:        b.state.WiFiIP,
		Networks:  b.state.WiFiNetworks,
	}}
}
