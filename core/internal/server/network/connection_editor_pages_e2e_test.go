package network

import (
	"encoding/binary"
	"encoding/json"
	"testing"

	mock_dbus "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/github.com/godbus/dbus/v5"
	"github.com/Wifx/gonetworkmanager/v2"
	"github.com/godbus/dbus/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestE2E_WiredEnterpriseAddedFromEditor(t *testing.T) {
	f := newEditorFixture(t)
	f.nm.EXPECT().GetPropertyVersion().Return("1.58.1", nil).Once()
	added := captureAddConnection(f.object(t, nmSettingsPath), nmSettingsAddConnection)

	resp := e2eRequest(t, f.backend, "network.connection.add", map[string]any{
		"settings": map[string]any{
			"connection": map[string]any{"id": "dms-test-eth", "type": "802-3-ethernet", "interface-name": "enp5s0"},
			"802-3-ethernet": map[string]any{
				"assigned-mac-address": "stable", "mac-address": "AA:BB:CC:DD:EE:FF",
			},
			"ipv4": map[string]any{
				"method":       "manual",
				"address-data": []any{map[string]any{"address": "192.0.2.10", "prefix": float64(24)}},
				"gateway":      "192.0.2.1",
				"dns-data":     []any{"192.0.2.53"},
			},
		},
		"enterprise": map[string]any{
			"eap": "ttls", "phase2": "pap", "identity": "t", "password": "x",
			"ca": "system", "serverDomain": "radius.example.org",
		},
	})

	require.Empty(t, resp.Error)
	s := *added
	assert.Equal(t, []byte{0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF}, s["802-3-ethernet"]["mac-address"].Value())
	assert.Equal(t, "stable", s["802-3-ethernet"]["assigned-mac-address"].Value())
	addrs, ok := s["ipv4"]["address-data"].Value().([]map[string]dbus.Variant)
	require.True(t, ok)
	require.Len(t, addrs, 1)
	assert.Equal(t, "192.0.2.10", addrs[0]["address"].Value())
	assert.Equal(t, uint32(24), addrs[0]["prefix"].Value())
	assert.Equal(t, []string{"ttls"}, s["802-1x"]["eap"].Value())
	assert.Equal(t, true, s["802-1x"]["system-ca-certs"].Value())
	assert.Equal(t, "pap", s["802-1x"]["phase2-auth"].Value())
}

func TestE2E_EnterpriseEditKeepsStoredCertificates(t *testing.T) {
	f := newEditorFixture(t)
	obj := f.profile(t, "u1", "/s/1")
	ca := []byte("stored-der-bytes")
	stored := func() nmSettings {
		s := connSection("u1", "Corp", "802-3-ethernet", nil)
		s["802-3-ethernet"] = map[string]dbus.Variant{"mtu": dbus.MakeVariant(uint32(1500))}
		s["ipv4"] = map[string]dbus.Variant{
			"method":   dbus.MakeVariant("auto"),
			"dns-data": dbus.MakeVariant([]string{"192.0.2.53"}),
		}
		s["802-1x"] = map[string]dbus.Variant{
			"eap":         dbus.MakeVariant([]string{"ttls"}),
			"phase2-auth": dbus.MakeVariant("pap"),
			"identity":    dbus.MakeVariant("old"),
			"ca-cert":     dbus.MakeVariant(ca),
		}
		return s
	}
	expectGetSettings(obj, stored())

	resp := e2eRequest(t, f.backend, "network.connection.getEnterprise", map[string]any{"uuid": "u1"})
	require.Empty(t, resp.Error)
	var cfg map[string]any
	require.NoError(t, json.Unmarshal(*resp.Result, &cfg))
	assert.Equal(t, "file", cfg["ca"])
	assert.Empty(t, cfg["caCertPath"])

	cfg["identity"] = "new"
	expectGetSettings(obj, stored())
	expectGetSecrets(obj, "802-1x", nmSettings{})
	got := captureUpdate2(obj, 0, nil)

	resp = e2eRequest(t, f.backend, "network.connection.update", map[string]any{
		"uuid":       "u1",
		"settings":   map[string]any{"802-3-ethernet": map[string]any{"mtu": float64(1400)}},
		"enterprise": cfg,
	})

	require.Empty(t, resp.Error)
	s := *got
	assert.Equal(t, ca, s["802-1x"]["ca-cert"].Value())
	assert.Equal(t, "new", s["802-1x"]["identity"].Value())
	assert.Equal(t, uint32(1400), s["802-3-ethernet"]["mtu"].Value())
	assert.Equal(t, []string{"192.0.2.53"}, s["ipv4"]["dns-data"].Value())
}

func TestE2E_OldNetworkManagerDNS(t *testing.T) {
	f := newEditorFixture(t)
	f.nm.EXPECT().GetPropertyVersion().Return("1.46.0", nil).Once()
	obj := f.profile(t, "u1", "/s/1")
	// NM stores network-order address bytes read as a native uint32.
	little := binary.NativeEndian.Uint16([]byte{1, 0}) == 1
	au := func(le, be uint32) uint32 {
		if little {
			return le
		}
		return be
	}
	stored := func() nmSettings {
		s := connSection("u1", "Wired", "802-3-ethernet", nil)
		s["ipv4"] = map[string]dbus.Variant{
			"method": dbus.MakeVariant("auto"),
			"dns":    dbus.MakeVariant([]uint32{au(0x3502_00C0, 0xC0000235)}),
		}
		return s
	}
	expectGetSettings(obj, stored())

	resp := e2eRequest(t, f.backend, "network.connection.get", map[string]any{"uuid": "u1"})
	require.Empty(t, resp.Error)
	var got struct {
		IPv4 map[string]any `json:"ipv4"`
	}
	require.NoError(t, json.Unmarshal(*resp.Result, &got))
	assert.Equal(t, []any{"192.0.2.53"}, got.IPv4["dns-data"])
	assert.NotContains(t, got.IPv4, "dns")

	expectGetSettings(obj, stored())
	sent := captureUpdate2(obj, 0, nil)
	resp = e2eRequest(t, f.backend, "network.connection.update", map[string]any{
		"uuid":     "u1",
		"settings": map[string]any{"ipv4": map[string]any{"dns-data": []any{"9.9.9.9"}}},
	})

	require.Empty(t, resp.Error)
	v4 := (*sent)["ipv4"]
	assert.Equal(t, []uint32{0x09090909}, v4["dns"].Value())
	assert.NotContains(t, v4, "dns-data")
}

func TestE2E_ActivateAndDeactivateProfile(t *testing.T) {
	f := newEditorFixture(t)
	conn := mockWiredProfile(t, "u1", "enp5s0", nil)
	f.settings.EXPECT().GetConnectionByUUID("u1").Return(conn, nil).Once()
	f.nm.EXPECT().ActivateConnection(conn, gonetworkmanager.Device(nil), (*dbus.Object)(nil)).Return(nil, nil).Once()
	ac := activeConnection(t, "u1")
	f.nm.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{ac}, nil).Once()
	f.nm.EXPECT().DeactivateConnection(ac).Return(nil).Once()

	resp := e2eRequest(t, f.backend, "network.connection.activate", map[string]any{"uuid": "u1"})
	require.Empty(t, resp.Error)
	resp = e2eRequest(t, f.backend, "network.connection.deactivate", map[string]any{"uuid": "u1"})
	assert.Empty(t, resp.Error)
}

func TestE2E_ReadOnlyListAndNoFirewalld(t *testing.T) {
	f := newEditorFixture(t)
	system := listedConnection(t, f, "/s/1", 0, connSection("u-sys", "Corp", "802-3-ethernet", nil))
	f.settings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{system}, nil).Once()
	f.nm.EXPECT().GetPropertyActiveConnections().Return(nil, nil).Once()
	expectPermissions(t, f, map[string]string{"org.freedesktop.NetworkManager.settings.modify.system": "no"}, nil)
	fw := mock_dbus.NewMockBusObject(t)
	f.backend.firewalldObjectFn = func() dbus.BusObject { return fw }
	fw.EXPECT().Call(firewalldGetZones, dbus.Flags(0)).
		Return(&dbus.Call{Err: dbus.Error{Name: "org.freedesktop.DBus.Error.ServiceUnknown"}}).Once()

	resp := e2eRequest(t, f.backend, "network.connection.list", nil)
	require.Empty(t, resp.Error)
	var profiles []struct {
		UUID      string `json:"uuid"`
		CanModify bool   `json:"canModify"`
	}
	require.NoError(t, json.Unmarshal(*resp.Result, &profiles))
	require.Len(t, profiles, 1)
	assert.False(t, profiles[0].CanModify)

	resp = e2eRequest(t, f.backend, "network.connection.firewallZones", nil)
	require.Empty(t, resp.Error)
	assert.JSONEq(t, `[]`, string(*resp.Result))
}
