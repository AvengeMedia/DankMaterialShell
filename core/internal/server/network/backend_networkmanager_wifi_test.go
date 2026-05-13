package network

import (
	"testing"

	mock_gonetworkmanager "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/github.com/Wifx/gonetworkmanager/v2"
	gonetworkmanager "github.com/Wifx/gonetworkmanager/v2"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

func TestNetworkManagerBackend_GetWiFiEnabled(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	mockNM.EXPECT().GetPropertyWirelessEnabled().Return(true, nil)

	enabled, err := backend.GetWiFiEnabled()
	assert.NoError(t, err)
	assert.True(t, enabled)
}

func TestNetworkManagerBackend_SetWiFiEnabled(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	mockNM.EXPECT().SetPropertyWirelessEnabled(true).Return(nil)

	err = backend.SetWiFiEnabled(true)
	assert.NoError(t, err)

	backend.stateMutex.RLock()
	assert.True(t, backend.state.WiFiEnabled)
	backend.stateMutex.RUnlock()
}

func TestNetworkManagerBackend_ScanWiFi_NoDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.wifiDevice = nil
	err = backend.ScanWiFi()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no WiFi device available")
}

func TestNetworkManagerBackend_ScanWiFi_Disabled(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockDeviceWireless := mock_gonetworkmanager.NewMockDeviceWireless(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.wifiDevice = mockDeviceWireless
	backend.wifiDev = mockDeviceWireless

	backend.stateMutex.Lock()
	backend.state.WiFiEnabled = false
	backend.stateMutex.Unlock()

	err = backend.ScanWiFi()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "WiFi is disabled")
}

func TestNetworkManagerBackend_GetWiFiNetworkDetails_NoDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.wifiDevice = nil
	_, err = backend.GetWiFiNetworkDetails("TestNetwork")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no WiFi device available")
}

func TestNetworkManagerBackend_ConnectWiFi_NoDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.wifiDevice = nil
	req := ConnectionRequest{SSID: "TestNetwork", Password: "password"}
	err = backend.ConnectWiFi(req)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no WiFi device available")
}

func TestNetworkManagerBackend_ConnectWiFi_AlreadyConnected(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockDeviceWireless := mock_gonetworkmanager.NewMockDeviceWireless(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.wifiDevice = mockDeviceWireless
	backend.wifiDev = mockDeviceWireless
	backend.wifiDevices = map[string]*wifiDeviceInfo{
		"wlan0": {
			device:    nil,
			wireless:  mockDeviceWireless,
			name:      "wlan0",
			hwAddress: "00:11:22:33:44:55",
		},
	}

	mockDeviceWireless.EXPECT().GetPropertyInterface().Return("wlan0", nil)

	backend.stateMutex.Lock()
	backend.state.WiFiConnected = true
	backend.state.WiFiSSID = "TestNetwork"
	backend.state.WiFiDevice = "wlan0"
	backend.stateMutex.Unlock()

	req := ConnectionRequest{SSID: "TestNetwork", Password: "password"}
	err = backend.ConnectWiFi(req)
	assert.NoError(t, err)
}

func TestNetworkManagerBackend_DisconnectWiFi_NoDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.wifiDevice = nil
	err = backend.DisconnectWiFi()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no WiFi device available")
}

func TestNetworkManagerBackend_IsConnectingTo(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.stateMutex.Lock()
	backend.state.IsConnecting = true
	backend.state.ConnectingSSID = "TestNetwork"
	backend.stateMutex.Unlock()

	assert.True(t, backend.IsConnectingTo("TestNetwork"))
	assert.False(t, backend.IsConnectingTo("OtherNetwork"))
}

func TestNetworkManagerBackend_IsConnectingTo_NotConnecting(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.stateMutex.Lock()
	backend.state.IsConnecting = false
	backend.state.ConnectingSSID = ""
	backend.stateMutex.Unlock()

	assert.False(t, backend.IsConnectingTo("TestNetwork"))
}

func TestNetworkManagerBackend_UpdateWiFiNetworks_NoDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.wifiDevice = nil
	_, err = backend.updateWiFiNetworks()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no WiFi device available")
}

func TestNetworkManagerBackend_FindConnection_NoSettings(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.settings = nil
	_, err = backend.findConnection("NonExistentNetwork")
	assert.Error(t, err)
}

func TestNetworkManagerBackend_CreateAndConnectWiFi_NoDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.wifiDevice = nil
	backend.wifiDev = nil
	req := ConnectionRequest{SSID: "TestNetwork", Password: "password"}
	err = backend.createAndConnectWiFi(req)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no WiFi device available")
}

func TestNetworkManagerBackend_EnterpriseInteractive_PasswordFlagsAgentOwned(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockDev := mock_gonetworkmanager.NewMockDeviceWireless(t)
	mockAP := mock_gonetworkmanager.NewMockAccessPoint(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)
	mockConn := mock_gonetworkmanager.NewMockConnection(t)
	mockActiveConn := mock_gonetworkmanager.NewMockActiveConnection(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	const iface = "wlan0"
	backend.wifiDevice = mockDev
	backend.wifiDev = mockDev
	backend.wifiDevices = map[string]*wifiDeviceInfo{
		iface: {device: mockDev, wireless: mockDev, name: iface, hwAddress: "00:11:22:33:44:55"},
	}
	backend.settings = mockSettings

	const KeyMgmt8021x = 512

	mockDev.EXPECT().GetPropertyInterface().Return(iface, nil)
	mockDev.EXPECT().GetAccessPoints().Return([]gonetworkmanager.AccessPoint{mockAP}, nil)
	mockAP.EXPECT().GetPropertySSID().Return("EnterpriseNet", nil)
	mockAP.EXPECT().GetPropertyFlags().Return(uint32(0), nil)
	mockAP.EXPECT().GetPropertyWPAFlags().Return(uint32(KeyMgmt8021x), nil)
	mockAP.EXPECT().GetPropertyRSNFlags().Return(uint32(0), nil)

	var captured map[string]map[string]any
	mockSettings.EXPECT().
		AddConnection(mock.Anything).
		Run(func(s gonetworkmanager.ConnectionSettings) { captured = map[string]map[string]any(s) }).
		Return(mockConn, nil)

	mockNM.EXPECT().
		ActivateWirelessConnection(mockConn, mock.Anything, mockAP).
		Return(mockActiveConn, nil)

	req := ConnectionRequest{SSID: "EnterpriseNet", Interactive: true}
	err = backend.createAndConnectWiFi(req)
	assert.NoError(t, err)

	dot1x, ok := captured["802-1x"]
	if !ok {
		t.Fatal("expected 802-1x settings")
	}
	assert.Equal(t, uint32(1), dot1x["password-flags"], "interactive enterprise should use AgentOwned password-flags")
}

func TestNetworkManagerBackend_EnterpriseNonInteractive_PasswordFlagsNone(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockDev := mock_gonetworkmanager.NewMockDeviceWireless(t)
	mockAP := mock_gonetworkmanager.NewMockAccessPoint(t)
	mockActiveConn := mock_gonetworkmanager.NewMockActiveConnection(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	const iface = "wlan0"
	backend.wifiDevice = mockDev
	backend.wifiDev = mockDev
	backend.wifiDevices = map[string]*wifiDeviceInfo{
		iface: {device: mockDev, wireless: mockDev, name: iface, hwAddress: "00:11:22:33:44:55"},
	}

	const KeyMgmt8021x = 512

	mockDev.EXPECT().GetPropertyInterface().Return(iface, nil)
	mockDev.EXPECT().GetAccessPoints().Return([]gonetworkmanager.AccessPoint{mockAP}, nil)
	mockAP.EXPECT().GetPropertySSID().Return("EnterpriseNet", nil)
	mockAP.EXPECT().GetPropertyFlags().Return(uint32(0), nil)
	mockAP.EXPECT().GetPropertyWPAFlags().Return(uint32(KeyMgmt8021x), nil)
	mockAP.EXPECT().GetPropertyRSNFlags().Return(uint32(0), nil)

	var captured map[string]map[string]any
	mockNM.EXPECT().
		AddAndActivateWirelessConnection(mock.Anything, mockDev, mockAP).
		Run(func(s map[string]map[string]any, _ gonetworkmanager.Device, _ gonetworkmanager.AccessPoint) {
			captured = s
		}).
		Return(mockActiveConn, nil)

	req := ConnectionRequest{
		SSID: "EnterpriseNet", Password: "pass123", Username: "user@e.com",
		Interactive: false,
	}
	err = backend.createAndConnectWiFi(req)
	assert.NoError(t, err)

	dot1x, ok := captured["802-1x"]
	if !ok {
		t.Fatal("expected 802-1x settings")
	}
	assert.Equal(t, uint32(0), dot1x["password-flags"], "non-interactive enterprise should use None password-flags")
	assert.Equal(t, "pass123", dot1x["password"])
	assert.Equal(t, "user@e.com", dot1x["identity"])
}
