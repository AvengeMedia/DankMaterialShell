package network

import (
	"encoding/json"
	"testing"

	mock_gonetworkmanager "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/github.com/Wifx/gonetworkmanager/v2"
	"github.com/Wifx/gonetworkmanager/v2"
	"github.com/godbus/dbus/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestE2E_BridgeWithPort(t *testing.T) {
	f := newEditorFixture(t)
	settingsObj := f.object(t, nmSettingsPath)
	bridge := captureAddConnection(settingsObj, nmSettingsAddConnection)

	resp := e2eRequest(t, f.backend, "network.connection.add", map[string]any{
		"settings": map[string]any{
			"connection": map[string]any{
				"id": "dms-test-br", "type": "bridge", "interface-name": "dmsbr0",
				"autoconnect": false, "autoconnect-slaves": float64(1),
			},
			"bridge": map[string]any{"stp": true, "priority": float64(4096)},
			"ipv4":   map[string]any{"method": "auto"},
			"ipv6":   map[string]any{"method": "auto"},
		},
	})
	require.Empty(t, resp.Error)

	b := *bridge
	assert.Equal(t, "i", b["connection"]["autoconnect-slaves"].Signature().String())
	assert.Equal(t, int32(1), b["connection"]["autoconnect-slaves"].Value())
	assert.Equal(t, "b", b["bridge"]["stp"].Signature().String())
	assert.Equal(t, true, b["bridge"]["stp"].Value())
	assert.Equal(t, "u", b["bridge"]["priority"].Signature().String())
	assert.Equal(t, uint32(4096), b["bridge"]["priority"].Value())
	uuid, ok := b["connection"]["uuid"].Value().(string)
	require.True(t, ok)

	port := captureAddConnection(settingsObj, nmSettingsAddConnection)
	resp = e2eRequest(t, f.backend, "network.connection.add", map[string]any{
		"settings": map[string]any{
			"connection": map[string]any{
				"id": "enp5s0-port-dmsbr0", "type": "802-3-ethernet", "interface-name": "enp5s0",
				"master": uuid, "slave-type": "bridge",
			},
			"802-3-ethernet": map[string]any{},
			"bridge-port":    map[string]any{"priority": float64(16)},
		},
	})
	require.Empty(t, resp.Error)

	p := *port
	assert.Equal(t, "s", p["connection"]["master"].Signature().String())
	assert.Equal(t, uuid, p["connection"]["master"].Value())
	assert.Equal(t, "s", p["connection"]["slave-type"].Signature().String())
	assert.Equal(t, "bridge", p["connection"]["slave-type"].Value())
	assert.Equal(t, "u", p["bridge-port"]["priority"].Signature().String())
	assert.Equal(t, uint32(16), p["bridge-port"]["priority"].Value())
	assert.NotContains(t, p, "ipv4")
	assert.NotContains(t, p, "ipv6")
}

func TestE2E_VlanAddAndBondArpUpdate(t *testing.T) {
	f := newEditorFixture(t)
	added := captureAddConnection(f.object(t, nmSettingsPath), nmSettingsAddConnection)

	resp := e2eRequest(t, f.backend, "network.connection.add", map[string]any{
		"settings": map[string]any{
			"connection": map[string]any{"id": "dms-test-vlan", "type": "vlan", "interface-name": "enp5s0.100", "autoconnect": false},
			"vlan":       map[string]any{"parent": "enp5s0", "id": float64(100), "flags": float64(3)},
			"ipv4":       map[string]any{"method": "auto"},
			"ipv6":       map[string]any{"method": "auto"},
		},
	})
	require.Empty(t, resp.Error)
	v := (*added)["vlan"]
	assert.Equal(t, "s", v["parent"].Signature().String())
	assert.Equal(t, "enp5s0", v["parent"].Value())
	assert.Equal(t, "u", v["id"].Signature().String())
	assert.Equal(t, uint32(100), v["id"].Value())
	assert.Equal(t, "u", v["flags"].Signature().String())
	assert.Equal(t, uint32(3), v["flags"].Value())

	obj := f.profile(t, "u-bond", "/s/bond")
	stored := connSection("u-bond", "dms-test-bond", "bond", map[string]dbus.Variant{
		"interface-name": dbus.MakeVariant("dmsbond0"),
	})
	stored["bond"] = map[string]dbus.Variant{"options": dbus.MakeVariant(map[string]string{
		"mode": "active-backup", "miimon": "100", "primary": "enp5s0",
		"updelay": "200", "downdelay": "200",
	})}
	expectGetSettings(obj, stored)
	got := captureUpdate2(obj, 0, nil)

	resp = e2eRequest(t, f.backend, "network.connection.update", map[string]any{
		"uuid": "u-bond",
		"settings": map[string]any{"bond": map[string]any{"options": map[string]any{
			"mode": "active-backup", "miimon": "0", "arp_interval": "1000",
			"arp_ip_target": "192.0.2.1,192.0.2.2", "primary": "enp5s0",
		}}},
	})
	require.Empty(t, resp.Error)
	opts := (*got)["bond"]["options"]
	assert.Equal(t, "a{ss}", opts.Signature().String())
	assert.Equal(t, map[string]string{
		"mode": "active-backup", "miimon": "0", "arp_interval": "1000",
		"arp_ip_target": "192.0.2.1,192.0.2.2", "primary": "enp5s0",
	}, opts.Value())
}

func TestE2E_HotspotKeepsEditorKeysAndQRCode(t *testing.T) {
	f := newEditorFixture(t)
	const path = dbus.ObjectPath("/s/hotspot")
	obj := f.object(t, path)
	hotspotActive := false

	conn := mock_gonetworkmanager.NewMockConnection(t)
	conn.EXPECT().GetPath().Return(path).Maybe()
	conn.EXPECT().GetSettings().RunAndReturn(func() (gonetworkmanager.ConnectionSettings, error) {
		return buildHotspotSettings(HotspotRequest{SSID: "dms-ap", Password: testHotspotPSK, Band: "a"}), nil
	}).Maybe()
	conn.EXPECT().GetSecrets("802-11-wireless-security").Return(gonetworkmanager.ConnectionSettings{
		"802-11-wireless-security": {"psk": testHotspotPSK},
	}, nil).Maybe()
	f.settings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{conn}, nil).Maybe()

	ac := mock_gonetworkmanager.NewMockActiveConnection(t)
	ac.EXPECT().GetPropertyType().Return("802-11-wireless", nil).Maybe()
	ac.EXPECT().GetPropertyConnection().Return(conn, nil).Maybe()
	ac.EXPECT().GetPropertyState().Return(gonetworkmanager.NmActiveConnectionStateActivated, nil).Maybe()
	f.nm.EXPECT().GetPropertyActiveConnections().RunAndReturn(func() ([]gonetworkmanager.ActiveConnection, error) {
		if hotspotActive {
			return []gonetworkmanager.ActiveConnection{ac}, nil
		}
		return nil, nil
	}).Maybe()

	expectGetSettings(obj, storedHotspotSettings())
	expectGetSecrets(obj, "802-11-wireless-security", nmSettings{
		"802-11-wireless-security": {"psk": dbus.MakeVariant("stored-psk")},
	})
	got := captureUpdate2(obj, 0, nil)

	resp := e2eRequest(t, f.backend, "network.hotspot.configure", map[string]any{
		"ssid": "dms-ap", "password": testHotspotPSK, "band": "a",
		"channel": float64(36), "address": "10.43.0.1/24",
	})
	require.Empty(t, resp.Error)

	s := *got
	assert.Equal(t, "hotspot-uuid", s["connection"]["uuid"].Value())
	assert.Equal(t, int32(1), s["connection"]["metered"].Value())
	assert.Equal(t, uint32(2), s["802-11-wireless"]["powersave"].Value())
	assert.Equal(t, "u", s["802-11-wireless"]["channel"].Signature().String())
	assert.Equal(t, uint32(36), s["802-11-wireless"]["channel"].Value())
	assert.Equal(t, "a", s["802-11-wireless"]["band"].Value())
	assert.Equal(t, "aa{sv}", s["ipv4"]["address-data"].Signature().String())
	assert.Equal(t, []map[string]dbus.Variant{{
		"address": dbus.MakeVariant("10.43.0.1"),
		"prefix":  dbus.MakeVariant(uint32(24)),
	}}, s["ipv4"]["address-data"].Value())

	resp = e2eRequest(t, f.backend, "network.qrcode-content", map[string]any{"ssid": "dms-ap"})
	require.NotEmpty(t, resp.Error, "no QR content before the hotspot is active")

	hotspotActive = true
	resp = e2eRequest(t, f.backend, "network.qrcode-content", map[string]any{"ssid": "dms-ap"})
	require.Empty(t, resp.Error)
	var content string
	require.NoError(t, json.Unmarshal(*resp.Result, &content))
	assert.Contains(t, content, "WIFI:")
	assert.Contains(t, content, testHotspotPSK)
}

func TestE2E_CaptivePortalSimulated(t *testing.T) {
	f := newEditorFixture(t)
	nmObj := f.object(t, dbusNMPath)

	f.backend.handleDBusSignal(&dbus.Signal{
		Path: dbusNMPath,
		Name: dbusPropsInterface + ".PropertiesChanged",
		Body: []any{dbusNMInterface, map[string]dbus.Variant{
			"Connectivity":             dbus.MakeVariant(uint32(2)),
			"ConnectivityCheckEnabled": dbus.MakeVariant(true),
		}},
	})
	st, err := f.backend.GetCurrentState()
	require.NoError(t, err)
	assert.Equal(t, "portal", st.Connectivity)
	assert.True(t, st.ConnectivityCheckEnabled)

	nmObj.EXPECT().Call(dbusNMInterface+".CheckConnectivity", dbus.Flags(0)).
		Return(&dbus.Call{Body: []any{uint32(4)}}).Once()
	resp := e2eRequest(t, f.backend, "network.connectivity.check", nil)
	require.Empty(t, resp.Error)
	assert.JSONEq(t, `{"connectivity":"full"}`, string(*resp.Result))

	nmObj.EXPECT().Call(dbusPropsInterface+".Set", dbus.FlagAllowInteractiveAuthorization,
		dbusNMInterface, "ConnectivityCheckEnabled", dbus.MakeVariant(false)).
		Return(&dbus.Call{}).Once()
	resp = e2eRequest(t, f.backend, "network.connectivity.setCheckEnabled", map[string]any{"enabled": false})
	assert.Empty(t, resp.Error)
}

func TestE2E_MobileAndDSLAdd(t *testing.T) {
	f := newEditorFixture(t)
	settingsObj := f.object(t, nmSettingsPath)

	gsm := captureAddConnection(settingsObj, nmSettingsAddConnection)
	resp := e2eRequest(t, f.backend, "network.connection.add", map[string]any{
		"settings": map[string]any{
			"connection": map[string]any{"id": "dms-test-gsm", "type": "gsm", "autoconnect": false},
			"gsm": map[string]any{
				"apn": "internet.example", "auto-config": false, "home-only": true, "password-flags": float64(2),
			},
			"ipv4": map[string]any{"method": "auto"},
			"ipv6": map[string]any{"method": "auto"},
		},
	})
	require.Empty(t, resp.Error)
	g := (*gsm)["gsm"]
	assert.Equal(t, "s", g["apn"].Signature().String())
	assert.Equal(t, "internet.example", g["apn"].Value())
	assert.Equal(t, "b", g["auto-config"].Signature().String())
	assert.Equal(t, false, g["auto-config"].Value())
	assert.Equal(t, true, g["home-only"].Value())
	assert.Equal(t, "u", g["password-flags"].Signature().String())
	assert.Equal(t, uint32(2), g["password-flags"].Value())
	assert.NotContains(t, g, "password")

	pppoe := captureAddConnection(settingsObj, nmSettingsAddConnection)
	resp = e2eRequest(t, f.backend, "network.connection.add", map[string]any{
		"settings": map[string]any{
			"connection":     map[string]any{"id": "dms-test-dsl", "type": "pppoe", "autoconnect": false},
			"pppoe":          map[string]any{"username": "user@isp.example", "service": "isp"},
			"802-3-ethernet": map[string]any{},
			"ppp": map[string]any{
				"refuse-pap": true, "lcp-echo-interval": float64(30), "lcp-echo-failure": float64(5),
			},
			"ipv4": map[string]any{"method": "auto"},
			"ipv6": map[string]any{"method": "auto"},
		},
	})
	require.Empty(t, resp.Error)
	s := *pppoe
	assert.Equal(t, "user@isp.example", s["pppoe"]["username"].Value())
	assert.Equal(t, "isp", s["pppoe"]["service"].Value())
	assert.Equal(t, "b", s["ppp"]["refuse-pap"].Signature().String())
	assert.Equal(t, true, s["ppp"]["refuse-pap"].Value())
	assert.Equal(t, "u", s["ppp"]["lcp-echo-interval"].Signature().String())
	assert.Equal(t, uint32(30), s["ppp"]["lcp-echo-interval"].Value())
	assert.Equal(t, uint32(5), s["ppp"]["lcp-echo-failure"].Value())
}

func TestE2E_ExistingProxySectionSurvivesEdit(t *testing.T) {
	f := newEditorFixture(t)
	obj := f.profile(t, "u-eth", "/s/eth")
	stored := connSection("u-eth", "Wired", "802-3-ethernet", nil)
	stored["802-3-ethernet"] = map[string]dbus.Variant{}
	stored["proxy"] = map[string]dbus.Variant{
		"method":       dbus.MakeVariant(int32(1)),
		"pac-url":      dbus.MakeVariant("http://192.0.2.1/p.pac"),
		"browser-only": dbus.MakeVariant(true),
	}
	expectGetSettings(obj, stored)
	got := captureUpdate2(obj, 0, nil)

	resp := e2eRequest(t, f.backend, "network.connection.update", map[string]any{
		"uuid":     "u-eth",
		"settings": map[string]any{"802-3-ethernet": map[string]any{"mtu": float64(1400)}},
	})
	require.Empty(t, resp.Error)

	s := *got
	assert.Equal(t, uint32(1400), s["802-3-ethernet"]["mtu"].Value())
	proxy := s["proxy"]
	require.NotNil(t, proxy)
	assert.Equal(t, "i", proxy["method"].Signature().String())
	assert.Equal(t, int32(1), proxy["method"].Value())
	assert.Equal(t, "s", proxy["pac-url"].Signature().String())
	assert.Equal(t, "http://192.0.2.1/p.pac", proxy["pac-url"].Value())
	assert.Equal(t, "b", proxy["browser-only"].Signature().String())
	assert.Equal(t, true, proxy["browser-only"].Value())
}
