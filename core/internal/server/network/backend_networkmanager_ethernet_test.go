package network

import (
	"testing"

	mock_gonetworkmanager "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/github.com/Wifx/gonetworkmanager/v2"
	"github.com/stretchr/testify/assert"
)

func TestNetworkManagerBackend_GetWiredConnections_NoDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.ethernetDevice = nil
	_, err = backend.GetWiredConnections()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no ethernet device available")
}

func TestNetworkManagerBackend_GetWiredNetworkDetails_NoDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.ethernetDevice = nil
	_, err = backend.GetWiredNetworkDetails("test-uuid")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no ethernet device available")
}

func TestNetworkManagerBackend_ConnectEthernet_NoDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.ethernetDevice = nil
	err = backend.ConnectEthernet()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no ethernet device available")
}

func TestNetworkManagerBackend_DisconnectEthernet_NoDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.ethernetDevice = nil
	err = backend.DisconnectEthernet()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no ethernet device available")
}

func TestNetworkManagerBackend_ActivateWiredConnection_NoDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.ethernetDevice = nil
	err = backend.ActivateWiredConnection("test-uuid")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no ethernet device available")
}

func TestNetworkManagerBackend_ActivateWiredConnection_NotFound(t *testing.T) {
	t.Skip("ActivateWiredConnection creates a new Settings instance internally, cannot be fully mocked")
}

func TestNetworkManagerBackend_ListEthernetConnections_NoDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.ethernetDevice = nil
	_, err = backend.listEthernetConnections()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no ethernet device available")
}
