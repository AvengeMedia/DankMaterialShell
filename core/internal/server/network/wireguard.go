package network

import (
	"cmp"
	"crypto/ecdh"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"math"
	"strings"
)

// generateWireGuardKeyPair returns a base64 key pair; the private key is
// clamped the way `wg genkey` does it.
func generateWireGuardKeyPair() (privateKey, publicKey string, err error) {
	k := make([]byte, 32)
	if _, err := rand.Read(k); err != nil {
		return "", "", err
	}
	k[0] &= 248
	k[31] = (k[31] & 127) | 64
	priv, err := ecdh.X25519().NewPrivateKey(k)
	if err != nil {
		return "", "", err
	}
	return base64.StdEncoding.EncodeToString(k),
		base64.StdEncoding.EncodeToString(priv.PublicKey().Bytes()), nil
}

func wireGuardPublicKey(privateKey string) (string, error) {
	k, err := base64.StdEncoding.DecodeString(privateKey)
	if err != nil || len(k) != 32 {
		return "", errors.New("invalid WireGuard key")
	}
	priv, err := ecdh.X25519().NewPrivateKey(k)
	if err != nil {
		return "", errors.New("invalid WireGuard key")
	}
	return base64.StdEncoding.EncodeToString(priv.PublicKey().Bytes()), nil
}

// wgNumber reads a number of any Go integer type or float64; negatives,
// non-finite or out-of-range floats and unknown types give 0.
func wgNumber(v any) uint64 {
	switch n := v.(type) {
	case int:
		return uint64(max(n, 0))
	case int8:
		return uint64(max(n, 0))
	case int16:
		return uint64(max(n, 0))
	case int32:
		return uint64(max(n, 0))
	case int64:
		return uint64(max(n, 0))
	case uint:
		return uint64(n)
	case uint8:
		return uint64(n)
	case uint16:
		return uint64(n)
	case uint32:
		return uint64(n)
	case uint64:
		return n
	case float64:
		if n >= 0 && n < math.MaxUint64 {
			return uint64(n)
		}
	}
	return 0
}

func wgStrings(v any) []string {
	switch l := v.(type) {
	case []string:
		return l
	case []any:
		out := make([]string, 0, len(l))
		for _, e := range l {
			if s, ok := e.(string); ok {
				out = append(out, s)
			}
		}
		return out
	}
	return nil
}

func wgDicts(v any) []map[string]any {
	switch l := v.(type) {
	case []map[string]any:
		return l
	case []any:
		out := make([]map[string]any, 0, len(l))
		for _, e := range l {
			if m, ok := e.(map[string]any); ok {
				out = append(out, m)
			}
		}
		return out
	}
	return nil
}

// wgQuickConfig renders decoded profile settings (with secrets) as a
// wg-quick file.
func wgQuickConfig(s map[string]map[string]any) (string, error) {
	wg := s["wireguard"]
	key, _ := wg["private-key"].(string)
	if key == "" {
		return "", errors.New("private key not available")
	}

	var b strings.Builder
	var broken string
	// A line break in a value would let a profile inject e.g. PostUp commands.
	line := func(name, v string) {
		if strings.ContainsAny(v, "\r\n") {
			broken = cmp.Or(broken, name)
			return
		}
		b.WriteString(name + " = " + v + "\n")
	}

	b.WriteString("[Interface]\n")
	line("PrivateKey", key)
	for _, f := range []struct{ key, name string }{
		{"listen-port", "ListenPort"}, {"fwmark", "FwMark"}, {"mtu", "MTU"},
	} {
		if n := wgNumber(wg[f.key]); n != 0 {
			fmt.Fprintf(&b, "%s = %d\n", f.name, n)
		}
	}

	var addrs, dns []string
	for _, fam := range []string{"ipv4", "ipv6"} {
		for _, a := range wgDicts(s[fam]["address-data"]) {
			addr, _ := a["address"].(string)
			if addr == "" {
				continue
			}
			if prefix, ok := a["prefix"]; ok {
				addr = fmt.Sprintf("%s/%d", addr, wgNumber(prefix))
			}
			addrs = append(addrs, addr)
		}
		dns = append(dns, wgStrings(s[fam]["dns-data"])...)
	}
	for _, fam := range []string{"ipv4", "ipv6"} {
		dns = append(dns, wgStrings(s[fam]["dns-search"])...)
	}
	if len(addrs) > 0 {
		line("Address", strings.Join(addrs, ", "))
	}
	if len(dns) > 0 {
		line("DNS", strings.Join(dns, ", "))
	}

	for _, p := range wgDicts(wg["peers"]) {
		b.WriteString("\n[Peer]\n")
		if v, _ := p["public-key"].(string); v != "" {
			line("PublicKey", v)
		}
		if v, _ := p["preshared-key"].(string); v != "" {
			line("PresharedKey", v)
		}
		if ips := wgStrings(p["allowed-ips"]); len(ips) > 0 {
			line("AllowedIPs", strings.Join(ips, ", "))
		}
		if v, _ := p["endpoint"].(string); v != "" {
			line("Endpoint", v)
		}
		if n := wgNumber(p["persistent-keepalive"]); n != 0 {
			fmt.Fprintf(&b, "PersistentKeepalive = %d\n", n)
		}
	}
	if broken != "" {
		return "", fmt.Errorf("%s contains a line break", broken)
	}
	return b.String(), nil
}
