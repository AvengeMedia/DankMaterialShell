package network

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestSystemdNetworkdBackend_New(t *testing.T) {
	backend, err := NewSystemdNetworkdBackend()
	assert.NoError(t, err)
	assert.NotNil(t, backend)
	assert.Equal(t, "networkd", backend.state.Backend)
	assert.NotNil(t, backend.links)
	assert.NotNil(t, backend.stopChan)
}

func TestSystemdNetworkdBackend_GetCurrentState(t *testing.T) {
	backend, _ := NewSystemdNetworkdBackend()
	backend.state.NetworkStatus = StatusEthernet
	backend.state.EthernetConnected = true
	backend.state.EthernetIP = "192.168.1.100"

	state, err := backend.GetCurrentState()
	assert.NoError(t, err)
	assert.NotNil(t, state)
	assert.Equal(t, StatusEthernet, state.NetworkStatus)
	assert.True(t, state.EthernetConnected)
	assert.Equal(t, "192.168.1.100", state.EthernetIP)
}

func TestSystemdNetworkdBackend_WiFiNotSupported(t *testing.T) {
	backend, _ := NewSystemdNetworkdBackend()

	err := backend.ScanWiFi()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not supported")

	req := ConnectionRequest{SSID: "test"}
	err = backend.ConnectWiFi(req)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not supported")

	err = backend.DisconnectWiFi()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not supported")

	err = backend.ForgetWiFiNetwork("test")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not supported")

	_, err = backend.GetWiFiNetworkDetails("test")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not supported")
}

func TestSystemdNetworkdBackend_VPNNotSupported(t *testing.T) {
	backend, _ := NewSystemdNetworkdBackend()

	profiles, err := backend.ListVPNProfiles()
	assert.NoError(t, err)
	assert.Empty(t, profiles)

	active, err := backend.ListActiveVPN()
	assert.NoError(t, err)
	assert.Empty(t, active)

	err = backend.ConnectVPN("test", false)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not supported")

	err = backend.DisconnectVPN("test")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not supported")

	err = backend.DisconnectAllVPN()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not supported")

	err = backend.ClearVPNCredentials("test")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not supported")
}

func TestSystemdNetworkdBackend_PromptBroker(t *testing.T) {
	backend, _ := NewSystemdNetworkdBackend()

	broker := backend.GetPromptBroker()
	assert.Nil(t, broker)

	err := backend.SetPromptBroker(nil)
	assert.NoError(t, err)

	err = backend.SubmitCredentials("token", nil, false)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not needed")

	err = backend.CancelCredentials("token")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not needed")
}

func TestSystemdNetworkdBackend_GetWiFiEnabled(t *testing.T) {
	backend, _ := NewSystemdNetworkdBackend()

	enabled, err := backend.GetWiFiEnabled()
	assert.NoError(t, err)
	assert.True(t, enabled)
}

func TestSystemdNetworkdBackend_SetWiFiEnabled(t *testing.T) {
	backend, _ := NewSystemdNetworkdBackend()

	err := backend.SetWiFiEnabled(false)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not supported")
}

func TestSystemdNetworkdBackend_DisconnectEthernet(t *testing.T) {
	backend, _ := NewSystemdNetworkdBackend()

	err := backend.DisconnectEthernet()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not supported")
}

func TestSystemdNetworkdBackend_GetEthernetDevices(t *testing.T) {
	backend, _ := NewSystemdNetworkdBackend()

	backend.state.EthernetDevices = []EthernetDevice{
		{Name: "enp0s3", State: "routable", Connected: true},
		{Name: "enp0s8", State: "no-carrier", Connected: false},
	}

	devices := backend.GetEthernetDevices()
	assert.Len(t, devices, 2)
	assert.Equal(t, "enp0s3", devices[0].Name)
	assert.True(t, devices[0].Connected)
}

func TestSystemdNetworkdBackend_DisconnectEthernetDevice(t *testing.T) {
	backend, _ := NewSystemdNetworkdBackend()

	err := backend.DisconnectEthernetDevice("enp0s3")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not supported")
}
