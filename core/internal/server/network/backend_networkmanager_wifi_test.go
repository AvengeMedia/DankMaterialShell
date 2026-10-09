package network

import (
	"errors"
	"testing"

	mock_gonetworkmanager "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/github.com/Wifx/gonetworkmanager/v2"
	mock_dbus "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/github.com/godbus/dbus/v5"
	"github.com/Wifx/gonetworkmanager/v2"
	"github.com/godbus/dbus/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
)

func TestGetWiFiQRCodeContent_ActiveHotspot(t *testing.T) {
	newBackend := func(t *testing.T, active ...gonetworkmanager.ActiveConnection) (*NetworkManagerBackend, *mock_gonetworkmanager.MockSettings) {
		mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
		mockSettings := mock_gonetworkmanager.NewMockSettings(t)
		backend, err := NewNetworkManagerBackend(mockNM)
		require.NoError(t, err)
		backend.settings = mockSettings
		mockNM.EXPECT().GetPropertyActiveConnections().Return(active, nil).Once()
		return backend, mockSettings
	}

	t.Run("active hotspot is used before any client profile lookup", func(t *testing.T) {
		const psk = "hotspot-psk"
		hsConn := mock_gonetworkmanager.NewMockConnection(t)
		hsActive := mock_gonetworkmanager.NewMockActiveConnection(t)
		req := HotspotRequest{SSID: "dms-ap", Password: psk}
		hsActive.EXPECT().GetPropertyType().Return("802-11-wireless", nil)
		hsActive.EXPECT().GetPropertyConnection().Return(hsConn, nil)
		hsConn.EXPECT().GetSettings().Return(buildHotspotSettings(req), nil)
		hsConn.EXPECT().GetSecrets("802-11-wireless-security").Return(gonetworkmanager.ConnectionSettings{
			"802-11-wireless-security": {"psk": psk},
		}, nil).Once()

		// mockSettings has no ListConnections expectation: a client lookup would fail the test.
		backend, _ := newBackend(t, hsActive)
		got, err := backend.GetWiFiQRCodeContent("dms-ap")
		require.NoError(t, err)
		assert.Contains(t, got, "S:dms-ap;")
		assert.Contains(t, got, psk)
	})

	t.Run("same-SSID client profile does not shadow the hotspot", func(t *testing.T) {
		const psk = "hotspot-psk"
		hsConn := mock_gonetworkmanager.NewMockConnection(t)
		hsActive := mock_gonetworkmanager.NewMockActiveConnection(t)
		hsActive.EXPECT().GetPropertyType().Return("802-11-wireless", nil)
		hsActive.EXPECT().GetPropertyConnection().Return(hsConn, nil)
		hsConn.EXPECT().GetSettings().Return(buildHotspotSettings(HotspotRequest{SSID: "dms-ap", Password: psk}), nil)
		hsConn.EXPECT().GetSecrets("802-11-wireless-security").Return(gonetworkmanager.ConnectionSettings{
			"802-11-wireless-security": {"psk": psk},
		}, nil).Once()

		clientConn := mock_gonetworkmanager.NewMockConnection(t)
		clientConn.EXPECT().GetSettings().Return(gonetworkmanager.ConnectionSettings{
			"connection":               {"type": "802-11-wireless", "id": "dms-ap"},
			"802-11-wireless":          {"ssid": []byte("dms-ap"), "mode": "infrastructure"},
			"802-11-wireless-security": {"key-mgmt": "wpa-psk"},
		}, nil).Maybe()
		clientConn.EXPECT().GetSecrets("802-11-wireless-security").Return(gonetworkmanager.ConnectionSettings{
			"802-11-wireless-security": {"psk": "client-psk"},
		}, nil).Maybe()

		backend, mockSettings := newBackend(t, hsActive)
		mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{clientConn}, nil).Maybe()
		got, err := backend.GetWiFiQRCodeContent("dms-ap")
		require.NoError(t, err)
		assert.Contains(t, got, psk)
		assert.NotContains(t, got, "client-psk")
	})

	t.Run("active hotspot with a different SSID falls through to the saved-connection error", func(t *testing.T) {
		hsConn := mock_gonetworkmanager.NewMockConnection(t)
		hsActive := mock_gonetworkmanager.NewMockActiveConnection(t)
		hsActive.EXPECT().GetPropertyType().Return("802-11-wireless", nil)
		hsActive.EXPECT().GetPropertyConnection().Return(hsConn, nil)
		hsConn.EXPECT().GetSettings().Return(buildHotspotSettings(HotspotRequest{SSID: "dms-ap", Password: "pw"}), nil)

		backend, mockSettings := newBackend(t, hsActive)
		mockSettings.EXPECT().ListConnections().Return(nil, nil).Once()
		_, err := backend.GetWiFiQRCodeContent("other-ssid")
		assert.ErrorContains(t, err, "no saved connection")
	})

	t.Run("inactive hotspot keeps the saved-connection error", func(t *testing.T) {
		backend, mockSettings := newBackend(t)
		mockSettings.EXPECT().ListConnections().Return(nil, nil).Once()
		_, err := backend.GetWiFiQRCodeContent("dms-ap")
		assert.ErrorContains(t, err, "no saved connection")
	})
}

func TestNetworkManagerBackend_GetWiFiEnabled(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	mockNM.EXPECT().GetPropertyWirelessEnabled().Return(true, nil)

	enabled, err := backend.GetWiFiEnabled()
	assert.NoError(t, err)
	assert.True(t, enabled)
}

func TestNetworkManagerBackend_SetWiFiEnabled(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	mockNM.EXPECT().SetPropertyWirelessEnabled(true).Return(nil)

	err = backend.SetWiFiEnabled(true)
	assert.NoError(t, err)

	backend.stateMutex.RLock()
	assert.True(t, backend.state.WiFiEnabled)
	backend.stateMutex.RUnlock()
}

func TestNetworkManagerBackend_ScanWiFi_NoDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.wifiDevice = nil
	err = backend.ScanWiFi()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no WiFi device available")
}

func TestNetworkManagerBackend_ScanWiFi_Disabled(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockDeviceWireless := mock_gonetworkmanager.NewMockDeviceWireless(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.wifiDevice = mockDeviceWireless
	backend.wifiDev = mockDeviceWireless

	backend.stateMutex.Lock()
	backend.state.WiFiEnabled = false
	backend.stateMutex.Unlock()

	err = backend.ScanWiFi()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "WiFi is disabled")
}

func TestNetworkManagerBackend_GetWiFiNetworkDetails_NoDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.wifiDevice = nil
	_, err = backend.GetWiFiNetworkDetails("TestNetwork")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no WiFi device available")
}

func TestNetworkManagerBackend_ConnectWiFi_NoDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.wifiDevice = nil
	req := ConnectionRequest{SSID: "TestNetwork", Password: "password"}
	err = backend.ConnectWiFi(req)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no WiFi device available")
}

func TestNetworkManagerBackend_ConnectWiFi_AlreadyConnected(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockDeviceWireless := mock_gonetworkmanager.NewMockDeviceWireless(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.wifiDevice = mockDeviceWireless
	backend.wifiDev = mockDeviceWireless
	backend.wifiDevices = map[string]*wifiDeviceInfo{
		"wlan0": {
			device:    nil,
			wireless:  mockDeviceWireless,
			name:      "wlan0",
			hwAddress: "00:11:22:33:44:55",
		},
	}

	mockDeviceWireless.EXPECT().GetPropertyInterface().Return("wlan0", nil)

	backend.stateMutex.Lock()
	backend.state.WiFiConnected = true
	backend.state.WiFiSSID = "TestNetwork"
	backend.state.WiFiDevice = "wlan0"
	backend.stateMutex.Unlock()

	req := ConnectionRequest{SSID: "TestNetwork", Password: "password"}
	err = backend.ConnectWiFi(req)
	assert.NoError(t, err)
}

func TestNetworkManagerBackend_DisconnectWiFi_NoDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.wifiDevice = nil
	err = backend.DisconnectWiFi()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no WiFi device available")
}

func TestNetworkManagerBackend_IsConnectingTo(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.stateMutex.Lock()
	backend.state.IsConnecting = true
	backend.state.ConnectingSSID = "TestNetwork"
	backend.stateMutex.Unlock()

	assert.True(t, backend.IsConnectingTo("TestNetwork"))
	assert.False(t, backend.IsConnectingTo("OtherNetwork"))
}

func TestNetworkManagerBackend_IsConnectingTo_NotConnecting(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.stateMutex.Lock()
	backend.state.IsConnecting = false
	backend.state.ConnectingSSID = ""
	backend.stateMutex.Unlock()

	assert.False(t, backend.IsConnectingTo("TestNetwork"))
}

func TestNetworkManagerBackend_UpdateWiFiNetworks_NoDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.wifiDevice = nil
	_, err = backend.updateWiFiNetworks()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no WiFi device available")
}

func TestNetworkManagerBackend_UpdateSavedWiFiNetworksPreservesVisibleSavedNetworks(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)
	mockConn := mock_gonetworkmanager.NewMockConnection(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)
	backend.settings = mockSettings

	backend.stateMutex.Lock()
	backend.state.WiFiNetworks = []WiFiNetwork{
		{
			SSID:   "Home",
			Signal: 76,
		},
	}
	backend.stateMutex.Unlock()

	settings := gonetworkmanager.ConnectionSettings{
		"connection": {
			"type":        "802-11-wireless",
			"autoconnect": true,
		},
		"802-11-wireless": {
			"ssid": []byte("Home"),
		},
		"802-11-wireless-security": {},
	}
	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{mockConn}, nil)
	mockConn.EXPECT().GetSettings().Return(settings, nil)

	err = backend.updateSavedWiFiNetworks()
	assert.NoError(t, err)

	backend.stateMutex.RLock()
	savedNetworks := append([]WiFiNetwork(nil), backend.state.SavedWiFiNetworks...)
	wifiNetworks := append([]WiFiNetwork(nil), backend.state.WiFiNetworks...)
	backend.stateMutex.RUnlock()

	assert.Len(t, wifiNetworks, 1)
	assert.True(t, wifiNetworks[0].Saved)
	assert.Len(t, savedNetworks, 1)
	assert.Equal(t, "Home", savedNetworks[0].SSID)
	assert.True(t, savedNetworks[0].Saved)
	assert.False(t, savedNetworks[0].OutOfRange)
	assert.Equal(t, uint8(76), savedNetworks[0].Signal)
}

func TestNetworkManagerBackend_FindConnection_NoSettings(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.settings = nil
	_, err = backend.findConnection("NonExistentNetwork")
	assert.Error(t, err)
}

func TestNetworkManagerBackend_CreateAndConnectWiFi_NoDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.wifiDevice = nil
	backend.wifiDev = nil
	req := ConnectionRequest{SSID: "TestNetwork", Password: "password"}
	err = backend.createAndConnectWiFi(req)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no WiFi device available")
}

const testWiFiConnPath = dbus.ObjectPath("/org/freedesktop/NetworkManager/Settings/7")

func wifiWriteFixture(t *testing.T) (*NetworkManagerBackend, *mock_gonetworkmanager.MockConnection, *mock_dbus.MockBusObject) {
	conn := mock_gonetworkmanager.NewMockConnection(t)
	conn.EXPECT().GetPath().Return(testWiFiConnPath).Maybe()
	conn.EXPECT().GetSettings().Return(gonetworkmanager.ConnectionSettings{
		"connection":      {"type": "802-11-wireless"},
		"802-11-wireless": {"ssid": []byte("home")},
	}, nil).Maybe()

	settings := mock_gonetworkmanager.NewMockSettings(t)
	settings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{conn}, nil).Maybe()

	backend, err := NewNetworkManagerBackend(mock_gonetworkmanager.NewMockNetworkManager(t))
	require.NoError(t, err)
	backend.settings = settings

	obj := mock_dbus.NewMockBusObject(t)
	backend.nmObjectFn = func(p dbus.ObjectPath) dbus.BusObject {
		require.Equal(t, testWiFiConnPath, p)
		return obj
	}
	return backend, conn, obj
}

func TestSetWiFiAutoconnect_KeepsManualDNSAndGateway(t *testing.T) {
	backend, _, obj := wifiWriteFixture(t)
	expectGetSettings(obj, nmSettings{
		"connection": {"autoconnect": dbus.MakeVariant(true)},
		"ipv4": {
			"address-data": dbus.MakeVariant([]map[string]dbus.Variant{{"address": dbus.MakeVariant("10.0.0.2"), "prefix": dbus.MakeVariant(uint32(24))}}),
			"addresses":    dbus.MakeVariant([][]uint32{{33554442, 24, 16777226}}),
			"gateway":      dbus.MakeVariant("10.0.0.1"),
			"dns":          dbus.MakeVariant([]uint32{16843009}),
			"dns-data":     dbus.MakeVariant([]string{"1.1.1.1"}),
		},
	})
	got := captureUpdate2(obj, nmUpdate2FlagToDisk, nil)

	require.NoError(t, backend.SetWiFiAutoconnect("home", false))

	assert.Equal(t, false, (*got)["connection"]["autoconnect"].Value())
	ipv4 := (*got)["ipv4"]
	assert.Contains(t, ipv4, "dns-data")
	assert.Contains(t, ipv4, "address-data")
	assert.Contains(t, ipv4, "gateway")
	assert.NotContains(t, ipv4, "addresses")
	assert.NotContains(t, ipv4, "dns")
}

func TestUpdateConnectionCredentials_NewPSKReplacesStored(t *testing.T) {
	backend, conn, obj := wifiWriteFixture(t)
	expectGetSettings(obj, nmSettings{
		"802-11-wireless-security": {"key-mgmt": dbus.MakeVariant("wpa-psk"), "psk-flags": dbus.MakeVariant(uint32(1))},
	})
	expectGetSecrets(obj, "802-11-wireless-security", nmSettings{
		"802-11-wireless-security": {"psk": dbus.MakeVariant("old")},
	})
	got := captureUpdate2(obj, nmUpdate2FlagToDisk, nil)

	require.NoError(t, updateConnectionCredentials(backend, conn, ConnectionRequest{Password: "new"}))

	sec := (*got)["802-11-wireless-security"]
	assert.Equal(t, "new", sec["psk"].Value())
	assert.Equal(t, uint32(0), sec["psk-flags"].Value())
}

func TestUpdateConnectionCredentials_EmptyPasswordWritesNothing(t *testing.T) {
	backend, conn, obj := wifiWriteFixture(t)
	expectGetSettings(obj, nmSettings{
		"802-11-wireless-security": {"key-mgmt": dbus.MakeVariant("wpa-psk")},
	})
	expectGetSecrets(obj, "802-11-wireless-security", nmSettings{
		"802-11-wireless-security": {"psk": dbus.MakeVariant("old")},
	})
	// No Update2 expectation: the strict mock fails the test if it is called.
	require.NoError(t, updateConnectionCredentials(backend, conn, ConnectionRequest{SSID: "home"}))
}

func ttlsConfig(t *testing.T, ca []byte) *EnterpriseConfig {
	return &EnterpriseConfig{
		EAP: "ttls", Phase2: "pap", Identity: "u@example.org",
		CA: "file", CACertPEM: string(pemCert(ca)), ServerDomain: "radius.example.org",
	}
}

func TestBuildWiFiSettings(t *testing.T) {
	ca := testCertDER(t, "ca")
	withPassword := func(c *EnterpriseConfig) *EnterpriseConfig { c.Password = "pw"; return c }

	t.Run("hidden sae", func(t *testing.T) {
		s, err := buildWiFiSettings(ConnectionRequest{SSID: "h", Hidden: true, Security: "sae", Password: "pw"}, apSecurity{})
		require.NoError(t, err)
		sec := s["802-11-wireless-security"]
		assert.Equal(t, "sae", sec["key-mgmt"])
		assert.Equal(t, int32(3), sec["pmf"])
		assert.Equal(t, "pw", sec["psk"])
		assert.Equal(t, true, s["802-11-wireless"]["hidden"])
		assert.Equal(t, []byte("h"), s["802-11-wireless"]["ssid"])
		assert.Equal(t, "h", s["connection"]["id"])
		assert.Equal(t, true, s["connection"]["autoconnect"])
		assert.Equal(t, "auto", s["ipv4"]["method"])
		assert.Equal(t, "auto", s["ipv6"]["method"])
	})

	t.Run("hidden owe", func(t *testing.T) {
		s, err := buildWiFiSettings(ConnectionRequest{SSID: "h", Hidden: true, Security: "owe"}, apSecurity{})
		require.NoError(t, err)
		sec := s["802-11-wireless-security"]
		assert.Equal(t, "owe", sec["key-mgmt"])
		assert.NotContains(t, sec, "psk")
	})

	t.Run("hidden wpa-eap ttls", func(t *testing.T) {
		s, err := buildWiFiSettings(ConnectionRequest{SSID: "h", Hidden: true, Security: "wpa-eap",
			Enterprise: withPassword(ttlsConfig(t, ca))}, apSecurity{})
		require.NoError(t, err)
		assert.Equal(t, "wpa-eap", s["802-11-wireless-security"]["key-mgmt"])
		x := s["802-1x"]
		assert.Equal(t, []string{"ttls"}, x["eap"])
		assert.Equal(t, "pap", x["phase2-auth"])
		assert.Equal(t, ca, x["ca-cert"])
		assert.Equal(t, "radius.example.org", x["domain-match"])
		assert.Equal(t, uint32(0), x["password-flags"])
		for k, v := range x {
			assert.NotNil(t, v, "nil value for %s", k)
		}
		assert.NotContains(t, x, "ca-path")
		assert.NotContains(t, x, "system-ca-certs")
	})

	t.Run("enterprise ap without config", func(t *testing.T) {
		_, err := buildWiFiSettings(ConnectionRequest{SSID: "e"}, apSecurity{enterprise: true, secured: true})
		assert.ErrorContains(t, err, "802.1X settings required")
	})

	t.Run("explicit security overrides psk ap", func(t *testing.T) {
		s, err := buildWiFiSettings(ConnectionRequest{SSID: "e", Security: "wpa-eap",
			Enterprise: withPassword(ttlsConfig(t, ca))}, apSecurity{psk: true, secured: true})
		require.NoError(t, err)
		assert.Equal(t, "wpa-eap", s["802-11-wireless-security"]["key-mgmt"])
		assert.Contains(t, s, "802-1x")
	})

	t.Run("hidden without security infers from request", func(t *testing.T) {
		s, err := buildWiFiSettings(ConnectionRequest{SSID: "h", Hidden: true, Password: "pw"}, apSecurity{})
		require.NoError(t, err)
		assert.Equal(t, "wpa-psk", s["802-11-wireless-security"]["key-mgmt"])

		s, err = buildWiFiSettings(ConnectionRequest{SSID: "h", Hidden: true}, apSecurity{})
		require.NoError(t, err)
		assert.NotContains(t, s, "802-11-wireless-security")
		assert.NotContains(t, s["802-11-wireless"], "security")
	})

	t.Run("psk required unless interactive", func(t *testing.T) {
		_, err := buildWiFiSettings(ConnectionRequest{SSID: "p", Security: "wpa-psk"}, apSecurity{})
		assert.Error(t, err)
		s, err := buildWiFiSettings(ConnectionRequest{SSID: "p", Interactive: true}, apSecurity{psk: true, secured: true})
		require.NoError(t, err)
		assert.NotContains(t, s["802-11-wireless-security"], "psk")
	})

	t.Run("unknown security", func(t *testing.T) {
		_, err := buildWiFiSettings(ConnectionRequest{SSID: "x", Security: "wep"}, apSecurity{})
		assert.ErrorContains(t, err, "wep")
	})
}

func TestSaveOnly_UpdatesExistingProfileInPlace(t *testing.T) {
	backend, _, obj := wifiWriteFixture(t)
	backend.wifiDevice = nil
	expectGetSettings(obj, nmSettings{
		"connection":               {"uuid": dbus.MakeVariant("u-1"), "id": dbus.MakeVariant("home")},
		"ipv4":                     {"method": dbus.MakeVariant("auto"), "dns-data": dbus.MakeVariant([]string{"9.9.9.9"})},
		"802-11-wireless-security": {"key-mgmt": dbus.MakeVariant("wpa-eap")},
		"802-1x": {
			"eap":            dbus.MakeVariant([]string{"peap"}),
			"phase2-auth":    dbus.MakeVariant("mschapv2"),
			"identity":       dbus.MakeVariant("old"),
			"password-flags": dbus.MakeVariant(uint32(1)),
		},
	})
	expectGetSecrets(obj, "802-11-wireless-security", nmSettings{})
	expectGetSecrets(obj, "802-1x", nmSettings{"802-1x": {"password": dbus.MakeVariant("stored")}})
	got := captureUpdate2(obj, nmUpdate2FlagToDisk, nil)

	ca := testCertDER(t, "ca")
	require.NoError(t, backend.ConnectWiFi(ConnectionRequest{SSID: "home", Security: "wpa-eap", SaveOnly: true,
		Enterprise: ttlsConfig(t, ca)}))

	x := (*got)["802-1x"]
	assert.Equal(t, []string{"ttls"}, x["eap"].Value())
	assert.Equal(t, "pap", x["phase2-auth"].Value())
	assert.Equal(t, "stored", x["password"].Value())
	assert.Equal(t, uint32(0), x["password-flags"].Value())
	assert.Equal(t, ca, x["ca-cert"].Value())
	assert.Equal(t, []string{"9.9.9.9"}, (*got)["ipv4"]["dns-data"].Value())
	assert.Equal(t, "u-1", (*got)["connection"]["uuid"].Value())
	assert.Equal(t, "wpa-eap", (*got)["802-11-wireless-security"]["key-mgmt"].Value())
	assert.False(t, backend.state.IsConnecting)
}

func TestUpdateConnectionCredentials_SAEToEnterpriseDropsPSKAndPMF(t *testing.T) {
	backend, conn, obj := wifiWriteFixture(t)
	expectGetSettings(obj, nmSettings{
		"802-11-wireless-security": {
			"key-mgmt":  dbus.MakeVariant("sae"),
			"pmf":       dbus.MakeVariant(int32(3)),
			"auth-alg":  dbus.MakeVariant("open"),
			"psk-flags": dbus.MakeVariant(uint32(0)),
		},
	})
	expectGetSecrets(obj, "802-11-wireless-security", nmSettings{
		"802-11-wireless-security": {"psk": dbus.MakeVariant("old")},
	})
	got := captureUpdate2(obj, nmUpdate2FlagToDisk, nil)

	cfg := ttlsConfig(t, testCertDER(t, "ca"))
	require.NoError(t, updateConnectionCredentials(backend, conn, ConnectionRequest{SSID: "home", Enterprise: cfg}))

	sec := (*got)["802-11-wireless-security"]
	assert.Equal(t, "wpa-eap", sec["key-mgmt"].Value())
	for _, k := range []string{"psk", "psk-flags", "pmf", "auth-alg"} {
		assert.NotContains(t, sec, k)
	}
}

func TestSaveOnly_ExistingProfileSetsHiddenAndAutoconnect(t *testing.T) {
	backend, _, obj := wifiWriteFixture(t)
	expectGetSettings(obj, nmSettings{
		"connection":               {"id": dbus.MakeVariant("home"), "autoconnect": dbus.MakeVariant(false)},
		"802-11-wireless":          {"ssid": dbus.MakeVariant([]byte("home"))},
		"802-11-wireless-security": {"key-mgmt": dbus.MakeVariant("wpa-psk")},
	})
	expectGetSecrets(obj, "802-11-wireless-security", nmSettings{
		"802-11-wireless-security": {"psk": dbus.MakeVariant("old")},
	})
	got := captureUpdate2(obj, nmUpdate2FlagToDisk, nil)

	require.NoError(t, backend.ConnectWiFi(ConnectionRequest{SSID: "home", Password: "new", Hidden: true,
		Security: "wpa-psk", SaveOnly: true}))

	assert.Equal(t, true, (*got)["802-11-wireless"]["hidden"].Value())
	assert.Equal(t, true, (*got)["connection"]["autoconnect"].Value())
	assert.Equal(t, "new", (*got)["802-11-wireless-security"]["psk"].Value())
}

func TestSaveOnly_PSKFamilyIsCompatible(t *testing.T) {
	backend, _, obj := wifiWriteFixture(t)
	expectGetSettings(obj, nmSettings{
		"connection":               {"id": dbus.MakeVariant("home")},
		"802-11-wireless":          {"ssid": dbus.MakeVariant([]byte("home"))},
		"802-11-wireless-security": {"key-mgmt": dbus.MakeVariant("sae")},
	})
	expectGetSecrets(obj, "802-11-wireless-security", nmSettings{})
	got := captureUpdate2(obj, nmUpdate2FlagToDisk, nil)

	require.NoError(t, backend.ConnectWiFi(ConnectionRequest{SSID: "home", Security: "wpa-psk", SaveOnly: true}))
	assert.Equal(t, true, (*got)["connection"]["autoconnect"].Value())
	assert.Equal(t, "sae", (*got)["802-11-wireless-security"]["key-mgmt"].Value())
}

func TestSaveOnly_OpenAndOWEProfilesSetAutoconnect(t *testing.T) {
	for _, security := range []string{"none", "owe"} {
		t.Run(security, func(t *testing.T) {
			backend, _, obj := wifiWriteFixture(t)
			settings := nmSettings{
				"connection":      {"id": dbus.MakeVariant("home"), "autoconnect": dbus.MakeVariant(false)},
				"802-11-wireless": {"ssid": dbus.MakeVariant([]byte("home"))},
			}
			if security == "owe" {
				settings["802-11-wireless-security"] = map[string]dbus.Variant{"key-mgmt": dbus.MakeVariant("owe")}
			}
			expectGetSettings(obj, settings)
			if security == "owe" {
				expectGetSecrets(obj, "802-11-wireless-security", nmSettings{})
			}
			got := captureUpdate2(obj, nmUpdate2FlagToDisk, nil)

			require.NoError(t, backend.ConnectWiFi(ConnectionRequest{SSID: "home", Password: "unused", Security: security, SaveOnly: true}))
			assert.Equal(t, true, (*got)["connection"]["autoconnect"].Value())
		})
	}
}

func TestSaveOnly_SecurityMismatchOnExistingProfileErrors(t *testing.T) {
	backend, _, obj := wifiWriteFixture(t)
	expectGetSettings(obj, nmSettings{
		"connection":      {"id": dbus.MakeVariant("home")},
		"802-11-wireless": {"ssid": dbus.MakeVariant([]byte("home"))},
	})
	// No Update2 expectation: the strict mock fails the test if it is called.
	err := backend.ConnectWiFi(ConnectionRequest{SSID: "home", Password: "pw", Security: "wpa-psk", SaveOnly: true})
	assert.ErrorContains(t, err, "security")
}

func TestSaveOnly_AddsNewProfileWithoutActivating(t *testing.T) {
	settings := mock_gonetworkmanager.NewMockSettings(t)
	settings.EXPECT().ListConnections().Return(nil, nil)
	var added gonetworkmanager.ConnectionSettings
	settings.EXPECT().AddConnection(mock.Anything).
		Run(func(s gonetworkmanager.ConnectionSettings) { added = s }).
		Return(nil, nil).Once()

	backend, err := NewNetworkManagerBackend(mock_gonetworkmanager.NewMockNetworkManager(t))
	require.NoError(t, err)
	backend.settings = settings
	backend.wifiDevice = nil
	changed := false
	backend.onStateChange = func() { changed = true }

	cfg := ttlsConfig(t, testCertDER(t, "ca"))
	cfg.Password = "pw"
	require.NoError(t, backend.ConnectWiFi(ConnectionRequest{SSID: "eduroam", Security: "wpa-eap", SaveOnly: true, Enterprise: cfg}))

	assert.Equal(t, []byte("eduroam"), added["802-11-wireless"]["ssid"])
	assert.Equal(t, []string{"ttls"}, added["802-1x"]["eap"])
	assert.Equal(t, "pw", added["802-1x"]["password"])
	assert.False(t, backend.state.IsConnecting)
	assert.Empty(t, backend.state.ConnectingSSID)
	assert.False(t, changed)
}

func TestConnectWiFi_ExistingEnterpriseUpdateFailureBlocksActivation(t *testing.T) {
	backend, _, obj := wifiWriteFixture(t)
	wireless := mock_gonetworkmanager.NewMockDeviceWireless(t)
	wireless.EXPECT().GetPropertyInterface().Return("wlan0", nil).Maybe()
	backend.wifiDevice = wireless
	backend.wifiDev = wireless
	backend.wifiDevices = map[string]*wifiDeviceInfo{"wlan0": {wireless: wireless, name: "wlan0"}}

	expectGetSettings(obj, nmSettings{"802-1x": {"eap": dbus.MakeVariant([]string{"peap"})}})
	obj.EXPECT().Call(nmConnGetSecrets, dbus.Flags(0), "802-1x").
		Return(&dbus.Call{Err: errors.New("denied")}).Once()

	cfg := ttlsConfig(t, testCertDER(t, "ca"))
	err := backend.ConnectWiFi(ConnectionRequest{SSID: "home", Enterprise: cfg})
	assert.ErrorContains(t, err, "denied")
	assert.False(t, backend.state.IsConnecting)
	assert.Empty(t, backend.state.ConnectingSSID)
	assert.NotEmpty(t, backend.state.LastError)
}
