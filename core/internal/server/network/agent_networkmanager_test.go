package network

import (
	"testing"

	"github.com/godbus/dbus/v5"
	"github.com/stretchr/testify/assert"
)

func TestNeedsExternalBrowserAuth(t *testing.T) {
	tests := []struct {
		name     string
		protocol string
		authType string
		username string
		data     map[string]string
		expected bool
	}{
		{
			name:     "GP with saml-auth-method REDIRECT",
			protocol: "gp",
			authType: "password",
			username: "user",
			data:     map[string]string{"saml-auth-method": "REDIRECT"},
			expected: true,
		},
		{
			name:     "GP with saml-auth-method POST",
			protocol: "gp",
			authType: "password",
			username: "user",
			data:     map[string]string{"saml-auth-method": "POST"},
			expected: true,
		},
		{
			name:     "GP with no authtype and no username",
			protocol: "gp",
			authType: "",
			username: "",
			data:     map[string]string{},
			expected: true,
		},
		{
			name:     "GP with username and password authtype",
			protocol: "gp",
			authType: "password",
			username: "john",
			data:     map[string]string{},
			expected: false,
		},
		{
			name:     "GP with username but no authtype",
			protocol: "gp",
			authType: "",
			username: "john",
			data:     map[string]string{},
			expected: false,
		},
		{
			name:     "GP with authtype but no username - should detect SAML",
			protocol: "gp",
			authType: "",
			username: "",
			data:     map[string]string{},
			expected: true,
		},
		{
			name:     "pulse with SAML",
			protocol: "pulse",
			authType: "",
			username: "",
			data:     map[string]string{"saml-auth-method": "REDIRECT"},
			expected: true,
		},
		{
			name:     "fortinet with non-password authtype",
			protocol: "fortinet",
			authType: "saml",
			username: "",
			data:     map[string]string{},
			expected: true,
		},
		{
			name:     "anyconnect with cert",
			protocol: "anyconnect",
			authType: "cert",
			username: "",
			data:     map[string]string{},
			expected: false,
		},
		{
			name:     "anyconnect with password",
			protocol: "anyconnect",
			authType: "password",
			username: "user",
			data:     map[string]string{},
			expected: false,
		},
		{
			name:     "empty protocol",
			protocol: "",
			authType: "",
			username: "",
			data:     map[string]string{},
			expected: false,
		},
		{
			name:     "GP with cert authtype",
			protocol: "gp",
			authType: "cert",
			username: "",
			data:     map[string]string{},
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := needsExternalBrowserAuth(tt.protocol, tt.authType, tt.username, tt.data)
			assert.Equal(t, tt.expected, result)
		})
	}
}

func TestBuildGPSamlSecretsResponse(t *testing.T) {
	tests := []struct {
		name        string
		settingName string
		cookie      string
		host        string
		fingerprint string
	}{
		{
			name:        "all fields populated",
			settingName: "vpn",
			cookie:      "authcookie=abc123&portal=GATE",
			host:        "vpn.example.com",
			fingerprint: "pin-sha256:ABCD1234",
		},
		{
			name:        "empty fingerprint",
			settingName: "vpn",
			cookie:      "authcookie=xyz",
			host:        "10.0.0.1",
			fingerprint: "",
		},
		{
			name:        "complex cookie with special chars",
			settingName: "vpn",
			cookie:      "authcookie=077058d3bc81&portal=PANGP_GW_01-N&user=john.doe@example.com&domain=Default&preferred-ip=192.168.1.100",
			host:        "connect.seclore.com",
			fingerprint: "pin-sha256:xp3scfzy3rOgQEXnfPiYKrUk7D66a8b8O+gEXaMPleE=",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := buildGPSamlSecretsResponse(tt.settingName, tt.cookie, tt.host, tt.fingerprint)

			assert.NotNil(t, result)
			assert.Contains(t, result, tt.settingName)

			vpnSec := result[tt.settingName]
			assert.NotNil(t, vpnSec)

			secretsVariant, ok := vpnSec["secrets"]
			assert.True(t, ok, "secrets key should exist")

			secrets, ok := secretsVariant.Value().(map[string]string)
			assert.True(t, ok, "secrets should be map[string]string")

			assert.Equal(t, tt.cookie, secrets["cookie"])
			assert.Equal(t, tt.host, secrets["gateway"])
			assert.Equal(t, tt.fingerprint, secrets["gwcert"])
		})
	}
}

func TestVpnFieldMeta_GPSaml(t *testing.T) {
	label, isSecret := vpnFieldMeta("gp-saml", "org.freedesktop.NetworkManager.openconnect")

	assert.Equal(t, "GlobalProtect SAML/SSO", label)
	assert.False(t, isSecret, "gp-saml should not be marked as secret")
}

func TestVpnFieldMeta_StandardFields(t *testing.T) {
	tests := []struct {
		field          string
		vpnService     string
		expectedLabel  string
		expectedSecret bool
	}{
		{
			field:          "username",
			vpnService:     "org.freedesktop.NetworkManager.openconnect",
			expectedLabel:  "Username",
			expectedSecret: false,
		},
		{
			field:          "password",
			vpnService:     "org.freedesktop.NetworkManager.openconnect",
			expectedLabel:  "Password",
			expectedSecret: true,
		},
		{
			field:          "key_pass",
			vpnService:     "org.freedesktop.NetworkManager.openconnect",
			expectedLabel:  "PIN",
			expectedSecret: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.field, func(t *testing.T) {
			label, isSecret := vpnFieldMeta(tt.field, tt.vpnService)
			assert.Equal(t, tt.expectedLabel, label)
			assert.Equal(t, tt.expectedSecret, isSecret)
		})
	}
}

func TestInferVPNFields_GPSaml(t *testing.T) {
	tests := []struct {
		name        string
		vpnService  string
		dataMap     map[string]string
		expectedLen int
		shouldHave  []string
	}{
		{
			name:       "GP with no authtype and no username - should require SAML",
			vpnService: "org.freedesktop.NetworkManager.openconnect",
			dataMap: map[string]string{
				"protocol": "gp",
				"gateway":  "vpn.example.com",
			},
			expectedLen: 1,
			shouldHave:  []string{"gp-saml"},
		},
		{
			name:       "GP with saml-auth-method REDIRECT",
			vpnService: "org.freedesktop.NetworkManager.openconnect",
			dataMap: map[string]string{
				"protocol":         "gp",
				"gateway":          "vpn.example.com",
				"saml-auth-method": "REDIRECT",
				"username":         "john",
			},
			expectedLen: 1,
			shouldHave:  []string{"gp-saml"},
		},
		{
			name:       "GP with saml-auth-method POST",
			vpnService: "org.freedesktop.NetworkManager.openconnect",
			dataMap: map[string]string{
				"protocol":         "gp",
				"gateway":          "vpn.example.com",
				"saml-auth-method": "POST",
			},
			expectedLen: 1,
			shouldHave:  []string{"gp-saml"},
		},
		{
			name:       "GP with username and password authtype - should use credentials",
			vpnService: "org.freedesktop.NetworkManager.openconnect",
			dataMap: map[string]string{
				"protocol": "gp",
				"gateway":  "vpn.example.com",
				"authtype": "password",
				"username": "john",
			},
			expectedLen: 1,
			shouldHave:  []string{"password"},
		},
		{
			name:       "GP with username but no authtype - password only",
			vpnService: "org.freedesktop.NetworkManager.openconnect",
			dataMap: map[string]string{
				"protocol": "gp",
				"gateway":  "vpn.example.com",
				"username": "john",
			},
			expectedLen: 1,
			shouldHave:  []string{"password"},
		},
		{
			name:       "GP with PKCS11 cert",
			vpnService: "org.freedesktop.NetworkManager.openconnect",
			dataMap: map[string]string{
				"protocol": "gp",
				"gateway":  "vpn.example.com",
				"authtype": "cert",
				"usercert": "pkcs11:model=PKCS%2315%20emulated;manufacturer=piv_II",
			},
			expectedLen: 1,
			shouldHave:  []string{"key_pass"},
		},
		{
			name:       "non-GP protocol (anyconnect)",
			vpnService: "org.freedesktop.NetworkManager.openconnect",
			dataMap: map[string]string{
				"protocol": "anyconnect",
				"gateway":  "vpn.example.com",
			},
			expectedLen: 2,
			shouldHave:  []string{"username", "password"},
		},
		{
			name:       "OpenVPN with username",
			vpnService: "org.freedesktop.NetworkManager.openvpn",
			dataMap: map[string]string{
				"connection-type": "password",
				"username":        "john",
			},
			expectedLen: 1,
			shouldHave:  []string{"password"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Convert dataMap to nmVariantMap
			vpnSettings := make(nmVariantMap)
			vpnSettings["data"] = dbus.MakeVariant(tt.dataMap)
			vpnSettings["service-type"] = dbus.MakeVariant(tt.vpnService)

			conn := make(map[string]nmVariantMap)
			conn["vpn"] = vpnSettings

			fields := inferVPNFields(conn, tt.vpnService)

			assert.Len(t, fields, tt.expectedLen, "unexpected number of fields")
			if len(tt.shouldHave) > 0 {
				for _, expected := range tt.shouldHave {
					assert.Contains(t, fields, expected, "should contain field: %s", expected)
				}
			}
		})
	}
}

func TestNmVariantMap(t *testing.T) {
	// Test that nmVariantMap and nmSettingMap work correctly
	settingMap := make(nmSettingMap)
	variantMap := make(nmVariantMap)

	variantMap["test-key"] = dbus.MakeVariant("test-value")
	settingMap["test-setting"] = variantMap

	assert.Contains(t, settingMap, "test-setting")
	assert.Contains(t, settingMap["test-setting"], "test-key")

	value := settingMap["test-setting"]["test-key"].Value()
	assert.Equal(t, "test-value", value)
}
