package network_test

import (
	"errors"
	"testing"

	mocks_network "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/network"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/network"
	"github.com/stretchr/testify/assert"
)

func TestManager_ConnectWiFi_NoDevice(t *testing.T) {
	backend := mocks_network.NewMockBackend(t)
	req := network.ConnectionRequest{
		SSID:     "TestNetwork",
		Password: "testpass123",
	}
	backend.EXPECT().ConnectWiFi(req).Return(errors.New("no WiFi device available"))

	manager := network.NewTestManager(backend, &network.NetworkState{})

	err := manager.ConnectWiFi(req)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no WiFi device available")
}

func TestManager_DisconnectWiFi_NoDevice(t *testing.T) {
	backend := mocks_network.NewMockBackend(t)
	backend.EXPECT().DisconnectWiFi().Return(errors.New("no WiFi device available"))

	manager := network.NewTestManager(backend, &network.NetworkState{})

	err := manager.DisconnectWiFi()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no WiFi device available")
}

func TestManager_ForgetWiFiNetwork_NotFound(t *testing.T) {
	backend := mocks_network.NewMockBackend(t)
	backend.EXPECT().ForgetWiFiNetwork("NonExistentNetwork").Return(errors.New("connection not found"))

	manager := network.NewTestManager(backend, &network.NetworkState{})

	err := manager.ForgetWiFiNetwork("NonExistentNetwork")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "connection not found")
}

func TestManager_ConnectEthernet_NoDevice(t *testing.T) {
	backend := mocks_network.NewMockBackend(t)
	backend.EXPECT().ConnectEthernet().Return(errors.New("no ethernet device available"))

	manager := network.NewTestManager(backend, &network.NetworkState{})

	err := manager.ConnectEthernet()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no ethernet device available")
}

func TestManager_DisconnectEthernet_NoDevice(t *testing.T) {
	backend := mocks_network.NewMockBackend(t)
	backend.EXPECT().DisconnectEthernet().Return(errors.New("no ethernet device available"))

	manager := network.NewTestManager(backend, &network.NetworkState{})

	err := manager.DisconnectEthernet()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no ethernet device available")
}

// Note: More comprehensive tests for connection operations would require
// mocking the NetworkManager D-Bus interfaces, which is beyond the scope
// of these unit tests. The tests above cover the basic error cases and
// validation logic. Integration tests would be needed for full coverage.
