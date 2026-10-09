package network

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/godbus/dbus/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func wgKeys(t *testing.T, f *editorFixture) (priv, pub string) {
	t.Helper()
	resp := e2eRequest(t, f.backend, "network.wireguard.keys", map[string]any{})
	require.Empty(t, resp.Error)
	var keys map[string]string
	require.NoError(t, json.Unmarshal(*resp.Result, &keys))
	require.NotEmpty(t, keys["privateKey"])
	require.NotEmpty(t, keys["publicKey"])
	return keys["privateKey"], keys["publicKey"]
}

func TestE2E_WireGuardCreatedFromEditor(t *testing.T) {
	f := newEditorFixture(t)
	priv, _ := wgKeys(t, f)
	_, peerKey := wgKeys(t, f)
	added := captureAddConnection(f.object(t, nmSettingsPath), nmSettingsAddConnection)

	resp := e2eRequest(t, f.backend, "network.connection.add", map[string]any{
		"settings": map[string]any{
			"connection": map[string]any{"id": "dms-test-wg", "type": "wireguard", "interface-name": "dmstest0", "autoconnect": false},
			"wireguard": map[string]any{
				"private-key": priv,
				"listen-port": float64(51820),
				"peers": []any{map[string]any{
					"public-key":           peerKey,
					"allowed-ips":          []any{"10.99.0.0/24"},
					"endpoint":             "192.0.2.1:51820",
					"persistent-keepalive": float64(25),
				}},
			},
			"ipv4": map[string]any{
				"method":       "manual",
				"address-data": []any{map[string]any{"address": "10.99.0.2", "prefix": float64(32)}},
			},
			"ipv6": map[string]any{"method": "ignore"},
		},
	})

	require.Empty(t, resp.Error)
	s := *added
	assert.Equal(t, "wireguard", s["connection"]["type"].Value())
	assert.Equal(t, priv, s["wireguard"]["private-key"].Value())
	assert.Equal(t, uint32(51820), s["wireguard"]["listen-port"].Value())
	assert.Equal(t, "aa{sv}", s["wireguard"]["peers"].Signature().String())
	peers, ok := s["wireguard"]["peers"].Value().([]map[string]dbus.Variant)
	require.True(t, ok)
	require.Len(t, peers, 1)
	assert.Equal(t, peerKey, peers[0]["public-key"].Value())
	assert.Equal(t, "as", peers[0]["allowed-ips"].Signature().String())
	assert.Equal(t, []string{"10.99.0.0/24"}, peers[0]["allowed-ips"].Value())
	assert.Equal(t, "192.0.2.1:51820", peers[0]["endpoint"].Value())
	assert.Equal(t, uint32(25), peers[0]["persistent-keepalive"].Value())
	assert.Equal(t, "ignore", s["ipv6"]["method"].Value())
}

// storedWireGuard is the profile shared by the edit and export journeys.
func storedWireGuard(peerKey string) nmSettings {
	s := connSection("u-wg", "dms-test-wg", "wireguard", map[string]dbus.Variant{
		"interface-name": dbus.MakeVariant("dmstest0"),
	})
	s["wireguard"] = map[string]dbus.Variant{
		"listen-port": dbus.MakeVariant(uint32(51820)),
		"peers": dbus.MakeVariant([]map[string]dbus.Variant{{
			"public-key":  dbus.MakeVariant(peerKey),
			"endpoint":    dbus.MakeVariant("192.0.2.1:51820"),
			"allowed-ips": dbus.MakeVariant([]string{"10.99.0.0/24"}),
		}}),
	}
	s["ipv4"] = map[string]dbus.Variant{
		"method":       dbus.MakeVariant("manual"),
		"address-data": dbus.MakeVariant([]map[string]dbus.Variant{{"address": dbus.MakeVariant("10.99.0.2"), "prefix": dbus.MakeVariant(uint32(32))}}),
		"dns-data":     dbus.MakeVariant([]string{"192.0.2.53"}),
	}
	return s
}

func wgSecrets(priv, peerKey string) nmSettings {
	return nmSettings{"wireguard": {
		"private-key": dbus.MakeVariant(priv),
		"peers": dbus.MakeVariant([]map[string]dbus.Variant{{
			"public-key":    dbus.MakeVariant(peerKey),
			"preshared-key": dbus.MakeVariant("stored-psk"),
		}}),
	}}
}

func TestE2E_WireGuardPeerEditKeepsPSKAndPrivateKey(t *testing.T) {
	f := newEditorFixture(t)
	priv, _ := wgKeys(t, f)
	_, peerKey := wgKeys(t, f)
	obj := f.profile(t, "u-wg", "/s/wg")
	expectGetSettings(obj, storedWireGuard(peerKey))
	expectGetSecrets(obj, "wireguard", wgSecrets(priv, peerKey))
	got := captureUpdate2(obj, 0, nil)

	resp := e2eRequest(t, f.backend, "network.connection.update", map[string]any{
		"uuid": "u-wg",
		"settings": map[string]any{"wireguard": map[string]any{"peers": []any{map[string]any{
			"public-key":  peerKey,
			"allowed-ips": []any{"10.99.0.0/24"},
			"endpoint":    "198.51.100.7:51820",
		}}}},
	})

	require.Empty(t, resp.Error)
	s := *got
	assert.Equal(t, priv, s["wireguard"]["private-key"].Value())
	peers, ok := s["wireguard"]["peers"].Value().([]map[string]dbus.Variant)
	require.True(t, ok)
	require.Len(t, peers, 1)
	assert.Equal(t, "198.51.100.7:51820", peers[0]["endpoint"].Value())
	assert.Equal(t, "stored-psk", peers[0]["preshared-key"].Value())
	assert.Equal(t, []string{"192.0.2.53"}, s["ipv4"]["dns-data"].Value())
}

func TestE2E_EditorNullRemovesOnlyThatSecret(t *testing.T) {
	t.Run("vpn secret", func(t *testing.T) {
		f := newEditorFixture(t)
		obj := f.profile(t, "u-ovpn", "/s/ovpn")
		s := connSection("u-ovpn", "dms-test-ovpn", "vpn", nil)
		s["vpn"] = map[string]dbus.Variant{
			"service-type": dbus.MakeVariant("org.freedesktop.NetworkManager.openvpn"),
			"data":         dbus.MakeVariant(map[string]string{"remote": "vpn.example.com", "connection-type": "password-tls"}),
		}
		expectGetSettings(obj, s)
		expectGetSecrets(obj, "vpn", nmSettings{"vpn": {
			"secrets": dbus.MakeVariant(map[string]string{"password": "pw", "cert-pass": "cp"}),
		}})
		got := captureUpdate2(obj, 0, nil)

		resp := e2eRequest(t, f.backend, "network.connection.update", map[string]any{
			"uuid":     "u-ovpn",
			"settings": map[string]any{"vpn": map[string]any{"secrets": map[string]any{"password": nil}}},
		})

		require.Empty(t, resp.Error)
		assert.Equal(t, map[string]string{"cert-pass": "cp"}, (*got)["vpn"]["secrets"].Value())
	})

	t.Run("wireguard peer psk", func(t *testing.T) {
		f := newEditorFixture(t)
		priv, _ := wgKeys(t, f)
		_, peerKey := wgKeys(t, f)
		obj := f.profile(t, "u-wg", "/s/wg")
		expectGetSettings(obj, storedWireGuard(peerKey))
		expectGetSecrets(obj, "wireguard", wgSecrets(priv, peerKey))
		got := captureUpdate2(obj, 0, nil)

		resp := e2eRequest(t, f.backend, "network.connection.update", map[string]any{
			"uuid": "u-wg",
			"settings": map[string]any{"wireguard": map[string]any{"peers": []any{map[string]any{
				"public-key":    peerKey,
				"allowed-ips":   []any{"10.99.0.0/24"},
				"preshared-key": nil,
			}}}},
		})

		require.Empty(t, resp.Error)
		s := *got
		assert.Equal(t, priv, s["wireguard"]["private-key"].Value())
		peers, ok := s["wireguard"]["peers"].Value().([]map[string]dbus.Variant)
		require.True(t, ok)
		require.Len(t, peers, 1)
		assert.NotContains(t, peers[0], "preshared-key")
	})
}

func TestE2E_WireGuardExport(t *testing.T) {
	f := newEditorFixture(t)
	priv, _ := wgKeys(t, f)
	_, peerKey := wgKeys(t, f)
	obj := f.profile(t, "u-wg", "/s/wg")
	expectGetSettings(obj, storedWireGuard(peerKey))
	expectGetSecrets(obj, "wireguard", wgSecrets(priv, peerKey))
	file := filepath.Join(t.TempDir(), "dmstest0.conf")

	resp := e2eRequest(t, f.backend, "network.connection.export", map[string]any{"uuid": "u-wg", "file": file})

	require.Empty(t, resp.Error)
	info, err := os.Stat(file)
	require.NoError(t, err)
	assert.Equal(t, os.FileMode(0o600), info.Mode().Perm())
	conf, err := os.ReadFile(file)
	require.NoError(t, err)
	assert.Contains(t, string(conf), "[Peer]")
	assert.Contains(t, string(conf), "AllowedIPs = 10.99.0.0/24")
	assert.Contains(t, string(conf), "PrivateKey = "+priv)
}
