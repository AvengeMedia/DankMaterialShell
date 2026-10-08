package network_test

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	mocks "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/network"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/network"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
)

func newPlainManager(t *testing.T) (*network.Manager, *mocks.MockBackend) {
	t.Helper()
	mb := mocks.NewMockBackend(t)
	return network.NewTestManager(mb, &network.NetworkState{}), mb
}

func newNMLikeManager(t *testing.T) (*network.Manager, *mocks.MockBackend) {
	t.Helper()
	mb := mocks.NewMockBackend(t)
	b := &editorBackend{MockBackend: mb, MockConnectionEditorBackend: mocks.NewMockConnectionEditorBackend(t)}
	return network.NewTestManager(b, &network.NetworkState{}), mb
}

func TestWifiConnectEnterpriseSaveOnly(t *testing.T) {
	m, mb := newNMLikeManager(t)
	var got network.ConnectionRequest
	mb.EXPECT().ConnectWiFi(mock.Anything).
		Run(func(r network.ConnectionRequest) { got = r }).Return(nil).Once()

	resp := call(t, m, "network.wifi.connect", map[string]any{
		"ssid": "eduroam", "security": "wpa-eap", "saveOnly": true, "hidden": true,
		"enterprise": map[string]any{"eap": "ttls", "ca": "system", "serverDomain": "radius.example.org"},
	})
	require.Empty(t, resp.Error)
	assert.JSONEq(t, `{"success":true,"message":"saved"}`, string(*resp.Result))
	assert.True(t, got.SaveOnly)
	assert.True(t, got.Hidden)
	assert.Equal(t, "wpa-eap", got.Security)
	require.NotNil(t, got.Enterprise)
	assert.Equal(t, "ttls", got.Enterprise.EAP)
	assert.Equal(t, "radius.example.org", got.Enterprise.ServerDomain)
}

func TestWifiConnectEnterpriseUnknownKey(t *testing.T) {
	m, _ := newNMLikeManager(t)
	resp := call(t, m, "network.wifi.connect", map[string]any{
		"ssid": "x", "enterprise": map[string]any{"bogus": 1},
	})
	assert.Contains(t, resp.Error, "bogus")
}

func TestWifiConnectSaveOnlyUnsupportedBackend(t *testing.T) {
	m, _ := newPlainManager(t)
	resp := call(t, m, "network.wifi.connect", map[string]any{"ssid": "x", "saveOnly": true})
	assert.Contains(t, resp.Error, "not supported")
}

func TestWifiConnectEnterpriseUnsupportedBackend(t *testing.T) {
	m, _ := newPlainManager(t)
	resp := call(t, m, "network.wifi.connect", map[string]any{
		"ssid": "x", "enterprise": map[string]any{"eap": "peap"},
	})
	assert.Contains(t, resp.Error, "not supported")
}

func TestEapConfigParseHandler(t *testing.T) {
	m, _ := newNMLikeManager(t)
	resp := call(t, m, "network.eapconfig.parse", map[string]any{"file": "testdata/uhh.eap-config"})
	require.Empty(t, resp.Error)
	var p network.EAPConfigProfile
	require.NoError(t, json.Unmarshal(*resp.Result, &p))
	assert.Equal(t, []string{"eduroam"}, p.SSIDs)

	assert.NotEmpty(t, call(t, m, "network.eapconfig.parse", map[string]any{"file": "testdata/missing"}).Error)
	assert.NotEmpty(t, call(t, m, "network.eapconfig.parse", map[string]any{"file": "testdata"}).Error)

	big := filepath.Join(t.TempDir(), "big.eap-config")
	require.NoError(t, os.WriteFile(big, bytes.Repeat([]byte("a"), 4<<20+1), 0o600))
	assert.Contains(t, call(t, m, "network.eapconfig.parse", map[string]any{"file": big}).Error, "too large")

	um, _ := newPlainManager(t)
	assert.Contains(t, call(t, um, "network.eapconfig.parse", map[string]any{"file": "testdata/uhh.eap-config"}).Error, "not supported")
}
