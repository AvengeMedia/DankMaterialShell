package network_test

import (
	"bytes"
	"encoding/json"
	"net"
	"testing"
	"time"

	mocks "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/network"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/network"
	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
)

type editorTestConn struct {
	net.Conn
	out bytes.Buffer
}

func (c *editorTestConn) Write(b []byte) (int, error)      { return c.out.Write(b) }
func (c *editorTestConn) Close() error                     { return nil }
func (c *editorTestConn) SetWriteDeadline(time.Time) error { return nil }

type editorBackend struct {
	*mocks.MockBackend
	*mocks.MockConnectionEditorBackend
}

func call(t *testing.T, m *network.Manager, method string, params map[string]any) ipc.Response[json.RawMessage] {
	t.Helper()
	c := &editorTestConn{}
	network.HandleRequest(ipc.NewConnWriter(c), ipc.Request{ID: 7, Method: method, Params: params}, m)
	var resp ipc.Response[json.RawMessage]
	require.NoError(t, json.NewDecoder(&c.out).Decode(&resp))
	return resp
}

func newEditorManager(t *testing.T) (*network.Manager, *mocks.MockConnectionEditorBackend) {
	t.Helper()
	ed := mocks.NewMockConnectionEditorBackend(t)
	b := &editorBackend{MockBackend: mocks.NewMockBackend(t), MockConnectionEditorBackend: ed}
	return network.NewTestManager(b, &network.NetworkState{}), ed
}

func TestConnectionUpdateHandler(t *testing.T) {
	m, ed := newEditorManager(t)
	var got network.SettingsPatch
	ed.EXPECT().UpdateConnectionSettings("u1", mock.Anything, false).
		Run(func(_ string, p network.SettingsPatch, _ bool) { got = p }).Return(nil).Once()

	resp := call(t, m, "network.connection.update", map[string]any{
		"uuid": "u1",
		"settings": map[string]any{
			"connection": map[string]any{"autoconnect": false},
			"ipv6":       nil,
		},
	})
	assert.Empty(t, resp.Error)
	require.Contains(t, got, "ipv6")
	assert.Nil(t, got["ipv6"])
	assert.Equal(t, false, got["connection"]["autoconnect"])
}

func TestConnectionUpdateHandlerBackendError(t *testing.T) {
	m, ed := newEditorManager(t)
	ed.EXPECT().UpdateConnectionSettings("u1", mock.Anything, true).
		Return(assert.AnError).Once()

	resp := call(t, m, "network.connection.update", map[string]any{
		"uuid":     "u1",
		"persist":  true,
		"settings": map[string]any{"connection": map[string]any{"id": "x"}},
	})
	assert.Equal(t, assert.AnError.Error(), resp.Error)
}

func TestConnectionAddHandlerDefaultsToPersist(t *testing.T) {
	m, ed := newEditorManager(t)
	ed.EXPECT().AddConnectionProfile(mock.Anything, true).Return("new-uuid", nil).Once()

	resp := call(t, m, "network.connection.add", map[string]any{
		"settings": map[string]any{"connection": map[string]any{"type": "802-3-ethernet"}},
	})
	assert.Empty(t, resp.Error)
	assert.JSONEq(t, `{"uuid":"new-uuid"}`, string(*resp.Result))
}

func TestConnectionListGetDeleteDuplicateHandlers(t *testing.T) {
	m, ed := newEditorManager(t)
	ed.EXPECT().ListConnectionProfiles().Return([]network.ConnectionProfile{{UUID: "u1", ID: "A"}}, nil).Once()
	ed.EXPECT().GetConnectionSettings("u1", true).Return(map[string]map[string]any{"connection": {"id": "A"}}, nil).Once()
	ed.EXPECT().DeleteConnectionProfile("u1").Return(nil).Once()
	ed.EXPECT().DuplicateConnectionProfile("u1", "B").Return("u2", nil).Once()

	resp := call(t, m, "network.connection.list", nil)
	assert.Contains(t, string(*resp.Result), `"uuid":"u1"`)
	resp = call(t, m, "network.connection.get", map[string]any{"uuid": "u1", "secrets": true})
	assert.JSONEq(t, `{"connection":{"id":"A"}}`, string(*resp.Result))
	resp = call(t, m, "network.connection.delete", map[string]any{"uuid": "u1"})
	assert.Empty(t, resp.Error)
	resp = call(t, m, "network.connection.duplicate", map[string]any{"uuid": "u1", "name": "B"})
	assert.JSONEq(t, `{"uuid":"u2"}`, string(*resp.Result))
}

func TestConnectionHandlersParamErrors(t *testing.T) {
	m, _ := newEditorManager(t)
	for _, method := range []string{
		"network.connection.get", "network.connection.update", "network.connection.add",
		"network.connection.delete", "network.connection.duplicate",
	} {
		assert.NotEmpty(t, call(t, m, method, map[string]any{}).Error, method)
	}
	assert.NotEmpty(t, call(t, m, "network.connection.duplicate", map[string]any{"uuid": "u"}).Error)
}

func TestConnectionEditorUnsupportedBackend(t *testing.T) {
	m := network.NewTestManager(mocks.NewMockBackend(t), &network.NetworkState{})
	resp := call(t, m, "network.connection.list", nil)
	assert.Contains(t, resp.Error, "not supported")
}

func TestConnectionUpdateHandlerEnterprise(t *testing.T) {
	m, ed := newEditorManager(t)
	var got network.SettingsPatch
	ed.EXPECT().UpdateConnectionSettings("u1", mock.Anything, false).
		Run(func(_ string, p network.SettingsPatch, _ bool) { got = p }).Return(nil).Once()

	resp := call(t, m, "network.connection.update", map[string]any{
		"uuid": "u1",
		"settings": map[string]any{
			"ipv4":   map[string]any{"mtu": 1400},
			"802-1x": map[string]any{"identity": "stale"},
		},
		"enterprise": map[string]any{"eap": "ttls", "phase2": "mschapv2", "identity": "bob", "ca": "file"},
	})
	require.Empty(t, resp.Error)
	assert.Equal(t, []string{"ttls"}, got["802-1x"]["eap"])
	assert.Equal(t, "bob", got["802-1x"]["identity"])
	assert.NotContains(t, got["802-1x"], "ca-cert")
	assert.Contains(t, got, "ipv4")
}

func TestConnectionAddHandlerEnterprise(t *testing.T) {
	m, ed := newEditorManager(t)
	var got network.SettingsPatch
	ed.EXPECT().AddConnectionProfile(mock.Anything, true).
		Run(func(p network.SettingsPatch, _ bool) { got = p }).Return("n1", nil).Once()

	resp := call(t, m, "network.connection.add", map[string]any{
		"settings":   map[string]any{"connection": map[string]any{"type": "802-11-wireless"}},
		"enterprise": map[string]any{"eap": "peap", "phase2": "mschapv2", "identity": "bob", "password": "pw", "ca": "none"},
	})
	require.Empty(t, resp.Error)
	assert.Equal(t, []string{"peap"}, got["802-1x"]["eap"])
}

func TestConnectionEnterpriseParamErrors(t *testing.T) {
	m, _ := newEditorManager(t)
	base := map[string]any{"connection": map[string]any{"id": "x"}}
	for _, ent := range []map[string]any{
		{"eap": "ttls", "bogus": 1},
		{"eap": "nope", "identity": "bob"},
	} {
		resp := call(t, m, "network.connection.update", map[string]any{"uuid": "u1", "settings": base, "enterprise": ent})
		assert.NotEmpty(t, resp.Error)
	}
}

func TestConnectionGetEnterpriseHandler(t *testing.T) {
	m, ed := newEditorManager(t)
	ed.EXPECT().GetConnectionSettings("u1", false).Return(map[string]map[string]any{
		"802-1x": {"eap": []string{"tls"}, "identity": "bob", "ca-cert": "blob"},
	}, nil).Once()
	ed.EXPECT().GetConnectionSettings("u2", false).Return(map[string]map[string]any{
		"connection": {"id": "x"},
	}, nil).Once()

	resp := call(t, m, "network.connection.getEnterprise", map[string]any{"uuid": "u1"})
	require.Empty(t, resp.Error)
	assert.Contains(t, string(*resp.Result), `"ca":"file"`)
	assert.Contains(t, string(*resp.Result), `"identity":"bob"`)

	resp = call(t, m, "network.connection.getEnterprise", map[string]any{"uuid": "u2"})
	assert.Equal(t, "connection has no 802.1X settings", resp.Error)
}

func TestConnectionActivateDeactivateFirewallHandlers(t *testing.T) {
	m, ed := newEditorManager(t)
	ed.EXPECT().ActivateConnectionProfile("u1", "").Return(nil).Once()
	ed.EXPECT().ActivateConnectionProfile("u1", "eth0").Return(nil).Once()
	ed.EXPECT().DeactivateConnectionProfile("u1").Return(nil).Once()
	ed.EXPECT().FirewallZones().Return([]string{"public", "home"}, nil).Once()

	assert.Empty(t, call(t, m, "network.connection.activate", map[string]any{"uuid": "u1"}).Error)
	assert.Empty(t, call(t, m, "network.connection.activate", map[string]any{"uuid": "u1", "device": "eth0"}).Error)
	assert.Empty(t, call(t, m, "network.connection.deactivate", map[string]any{"uuid": "u1"}).Error)
	resp := call(t, m, "network.connection.firewallZones", nil)
	assert.JSONEq(t, `["public","home"]`, string(*resp.Result))
	for _, method := range []string{"network.connection.activate", "network.connection.deactivate", "network.connection.getEnterprise"} {
		assert.NotEmpty(t, call(t, m, method, map[string]any{}).Error, method)
	}
}

func TestWireGuardKeysHandler(t *testing.T) {
	m := network.NewTestManager(mocks.NewMockBackend(t), &network.NetworkState{})
	var pair map[string]string
	resp := call(t, m, "network.wireguard.keys", nil)
	require.Empty(t, resp.Error)
	require.NoError(t, json.Unmarshal(*resp.Result, &pair))
	require.NotEmpty(t, pair["privateKey"])

	var derived map[string]string
	resp = call(t, m, "network.wireguard.keys", map[string]any{"privateKey": pair["privateKey"]})
	require.Empty(t, resp.Error)
	require.NoError(t, json.Unmarshal(*resp.Result, &derived))
	assert.Equal(t, pair, derived)

	assert.Equal(t, "invalid WireGuard key", call(t, m, "network.wireguard.keys", map[string]any{"privateKey": "abc"}).Error)
}

func TestConnectionExportHandler(t *testing.T) {
	m, ed := newEditorManager(t)
	ed.EXPECT().ExportConnectionProfile("u1", "/tmp/x.conf").Return(nil).Once()
	assert.Empty(t, call(t, m, "network.connection.export", map[string]any{"uuid": "u1", "file": "/tmp/x.conf"}).Error)
	assert.NotEmpty(t, call(t, m, "network.connection.export", map[string]any{"uuid": "u1"}).Error)

	m = network.NewTestManager(mocks.NewMockBackend(t), &network.NetworkState{})
	resp := call(t, m, "network.connection.export", map[string]any{"uuid": "u1", "file": "/tmp/x.conf"})
	assert.Contains(t, resp.Error, "not supported")
}

func TestConnectionNewMethodsUnsupportedBackend(t *testing.T) {
	m := network.NewTestManager(mocks.NewMockBackend(t), &network.NetworkState{})
	for method, p := range map[string]map[string]any{
		"network.connection.activate":      {"uuid": "u"},
		"network.connection.deactivate":    {"uuid": "u"},
		"network.connection.getEnterprise": {"uuid": "u"},
		"network.connection.firewallZones": {},
	} {
		assert.Contains(t, call(t, m, method, p).Error, "not supported", method)
	}
}

func TestConnectivityHandlers(t *testing.T) {
	m, ed := newEditorManager(t)
	ed.EXPECT().CheckConnectivity().Return("portal", nil).Once()
	resp := call(t, m, "network.connectivity.check", map[string]any{})
	assert.Empty(t, resp.Error)
	assert.JSONEq(t, `{"connectivity":"portal"}`, string(*resp.Result))

	ed.EXPECT().CheckConnectivity().Return("", assert.AnError).Once()
	assert.Equal(t, assert.AnError.Error(), call(t, m, "network.connectivity.check", nil).Error)

	ed.EXPECT().SetConnectivityCheckEnabled(true).Return(nil).Once()
	assert.Empty(t, call(t, m, "network.connectivity.setCheckEnabled", map[string]any{"enabled": true}).Error)

	ed.EXPECT().SetConnectivityCheckEnabled(false).Return(assert.AnError).Once()
	assert.Equal(t, assert.AnError.Error(), call(t, m, "network.connectivity.setCheckEnabled", map[string]any{"enabled": false}).Error)

	assert.Contains(t, call(t, m, "network.connectivity.setCheckEnabled", map[string]any{}).Error, "enabled")
}
