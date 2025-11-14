package network

import (
	"testing"

	mock_gonetworkmanager "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/github.com/Wifx/gonetworkmanager/v2"
	"github.com/Wifx/gonetworkmanager/v2"
	"github.com/godbus/dbus/v5"
	"github.com/stretchr/testify/assert"
)

func TestNetworkManagerBackend_HandleDBusSignal_NewConnection(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	sig := &dbus.Signal{
		Name: "org.freedesktop.NetworkManager.Settings.NewConnection",
		Body: []interface{}{"/org/freedesktop/NetworkManager/Settings/1"},
	}

	assert.NotPanics(t, func() {
		backend.handleDBusSignal(sig)
	})
}

func TestNetworkManagerBackend_HandleDBusSignal_ConnectionRemoved(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	sig := &dbus.Signal{
		Name: "org.freedesktop.NetworkManager.Settings.ConnectionRemoved",
		Body: []interface{}{"/org/freedesktop/NetworkManager/Settings/1"},
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
		Body: []interface{}{"only-one-element"},
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
		Body: []interface{}{123, map[string]dbus.Variant{}},
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
		Body: []interface{}{dbusNMInterface, "not-a-map"},
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
		"ActiveConnections": dbus.MakeVariant([]interface{}{}),
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
		backend.handleDeviceChange(changes)
	})
}

func TestNetworkManagerBackend_HandleDeviceChange_Ip4Config(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	changes := map[string]dbus.Variant{
		"Ip4Config": dbus.MakeVariant("/"),
	}

	assert.NotPanics(t, func() {
		backend.handleDeviceChange(changes)
	})
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
		"AccessPoints": dbus.MakeVariant([]interface{}{}),
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
