package network

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestUnshellQuote(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "single quoted",
			input:    "'hello world'",
			expected: "hello world",
		},
		{
			name:     "double quoted",
			input:    `"hello world"`,
			expected: "hello world",
		},
		{
			name:     "unquoted",
			input:    "hello",
			expected: "hello",
		},
		{
			name:     "empty single quotes",
			input:    "''",
			expected: "",
		},
		{
			name:     "empty double quotes",
			input:    `""`,
			expected: "",
		},
		{
			name:     "single quote only",
			input:    "'",
			expected: "'",
		},
		{
			name:     "mismatched quotes",
			input:    "'hello\"",
			expected: "'hello\"",
		},
		{
			name:     "with special chars",
			input:    "'cookie=abc123&user=john'",
			expected: "cookie=abc123&user=john",
		},
		{
			name:     "complex cookie",
			input:    `'authcookie=077058d3bc81&portal=PANGP_GW_01-N&user=john.doe@example.com&domain=Default&preferred-ip=192.168.1.100'`,
			expected: "authcookie=077058d3bc81&portal=PANGP_GW_01-N&user=john.doe@example.com&domain=Default&preferred-ip=192.168.1.100",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := unshellQuote(tt.input)
			assert.Equal(t, tt.expected, result)
		})
	}
}

func TestParseGPSamlFromCommandLine(t *testing.T) {
	tests := []struct {
		name           string
		line           string
		initialResult  *gpSamlAuthResult
		expectedCookie string
		expectedUser   string
		expectedFP     string
	}{
		{
			name:           "full openconnect command",
			line:           "openconnect --protocol=gp --cookie=AUTH123 --servercert=pin-sha256:ABC --user=john",
			initialResult:  &gpSamlAuthResult{},
			expectedCookie: "AUTH123",
			expectedUser:   "john",
			expectedFP:     "pin-sha256:ABC",
		},
		{
			name:           "with equals signs in cookie",
			line:           "openconnect --cookie=authcookie=xyz123&portal=GATE --user=jane",
			initialResult:  &gpSamlAuthResult{},
			expectedCookie: "authcookie=xyz123&portal=GATE",
			expectedUser:   "jane",
			expectedFP:     "",
		},
		{
			name:           "non-openconnect line",
			line:           "some other output",
			initialResult:  &gpSamlAuthResult{},
			expectedCookie: "",
			expectedUser:   "",
			expectedFP:     "",
		},
		{
			name:           "preserves existing values",
			line:           "openconnect --user=newuser",
			initialResult:  &gpSamlAuthResult{Cookie: "existing", Fingerprint: "existing-fp"},
			expectedCookie: "existing",
			expectedUser:   "newuser",
			expectedFP:     "existing-fp",
		},
		{
			name:           "only updates empty fields",
			line:           "openconnect --cookie=NEW --user=NEW",
			initialResult:  &gpSamlAuthResult{Cookie: "OLD"},
			expectedCookie: "OLD",
			expectedUser:   "NEW",
			expectedFP:     "",
		},
		{
			name:           "real gp-saml-gui output",
			line:           "openconnect --protocol=gp --user=john.doe@example.com --os=linux-64 --usergroup=gateway:prelogin-cookie --passwd-on-stdin",
			initialResult:  &gpSamlAuthResult{},
			expectedCookie: "",
			expectedUser:   "john.doe@example.com",
			expectedFP:     "",
		},
		{
			name:           "with server cert flag",
			line:           "openconnect --servercert=pin-sha256:xp3scfzy3rOgQEXnfPiYKrUk7D66a8b8O+gEXaMPleE= vpn.example.com",
			initialResult:  &gpSamlAuthResult{},
			expectedCookie: "",
			expectedUser:   "",
			expectedFP:     "pin-sha256:xp3scfzy3rOgQEXnfPiYKrUk7D66a8b8O+gEXaMPleE=",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := tt.initialResult
			parseGPSamlFromCommandLine(tt.line, result)

			assert.Equal(t, tt.expectedCookie, result.Cookie, "cookie mismatch")
			assert.Equal(t, tt.expectedUser, result.User, "user mismatch")
			assert.Equal(t, tt.expectedFP, result.Fingerprint, "fingerprint mismatch")
		})
	}
}

func TestParseGPSamlFromCommandLine_MultipleLines(t *testing.T) {
	// Simulate gp-saml-gui output with command line suggestion
	lines := []string{
		"",
		"SAML REDIRECT",
		"Got SAML Login URL",
		"POST to ACS endpoint...",
		"Got 'prelogin-cookie': 'FAKE_cookie_12345'",
		"openconnect --protocol=gp --user=john.doe@example.com --usergroup=gateway:prelogin-cookie --passwd-on-stdin vpn.example.com",
		"",
	}

	result := &gpSamlAuthResult{}
	for _, line := range lines {
		parseGPSamlFromCommandLine(line, result)
	}

	assert.Equal(t, "john.doe@example.com", result.User)
	assert.Empty(t, result.Cookie, "cookie should not be parsed from command line")
	assert.Empty(t, result.Fingerprint)
}
