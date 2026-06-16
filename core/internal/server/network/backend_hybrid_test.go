package network

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestHybridIwdNetworkdBackend_New(t *testing.T) {
	wifi, _ := NewIWDBackend()
	l3, _ := NewSystemdNetworkdBackend()

	hybrid, err := NewHybridIwdNetworkdBackend(wifi, l3)
	assert.NoError(t, err)
	assert.NotNil(t, hybrid)
	assert.NotNil(t, hybrid.wifi)
	assert.NotNil(t, hybrid.l3)
}

func TestHybridIwdNetworkdBackend_GetCurrentState_MergesState(t *testing.T) {
	wifi, _ := NewIWDBackend()
	l3, _ := NewSystemdNetworkdBackend()
	hybrid, _ := NewHybridIwdNetworkdBackend(wifi, l3)

	wifi.state.WiFiConnected = true
	wifi.state.WiFiSSID = "TestNetwork"
	wifi.state.WiFiBSSID = "00:11:22:33:44:55"
	wifi.state.WiFiSignal = 75
	wifi.state.WiFiDevice = "wlan0"
	wifi.state.SavedWiFiNetworks = []WiFiNetwork{
		{
			SSID:        "TestNetwork",
			Saved:       true,
			Autoconnect: true,
			Connected:   true,
		},
		{
			SSID:       "AwayNetwork",
			Saved:      true,
			OutOfRange: true,
		},
	}

	l3.state.WiFiIP = "192.168.1.100"
	l3.state.EthernetConnected = false

	state, err := hybrid.GetCurrentState()
	assert.NoError(t, err)
	assert.NotNil(t, state)
	assert.Equal(t, "iwd+networkd", state.Backend)
	assert.Equal(t, "TestNetwork", state.WiFiSSID)
	assert.Equal(t, "00:11:22:33:44:55", state.WiFiBSSID)
	assert.Equal(t, uint8(75), state.WiFiSignal)
	assert.Equal(t, "192.168.1.100", state.WiFiIP)
	assert.True(t, state.WiFiConnected)
	assert.False(t, state.EthernetConnected)
	assert.Equal(t, StatusWiFi, state.NetworkStatus)
	assert.Len(t, state.SavedWiFiNetworks, 2)
	assert.Equal(t, "TestNetwork", state.SavedWiFiNetworks[0].SSID)
	assert.True(t, state.SavedWiFiNetworks[1].OutOfRange)
}

func TestHybridIwdNetworkdBackend_GetCurrentState_EthernetPriority(t *testing.T) {
	wifi, _ := NewIWDBackend()
	l3, _ := NewSystemdNetworkdBackend()
	hybrid, _ := NewHybridIwdNetworkdBackend(wifi, l3)

	wifi.state.WiFiConnected = true
	wifi.state.WiFiSSID = "TestNetwork"

	l3.state.WiFiIP = "192.168.1.100"
	l3.state.EthernetConnected = true
	l3.state.EthernetIP = "192.168.1.50"
	l3.state.EthernetDevice = "eth0"

	state, err := hybrid.GetCurrentState()
	assert.NoError(t, err)
	assert.Equal(t, StatusEthernet, state.NetworkStatus)
	assert.Equal(t, "192.168.1.50", state.EthernetIP)
	assert.Equal(t, "eth0", state.EthernetDevice)
}

func TestHybridIwdNetworkdBackend_GetCurrentState_WiFiNoIP(t *testing.T) {
	wifi, _ := NewIWDBackend()
	l3, _ := NewSystemdNetworkdBackend()
	hybrid, _ := NewHybridIwdNetworkdBackend(wifi, l3)

	wifi.state.WiFiConnected = true
	wifi.state.WiFiSSID = "TestNetwork"

	l3.state.WiFiIP = ""
	l3.state.EthernetConnected = false

	state, err := hybrid.GetCurrentState()
	assert.NoError(t, err)
	assert.Equal(t, StatusDisconnected, state.NetworkStatus)
	assert.True(t, state.WiFiConnected)
	assert.Empty(t, state.WiFiIP)
}

func TestHybridIwdNetworkdBackend_WiFiDelegation(t *testing.T) {
	wifi, _ := NewIWDBackend()
	l3, _ := NewSystemdNetworkdBackend()
	hybrid, _ := NewHybridIwdNetworkdBackend(wifi, l3)

	enabled, err := hybrid.GetWiFiEnabled()
	assert.NoError(t, err)
	assert.True(t, enabled)

	state, err := hybrid.GetCurrentState()
	assert.NoError(t, err)
	assert.NotNil(t, state)
	assert.Equal(t, "iwd+networkd", state.Backend)
}

func TestHybridIwdNetworkdBackend_WiredDelegation(t *testing.T) {
	wifi, _ := NewIWDBackend()
	l3, _ := NewSystemdNetworkdBackend()
	hybrid, _ := NewHybridIwdNetworkdBackend(wifi, l3)

	conns, err := hybrid.GetWiredConnections()
	assert.NoError(t, err)
	assert.Empty(t, conns)
}

func TestHybridIwdNetworkdBackend_VPNNotSupported(t *testing.T) {
	wifi, _ := NewIWDBackend()
	l3, _ := NewSystemdNetworkdBackend()
	hybrid, _ := NewHybridIwdNetworkdBackend(wifi, l3)

	profiles, err := hybrid.ListVPNProfiles()
	assert.NoError(t, err)
	assert.Empty(t, profiles)

	active, err := hybrid.ListActiveVPN()
	assert.NoError(t, err)
	assert.Empty(t, active)

	err = hybrid.ConnectVPN("test", false)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not supported")
}

func TestHybridIwdNetworkdBackend_PromptBrokerDelegation(t *testing.T) {
	wifi, _ := NewIWDBackend()
	l3, _ := NewSystemdNetworkdBackend()
	hybrid, _ := NewHybridIwdNetworkdBackend(wifi, l3)

	broker := hybrid.GetPromptBroker()
	assert.Nil(t, broker)
}
