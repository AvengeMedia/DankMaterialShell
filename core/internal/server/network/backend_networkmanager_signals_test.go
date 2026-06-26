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

func TestNetworkManagerBackend_HandleDBusSignal_NewConnection(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)
	backend.settings = emptySettingsMock(t)

	sig := &dbus.Signal{
		Name: "org.freedesktop.NetworkManager.Settings.NewConnection",
		Body: []any{"/org/freedesktop/NetworkManager/Settings/1"},
	}

	assert.NotPanics(t, func() {
		backend.handleDBusSignal(sig)
	})
}

func TestNetworkManagerBackend_HandleDBusSignal_ConnectionRemoved(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)
	backend.settings = emptySettingsMock(t)

	sig := &dbus.Signal{
		Name: "org.freedesktop.NetworkManager.Settings.ConnectionRemoved",
		Body: []any{"/org/freedesktop/NetworkManager/Settings/1"},
	}

	assert.NotPanics(t, func() {
		backend.handleDBusSignal(sig)
	})
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

func TestNetworkManagerBackend_HandleNetworkManagerChange(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{}, nil).Maybe()
	mockNM.EXPECT().GetPropertyPrimaryConnection().Return(nil, nil).Maybe()

	changes := map[string]dbus.Variant{
		"PrimaryConnection": dbus.MakeVariant("/"),
		"State":             dbus.MakeVariant(uint32(70)),
	}

	assert.NotPanics(t, func() {
		backend.handleNetworkManagerChange(changes)
	})
}

func TestNetworkManagerBackend_HandleNetworkManagerChange_WirelessEnabled(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	mockNM.EXPECT().GetPropertyWirelessEnabled().Return(true, nil)
	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{}, nil).Maybe()
	mockNM.EXPECT().GetPropertyPrimaryConnection().Return(nil, nil).Maybe()

	changes := map[string]dbus.Variant{
		"WirelessEnabled": dbus.MakeVariant(true),
	}

	assert.NotPanics(t, func() {
		backend.handleNetworkManagerChange(changes)
	})
}

func TestNetworkManagerBackend_HandleNetworkManagerChange_ActiveConnections(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{}, nil)
	mockNM.EXPECT().GetPropertyPrimaryConnection().Return(nil, nil).Maybe()

	changes := map[string]dbus.Variant{
		"ActiveConnections": dbus.MakeVariant([]any{}),
	}

	assert.NotPanics(t, func() {
		backend.handleNetworkManagerChange(changes)
	})
}

func TestNetworkManagerBackend_HandleDeviceChange(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{}, nil).Maybe()
	mockNM.EXPECT().GetPropertyPrimaryConnection().Return(nil, nil).Maybe()

	changes := map[string]dbus.Variant{
		"State": dbus.MakeVariant(uint32(100)),
	}

	assert.NotPanics(t, func() {
		backend.handleDeviceChange("/org/freedesktop/NetworkManager/Devices/1", changes)
	})
}

func TestNetworkManagerBackend_HandleDeviceChange_Ip4Config(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)
	backend.settings = emptySettingsMock(t)

	changes := map[string]dbus.Variant{
		"Ip4Config": dbus.MakeVariant("/"),
	}

	assert.NotPanics(t, func() {
		backend.handleDeviceChange("/org/freedesktop/NetworkManager/Devices/1", changes)
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

func TestNetworkManagerBackend_HandleWiFiChange_ActiveAccessPoint(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	changes := map[string]dbus.Variant{
		"ActiveAccessPoint": dbus.MakeVariant("/"),
	}

	assert.NotPanics(t, func() {
		backend.handleWiFiChange(changes)
	})
}

func TestNetworkManagerBackend_HandleWiFiChange_AccessPoints(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	changes := map[string]dbus.Variant{
		"AccessPoints": dbus.MakeVariant([]any{}),
	}

	assert.NotPanics(t, func() {
		backend.handleWiFiChange(changes)
	})
}

func TestNetworkManagerBackend_HandleAccessPointChange_NoStrength(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	changes := map[string]dbus.Variant{
		"SomeOtherProperty": dbus.MakeVariant("value"),
	}

	assert.NotPanics(t, func() {
		backend.handleAccessPointChange(changes)
	})
}

func TestNetworkManagerBackend_HandleAccessPointChange_WithStrength(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.stateMutex.Lock()
	backend.state.WiFiSignal = 50
	backend.stateMutex.Unlock()

	changes := map[string]dbus.Variant{
		"Strength": dbus.MakeVariant(uint8(80)),
	}

	assert.NotPanics(t, func() {
		backend.handleAccessPointChange(changes)
	})
}

func TestNetworkManagerBackend_StopSignalPump_NoConnection(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.dbusConn = nil
	assert.NotPanics(t, func() {
		backend.stopSignalPump()
	})
}
