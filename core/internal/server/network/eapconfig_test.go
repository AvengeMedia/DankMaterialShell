package network

import (
	"crypto/sha256"
	"crypto/x509"
	"encoding/hex"
	"encoding/pem"
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// testdata/uhh.eap-config: https://cat.eduroam.org/user/API.php?action=downloadInstaller&device=eap-generic&profile=10830 (fetched 2026-10-03)

func certFingerprints(t *testing.T, bundle string) []string {
	t.Helper()
	var out []string
	for rest := []byte(bundle); ; {
		var b *pem.Block
		b, rest = pem.Decode(rest)
		if b == nil {
			return out
		}
		_, err := x509.ParseCertificate(b.Bytes)
		require.NoError(t, err)
		sum := sha256.Sum256(b.Bytes)
		out = append(out, strings.ToUpper(hex.EncodeToString(sum[:])))
	}
}

func parseTestFile(t *testing.T, name string) EAPConfigProfile {
	t.Helper()
	data, err := os.ReadFile("testdata/" + name)
	require.NoError(t, err)
	p, err := parseEAPConfig(data)
	require.NoError(t, err)
	return p
}

func TestParseEAPConfig_UHH(t *testing.T) {
	p := parseTestFile(t, "uhh.eap-config")
	assert.Equal(t, "Universität Hamburg - uhh.eduroam2023", p.ProviderName)
	assert.Equal(t, []string{"eduroam"}, p.SSIDs)
	assert.Equal(t, "uni-hamburg.de", p.UsernameSuffix)
	assert.True(t, p.UsernameHint)

	e := p.Enterprise
	assert.Equal(t, "ttls", e.EAP)
	assert.Equal(t, "pap", e.Phase2)
	assert.Equal(t, "roamrad.rrz.uni-hamburg.de", e.ServerDomain)
	assert.False(t, e.ServerDomainSuffix)
	assert.Equal(t, "anonymous@uni-hamburg.de", e.AnonymousIdentity)
	assert.Equal(t, "file", e.CA)
	assert.Equal(t, []string{"A29D3C57FD0F4F32B786AB19A4DFDA6AB24404CAE262A32CFC13F3A69423F543"}, certFingerprints(t, e.CACertPEM))
}

func TestParseEAPConfig_Synthetic(t *testing.T) {
	p := parseTestFile(t, "peap-tls.eap-config")
	assert.Equal(t, "example.org", p.ProviderName)
	assert.Equal(t, []string{"corp", "guest"}, p.SSIDs)
	assert.False(t, p.UsernameHint)

	e := p.Enterprise
	assert.Equal(t, "peap", e.EAP)
	assert.Equal(t, "mschapv2", e.Phase2)
	assert.Equal(t, "a.example.org;b.example.org", e.ServerDomain)
	assert.Equal(t, "anon@example.org", e.AnonymousIdentity)
	assert.Len(t, certFingerprints(t, e.CACertPEM), 2)
}

func TestParseEAPConfig_Rejects(t *testing.T) {
	wrap := func(method, apply string) []byte {
		return []byte(`<EAPIdentityProviderList><EAPIdentityProvider ID="x"><AuthenticationMethods><AuthenticationMethod>` +
			method + `</AuthenticationMethod></AuthenticationMethods><CredentialApplicability>` + apply +
			`</CredentialApplicability></EAPIdentityProvider></EAPIdentityProviderList>`)
	}
	ssid := `<IEEE80211><SSID>net</SSID></IEEE80211>`
	cases := []struct {
		name string
		data []byte
		want string
	}{
		{"passpoint only", wrap(`<EAPMethod><Type>25</Type></EAPMethod>`, `<IEEE80211><ConsortiumOID>001bc50460</ConsortiumOID></IEEE80211>`), "no Wi-Fi network name"},
		{"leap only", wrap(`<EAPMethod><Type>17</Type></EAPMethod>`, ssid), "no supported authentication method (found types 17)"},
		{"ttls without usable inner", wrap(`<EAPMethod><Type>21</Type></EAPMethod>`, ssid), "no supported authentication method"},
		{"bad base64 CA", wrap(`<EAPMethod><Type>25</Type></EAPMethod><ServerSideCredential><CA>!!!</CA></ServerSideCredential>`, ssid), "invalid CA certificate"},
		{"not a certificate", wrap(`<EAPMethod><Type>25</Type></EAPMethod><ServerSideCredential><CA>aGVsbG8=</CA></ServerSideCredential>`, ssid), "invalid CA certificate"},
		{"malformed XML", []byte(`<EAPIdentityProviderList><oops>`), "invalid .eap-config"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			_, err := parseEAPConfig(c.data)
			require.Error(t, err)
			assert.Contains(t, err.Error(), c.want)
		})
	}
}

func TestParseEAPConfig_FeedsBuilder(t *testing.T) {
	for _, name := range []string{"uhh.eap-config", "peap-tls.eap-config"} {
		t.Run(name, func(t *testing.T) {
			e := parseTestFile(t, name).Enterprise
			e.Identity = "user@example.org"
			e.Password = "secret"
			_, err := enterprise8021xPatch(e, true)
			assert.NoError(t, err)
		})
	}
}

func TestParseEAPConfig_InnerMethods(t *testing.T) {
	wrap := func(method string) []byte {
		return []byte(`<EAPIdentityProviderList><EAPIdentityProvider ID="x"><AuthenticationMethods><AuthenticationMethod>` +
			method + `<ClientSideCredential><OuterIdentity>anon@x</OuterIdentity></ClientSideCredential>` +
			`</AuthenticationMethod></AuthenticationMethods><CredentialApplicability><IEEE80211><SSID>net</SSID></IEEE80211>` +
			`</CredentialApplicability></EAPIdentityProvider></EAPIdentityProviderList>`)
	}
	innerEAP := func(outer, inner int) string {
		return fmt.Sprintf(`<EAPMethod><Type>%d</Type></EAPMethod><InnerAuthenticationMethod><EAPMethod><Type>%d</Type></EAPMethod></InnerAuthenticationMethod>`, outer, inner)
	}
	innerNonEAP := func(inner int) string {
		return fmt.Sprintf(`<EAPMethod><Type>21</Type></EAPMethod><InnerAuthenticationMethod><NonEAPAuthMethod><Type>%d</Type></NonEAPAuthMethod></InnerAuthenticationMethod>`, inner)
	}
	tests := []struct {
		name, method, eap, phase2 string
	}{
		{"peap mschapv2", innerEAP(25, 26), "peap", "mschapv2"},
		{"peap gtc", innerEAP(25, 6), "peap", "gtc"},
		{"peap md5", innerEAP(25, 4), "peap", "md5"},
		{"ttls eap-mschapv2", innerEAP(21, 26), "ttls", "eap-mschapv2"},
		{"ttls mschap", innerNonEAP(2), "ttls", "mschap"},
		{"ttls mschapv2", innerNonEAP(3), "ttls", "mschapv2"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			p, err := parseEAPConfig(wrap(tt.method))
			require.NoError(t, err)
			assert.Equal(t, tt.eap, p.Enterprise.EAP)
			assert.Equal(t, tt.phase2, p.Enterprise.Phase2)
			assert.Equal(t, "anon@x", p.Enterprise.AnonymousIdentity)
		})
	}

	t.Run("tls", func(t *testing.T) {
		p, err := parseEAPConfig(wrap(`<EAPMethod><Type>13</Type></EAPMethod>`))
		require.NoError(t, err)
		assert.Equal(t, "tls", p.Enterprise.EAP)
		assert.Equal(t, "anon@x", p.Enterprise.Identity)
		assert.Empty(t, p.Enterprise.AnonymousIdentity)
	})
}
