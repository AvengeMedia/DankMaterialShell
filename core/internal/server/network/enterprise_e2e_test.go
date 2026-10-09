package network

import (
	"encoding/json"
	"encoding/pem"
	"testing"

	mock_gonetworkmanager "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/github.com/Wifx/gonetworkmanager/v2"
	"github.com/Wifx/gonetworkmanager/v2"
	"github.com/godbus/dbus/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
)

// uhhEnterprise runs the import file through network.eapconfig.parse and
// returns its enterprise block with the user's credentials added, plus the
// CA certificate as DER.
func uhhEnterprise(t *testing.T, b Backend) (map[string]any, []byte) {
	t.Helper()
	resp := e2eRequest(t, b, "network.eapconfig.parse", map[string]any{"file": "testdata/uhh.eap-config"})
	require.Empty(t, resp.Error)
	var parsed struct {
		Enterprise map[string]any `json:"enterprise"`
	}
	require.NoError(t, json.Unmarshal(*resp.Result, &parsed))
	block, _ := pem.Decode([]byte(parsed.Enterprise["caCertPem"].(string)))
	require.NotNil(t, block)
	parsed.Enterprise["identity"] = "stine@uni-hamburg.de"
	parsed.Enterprise["password"] = "s3cret"
	return parsed.Enterprise, block.Bytes
}

func assertUHHSection(t *testing.T, x map[string]any, ca []byte) {
	t.Helper()
	assert.Equal(t, []string{"ttls"}, x["eap"])
	assert.Equal(t, "pap", x["phase2-auth"])
	assert.NotContains(t, x, "phase2-autheap")
	assert.Equal(t, "anonymous@uni-hamburg.de", x["anonymous-identity"])
	assert.Equal(t, "roamrad.rrz.uni-hamburg.de", x["domain-match"])
	assert.Equal(t, ca, x["ca-cert"])
	assert.Equal(t, uint32(0), x["password-flags"])
	assert.NotContains(t, x, "ca-path")
	assert.NotContains(t, x, "system-ca-certs")
}

func wifiDeviceFixture(f *editorFixture, t *testing.T) *mock_gonetworkmanager.MockDeviceWireless {
	wireless := mock_gonetworkmanager.NewMockDeviceWireless(t)
	wireless.EXPECT().GetPropertyInterface().Return("wlan0", nil).Maybe()
	f.backend.wifiDevice = wireless
	f.backend.wifiDevices = map[string]*wifiDeviceInfo{"wlan0": {device: wireless, wireless: wireless, name: "wlan0"}}
	f.settings.EXPECT().ListConnections().Return(nil, nil).Maybe()
	return wireless
}

func TestE2E_EduroamImportOffCampus(t *testing.T) {
	f := newEditorFixture(t)
	f.settings.EXPECT().ListConnections().Return(nil, nil).Once()
	var added gonetworkmanager.ConnectionSettings
	f.settings.EXPECT().AddConnection(mock.Anything).
		Run(func(s gonetworkmanager.ConnectionSettings) { added = s }).
		Return(nil, nil).Once()
	// No Wi-Fi device and no activation expectations: the strict mocks fail on any.
	ent, ca := uhhEnterprise(t, f.backend)

	resp := e2eRequest(t, f.backend, "network.wifi.connect", map[string]any{
		"ssid": "eduroam", "security": "wpa-eap", "saveOnly": true, "enterprise": ent,
	})

	require.Empty(t, resp.Error)
	assert.JSONEq(t, `{"success":true,"message":"saved"}`, string(*resp.Result))
	assert.Equal(t, []byte("eduroam"), added["802-11-wireless"]["ssid"])
	assert.Equal(t, "wpa-eap", added["802-11-wireless-security"]["key-mgmt"])
	assertUHHSection(t, added["802-1x"], ca)
	assert.Equal(t, "stine@uni-hamburg.de", added["802-1x"]["identity"])
	assert.Equal(t, "s3cret", added["802-1x"]["password"])
}

func TestE2E_EduroamReimportUpdatesInPlace(t *testing.T) {
	f := newEditorFixture(t)
	const path = dbus.ObjectPath("/s/eduroam")
	conn := mock_gonetworkmanager.NewMockConnection(t)
	conn.EXPECT().GetPath().Return(path).Maybe()
	conn.EXPECT().GetSettings().Return(gonetworkmanager.ConnectionSettings{
		"connection":      {"type": "802-11-wireless"},
		"802-11-wireless": {"ssid": []byte("eduroam")},
	}, nil).Maybe()
	f.settings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{conn}, nil).Once()

	obj := f.object(t, path)
	expectGetSettings(obj, nmSettings{
		"connection":               {"uuid": dbus.MakeVariant("u-edu"), "id": dbus.MakeVariant("eduroam")},
		"802-11-wireless":          {"ssid": dbus.MakeVariant([]byte("eduroam"))},
		"ipv4":                     {"method": dbus.MakeVariant("auto"), "dns-data": dbus.MakeVariant([]string{"9.9.9.9"})},
		"802-11-wireless-security": {"key-mgmt": dbus.MakeVariant("wpa-eap")},
		"802-1x": {
			"eap":         dbus.MakeVariant([]string{"peap"}),
			"phase2-auth": dbus.MakeVariant("mschapv2"),
			"identity":    dbus.MakeVariant("old@uni-hamburg.de"),
		},
	})
	expectGetSecrets(obj, "802-11-wireless-security", nmSettings{})
	expectGetSecrets(obj, "802-1x", nmSettings{})
	got := captureUpdate2(obj, nmUpdate2FlagToDisk, nil)
	ent, ca := uhhEnterprise(t, f.backend)

	resp := e2eRequest(t, f.backend, "network.wifi.connect", map[string]any{
		"ssid": "eduroam", "security": "wpa-eap", "saveOnly": true, "enterprise": ent,
	})

	require.Empty(t, resp.Error)
	s := *got
	assert.Equal(t, "u-edu", s["connection"]["uuid"].Value())
	assert.Equal(t, []string{"9.9.9.9"}, s["ipv4"]["dns-data"].Value())
	x := map[string]any{}
	for k, v := range s["802-1x"] {
		x[k] = v.Value()
	}
	assertUHHSection(t, x, ca)
	assert.Equal(t, "stine@uni-hamburg.de", x["identity"])
}

func TestE2E_VisibleEnterpriseAP_AskEveryTime(t *testing.T) {
	f := newEditorFixture(t)
	wireless := wifiDeviceFixture(f, t)
	ap := mock_gonetworkmanager.NewMockAccessPoint(t)
	ap.EXPECT().GetPropertySSID().Return("corp", nil)
	ap.EXPECT().GetPropertyFlags().Return(uint32(1), nil).Maybe()
	ap.EXPECT().GetPropertyWPAFlags().Return(uint32(0), nil).Maybe()
	ap.EXPECT().GetPropertyRSNFlags().Return(uint32(gonetworkmanager.Nm80211APSecKeyMgmt8021X), nil).Maybe()
	wireless.EXPECT().GetAccessPoints().Return([]gonetworkmanager.AccessPoint{ap}, nil).Once()
	var got map[string]map[string]any
	f.nm.EXPECT().AddAndActivateWirelessConnection(mock.Anything, wireless, ap).
		Run(func(s map[string]map[string]any, _ gonetworkmanager.Device, _ gonetworkmanager.AccessPoint) { got = s }).
		Return(nil, nil).Once()

	resp := e2eRequest(t, f.backend, "network.wifi.connect", map[string]any{
		"ssid": "corp",
		"enterprise": map[string]any{
			"eap": "peap", "phase2": "mschapv2", "identity": "alice", "askPassword": true,
			"ca": "system", "serverDomain": "radius.example.org",
		},
	})

	require.Empty(t, resp.Error)
	x := got["802-1x"]
	assert.Equal(t, uint32(2), x["password-flags"])
	assert.NotContains(t, x, "password")
	assert.Equal(t, []string{"peap"}, x["eap"])
	assert.Equal(t, "mschapv2", x["phase2-auth"])
	assert.NotContains(t, x, "ca-path")
	assert.Equal(t, true, x["system-ca-certs"])
	assert.Equal(t, "radius.example.org", x["domain-match"])
	assert.Equal(t, "wpa-eap", got["802-11-wireless-security"]["key-mgmt"])
}

func TestE2E_HiddenWPA3(t *testing.T) {
	f := newEditorFixture(t)
	wireless := wifiDeviceFixture(f, t)
	var got map[string]map[string]any
	f.nm.EXPECT().AddAndActivateConnection(mock.Anything, wireless).
		Run(func(s map[string]map[string]any, _ gonetworkmanager.Device) { got = s }).
		Return(nil, nil).Once()

	resp := e2eRequest(t, f.backend, "network.wifi.connect", map[string]any{
		"ssid": "secret-net", "hidden": true, "security": "sae", "password": "testtest1",
	})

	require.Empty(t, resp.Error)
	assert.Equal(t, "sae", got["802-11-wireless-security"]["key-mgmt"])
	assert.Equal(t, "testtest1", got["802-11-wireless-security"]["psk"])
	assert.Equal(t, true, got["802-11-wireless"]["hidden"])
}
