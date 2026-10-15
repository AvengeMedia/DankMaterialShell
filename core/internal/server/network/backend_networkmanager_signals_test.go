package network

import (
	"testing"

	mock_gonetworkmanager "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/github.com/Wifx/gonetworkmanager/v2"
	"github.com/Wifx/gonetworkmanager/v2"
	"github.com/godbus/dbus/v5"
	"github.com/stretchr/testify/assert"
)

// emptySettingsMock keeps tests hermetic: without it, networkManagerSettings()
// falls back to the real system D-Bus and picks up whatever profiles exist on
// the developer's machine.
func emptySettingsMock(t *testing.T) *mock_gonetworkmanager.MockSettings {
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)
	mockSettings.EXPECT().ListConnections().Return(nil, nil).Maybe()
	return mockSettings
}

func TestNetworkManagerBackend_HandleDBusSignal_InvalidBody(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	sig := &dbus.Signal{
		Name: "org.freedesktop.DBus.Properties.PropertiesChanged",
		Body: []any{"only-one-element"},
	}

	assert.NotPanics(t, func() {
		backend.handleDBusSignal(sig)
	})
}

func TestNetworkManagerBackend_HandleDBusSignal_InvalidInterface(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	sig := &dbus.Signal{
		Name: "org.freedesktop.DBus.Properties.PropertiesChanged",
		Body: []any{123, map[string]dbus.Variant{}},
	}

	assert.NotPanics(t, func() {
		backend.handleDBusSignal(sig)
	})
}

func TestNetworkManagerBackend_HandleDBusSignal_InvalidChanges(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	sig := &dbus.Signal{
		Name: "org.freedesktop.DBus.Properties.PropertiesChanged",
		Body: []any{dbusNMInterface, "not-a-map"},
	}

	assert.NotPanics(t, func() {
		backend.handleDBusSignal(sig)
	})
}

func TestNetworkManagerBackend_HandleDeviceChange_UnmanagedRefreshesHotspotState(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockWiFi := mock_gonetworkmanager.NewMockDeviceWireless(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)
	backend.settings = emptySettingsMock(t)
	backend.wifiDevices = map[string]*wifiDeviceInfo{
		"wlan0": {device: mockWiFi, wireless: mockWiFi, name: "wlan0"},
	}
	backend.state.HotspotAvailable = true

	stateChangeCalls := 0
	backend.onStateChange = func() {
		stateChangeCalls++
	}

	mockWiFi.EXPECT().GetPropertyState().Return(gonetworkmanager.NmDeviceStateUnavailable, nil)
	mockWiFi.EXPECT().GetAccessPoints().Return([]gonetworkmanager.AccessPoint{}, nil)
	mockWiFi.EXPECT().GetPropertyManaged().Return(false, nil)

	changes := map[string]dbus.Variant{
		"Managed": dbus.MakeVariant(false),
	}
	backend.handleDeviceChange("/org/freedesktop/NetworkManager/Devices/1", changes)

	assert.Equal(t, 1, stateChangeCalls, "unmanaged transition must notify subscribers")

	backend.stateMutex.RLock()
	defer backend.stateMutex.RUnlock()
	assert.False(t, backend.state.HotspotAvailable, "availability must be recomputed when the only AP-capable radio becomes unmanaged")
}
