package network

import (
	"encoding/base64"
	"encoding/hex"
	"math"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestWireGuardPublicKeyRFC7748Vector(t *testing.T) {
	priv, _ := hex.DecodeString("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
	want, _ := hex.DecodeString("8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a")

	pub, err := wireGuardPublicKey(base64.StdEncoding.EncodeToString(priv))
	require.NoError(t, err)
	assert.Equal(t, base64.StdEncoding.EncodeToString(want), pub)

	_, err = wireGuardPublicKey(base64.StdEncoding.EncodeToString(priv[:31]))
	assert.ErrorContains(t, err, "invalid WireGuard key")
	_, err = wireGuardPublicKey("not base64!")
	assert.ErrorContains(t, err, "invalid WireGuard key")
}

func TestGenerateWireGuardKeyPair(t *testing.T) {
	priv, pub, err := generateWireGuardKeyPair()
	require.NoError(t, err)

	raw, err := base64.StdEncoding.DecodeString(priv)
	require.NoError(t, err)
	require.Len(t, raw, 32)
	assert.Zero(t, raw[0]&7)
	assert.Equal(t, byte(64), raw[31]&0xC0)

	derived, err := wireGuardPublicKey(priv)
	require.NoError(t, err)
	assert.Equal(t, pub, derived)
}

func wgTestSettings() map[string]map[string]any {
	return map[string]map[string]any{
		"wireguard": {
			"private-key": "PRIV",
			"listen-port": uint32(51820),
			"fwmark":      float64(0),
			"mtu":         int64(1380),
			"peers": []map[string]any{
				{
					"public-key":           "PUB1",
					"endpoint":             "vpn.example.com:51820",
					"allowed-ips":          []string{"0.0.0.0/0", "::/0"},
					"preshared-key":        "PSK1",
					"persistent-keepalive": uint32(25),
				},
				{
					"public-key":  "PUB2",
					"allowed-ips": []any{"10.0.0.0/24"},
				},
			},
		},
		"ipv4": {
			"address-data": []map[string]any{{"address": "10.0.0.2", "prefix": uint32(32)}},
			"dns-data":     []string{"10.0.0.1"},
			"dns-search":   []string{"lan"},
		},
		"ipv6": {
			"address-data": []map[string]any{{"address": "fd00::2", "prefix": uint32(128)}},
		},
	}
}

func TestWgQuickConfig(t *testing.T) {
	got, err := wgQuickConfig(wgTestSettings())
	require.NoError(t, err)
	want := `[Interface]
PrivateKey = PRIV
ListenPort = 51820
MTU = 1380
Address = 10.0.0.2/32, fd00::2/128
DNS = 10.0.0.1, lan

[Peer]
PublicKey = PUB1
PresharedKey = PSK1
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = vpn.example.com:51820
PersistentKeepalive = 25

[Peer]
PublicKey = PUB2
AllowedIPs = 10.0.0.0/24
`
	assert.Equal(t, want, got)

	s := wgTestSettings()
	delete(s["wireguard"], "private-key")
	_, err = wgQuickConfig(s)
	assert.ErrorContains(t, err, "private key not available")
}

func TestWgQuickConfigRejectsLineBreaks(t *testing.T) {
	inject := map[string]func(s map[string]map[string]any){
		"PrivateKey": func(s map[string]map[string]any) { s["wireguard"]["private-key"] = "PRIV\nPostUp = x" },
		"Endpoint": func(s map[string]map[string]any) {
			s["wireguard"]["peers"].([]map[string]any)[0]["endpoint"] = "h:1\r\nPostUp = x"
		},
		"AllowedIPs": func(s map[string]map[string]any) {
			s["wireguard"]["peers"].([]map[string]any)[1]["allowed-ips"] = []string{"10.0.0.0/24\nPostUp = x"}
		},
		"DNS": func(s map[string]map[string]any) { s["ipv4"]["dns-search"] = []string{"lan\nPostUp = x"} },
		"Address": func(s map[string]map[string]any) {
			s["ipv6"]["address-data"] = []map[string]any{{"address": "fd00::2\n"}}
		},
	}
	for name, mutate := range inject {
		s := wgTestSettings()
		mutate(s)
		_, err := wgQuickConfig(s)
		assert.ErrorContains(t, err, name, name)
	}
}

func TestWgQuickConfigAddressWithoutPrefix(t *testing.T) {
	s := wgTestSettings()
	s["ipv4"]["address-data"] = []map[string]any{{"address": "10.0.0.2"}}
	got, err := wgQuickConfig(s)
	require.NoError(t, err)
	assert.Contains(t, got, "Address = 10.0.0.2, fd00::2/128\n")
}

func TestWgNumber(t *testing.T) {
	for _, v := range []any{math.NaN(), math.Inf(1), math.Inf(-1), float64(-3), 1e30, int16(-1), "5", nil} {
		assert.Zero(t, wgNumber(v), "%#v", v)
	}
	for _, v := range []any{float64(25), int16(25), uint8(25), int8(25), int(25), uint64(25)} {
		assert.Equal(t, uint64(25), wgNumber(v), "%#v", v)
	}
}
