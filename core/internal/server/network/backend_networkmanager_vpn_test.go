package network

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"

	mock_gonetworkmanager "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/github.com/Wifx/gonetworkmanager/v2"
	mock_dbus "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/github.com/godbus/dbus/v5"
	"github.com/Wifx/gonetworkmanager/v2"
	"github.com/godbus/dbus/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestNetworkManagerBackend_ListVPNProfiles(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)
	backend.settings = mockSettings

	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{}, nil)

	profiles, err := backend.ListVPNProfiles()
	assert.NoError(t, err)
	assert.Empty(t, profiles)
}

func TestNetworkManagerBackend_ListActiveVPN(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{}, nil)

	active, err := backend.ListActiveVPN()
	assert.NoError(t, err)
	assert.Empty(t, active)
}

func TestNetworkManagerBackend_ConnectVPN_NotFound(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)
	backend.settings = mockSettings

	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{}, nil)

	err = backend.ConnectVPN("non-existent-vpn-12345", false)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
}

func TestNetworkManagerBackend_ConnectVPN_SingleActive_NoActiveVPN(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)
	backend.settings = mockSettings

	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{}, nil)
	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{}, nil)

	err = backend.ConnectVPN("non-existent-vpn-12345", true)
	assert.Error(t, err)
}

func TestNetworkManagerBackend_DisconnectVPN_NotActive(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{}, nil)

	err = backend.DisconnectVPN("non-existent-vpn-12345")
	assert.Error(t, err)
}

func TestNetworkManagerBackend_DisconnectAllVPN(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{}, nil)

	err = backend.DisconnectAllVPN()
	assert.NoError(t, err)
}

func TestNetworkManagerBackend_ClearVPNCredentials_NotFound(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)
	backend.settings = mockSettings

	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{}, nil)

	err = backend.ClearVPNCredentials("non-existent-vpn-12345")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
}

func TestNetworkManagerBackend_UpdateVPNConnectionState_NotConnecting(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.stateMutex.Lock()
	backend.state.IsConnectingVPN = false
	backend.state.ConnectingVPNUUID = ""
	backend.stateMutex.Unlock()

	assert.NotPanics(t, func() {
		backend.updateVPNConnectionState()
	})
}

func TestNetworkManagerBackend_UpdateVPNConnectionState_EmptyUUID(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.stateMutex.Lock()
	backend.state.IsConnectingVPN = true
	backend.state.ConnectingVPNUUID = ""
	backend.stateMutex.Unlock()

	assert.NotPanics(t, func() {
		backend.updateVPNConnectionState()
	})
}

func TestDetectVPNAuthAction_Fortinet(t *testing.T) {
	service := "org.freedesktop.NetworkManager.openconnect"

	assert.Equal(t, "openconnect_password", detectVPNAuthAction(service, map[string]string{
		"protocol": "fortinet",
		"authtype": "password",
	}))
	assert.Empty(t, detectVPNAuthAction(service, map[string]string{
		"protocol": "anyconnect",
		"authtype": "password",
	}))
	assert.Equal(t, "fortinet_saml", detectVPNAuthAction(service, map[string]string{
		"protocol": "fortinet",
		"authtype": "saml",
	}))
	assert.Equal(t, "fortinet_saml", detectVPNAuthAction(service, map[string]string{
		"protocol":         "fortinet",
		"saml-auth-method": "REDIRECT",
	}))
}

func TestEnsureOpenConnectAgentFlags(t *testing.T) {
	data := map[string]string{"protocol": "fortinet"}
	assert.True(t, setOpenConnectAgentFlags(data))
	assert.Equal(t, "2", data["cookie-flags"])
	assert.Equal(t, "2", data["gateway-flags"])
	assert.Equal(t, "2", data["gwcert-flags"])
	assert.False(t, setOpenConnectAgentFlags(data))
}

func TestOpenConnectCertificateConfirmation(t *testing.T) {
	binDir := t.TempDir()
	openConnectPath := filepath.Join(binDir, "openconnect")
	script := `#!/bin/sh
case "$*" in
  *--servercert=pin-sha256:TEST-FINGERPRINT*)
    printf '%s\n' "COOKIE='SVPNCOOKIE=test'" "HOST='vpn.example.test'" "FINGERPRINT='pin-sha256:TEST-FINGERPRINT'"
    exit 0
    ;;
esac
printf '%s\n' 'Add --servercert pin-sha256:TEST-FINGERPRINT' >&2
exit 1
`
	assert.NoError(t, os.WriteFile(openConnectPath, []byte(script), 0o755))
	t.Setenv("PATH", binDir)

	conn := mock_gonetworkmanager.NewMockConnection(t)
	connPath := dbus.ObjectPath("/org/freedesktop/NetworkManager/Settings/999")
	conn.EXPECT().GetSecrets("vpn").Return(gonetworkmanager.ConnectionSettings{
		"vpn": {"secrets": map[string]string{"password": "test-password"}},
	}, nil)
	conn.EXPECT().GetPath().Return(connPath).Twice()

	broker := &fakePromptBroker{
		asked: make(chan PromptRequest, 1),
		reply: PromptReply{},
	}
	backend := &NetworkManagerBackend{promptBroker: broker}
	data := map[string]string{
		"gateway":  "vpn.example.test:443",
		"protocol": "fortinet",
		"authtype": "password",
		"username": "test-user",
	}

	result, err := backend.handleOpenConnectPasswordAuth(
		context.Background(), conn, "Test VPN", "test-uuid",
		"org.freedesktop.NetworkManager.openconnect", data,
	)
	assert.NoError(t, err)
	assert.Equal(t, "SVPNCOOKIE=test", result.Cookie)
	assert.Equal(t, "vpn.example.test:443", result.Host)

	prompt := <-broker.asked
	assert.Equal(t, "server-certificate", prompt.Reason)
	assert.Equal(t, []string{"pin-sha256:TEST-FINGERPRINT"}, prompt.Hints)

	assert.Equal(t, map[string]string{
		"certificate:vpn.example.test:443": "pin-sha256:TEST-FINGERPRINT",
	}, backend.pendingVPNSave.PersistentSecrets)
}

func TestOpenConnectCertificateRotationReprompts(t *testing.T) {
	binDir := t.TempDir()
	openConnectPath := filepath.Join(binDir, "openconnect")
	script := `#!/bin/sh
case "$*" in
  *--servercert=pin-sha256:NEW-FINGERPRINT*)
    printf '%s\n' "COOKIE='SVPNCOOKIE=test'" "HOST='vpn.example.test'" "FINGERPRINT='pin-sha256:NEW-FINGERPRINT'"
    exit 0
    ;;
esac
printf '%s\n' 'Add --servercert pin-sha256:NEW-FINGERPRINT' >&2
exit 1
`
	assert.NoError(t, os.WriteFile(openConnectPath, []byte(script), 0o755))
	t.Setenv("PATH", binDir)

	conn := mock_gonetworkmanager.NewMockConnection(t)
	connPath := dbus.ObjectPath("/org/freedesktop/NetworkManager/Settings/999")
	conn.EXPECT().GetSecrets("vpn").Return(gonetworkmanager.ConnectionSettings{
		"vpn": {"secrets": map[string]string{
			"password":                         "test-password",
			"certificate:vpn.example.test:443": "pin-sha256:OLD-FINGERPRINT",
		}},
	}, nil)
	conn.EXPECT().GetPath().Return(connPath).Twice()

	broker := &fakePromptBroker{
		asked: make(chan PromptRequest, 1),
		reply: PromptReply{},
	}
	backend := &NetworkManagerBackend{promptBroker: broker}
	data := map[string]string{
		"gateway":  "vpn.example.test:443",
		"protocol": "fortinet",
		"authtype": "password",
		"username": "test-user",
	}

	result, err := backend.handleOpenConnectPasswordAuth(
		context.Background(), conn, "Test VPN", "test-uuid",
		"org.freedesktop.NetworkManager.openconnect", data,
	)
	assert.NoError(t, err)
	assert.Equal(t, "SVPNCOOKIE=test", result.Cookie)

	prompt := <-broker.asked
	assert.Equal(t, "server-certificate-changed", prompt.Reason)
	assert.Equal(t, []string{"pin-sha256:NEW-FINGERPRINT"}, prompt.Hints)

	assert.Equal(t, map[string]string{
		"certificate:vpn.example.test:443": "pin-sha256:NEW-FINGERPRINT",
	}, backend.pendingVPNSave.PersistentSecrets)
	assert.False(t, backend.pendingVPNSave.SavePassword)
	assert.Empty(t, backend.pendingVPNSave.Secrets)
}

func TestParseNmcliAddedUUID(t *testing.T) {
	const uuid = "0e1f2a3b-4c5d-6e7f-8091-a2b3c4d5e6f7"
	tests := []struct {
		name, output, wantName, wantUUID string
	}{
		{"simple", "Connection 'proton0' (" + uuid + ") successfully added.\n", "proton0", uuid},
		{"spaces and parens", "Connection 'my vpn (work)' (" + uuid + ") successfully added.", "my vpn (work)", uuid},
		{"warning first", "Warning: password-flags ignored\nConnection 'office' (" + uuid + ") successfully added.\n", "office", uuid},
		{"garbage", "Error: failed to import\n", "", ""},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gotName, gotUUID := parseNmcliAddedUUID(tt.output)
			assert.Equal(t, tt.wantName, gotName)
			assert.Equal(t, tt.wantUUID, gotUUID)
		})
	}
}

const testVPNPath = dbus.ObjectPath("/org/freedesktop/NetworkManager/Settings/7")

func vpnBackendWithObject(t *testing.T, obj *mock_dbus.MockBusObject) *NetworkManagerBackend {
	backend, err := NewNetworkManagerBackend(mock_gonetworkmanager.NewMockNetworkManager(t))
	require.NoError(t, err)
	backend.nmObjectFn = func(p dbus.ObjectPath) dbus.BusObject {
		assert.Equal(t, testVPNPath, p)
		return obj
	}
	return backend
}

func storedVPNProfile() nmSettings {
	return nmSettings{
		"connection": {"id": dbus.MakeVariant("office"), "uuid": dbus.MakeVariant("vpn-uuid"), "type": dbus.MakeVariant("vpn"), "autoconnect": dbus.MakeVariant(true)},
		"vpn": {
			"service-type": dbus.MakeVariant("org.freedesktop.NetworkManager.openvpn"),
			"data":         dbus.MakeVariant(map[string]string{"remote": "vpn.example.com", "connection-type": "password"}),
		},
		"ipv4": {"method": dbus.MakeVariant("auto"), "dns-data": dbus.MakeVariant([]string{"10.0.0.53"}), "never-default": dbus.MakeVariant(true)},
		"ipv6": {"method": dbus.MakeVariant("auto")},
	}
}

func TestUpdateVPNConfig_KeepsIPSectionsAndSecrets(t *testing.T) {
	obj := mock_dbus.NewMockBusObject(t)
	backend := vpnBackendWithObject(t, obj)

	conn := mock_gonetworkmanager.NewMockConnection(t)
	conn.EXPECT().GetPath().Return(testVPNPath).Maybe()
	conn.EXPECT().GetSettings().Return(gonetworkmanager.ConnectionSettings{
		"connection": {"id": "office", "uuid": "vpn-uuid", "type": "vpn"},
	}, nil)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)
	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{conn}, nil)
	backend.settings = mockSettings

	expectGetSettings(obj, storedVPNProfile())
	expectGetSecrets(obj, "vpn", nmSettings{"vpn": {"secrets": dbus.MakeVariant(map[string]string{"password": "hunter2"})}})
	got := captureUpdate2(obj, nmUpdate2FlagToDisk, nil)

	err := backend.UpdateVPNConfig("vpn-uuid", map[string]any{
		"autoconnect": false,
		"data":        map[string]any{"remote": "vpn2.example.com"},
	})
	require.NoError(t, err)

	s := *got
	assert.Equal(t, false, s["connection"]["autoconnect"].Value())
	assert.Equal(t, []string{"10.0.0.53"}, s["ipv4"]["dns-data"].Value())
	assert.Equal(t, map[string]string{"password": "hunter2"}, s["vpn"]["secrets"].Value())
	assert.Equal(t, map[string]string{"remote": "vpn2.example.com", "connection-type": "password"}, s["vpn"]["data"].Value())
}

func TestSaveVPNCredentials_KeepsIPSections(t *testing.T) {
	obj := mock_dbus.NewMockBusObject(t)
	backend := vpnBackendWithObject(t, obj)

	expectGetSettings(obj, storedVPNProfile())
	expectGetSecrets(obj, "vpn", nmSettings{"vpn": {"secrets": dbus.MakeVariant(map[string]string{"cert-pass": "b"})}})
	got := captureUpdate2(obj, nmUpdate2FlagToDisk, nil)

	backend.saveVPNCredentials(&pendingVPNCredentials{
		ConnectionPath: string(testVPNPath),
		Username:       "alice",
		Password:       "pw",
		SavePassword:   true,
	})

	s := *got
	require.NotNil(t, s)
	assert.Equal(t, true, s["ipv4"]["never-default"].Value())
	assert.Equal(t, []string{"10.0.0.53"}, s["ipv4"]["dns-data"].Value())
	assert.Contains(t, s, "ipv6")
	assert.Equal(t, map[string]string{"cert-pass": "b", "password": "pw"}, s["vpn"]["secrets"].Value())
	data := s["vpn"]["data"].Value().(map[string]string)
	assert.Equal(t, "alice", data["username"])
	assert.Equal(t, "0", data["password-flags"])
	assert.Equal(t, "vpn.example.com", data["remote"])
}

func listedVPN(t *testing.T, backend *NetworkManagerBackend, connType string) *mock_gonetworkmanager.MockConnection {
	conn := mock_gonetworkmanager.NewMockConnection(t)
	conn.EXPECT().GetPath().Return(testVPNPath).Maybe()
	conn.EXPECT().GetSettings().Return(gonetworkmanager.ConnectionSettings{
		"connection": {"id": "office", "uuid": "vpn-uuid", "type": connType},
	}, nil)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)
	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{conn}, nil)
	backend.settings = mockSettings
	return conn
}

func TestClearVPNCredentials_DropsSecretsKeepsProfile(t *testing.T) {
	obj := mock_dbus.NewMockBusObject(t)
	backend := vpnBackendWithObject(t, obj)
	conn := listedVPN(t, backend, "vpn")
	conn.EXPECT().ClearSecrets().Return(nil).Once()

	expectGetSettings(obj, storedVPNProfile())
	expectGetSecrets(obj, "vpn", nmSettings{"vpn": {"secrets": dbus.MakeVariant(map[string]string{"password": "hunter2"})}})
	got := captureUpdate2(obj, nmUpdate2FlagToDisk, nil)

	require.NoError(t, backend.ClearVPNCredentials("vpn-uuid"))

	s := *got
	assert.NotContains(t, s["vpn"], "secrets")
	data := s["vpn"]["data"].Value().(map[string]string)
	assert.Equal(t, "1", data["password-flags"])
	assert.Equal(t, "vpn.example.com", data["remote"])
	assert.Equal(t, []string{"10.0.0.53"}, s["ipv4"]["dns-data"].Value())
	assert.Equal(t, true, s["ipv4"]["never-default"].Value())
}

func TestClearVPNCredentials_SecretsReadFailureAborts(t *testing.T) {
	obj := mock_dbus.NewMockBusObject(t)
	backend := vpnBackendWithObject(t, obj)
	listedVPN(t, backend, "vpn")

	expectGetSettings(obj, storedVPNProfile())
	obj.EXPECT().Call(nmConnGetSecrets, dbus.Flags(0), "vpn").
		Return(&dbus.Call{Err: errors.New("agent gone")}).Once()

	require.Error(t, backend.ClearVPNCredentials("vpn-uuid"))
}

func TestClearVPNCredentials_WireGuardSkipsUpdate(t *testing.T) {
	obj := mock_dbus.NewMockBusObject(t)
	backend := vpnBackendWithObject(t, obj)
	conn := listedVPN(t, backend, "wireguard")
	conn.EXPECT().ClearSecrets().Return(nil).Once()

	// The strict mock object fails the test on any D-Bus call.
	require.NoError(t, backend.ClearVPNCredentials("office"))
}

func TestWireGuardImportName(t *testing.T) {
	tests := []struct {
		path string
		name string
		copy bool
	}{
		{"/x/wg0.conf", "wg0", false},
		{"/x/protonvpn-DE-523.conf", "protonvpn-DE-52", true},
		{"/x/My VPN.conf", "MyVPN", true},
		{"/x/äöü.conf", "wg0", true},
		{"/x/wg0", "wg0", true},
		{"/x/wg0.CONF", "wg0.CONF", true},
	}
	for _, tt := range tests {
		name, cp := wireGuardImportName(tt.path)
		assert.Equal(t, tt.name, name, tt.path)
		assert.Equal(t, tt.copy, cp, tt.path)
	}
}

func TestLooksLikeWireGuardConfig(t *testing.T) {
	assert.True(t, looksLikeWireGuardConfig([]byte("[Interface]\nprivatekey = abc\nAddress=10.0.0.2/32\n[Peer]\nPublicKey=x\n")))
	assert.False(t, looksLikeWireGuardConfig([]byte("client\ndev tun\nremote example.com 1194\n")))
	assert.False(t, looksLikeWireGuardConfig([]byte("[Peer]\nPrivateKey=abc\n")))
}

func TestStageWireGuardImport(t *testing.T) {
	dir := t.TempDir()
	src := filepath.Join(dir, "My VPN.conf")
	require.NoError(t, os.WriteFile(src, []byte("[Interface]\nPrivateKey=abc\n"), 0o600))

	staged, cleanup, err := stageWireGuardImport(src)
	require.NoError(t, err)
	assert.Equal(t, "MyVPN.conf", filepath.Base(staged))
	info, err := os.Stat(staged)
	require.NoError(t, err)
	assert.Equal(t, os.FileMode(0o600), info.Mode().Perm())
	cleanup()
	_, err = os.Stat(staged)
	assert.True(t, os.IsNotExist(err))

	ovpn := filepath.Join(dir, "my vpn.ovpn")
	require.NoError(t, os.WriteFile(ovpn, []byte("client\n"), 0o600))
	got, cleanup, err := stageWireGuardImport(ovpn)
	require.NoError(t, err)
	cleanup()
	assert.Equal(t, ovpn, got)

	big := filepath.Join(dir, "big vpn.conf")
	require.NoError(t, os.WriteFile(big, append([]byte("[Interface]\nPrivateKey=abc\n"), make([]byte, maxEnterpriseFileSize)...), 0o600))
	got, cleanup, err = stageWireGuardImport(big)
	require.NoError(t, err)
	cleanup()
	assert.Equal(t, big, got)
}
