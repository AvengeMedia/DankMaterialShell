package network

import (
	"testing"

	mock_gonetworkmanager "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/github.com/Wifx/gonetworkmanager/v2"
	"github.com/stretchr/testify/assert"
)

func TestNetworkManagerBackend_New(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)
	assert.NotNil(t, backend)
	assert.Equal(t, "networkmanager", backend.state.Backend)
	assert.NotNil(t, backend.stopChan)
	assert.NotNil(t, backend.state)
}

func TestNetworkManagerBackend_GetCurrentState(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.state.NetworkStatus = StatusWiFi
	backend.state.WiFiConnected = true
	backend.state.WiFiSSID = "TestNetwork"
	backend.state.WiFiIP = "192.168.1.100"
	backend.state.WiFiNetworks = []WiFiNetwork{
		{SSID: "TestNetwork", Signal: 80, Connected: true},
	}
	backend.state.WiredConnections = []WiredConnection{
		{ID: "Wired connection 1", UUID: "test-uuid"},
	}

	state, err := backend.GetCurrentState()
	assert.NoError(t, err)
	assert.NotNil(t, state)
	assert.Equal(t, StatusWiFi, state.NetworkStatus)
	assert.True(t, state.WiFiConnected)
	assert.Equal(t, "TestNetwork", state.WiFiSSID)
	assert.Len(t, state.WiFiNetworks, 1)
	assert.Len(t, state.WiredConnections, 1)

	assert.NotSame(t, &backend.state.WiFiNetworks, &state.WiFiNetworks)
	assert.NotSame(t, &backend.state.WiredConnections, &state.WiredConnections)
}

func TestNetworkManagerBackend_SetPromptBroker_Nil(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	err = backend.SetPromptBroker(nil)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "cannot be nil")
}

func TestNetworkManagerBackend_SubmitCredentials_NoBroker(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.promptBroker = nil
	err = backend.SubmitCredentials("token", map[string]string{"password": "test"}, false)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not initialized")
}

func TestNetworkManagerBackend_CancelCredentials_NoBroker(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.promptBroker = nil
	err = backend.CancelCredentials("token")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not initialized")
}

func TestNetworkManagerBackend_EnsureWiFiDevice_NoDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.wifiDevice = nil
	backend.wifiDev = nil

	err = backend.ensureWiFiDevice()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no WiFi device available")
}

func TestNetworkManagerBackend_EnsureWiFiDevice_AlreadySet(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.wifiDev = "dummy-device"

	err = backend.ensureWiFiDevice()
	assert.NoError(t, err)
}

func TestNetworkManagerBackend_StartSecretAgent_NoBroker(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.promptBroker = nil
	err = backend.startSecretAgent()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "prompt broker not set")
}

func TestNetworkManagerBackend_Close(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	assert.NotPanics(t, func() {
		backend.Close()
	})
}

func TestNetworkManagerBackend_GetPromptBroker(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	broker := backend.GetPromptBroker()
	assert.Nil(t, broker)
}

func TestNetworkManagerBackend_StopMonitoring_NoSignals(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	assert.NotPanics(t, func() {
		backend.StopMonitoring()
	})
}
