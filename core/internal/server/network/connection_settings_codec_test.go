package network

import (
	"encoding/binary"
	"encoding/json"
	"net"
	"strings"
	"testing"

	"github.com/godbus/dbus/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestSettingSignaturesMatchNMSettingsDBus(t *testing.T) {
	ip := map[string]string{
		"method": "s", "address-data": "aa{sv}", "gateway": "s", "route-data": "aa{sv}",
		"dns-data": "as", "dns-search": "as", "dns-options": "as", "dns-priority": "i",
		"route-metric": "x", "route-table": "u", "never-default": "b", "ignore-auto-dns": "b",
		"ignore-auto-routes": "b", "may-fail": "b", "dhcp-hostname": "s",
	}
	want := map[string]string{
		"connection.id": "s", "connection.uuid": "s", "connection.type": "s",
		"connection.interface-name": "s", "connection.autoconnect": "b",
		"connection.autoconnect-priority": "i", "connection.autoconnect-retries": "i",
		"connection.metered": "i", "connection.zone": "s", "connection.secondaries": "as",
		"connection.permissions": "as", "connection.stable-id": "s",
		"ipv6.ip6-privacy": "i", "ipv6.addr-gen-mode": "i",
	}
	for k, sig := range ip {
		want["ipv4."+k] = sig
		want["ipv6."+k] = sig
	}
	for name, sig := range want {
		assert.Equal(t, sig, settingSignatures[name], name)
		_, err := dbus.ParseSignature(sig)
		assert.NoError(t, err, name)
	}

	for _, fam := range []string{"ipv4", "ipv6"} {
		assert.Equal(t, map[string]string{"address": "s", "prefix": "u", "label": "s"},
			nestedDictSignatures[fam+".address-data"])
		route := nestedDictSignatures[fam+".route-data"]
		for k, sig := range map[string]string{"dest": "s", "prefix": "u", "next-hop": "s", "metric": "u",
			"table": "u", "onlink": "b", "src": "s", "tos": "y", "scope": "y"} {
			assert.Equal(t, sig, route[k], k)
		}
	}

	for name, sig := range map[string]string{
		"802-3-ethernet.mac-address": "ay", "802-3-ethernet.assigned-mac-address": "s",
		"802-3-ethernet.wake-on-lan": "u", "802-3-ethernet.auto-negotiate": "b",
		"802-3-ethernet.accept-all-mac-addresses": "i", "802-3-ethernet.mac-address-denylist": "as",
		"802-11-wireless.ssid": "ay", "802-11-wireless.bssid": "ay", "802-11-wireless.channel-width": "i",
		"802-11-wireless.powersave": "u", "802-11-wireless.ap-isolation": "i",
		"802-11-wireless.seen-bssids": "as", "connection.timestamp": "t",
		"ipv4.dhcp-client-id": "s", "ipv6.token": "s", "ipv6.dhcp-send-hostname": "b",
		"ipv4.dhcp-send-hostname-v2": "i", "ipv6.dhcp-send-hostname-v2": "i",
	} {
		assert.Equal(t, sig, settingSignatures[name], name)
	}
}

func TestSettingsCodecRoundTripKeepsSignatures(t *testing.T) {
	stored := map[string]map[string]dbus.Variant{
		"connection": {
			"id":                   dbus.MakeVariant("Wired connection 1"),
			"autoconnect":          dbus.MakeVariant(false),
			"autoconnect-priority": dbus.MakeVariant(int32(-999)),
			"timestamp":            dbus.MakeVariant(uint64(1759400000)),
			"permissions":          dbus.MakeVariant([]string{"user:marlon"}),
		},
		"ipv4": {
			"method":       dbus.MakeVariant("manual"),
			"route-metric": dbus.MakeVariant(int64(-1)),
			"dns-data":     dbus.MakeVariant([]string{"192.0.2.53"}),
			"address-data": dbus.MakeVariant([]map[string]dbus.Variant{
				{"address": dbus.MakeVariant("192.0.2.10"), "prefix": dbus.MakeVariant(uint32(24))},
			}),
			"addresses": dbus.MakeVariant([][]uint32{{1, 24, 2}}),
		},
		"vpn": {
			"data": dbus.MakeVariant(map[string]string{"remote": "vpn.example.com"}),
		},
		"802-3-ethernet": {
			"mac-address": dbus.MakeVariant([]byte{0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff}),
		},
	}

	decoded := decodeSettingsForJSON(stored)
	assert.NotContains(t, decoded["ipv4"], "addresses")
	assert.Equal(t, []string{"192.0.2.53"}, decoded["ipv4"]["dns-data"])

	raw, err := json.Marshal(decoded)
	require.NoError(t, err)
	var fromJSON map[string]map[string]any
	require.NoError(t, json.Unmarshal(raw, &fromJSON))

	for section, keys := range fromJSON {
		for key, value := range keys {
			orig := stored[section][key]
			got, err := encodeSettingValue(section, key, value, &orig)
			require.NoError(t, err, section+"."+key)
			assert.Equal(t, orig.Signature(), got.Signature(), section+"."+key)
			assert.Equal(t, orig.Value(), got.Value(), section+"."+key)
		}
	}
}

func TestEncodeSettingValueNumberTyping(t *testing.T) {
	v, err := encodeSettingValue("connection", "autoconnect-priority", 5.0, nil)
	require.NoError(t, err)
	assert.Equal(t, int32(5), v.Value())

	v, err = encodeSettingValue("ipv4", "route-metric", -1.0, nil)
	require.NoError(t, err)
	assert.Equal(t, int64(-1), v.Value())

	v, err = encodeSettingValue("ipv4", "address-data", []any{
		map[string]any{"address": "192.0.2.10", "prefix": 24.0},
	}, nil)
	require.NoError(t, err)
	assert.Equal(t, "aa{sv}", v.Signature().String())
	addrs := v.Value().([]map[string]dbus.Variant)
	assert.Equal(t, uint32(24), addrs[0]["prefix"].Value())

	_, err = encodeSettingValue("connection", "autoconnect-priority", 1.5, nil)
	assert.ErrorContains(t, err, "connection.autoconnect-priority")

	_, err = encodeSettingValue("ipv4", "route-table", -1.0, nil)
	assert.ErrorContains(t, err, "ipv4.route-table")

	_, err = encodeSettingValue("ipv4", "route-table", 4294967296.0, nil)
	assert.ErrorContains(t, err, "ipv4.route-table")

	_, err = encodeSettingValue("ipv4", "address-data", []any{
		map[string]any{"address": "192.0.2.10", "prefix": 24.5},
	}, nil)
	assert.ErrorContains(t, err, "ipv4.address-data.prefix")

	_, err = encodeSettingValue("ipv4", "address-data", []any{
		map[string]any{"bogus": "x"},
	}, nil)
	assert.ErrorContains(t, err, "ipv4.address-data.bogus")
}

func TestApplySettingsPatchSemantics(t *testing.T) {
	newSettings := func() map[string]map[string]dbus.Variant {
		return map[string]map[string]dbus.Variant{
			"connection": {
				"id":          dbus.MakeVariant("home"),
				"zone":        dbus.MakeVariant("public"),
				"custom-key":  dbus.MakeVariant("old"),
				"autoconnect": dbus.MakeVariant(true),
			},
			"proxy": {"method": dbus.MakeVariant(int32(0))},
		}
	}

	s := newSettings()
	err := applySettingsPatch(s, SettingsPatch{
		"connection": {"zone": nil, "custom-key": "new", "autoconnect-priority": 5.0},
		"proxy":      nil,
	})
	require.NoError(t, err)
	assert.NotContains(t, s["connection"], "zone")
	assert.NotContains(t, s, "proxy")
	assert.Equal(t, dbus.MakeVariant("new"), s["connection"]["custom-key"])
	assert.Equal(t, dbus.MakeVariant(int32(5)), s["connection"]["autoconnect-priority"])
	assert.Equal(t, dbus.MakeVariant("home"), s["connection"]["id"])

	// Map order is random; repeat so an in-place apply can't pass by luck.
	for range 20 {
		s = newSettings()
		err = applySettingsPatch(s, SettingsPatch{
			"connection": {"id": "renamed", "zone": nil, "not-a-key": "x"},
			"proxy":      nil,
		})
		require.ErrorContains(t, err, "connection.not-a-key")
		require.Equal(t, newSettings(), s)
	}
}

func TestEncodeNewSettings(t *testing.T) {
	s, err := encodeNewSettings(SettingsPatch{
		"connection":     {"id": "office", "type": "802-3-ethernet", "autoconnect": false},
		"802-3-ethernet": {},
		"ipv4":           {"method": "auto", "dns-data": []any{"192.0.2.53"}},
	})
	require.NoError(t, err)
	assert.Equal(t, dbus.MakeVariant(false), s["connection"]["autoconnect"])
	assert.Contains(t, s, "802-3-ethernet")
	assert.Equal(t, dbus.MakeVariant([]string{"192.0.2.53"}), s["ipv4"]["dns-data"])

	_, err = encodeNewSettings(SettingsPatch{"connection": {"custom-key": "x"}})
	assert.ErrorContains(t, err, "connection.custom-key")
}

func TestApplySettingsPatchDeleteOnlyDoesNotCreateSection(t *testing.T) {
	s := map[string]map[string]dbus.Variant{"connection": {"id": dbus.MakeVariant("home")}}
	require.NoError(t, applySettingsPatch(s, SettingsPatch{"ipv6": {"dns-data": nil}}))
	assert.NotContains(t, s, "ipv6")

	require.NoError(t, applySettingsPatch(s, SettingsPatch{"ipv6": {"dns-data": nil, "method": "auto"}}))
	assert.Equal(t, map[string]dbus.Variant{"method": dbus.MakeVariant("auto")}, s["ipv6"])
}

func TestApplySettingsPatchNilSettings(t *testing.T) {
	err := applySettingsPatch(nil, SettingsPatch{"connection": {"id": "x"}})
	assert.Error(t, err)
}

func TestEncodeIntegerUpperBounds(t *testing.T) {
	v, err := encodeSettingValue("connection", "autoconnect-priority", 2147483647.0, nil)
	require.NoError(t, err)
	assert.Equal(t, int32(2147483647), v.Value())
	_, err = encodeSettingValue("connection", "autoconnect-priority", 2147483648.0, nil)
	assert.ErrorContains(t, err, "connection.autoconnect-priority")

	v, err = encodeSettingValue("ipv4", "route-metric", -9223372036854775808.0, nil)
	require.NoError(t, err)
	assert.Equal(t, int64(-1<<63), v.Value())
	_, err = encodeSettingValue("ipv4", "route-metric", float64(1<<63), nil)
	assert.ErrorContains(t, err, "ipv4.route-metric")
}

func TestCertKindRoundTrip(t *testing.T) {
	path := append([]byte("file:///etc/x.pem"), 0)
	blob := []byte{0x30, 0x82, 0x01}
	stored := map[string]map[string]dbus.Variant{"802-1x": {
		"ca-cert":     dbus.MakeVariant(path),
		"client-cert": dbus.MakeVariant(blob),
		"private-key": dbus.MakeVariant(blob),
	}}
	got := decodeSettingsForJSON(stored)["802-1x"]
	assert.Equal(t, "/etc/x.pem", got["ca-cert"])
	assert.Equal(t, "blob", got["client-cert"])
	assert.Equal(t, "blob", got["private-key"])

	v, err := encodeSettingValue("802-1x", "ca-cert", "/etc/x.pem", nil)
	require.NoError(t, err)
	assert.Equal(t, path, v.Value())

	old := stored["802-1x"]["client-cert"]
	v, err = encodeSettingValue("802-1x", "client-cert", "blob", &old)
	require.NoError(t, err)
	assert.Equal(t, blob, v.Value())

	_, err = encodeSettingValue("802-1x", "client-cert", "blob", nil)
	assert.ErrorContains(t, err, "802-1x.client-cert")
	_, err = encodeSettingValue("802-1x", "ca-cert", "relative.pem", nil)
	assert.ErrorContains(t, err, "802-1x.ca-cert")
}

func TestCertKindEdgeCases(t *testing.T) {
	got := decodeSettingsForJSON(map[string]map[string]dbus.Variant{"802-1x": {
		"phase2-ca-cert":     dbus.MakeVariant(append([]byte("file:///etc/inner.pem"), 0)),
		"phase2-client-cert": dbus.MakeVariant([]byte{0x30, 0x82}),
		"phase2-private-key": dbus.MakeVariant([]byte{0x30, 0x82}),
		"ca-cert":            dbus.MakeVariant(append([]byte("file://"), 0)),
		"client-cert":        dbus.MakeVariant([]byte("file:///etc/x.pem")),
	}})["802-1x"]
	assert.Equal(t, "/etc/inner.pem", got["phase2-ca-cert"])
	assert.Equal(t, "blob", got["phase2-client-cert"])
	assert.Equal(t, "blob", got["phase2-private-key"])
	assert.Equal(t, "blob", got["ca-cert"], "empty path")
	assert.Equal(t, "blob", got["client-cert"], "no trailing NUL")

	_, err := encodeSettingValue("802-1x", "ca-cert", "/etc/a\x00b.pem", nil)
	assert.ErrorContains(t, err, "802-1x.ca-cert")

	stored := dbus.MakeVariant([]byte("old"))
	v, err := encodeSettingValue("802-11-wireless", "ssid", []byte("Campus"), &stored)
	require.NoError(t, err)
	assert.Equal(t, []byte("Campus"), v.Value())
}

func TestNativeValuesPassThrough(t *testing.T) {
	for _, tc := range []struct {
		section, key string
		value        any
		sig          string
	}{
		{"802-1x", "ca-cert", []byte{1, 2}, "ay"},
		{"802-1x", "eap", []string{"ttls"}, "as"},
		{"802-1x", "password-flags", uint32(2), "u"},
	} {
		v, err := encodeSettingValue(tc.section, tc.key, tc.value, nil)
		require.NoError(t, err, tc.key)
		assert.Equal(t, tc.sig, v.Signature().String(), tc.key)
		assert.Equal(t, tc.value, v.Value(), tc.key)
	}
	_, err := encodeSettingValue("802-1x", "password-flags", 2, nil)
	assert.ErrorContains(t, err, "802-1x.password-flags")
}

func TestEncodeNewSettingsSkipsNilKeys(t *testing.T) {
	s, err := encodeNewSettings(SettingsPatch{"802-1x": {"identity": "u", "password": nil}})
	require.NoError(t, err)
	assert.Contains(t, s["802-1x"], "identity")
	assert.NotContains(t, s["802-1x"], "password")
}

func TestEnterpriseSignatureRows(t *testing.T) {
	want := map[string]string{
		"802-1x.eap": "as", "802-1x.identity": "s", "802-1x.anonymous-identity": "s",
		"802-1x.password": "s", "802-1x.password-flags": "u", "802-1x.phase2-auth": "s",
		"802-1x.phase2-autheap": "s", "802-1x.ca-cert": "ay", "802-1x.ca-path": "s",
		"802-1x.system-ca-certs": "b", "802-1x.domain-match": "s", "802-1x.domain-suffix-match": "s",
		"802-1x.client-cert": "ay", "802-1x.private-key": "ay", "802-1x.private-key-password": "s",
		"802-1x.private-key-password-flags": "u", "802-1x.phase1-peapver": "s",
		"802-1x.phase1-peaplabel": "s", "802-1x.phase1-auth-flags": "u", "802-1x.openssl-ciphers": "s",
		"802-1x.altsubject-matches": "as", "802-1x.auth-timeout": "i", "802-1x.optional": "b",
		"802-11-wireless-security.key-mgmt": "s", "802-11-wireless-security.psk": "s",
		"802-11-wireless-security.psk-flags": "u", "802-11-wireless-security.pmf": "i",
		"802-11-wireless-security.proto": "as", "802-11-wireless-security.pairwise": "as",
		"802-11-wireless-security.group": "as",
	}
	for name, sig := range want {
		assert.Equal(t, sig, settingSignatures[name], name)
	}
}

func TestEncodeDictListRejectsNullInnerValue(t *testing.T) {
	_, err := encodeSettingValue("ipv4", "address-data", []any{
		map[string]any{"address": "192.0.2.10", "prefix": nil},
	}, nil)
	assert.ErrorContains(t, err, "ipv4.address-data.prefix")
}

func TestEncodeAcceptsNullSecretTombstones(t *testing.T) {
	v, err := encodeSettingValue("vpn", "secrets", map[string]any{"password": nil, "cert-pass": "x"}, nil)
	require.NoError(t, err)
	assert.Equal(t, map[string]string{"cert-pass": "x"}, v.Value())

	v, err = encodeSettingValue("wireguard", "peers", []any{map[string]any{"public-key": "A", "preshared-key": nil}}, nil)
	require.NoError(t, err)
	assert.Equal(t, []map[string]dbus.Variant{{"public-key": dbus.MakeVariant("A")}}, v.Value())

	_, err = encodeSettingValue("vpn", "data", map[string]any{"remote": nil}, nil)
	assert.ErrorContains(t, err, "vpn.data.remote")
}

func TestMACKind(t *testing.T) {
	dec := decodeSettingsForJSON(map[string]map[string]dbus.Variant{
		"802-3-ethernet": {
			"mac-address":        dbus.MakeVariant([]byte{0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff}),
			"cloned-mac-address": dbus.MakeVariant([]byte{1, 2, 3}),
		},
	})
	assert.Equal(t, "AA:BB:CC:DD:EE:FF", dec["802-3-ethernet"]["mac-address"])
	assert.NotContains(t, dec["802-3-ethernet"], "cloned-mac-address")

	v, err := encodeSettingValue("802-3-ethernet", "mac-address", "aa:bb:cc:dd:ee:ff", nil)
	require.NoError(t, err)
	assert.Equal(t, "ay", v.Signature().String())
	assert.Equal(t, []byte{0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff}, v.Value())

	_, err = encodeSettingValue("802-3-ethernet", "mac-address", "zz", nil)
	require.ErrorContains(t, err, "802-3-ethernet.mac-address")
	_, err = encodeSettingValue("802-3-ethernet", "mac-address", "00:11:22:33:44:55:66:77", nil)
	require.ErrorContains(t, err, "802-3-ethernet.mac-address")
}

func TestSSIDKind(t *testing.T) {
	for _, bad := range []string{"", strings.Repeat("a", 33)} {
		_, err := encodeSettingValue("802-11-wireless", "ssid", bad, nil)
		assert.ErrorContains(t, err, "802-11-wireless.ssid")
	}
	v, err := encodeSettingValue("802-11-wireless", "ssid", "eduroam", nil)
	require.NoError(t, err)
	assert.Equal(t, []byte("eduroam"), v.Value())
	dec := decodeSettingsForJSON(map[string]map[string]dbus.Variant{"802-11-wireless": {"ssid": v}})
	assert.Equal(t, "eduroam", dec["802-11-wireless"]["ssid"])

	dec = decodeSettingsForJSON(map[string]map[string]dbus.Variant{
		"802-11-wireless": {"ssid": dbus.MakeVariant([]byte{0xff, 0xfe}), "mode": dbus.MakeVariant("ap")},
	})
	assert.NotContains(t, dec["802-11-wireless"], "ssid")
	assert.Equal(t, "ap", dec["802-11-wireless"]["mode"])
}

func TestRouteAttributesEncode(t *testing.T) {
	var patch SettingsPatch
	require.NoError(t, json.Unmarshal([]byte(`{"ipv4":{"route-data":[
		{"dest":"10.0.0.0","prefix":8,"next-hop":"192.0.2.1","onlink":true,"table":100,"src":"192.0.2.10"}]}}`), &patch))
	s, err := encodeNewSettings(patch)
	require.NoError(t, err)
	routes := s["ipv4"]["route-data"].Value().([]map[string]dbus.Variant)
	require.Len(t, routes, 1)
	assert.Equal(t, "b", routes[0]["onlink"].Signature().String())
	assert.Equal(t, "u", routes[0]["table"].Signature().String())
	assert.Equal(t, "s", routes[0]["src"].Signature().String())
	assert.Equal(t, "aa{sv}", s["ipv4"]["route-data"].Signature().String())
}

func TestLegacyDNSDecodeLiteralValues(t *testing.T) {
	// NM stores the address bytes in network order, read as a native uint32.
	little := binary.NativeEndian.Uint16([]byte{1, 0}) == 1
	pick := func(le, be uint32) uint32 {
		if little {
			return le
		}
		return be
	}
	for want, au := range map[string]uint32{
		"192.168.1.2": pick(0x0201A8C0, 0xC0A80102),
		"1.1.1.1":     0x01010101,
	} {
		dec := decodeSettingsForJSON(map[string]map[string]dbus.Variant{
			"ipv4": {"dns": dbus.MakeVariant([]uint32{au})},
		})
		assert.Equal(t, []string{want}, dec["ipv4"]["dns-data"])
	}
}

func TestLegacyDNSDecode(t *testing.T) {
	au := binary.NativeEndian.Uint32(net.ParseIP("192.0.2.53").To4())
	dec := decodeSettingsForJSON(map[string]map[string]dbus.Variant{
		"ipv4": {"dns": dbus.MakeVariant([]uint32{au})},
		"ipv6": {"dns": dbus.MakeVariant([][]byte{net.ParseIP("2001:db8::53")})},
	})
	assert.Equal(t, []string{"192.0.2.53"}, dec["ipv4"]["dns-data"])
	assert.Equal(t, []string{"2001:db8::53"}, dec["ipv6"]["dns-data"])
	assert.NotContains(t, dec["ipv4"], "dns")
	assert.NotContains(t, dec["ipv6"], "dns")

	dec = decodeSettingsForJSON(map[string]map[string]dbus.Variant{
		"ipv4": {
			"dns":      dbus.MakeVariant([]uint32{au}),
			"dns-data": dbus.MakeVariant([]string{"198.51.100.1"}),
		},
	})
	assert.Equal(t, []string{"198.51.100.1"}, dec["ipv4"]["dns-data"])
	assert.NotContains(t, dec["ipv4"], "dns")
}

func TestWireGuardPeersRoundTrip(t *testing.T) {
	var peers []any
	require.NoError(t, json.Unmarshal([]byte(`[{"public-key":"k","endpoint":"1.2.3.4:51820",
		"allowed-ips":["10.0.0.0/24","::/0"],"persistent-keepalive":25}]`), &peers))
	s, err := encodeNewSettings(SettingsPatch{"wireguard": {"peers": peers}})
	require.NoError(t, err)

	v := s["wireguard"]["peers"]
	assert.Equal(t, "aa{sv}", v.Signature().String())
	peer := v.Value().([]map[string]dbus.Variant)[0]
	assert.Equal(t, "s", peer["public-key"].Signature().String())
	assert.Equal(t, "s", peer["endpoint"].Signature().String())
	assert.Equal(t, "as", peer["allowed-ips"].Signature().String())
	assert.Equal(t, "u", peer["persistent-keepalive"].Signature().String())

	got := decodeSettingsForJSON(s)["wireguard"]["peers"].([]map[string]any)[0]
	assert.Equal(t, []string{"10.0.0.0/24", "::/0"}, got["allowed-ips"])
	assert.Equal(t, "1.2.3.4:51820", got["endpoint"])
	assert.Equal(t, uint32(25), got["persistent-keepalive"])
}

func TestWireGuardAndVPNScalarRows(t *testing.T) {
	s, err := encodeNewSettings(SettingsPatch{
		"wireguard": {"listen-port": 51820.0, "peer-routes": false, "ip4-auto-default-route": -1.0},
		"vpn":       {"data": map[string]any{"remote": "a"}, "timeout": 30.0},
	})
	require.NoError(t, err)
	assert.Equal(t, uint32(51820), s["wireguard"]["listen-port"].Value())
	assert.Equal(t, int32(-1), s["wireguard"]["ip4-auto-default-route"].Value())
	assert.Equal(t, "a{ss}", s["vpn"]["data"].Signature().String())

	_, err = encodeNewSettings(SettingsPatch{"wireguard": {"listen-port": -1.0}})
	require.ErrorContains(t, err, "wireguard.listen-port")
}

func TestWireGuardUnknownPeerKey(t *testing.T) {
	_, err := encodeNewSettings(SettingsPatch{"wireguard": {"peers": []any{map[string]any{"bogus": "x"}}}})
	require.ErrorContains(t, err, "wireguard.peers.bogus")
}

func TestWireGuardAndVPNSignaturesMatchNMSettingsDBus(t *testing.T) {
	want := map[string]string{
		"wireguard.private-key": "s", "wireguard.private-key-flags": "u", "wireguard.listen-port": "u",
		"wireguard.fwmark": "u", "wireguard.peer-routes": "b", "wireguard.mtu": "u",
		"wireguard.ip4-auto-default-route": "i", "wireguard.ip6-auto-default-route": "i",
		"wireguard.peers":  "aa{sv}",
		"vpn.service-type": "s", "vpn.user-name": "s", "vpn.persistent": "b", "vpn.timeout": "u",
		"vpn.data": "a{ss}", "vpn.secrets": "a{ss}",
	}
	for name, sig := range want {
		assert.Equal(t, sig, settingSignatures[name], name)
	}
}

func TestLinkTypeRowsEncode(t *testing.T) {
	s, err := encodeNewSettings(SettingsPatch{
		"connection": {"autoconnect-slaves": 1.0, "master": "u", "slave-type": "bond"},
		"vlan":       {"id": 100.0, "flags": 3.0, "parent": "enp5s0"},
		"bond":       {"options": map[string]any{"mode": "active-backup", "miimon": "100"}},
		"bridge":     {"mac-address": "aa:bb:cc:dd:ee:ff", "stp": true, "priority": 4096.0},
	})
	require.NoError(t, err)
	assert.Equal(t, "i", s["connection"]["autoconnect-slaves"].Signature().String())
	assert.Equal(t, "u", s["vlan"]["id"].Signature().String())
	assert.Equal(t, "u", s["vlan"]["flags"].Signature().String())
	assert.Equal(t, "s", s["vlan"]["parent"].Signature().String())
	assert.Equal(t, "a{ss}", s["bond"]["options"].Signature().String())
	assert.Equal(t, []byte{0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff}, s["bridge"]["mac-address"].Value())

	_, err = encodeNewSettings(SettingsPatch{"vlan": {"id": -1.0}})
	require.ErrorContains(t, err, "vlan.id")
}

func TestLinkTypeSignaturesMatchNMSettingsDBus(t *testing.T) {
	want := map[string]string{
		"connection.master": "s", "connection.slave-type": "s", "connection.controller": "s",
		"connection.port-type": "s", "connection.autoconnect-slaves": "i", "connection.autoconnect-ports": "i",
		"vlan.parent": "s", "vlan.id": "u", "vlan.flags": "u", "vlan.protocol": "s",
		"vlan.ingress-priority-map": "as", "vlan.egress-priority-map": "as",
		"bond.options": "a{ss}", "bond.interface-name": "s",
		"bridge.stp": "b", "bridge.priority": "u", "bridge.forward-delay": "u", "bridge.hello-time": "u",
		"bridge.max-age": "u", "bridge.ageing-time": "u", "bridge.mac-address": "ay",
		"bridge.multicast-snooping": "b", "bridge.vlan-filtering": "b", "bridge.vlan-default-pvid": "u",
		"bridge.group-forward-mask": "u", "bridge.multicast-router": "s",
		"bridge-port.priority": "u", "bridge-port.path-cost": "u", "bridge-port.hairpin-mode": "b",
		"gsm.apn": "s", "gsm.auto-config": "b", "gsm.username": "s", "gsm.password": "s",
		"gsm.password-flags": "u", "gsm.pin": "s", "gsm.pin-flags": "u", "gsm.home-only": "b",
		"gsm.network-id": "s", "gsm.number": "s", "gsm.mtu": "u", "gsm.device-id": "s", "gsm.sim-id": "s",
		"gsm.sim-operator-id": "s", "gsm.initial-eps-bearer-apn": "s", "gsm.initial-eps-bearer-configure": "b",
		"cdma.number": "s", "cdma.username": "s", "cdma.password": "s", "cdma.password-flags": "u", "cdma.mtu": "u",
		"pppoe.parent": "s", "pppoe.service": "s", "pppoe.username": "s", "pppoe.password": "s",
		"pppoe.password-flags": "u",
		"ppp.refuse-eap":       "b", "ppp.refuse-pap": "b", "ppp.refuse-chap": "b", "ppp.refuse-mschap": "b",
		"ppp.refuse-mschapv2": "b", "ppp.require-mppe": "b", "ppp.require-mppe-128": "b",
		"ppp.mppe-stateful": "b", "ppp.nobsdcomp": "b", "ppp.nodeflate": "b", "ppp.no-vj-comp": "b",
		"ppp.noauth": "b", "ppp.lcp-echo-interval": "u", "ppp.lcp-echo-failure": "u", "ppp.mtu": "u",
		"ppp.mru": "u", "ppp.baud": "u", "ppp.crtscts": "b",
		"bluetooth.bdaddr": "ay", "bluetooth.type": "s",
	}
	for name, sig := range want {
		assert.Equal(t, sig, settingSignatures[name], name)
	}
}

func TestBluetoothAddressAndStoredProxy(t *testing.T) {
	dec := decodeSettingsForJSON(map[string]map[string]dbus.Variant{
		"bluetooth": {"bdaddr": dbus.MakeVariant([]byte{0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff})},
		"proxy": {
			"method":  dbus.MakeVariant(int32(1)),
			"pac-url": dbus.MakeVariant("http://x/p.pac"),
		},
	})
	assert.Equal(t, "AA:BB:CC:DD:EE:FF", dec["bluetooth"]["bdaddr"])
	assert.Equal(t, "http://x/p.pac", dec["proxy"]["pac-url"])

	storedInt, storedStr := dbus.MakeVariant(int32(0)), dbus.MakeVariant("")
	v, err := encodeSettingValue("proxy", "method", dec["proxy"]["method"], &storedInt)
	require.NoError(t, err)
	assert.Equal(t, "i", v.Signature().String())
	v, err = encodeSettingValue("proxy", "pac-url", dec["proxy"]["pac-url"], &storedStr)
	require.NoError(t, err)
	assert.Equal(t, "s", v.Signature().String())
}
