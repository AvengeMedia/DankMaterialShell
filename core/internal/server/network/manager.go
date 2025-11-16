package network

import (
	"fmt"
	"sync"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
)

func NewManager() (*Manager, error) {
	detection, err := DetectNetworkStack()
	if err != nil {
		return nil, fmt.Errorf("failed to detect network stack: %w", err)
	}

	log.Infof("Network backend detection: %s", detection.ChosenReason)

	var backend Backend
	switch detection.Backend {
	case BackendNetworkManager:
		nm, err := NewNetworkManagerBackend()
		if err != nil {
			return nil, fmt.Errorf("failed to create NetworkManager backend: %w", err)
		}
		backend = nm

	case BackendIwd:
		iwd, err := NewIWDBackend()
		if err != nil {
			return nil, fmt.Errorf("failed to create iwd backend: %w", err)
		}
		backend = iwd

	case BackendNetworkd:
		if detection.HasIwd && !detection.HasNM {
			wifi, err := NewIWDBackend()
			if err != nil {
				return nil, fmt.Errorf("failed to create iwd backend: %w", err)
			}
			l3, err := NewSystemdNetworkdBackend()
			if err != nil {
				return nil, fmt.Errorf("failed to create networkd backend: %w", err)
			}
			hybrid, err := NewHybridIwdNetworkdBackend(wifi, l3)
			if err != nil {
				return nil, fmt.Errorf("failed to create hybrid backend: %w", err)
			}
			backend = hybrid
		} else {
			nd, err := NewSystemdNetworkdBackend()
			if err != nil {
				return nil, fmt.Errorf("failed to create networkd backend: %w", err)
			}
			backend = nd
		}

	default:
		return nil, fmt.Errorf("no supported network backend found: %s", detection.ChosenReason)
	}

	m := &Manager{
		backend: backend,
		state: &NetworkState{
			NetworkStatus: StatusDisconnected,
			Preference:    PreferenceAuto,
			WiFiNetworks:  []WiFiNetwork{},
		},
		stateMutex: sync.RWMutex{},

		stopChan: make(chan struct{}),
		dirty:    make(chan struct{}, 1),
	}

	broker := NewSubscriptionBroker(m.broadcastCredentialPrompt)
	if err := backend.SetPromptBroker(broker); err != nil {
		return nil, fmt.Errorf("failed to set prompt broker: %w", err)
	}

	if err := backend.Initialize(); err != nil {
		return nil, fmt.Errorf("failed to initialize backend: %w", err)
	}

	if err := m.syncStateFromBackend(); err != nil {
		return nil, fmt.Errorf("failed to sync initial state: %w", err)
	}

	m.notifierWg.Add(1)
	go m.notifier()

	if err := backend.StartMonitoring(m.onBackendStateChange); err != nil {
		m.Close()
		return nil, fmt.Errorf("failed to start monitoring: %w", err)
	}

	return m, nil
}

func (m *Manager) syncStateFromBackend() error {
	backendState, err := m.backend.GetCurrentState()
	if err != nil {
		return err
	}

	m.stateMutex.Lock()
	m.state.Backend = backendState.Backend
	m.state.NetworkStatus = backendState.NetworkStatus
	m.state.EthernetIP = backendState.EthernetIP
	m.state.EthernetDevice = backendState.EthernetDevice
	m.state.EthernetConnected = backendState.EthernetConnected
	m.state.EthernetConnectionUuid = backendState.EthernetConnectionUuid
	m.state.WiFiIP = backendState.WiFiIP
	m.state.WiFiDevice = backendState.WiFiDevice
	m.state.WiFiConnected = backendState.WiFiConnected
	m.state.WiFiEnabled = backendState.WiFiEnabled
	m.state.WiFiSSID = backendState.WiFiSSID
	m.state.WiFiBSSID = backendState.WiFiBSSID
	m.state.WiFiSignal = backendState.WiFiSignal
	m.state.WiFiNetworks = backendState.WiFiNetworks
	m.state.WiredConnections = backendState.WiredConnections
	m.state.VPNProfiles = backendState.VPNProfiles
	m.state.VPNActive = backendState.VPNActive
	m.state.IsConnecting = backendState.IsConnecting
	m.state.ConnectingSSID = backendState.ConnectingSSID
	m.state.LastError = backendState.LastError
	m.stateMutex.Unlock()

	return nil
}

func (m *Manager) onBackendStateChange() {
	if err := m.syncStateFromBackend(); err != nil {
		log.Errorf("failed to sync state from backend: %v", err)
	}
	m.notifySubscribers()
}

func signalChangeSignificant(old, new uint8) bool {
	if old == 0 || new == 0 {
		return true
	}
	diff := int(new) - int(old)
	if diff < 0 {
		diff = -diff
	}
	return diff >= 5
}

func (m *Manager) snapshotState() NetworkState {
	m.stateMutex.RLock()
	defer m.stateMutex.RUnlock()
	s := *m.state
	s.WiFiNetworks = append([]WiFiNetwork(nil), m.state.WiFiNetworks...)
	s.WiredConnections = append([]WiredConnection(nil), m.state.WiredConnections...)
	s.VPNProfiles = append([]VPNProfile(nil), m.state.VPNProfiles...)
	s.VPNActive = append([]VPNActive(nil), m.state.VPNActive...)
	return s
}

func stateChangedMeaningfully(old, new *NetworkState) bool {
	if old.NetworkStatus != new.NetworkStatus {
		return true
	}
	if old.Preference != new.Preference {
		return true
	}
	if old.EthernetConnected != new.EthernetConnected {
		return true
	}
	if old.EthernetIP != new.EthernetIP {
		return true
	}
	if old.WiFiConnected != new.WiFiConnected {
		return true
	}
	if old.WiFiEnabled != new.WiFiEnabled {
		return true
	}
	if old.WiFiSSID != new.WiFiSSID {
		return true
	}
	if old.WiFiBSSID != new.WiFiBSSID {
		return true
	}
	if old.WiFiIP != new.WiFiIP {
		return true
	}
	if !signalChangeSignificant(old.WiFiSignal, new.WiFiSignal) {
		if old.WiFiSignal != new.WiFiSignal {
			return false
		}
	} else if old.WiFiSignal != new.WiFiSignal {
		return true
	}
	if old.IsConnecting != new.IsConnecting {
		return true
	}
	if old.ConnectingSSID != new.ConnectingSSID {
		return true
	}
	if old.LastError != new.LastError {
		return true
	}
	if len(old.WiFiNetworks) != len(new.WiFiNetworks) {
		return true
	}
	if len(old.WiredConnections) != len(new.WiredConnections) {
		return true
	}

	for i := range old.WiFiNetworks {
		oldNet := &old.WiFiNetworks[i]
		newNet := &new.WiFiNetworks[i]
		if oldNet.SSID != newNet.SSID {
			return true
		}
		if oldNet.Connected != newNet.Connected {
			return true
		}
		if oldNet.Saved != newNet.Saved {
			return true
		}
		if oldNet.Autoconnect != newNet.Autoconnect {
			return true
		}
	}

	for i := range old.WiredConnections {
		oldNet := &old.WiredConnections[i]
		newNet := &new.WiredConnections[i]
		if oldNet.ID != newNet.ID {
			return true
		}
		if oldNet.IsActive != newNet.IsActive {
			return true
		}
	}

	// Check VPN profiles count
	if len(old.VPNProfiles) != len(new.VPNProfiles) {
		return true
	}

	// Check active VPN connections count or state
	if len(old.VPNActive) != len(new.VPNActive) {
		return true
	}

	// Check if any active VPN changed
	for i := range old.VPNActive {
		oldVPN := &old.VPNActive[i]
		newVPN := &new.VPNActive[i]
		if oldVPN.UUID != newVPN.UUID {
			return true
		}
		if oldVPN.State != newVPN.State {
			return true
		}
	}

	return false
}

func (m *Manager) GetState() NetworkState {
	return m.snapshotState()
}

func (m *Manager) Subscribe(id string) chan NetworkState {
	ch := make(chan NetworkState, 64)
	m.subscribers.Store(id, ch)
	return ch
}

func (m *Manager) Unsubscribe(id string) {
	if val, ok := m.subscribers.LoadAndDelete(id); ok {
		close(val)
	}
}

func (m *Manager) SubscribeCredentials(id string) chan CredentialPrompt {
	ch := make(chan CredentialPrompt, 16)
	m.credentialSubscribers.Store(id, ch)
	return ch
}

func (m *Manager) UnsubscribeCredentials(id string) {
	if ch, ok := m.credentialSubscribers.LoadAndDelete(id); ok {
		close(ch)
	}
}

func (m *Manager) broadcastCredentialPrompt(prompt CredentialPrompt) {
	m.credentialSubscribers.Range(func(key string, ch chan CredentialPrompt) bool {
		select {
		case ch <- prompt:
		default:
		}
		return true
	})
}

func (m *Manager) notifier() {
	defer m.notifierWg.Done()
	const minGap = 100 * time.Millisecond
	timer := time.NewTimer(minGap)
	timer.Stop()
	var pending bool
	for {
		select {
		case <-m.stopChan:
			timer.Stop()
			return
		case <-m.dirty:
			if pending {
				continue
			}
			pending = true
			timer.Reset(minGap)
		case <-timer.C:
			if !pending {
				continue
			}

			currentState := m.snapshotState()

			if m.lastNotifiedState != nil && !stateChangedMeaningfully(m.lastNotifiedState, &currentState) {
				pending = false
				continue
			}

			m.subscribers.Range(func(key string, ch chan NetworkState) bool {
				select {
				case ch <- currentState:
				default:
				}
				return true
			})

			stateCopy := currentState
			m.lastNotifiedState = &stateCopy
			pending = false
		}
	}
}

func (m *Manager) notifySubscribers() {
	select {
	case m.dirty <- struct{}{}:
	default:
	}
}

func (m *Manager) SetPromptBroker(broker PromptBroker) error {
	return m.backend.SetPromptBroker(broker)
}

func (m *Manager) SubmitCredentials(token string, secrets map[string]string, save bool) error {
	return m.backend.SubmitCredentials(token, secrets, save)
}

func (m *Manager) CancelCredentials(token string) error {
	return m.backend.CancelCredentials(token)
}

func (m *Manager) GetPromptBroker() PromptBroker {
	return m.backend.GetPromptBroker()
}

func (m *Manager) Close() {
	close(m.stopChan)
	m.notifierWg.Wait()

	if m.backend != nil {
		m.backend.Close()
	}

	m.subscribers.Range(func(key string, ch chan NetworkState) bool {
		close(ch)
		m.subscribers.Delete(key)
		return true
	})
}

func (m *Manager) ScanWiFi() error {
	return m.backend.ScanWiFi()
}

func (m *Manager) GetWiFiNetworks() []WiFiNetwork {
	m.stateMutex.RLock()
	defer m.stateMutex.RUnlock()
	networks := make([]WiFiNetwork, len(m.state.WiFiNetworks))
	copy(networks, m.state.WiFiNetworks)
	return networks
}

func (m *Manager) GetNetworkInfo(ssid string) (*WiFiNetwork, error) {
	m.stateMutex.RLock()
	defer m.stateMutex.RUnlock()

	for _, network := range m.state.WiFiNetworks {
		if network.SSID == ssid {
			return &network, nil
		}
	}

	return nil, fmt.Errorf("network not found: %s", ssid)
}

func (m *Manager) GetNetworkInfoDetailed(ssid string) (*NetworkInfoResponse, error) {
	return m.backend.GetWiFiNetworkDetails(ssid)
}

func (m *Manager) ToggleWiFi() error {
	enabled, err := m.backend.GetWiFiEnabled()
	if err != nil {
		return fmt.Errorf("failed to get WiFi state: %w", err)
	}

	err = m.backend.SetWiFiEnabled(!enabled)
	if err != nil {
		return fmt.Errorf("failed to toggle WiFi: %w", err)
	}

	return nil
}

func (m *Manager) EnableWiFi() error {
	err := m.backend.SetWiFiEnabled(true)
	if err != nil {
		return fmt.Errorf("failed to enable WiFi: %w", err)
	}

	return nil
}

func (m *Manager) DisableWiFi() error {
	err := m.backend.SetWiFiEnabled(false)
	if err != nil {
		return fmt.Errorf("failed to disable WiFi: %w", err)
	}

	return nil
}

func (m *Manager) ConnectWiFi(req ConnectionRequest) error {
	return m.backend.ConnectWiFi(req)
}

func (m *Manager) DisconnectWiFi() error {
	return m.backend.DisconnectWiFi()
}

func (m *Manager) ForgetWiFiNetwork(ssid string) error {
	return m.backend.ForgetWiFiNetwork(ssid)
}

func (m *Manager) GetWiredConfigs() []WiredConnection {
	m.stateMutex.RLock()
	defer m.stateMutex.RUnlock()
	configs := make([]WiredConnection, len(m.state.WiredConnections))
	copy(configs, m.state.WiredConnections)
	return configs
}

func (m *Manager) GetWiredNetworkInfoDetailed(uuid string) (*WiredNetworkInfoResponse, error) {
	return m.backend.GetWiredNetworkDetails(uuid)
}

func (m *Manager) ConnectEthernet() error {
	return m.backend.ConnectEthernet()
}

func (m *Manager) DisconnectEthernet() error {
	return m.backend.DisconnectEthernet()
}

func (m *Manager) activateConnection(uuid string) error {
	return m.backend.ActivateWiredConnection(uuid)
}

func (m *Manager) ListVPNProfiles() ([]VPNProfile, error) {
	return m.backend.ListVPNProfiles()
}

func (m *Manager) ListActiveVPN() ([]VPNActive, error) {
	return m.backend.ListActiveVPN()
}

func (m *Manager) ConnectVPN(uuidOrName string, singleActive bool) error {
	return m.backend.ConnectVPN(uuidOrName, singleActive)
}

func (m *Manager) DisconnectVPN(uuidOrName string) error {
	return m.backend.DisconnectVPN(uuidOrName)
}

func (m *Manager) DisconnectAllVPN() error {
	return m.backend.DisconnectAllVPN()
}

func (m *Manager) ClearVPNCredentials(uuidOrName string) error {
	return m.backend.ClearVPNCredentials(uuidOrName)
}

func (m *Manager) SetWiFiAutoconnect(ssid string, autoconnect bool) error {
	return m.backend.SetWiFiAutoconnect(ssid, autoconnect)
}
