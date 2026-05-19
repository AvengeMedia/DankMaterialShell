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

func TestLinkInfo_Classify(t *testing.T) {
	// When networkd reports a Type via Describe, classification is exact.
	cases := []struct {
		name      string
		ifname    string
		linkType  string
		wantWired bool
		wantWifi  bool
	}{
		{"ether type", "dock", "ether", true, false},
		{"wlan type", "wifi", "wlan", false, true},
		{"loopback type", "lo", "loopback", false, false},
		{"none type (tun overlay)", "nebula.homelab", "none", false, false},
		{"none type (wireguard)", "wg0", "none", false, false},
		// Fallback path: linkType unavailable, name-prefix heuristic applies.
		{"fallback enp wired", "enp141s0", "", true, false},
		{"fallback wlan wireless", "wlan0", "", false, true},
		{"fallback wlp wireless", "wlp3s0", "", false, true},
		{"fallback lo skipped", "lo", "", false, false},
		{"fallback docker skipped", "docker0", "", false, false},
		{"fallback tun skipped", "tun0", "", false, false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			l := &linkInfo{name: tc.ifname, linkType: tc.linkType}
			assert.Equal(t, tc.wantWired, l.isWired(), "isWired")
			assert.Equal(t, tc.wantWifi, l.isWireless(), "isWireless")
		})
	}
}

func TestParseDescribeType(t *testing.T) {
	// parseDescribeType is the seam between networkd's Describe RPC and the
	// classifier. On any failure path it must return "" so callers fall back
	// to name-prefix heuristics rather than misclassifying the link.
	cases := []struct {
		name string
		in   string
		want string
	}{
		{"ether", `{"Type":"ether","Name":"enp141s0"}`, "ether"},
		{"wlan", `{"Type":"wlan","Name":"wlan0"}`, "wlan"},
		{"loopback", `{"Type":"loopback","Name":"lo"}`, "loopback"},
		{"none with kind", `{"Type":"none","Kind":"tun","Name":"nebula.homelab"}`, "none"},
		{"empty payload", ``, ""},
		{"empty object", `{}`, ""},
		{"missing Type field", `{"Name":"wlan0","Kind":""}`, ""},
		{"explicit empty Type", `{"Type":"","Name":"wlan0"}`, ""},
		{"malformed json", `{"Type":"ether"`, ""},
		{"non-string Type", `{"Type":42}`, ""},
		{"unrelated payload", `"just a string"`, ""},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			assert.Equal(t, tc.want, parseDescribeType(tc.in))
		})
	}
}

func TestLooksVirtual(t *testing.T) {
	virtual := []string{"lo", "docker0", "veth123", "virbr0", "br-abc", "vnet0", "tun0", "tap0", "vboxnet0", "vmnet1", "kube-ipvs0", "cni0", "flannel.1", "cali-abc"}
	for _, n := range virtual {
		assert.True(t, looksVirtual(n), "%s should look virtual", n)
	}
	real := []string{"enp141s0", "eno1", "wlan0", "wlp3s0", "wifi", "dock", "nebula.homelab", "wg0"}
	for _, n := range real {
		assert.False(t, looksVirtual(n), "%s should not look virtual", n)
	}
}
