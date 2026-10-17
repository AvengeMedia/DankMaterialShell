package network

import (
	"errors"
	"testing"

	mock_dbus "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/github.com/godbus/dbus/v5"
	"github.com/godbus/dbus/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
)

type legacyIP6Addr struct {
	Addr    []byte
	Prefix  uint32
	Gateway []byte
}

func expectGetSettings(obj *mock_dbus.MockBusObject, s nmSettings) {
	obj.EXPECT().Call(nmConnGetSettings, dbus.Flags(0)).
		Return(&dbus.Call{Body: []any{s}}).Once()
}

func expectGetSecrets(obj *mock_dbus.MockBusObject, setting string, s nmSettings) {
	obj.EXPECT().Call(nmConnGetSecrets, dbus.Flags(0), setting).
		Return(&dbus.Call{Body: []any{s}}).Once()
}

func captureUpdate2(obj *mock_dbus.MockBusObject, flags uint32, err error) *nmSettings {
	var got nmSettings
	obj.EXPECT().Call(nmConnUpdate2, dbus.Flags(0), mock.Anything, flags, mock.Anything).
		Run(func(_ string, _ dbus.Flags, args ...any) {
			got = args[0].(nmSettings)
		}).
		Return(&dbus.Call{Err: err, Body: []any{map[string]dbus.Variant{}}}).Once()
	return &got
}

func TestUpdateConnectionSettings_ManualDNSAndGatewaySurviveAutoconnectFlip(t *testing.T) {
	obj := mock_dbus.NewMockBusObject(t)
	legacyAddrs := []legacyIP6Addr{{Addr: make([]byte, 16), Prefix: 64, Gateway: make([]byte, 16)}}
	expectGetSettings(obj, nmSettings{
		"connection": {"id": dbus.MakeVariant("Wired"), "autoconnect": dbus.MakeVariant(true)},
		"ipv4": {
			"method":       dbus.MakeVariant("manual"),
			"addresses":    dbus.MakeVariant([][]uint32{{0x0100a8c0, 24, 0x0101a8c0}}),
			"address-data": dbus.MakeVariant([]map[string]dbus.Variant{{"address": dbus.MakeVariant("192.168.0.1"), "prefix": dbus.MakeVariant(uint32(24))}}),
			"gateway":      dbus.MakeVariant("192.168.1.1"),
			"dns":          dbus.MakeVariant([]uint32{0x01010101}),
			"dns-data":     dbus.MakeVariant([]string{"1.1.1.1"}),
		},
		"ipv6": {
			"method":       dbus.MakeVariant("manual"),
			"addresses":    dbus.MakeVariant(legacyAddrs),
			"address-data": dbus.MakeVariant([]map[string]dbus.Variant{{"address": dbus.MakeVariant("fd00::1"), "prefix": dbus.MakeVariant(uint32(64))}}),
		},
	})
	got := captureUpdate2(obj, 0, nil)

	err := updateConnectionSettings(obj, false, func(s nmSettings) error {
		setSettingValue(s, "connection", "autoconnect", false)
		return nil
	})
	require.NoError(t, err)

	s := *got
	assert.Equal(t, false, s["connection"]["autoconnect"].Value())
	for _, key := range []string{"addresses", "dns"} {
		assert.NotContains(t, s["ipv4"], key)
	}
	assert.NotContains(t, s["ipv6"], "addresses")
	assert.Equal(t, "192.168.1.1", s["ipv4"]["gateway"].Value())
	assert.Equal(t, "as", s["ipv4"]["dns-data"].Signature().String())
	assert.Equal(t, "aa{sv}", s["ipv4"]["address-data"].Signature().String())
	assert.Equal(t, "aa{sv}", s["ipv6"]["address-data"].Signature().String())
}

func TestDropLegacyIPKeys_KeepsLegacyWithoutModernTwin(t *testing.T) {
	s := nmSettings{"ipv4": {
		"dns":       dbus.MakeVariant([]uint32{0x01010101}),
		"routes":    dbus.MakeVariant([][]uint32{{0, 0, 0, 0}}),
		"addresses": dbus.MakeVariant([][]uint32{{1, 24, 0}}),
	}}
	dropLegacyIPKeys(s)
	assert.Contains(t, s["ipv4"], "dns")
	assert.Contains(t, s["ipv4"], "routes")
	assert.Contains(t, s["ipv4"], "addresses")
}

func secretsFixture() nmSettings {
	return nmSettings{
		"connection":               {"id": dbus.MakeVariant("x")},
		"802-11-wireless-security": {"key-mgmt": dbus.MakeVariant("wpa-psk")},
		"vpn": {
			"service-type": dbus.MakeVariant("org.freedesktop.NetworkManager.openvpn"),
		},
		"wireguard": {
			"peers": dbus.MakeVariant([]map[string]dbus.Variant{
				{"public-key": dbus.MakeVariant("PEER_A"), "endpoint": dbus.MakeVariant("a:51820")},
				{"public-key": dbus.MakeVariant("PEER_B")},
			}),
		},
	}
}

func expectStoredSecrets(obj *mock_dbus.MockBusObject) {
	expectGetSecrets(obj, "802-11-wireless-security", nmSettings{
		"802-11-wireless-security": {"psk": dbus.MakeVariant("old")},
	})
	expectGetSecrets(obj, "vpn", nmSettings{
		"vpn": {"secrets": dbus.MakeVariant(map[string]string{"password": "a", "cert-pass": "b"})},
	})
	expectGetSecrets(obj, "wireguard", nmSettings{"wireguard": {
		"peers": dbus.MakeVariant([]map[string]dbus.Variant{
			{"public-key": dbus.MakeVariant("PEER_B"), "preshared-key": dbus.MakeVariant("PSK_B")},
		}),
	}})
}

func TestUpdateConnectionSettings_SecretsMergedAndPatchWins(t *testing.T) {
	t.Run("stored secrets kept", func(t *testing.T) {
		obj := mock_dbus.NewMockBusObject(t)
		expectGetSettings(obj, secretsFixture())
		expectStoredSecrets(obj)
		got := captureUpdate2(obj, 0, nil)

		require.NoError(t, updateConnectionSettings(obj, false, func(nmSettings) error { return nil }))

		s := *got
		assert.Equal(t, "old", s["802-11-wireless-security"]["psk"].Value())
		assert.Equal(t, map[string]string{"password": "a", "cert-pass": "b"}, s["vpn"]["secrets"].Value())

		peers := s["wireguard"]["peers"]
		assert.Equal(t, "aa{sv}", peers.Signature().String())
		list := peers.Value().([]map[string]dbus.Variant)
		require.Len(t, list, 2)
		assert.NotContains(t, list[0], "preshared-key")
		assert.Equal(t, "a:51820", list[0]["endpoint"].Value())
		assert.Equal(t, "PSK_B", list[1]["preshared-key"].Value())
	})

	t.Run("patch wins", func(t *testing.T) {
		obj := mock_dbus.NewMockBusObject(t)
		fixture := secretsFixture()
		fixture["vpn"]["secrets"] = dbus.MakeVariant(map[string]string{"password": "c"})
		expectGetSettings(obj, fixture)
		expectStoredSecrets(obj)
		got := captureUpdate2(obj, 0, nil)

		require.NoError(t, updateConnectionSettings(obj, false, func(s nmSettings) error {
			setSettingValue(s, "802-11-wireless-security", "psk", "new")
			return nil
		}))

		s := *got
		assert.Equal(t, "new", s["802-11-wireless-security"]["psk"].Value())
		assert.Equal(t, map[string]string{"password": "c", "cert-pass": "b"}, s["vpn"]["secrets"].Value())
	})

	t.Run("mutate edits merged vpn secrets", func(t *testing.T) {
		obj := mock_dbus.NewMockBusObject(t)
		expectGetSettings(obj, secretsFixture())
		expectStoredSecrets(obj)
		got := captureUpdate2(obj, 0, nil)

		require.NoError(t, updateConnectionSettings(obj, false, func(s nmSettings) error {
			secrets := s["vpn"]["secrets"].Value().(map[string]string)
			secrets["password"] = "c"
			setSettingValue(s, "vpn", "secrets", secrets)
			return nil
		}))

		assert.Equal(t, map[string]string{"password": "c", "cert-pass": "b"}, (*got)["vpn"]["secrets"].Value())
	})

	t.Run("mutate replacing vpn secrets and peers keeps unmentioned secrets", func(t *testing.T) {
		obj := mock_dbus.NewMockBusObject(t)
		expectGetSettings(obj, secretsFixture())
		expectStoredSecrets(obj)
		got := captureUpdate2(obj, 0, nil)

		require.NoError(t, updateConnectionSettings(obj, false, func(s nmSettings) error {
			setSettingValue(s, "vpn", "secrets", map[string]string{"password": "z"})
			setSettingValue(s, "wireguard", "peers", []map[string]dbus.Variant{
				{"public-key": dbus.MakeVariant("PEER_B"), "endpoint": dbus.MakeVariant("b:51820")},
				{"public-key": dbus.MakeVariant("PEER_C")},
			})
			return nil
		}))

		s := *got
		assert.Equal(t, map[string]string{"password": "z", "cert-pass": "b"}, s["vpn"]["secrets"].Value())
		list := s["wireguard"]["peers"].Value().([]map[string]dbus.Variant)
		require.Len(t, list, 2)
		assert.Equal(t, "b:51820", list[0]["endpoint"].Value())
		assert.Equal(t, "PSK_B", list[0]["preshared-key"].Value())
		assert.NotContains(t, list[1], "preshared-key")
	})

	t.Run("explicit peer psk in mutate wins over stored", func(t *testing.T) {
		obj := mock_dbus.NewMockBusObject(t)
		expectGetSettings(obj, secretsFixture())
		expectStoredSecrets(obj)
		got := captureUpdate2(obj, 0, nil)

		require.NoError(t, updateConnectionSettings(obj, false, func(s nmSettings) error {
			setSettingValue(s, "wireguard", "peers", []map[string]dbus.Variant{
				{"public-key": dbus.MakeVariant("PEER_B"), "preshared-key": dbus.MakeVariant("NEW")},
			})
			return nil
		}))

		list := (*got)["wireguard"]["peers"].Value().([]map[string]dbus.Variant)
		assert.Equal(t, "NEW", list[0]["preshared-key"].Value())
	})

	t.Run("containers deleted by mutate stay deleted", func(t *testing.T) {
		obj := mock_dbus.NewMockBusObject(t)
		expectGetSettings(obj, secretsFixture())
		expectStoredSecrets(obj)
		got := captureUpdate2(obj, 0, nil)

		require.NoError(t, updateConnectionSettings(obj, false, func(s nmSettings) error {
			deleteSettingValue(s, "vpn", "secrets")
			delete(s, "wireguard")
			return nil
		}))

		assert.NotContains(t, (*got)["vpn"], "secrets")
		assert.NotContains(t, *got, "wireguard")
	})

	// Update2 drops omitted secrets, so a failed read must abort the write.
	t.Run("GetSecrets error aborts the write", func(t *testing.T) {
		obj := mock_dbus.NewMockBusObject(t)
		expectGetSettings(obj, nmSettings{"802-11-wireless-security": {"key-mgmt": dbus.MakeVariant("wpa-psk")}})
		obj.EXPECT().Call(nmConnGetSecrets, dbus.Flags(0), "802-11-wireless-security").
			Return(&dbus.Call{Err: dbus.Error{Name: "org.freedesktop.DBus.Error.NoReply", Body: []any{"timeout"}}}).Once()

		err := updateConnectionSettings(obj, false, func(nmSettings) error { return nil })
		require.ErrorContains(t, err, "failed to get secrets for 802-11-wireless-security: timeout")
		obj.AssertNotCalled(t, "Call", nmConnUpdate2, mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})
}

func TestUpdateConnectionSettings_ExplicitNullRemovesNestedSecrets(t *testing.T) {
	update := func(t *testing.T, patch SettingsPatch) nmSettings {
		obj := mock_dbus.NewMockBusObject(t)
		expectGetSettings(obj, secretsFixture())
		expectStoredSecrets(obj)
		got := captureUpdate2(obj, 0, nil)
		require.NoError(t, updateConnectionSettingsRemoving(obj, false, secretRemovalsFromPatch(patch), func(s nmSettings) error {
			return applySettingsPatch(s, patch)
		}))
		return *got
	}
	peers := func(s nmSettings) []map[string]dbus.Variant {
		return s["wireguard"]["peers"].Value().([]map[string]dbus.Variant)
	}

	t.Run("null vpn secret removed, unmentioned kept", func(t *testing.T) {
		s := update(t, SettingsPatch{"vpn": {"secrets": map[string]any{"password": nil}}})
		assert.Equal(t, map[string]string{"cert-pass": "b"}, s["vpn"]["secrets"].Value())
	})

	t.Run("partial vpn secrets patch keeps unmentioned", func(t *testing.T) {
		s := update(t, SettingsPatch{"vpn": {"secrets": map[string]any{"password": "z"}}})
		assert.Equal(t, map[string]string{"password": "z", "cert-pass": "b"}, s["vpn"]["secrets"].Value())
	})

	t.Run("null peer psk removed", func(t *testing.T) {
		s := update(t, SettingsPatch{"wireguard": {"peers": []any{
			map[string]any{"public-key": "PEER_B", "preshared-key": nil},
		}}})
		list := peers(s)
		require.Len(t, list, 1)
		assert.NotContains(t, list[0], "preshared-key")
	})

	t.Run("omitted peer psk kept", func(t *testing.T) {
		s := update(t, SettingsPatch{"wireguard": {"peers": []any{
			map[string]any{"public-key": "PEER_B", "endpoint": "b:1"},
		}}})
		assert.Equal(t, "PSK_B", peers(s)[0]["preshared-key"].Value())
	})

	t.Run("whole container null still deletes", func(t *testing.T) {
		s := update(t, SettingsPatch{"vpn": {"secrets": nil}})
		assert.NotContains(t, s["vpn"], "secrets")
	})
}

func TestSecretRemovalsFromPatch(t *testing.T) {
	r := secretRemovalsFromPatch(SettingsPatch{
		"vpn": {"secrets": map[string]any{"password": nil, "cert-pass": "x"}},
		"wireguard": {"peers": []any{
			map[string]any{"public-key": "A", "preshared-key": nil},
			map[string]any{"public-key": "B", "preshared-key": "K"},
			map[string]any{"public-key": "C"},
		}},
	})
	assert.Equal(t, secretRemovals{vpnSecrets: []string{"password"}, peerPSKs: []string{"A"}}, r)
	assert.Equal(t, secretRemovals{}, secretRemovalsFromPatch(SettingsPatch{"vpn": nil, "wireguard": {"peers": nil}}))
}

func TestUpdateConnectionSettings_NilObject(t *testing.T) {
	err := updateConnectionSettings(nil, false, func(nmSettings) error { return nil })
	require.ErrorContains(t, err, "D-Bus connection unavailable")
}

func TestUpdateConnectionSettings_MutateErrorWritesNothing(t *testing.T) {
	obj := mock_dbus.NewMockBusObject(t)
	expectGetSettings(obj, nmSettings{"connection": {"id": dbus.MakeVariant("x")}})

	err := updateConnectionSettings(obj, true, func(nmSettings) error { return errors.New("bad value") })
	require.ErrorContains(t, err, "bad value")
	obj.AssertNotCalled(t, "Call", nmConnUpdate2, mock.Anything, mock.Anything, mock.Anything, mock.Anything)
}

func TestUpdateConnectionSettings_PersistFlagAndNMError(t *testing.T) {
	obj := mock_dbus.NewMockBusObject(t)
	expectGetSettings(obj, nmSettings{"connection": {"id": dbus.MakeVariant("x")}})
	nmErr := dbus.Error{Name: "org.freedesktop.NetworkManager.Settings.Connection.InvalidProperty", Body: []any{"ipv4.dns: invalid IP address"}}
	captureUpdate2(obj, 0x1, nmErr)

	err := updateConnectionSettings(obj, true, func(nmSettings) error { return nil })
	require.Error(t, err)
	assert.Equal(t, "failed to update connection: ipv4.dns: invalid IP address", err.Error())
}

func TestSetAndDeleteSettingValue(t *testing.T) {
	s := nmSettings{}
	setSettingValue(s, "ipv4", "method", "auto")
	setSettingValue(s, "ipv4", "dns", dbus.MakeVariant([]uint32{1}))
	assert.Equal(t, "auto", s["ipv4"]["method"].Value())
	assert.Equal(t, "au", s["ipv4"]["dns"].Signature().String())
	deleteSettingValue(s, "ipv4", "method")
	deleteSettingValue(s, "missing", "key")
	assert.NotContains(t, s["ipv4"], "method")
}

func TestNMObject(t *testing.T) {
	assert.Nil(t, (&NetworkManagerBackend{}).nmObject("/x"))

	obj := mock_dbus.NewMockBusObject(t)
	b := &NetworkManagerBackend{nmObjectFn: func(dbus.ObjectPath) dbus.BusObject { return obj }}
	assert.Same(t, obj, b.nmObject("/x"))
}
