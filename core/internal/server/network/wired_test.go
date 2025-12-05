package network

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestManager_GetWiredConfigs(t *testing.T) {
	manager := &Manager{
		state: &NetworkState{
			EthernetConnected: true,
			WiredConnections: []WiredConnection{
				{ID: "Test", IsActive: true},
			},
		},
	}

	configs := manager.GetWiredConfigs()

	assert.Len(t, configs, 1)
	assert.Equal(t, "Test", configs[0].ID)
}

func TestManager_GetEthernetDevices(t *testing.T) {
	manager := &Manager{
		state: &NetworkState{
			EthernetDevices: []EthernetDevice{
				{Name: "enp0s3", Connected: true, IP: "192.168.1.100"},
				{Name: "enp0s8", Connected: false},
			},
		},
	}

	devices := manager.GetEthernetDevices()

	assert.Len(t, devices, 2)
	assert.Equal(t, "enp0s3", devices[0].Name)
	assert.True(t, devices[0].Connected)
	assert.Equal(t, "enp0s8", devices[1].Name)
	assert.False(t, devices[1].Connected)
}

func TestManager_GetEthernetDevices_Empty(t *testing.T) {
	manager := &Manager{
		state: &NetworkState{},
	}

	devices := manager.GetEthernetDevices()
	assert.Empty(t, devices)
}
