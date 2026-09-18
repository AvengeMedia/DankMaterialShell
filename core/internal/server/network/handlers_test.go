package network

import (
	"bytes"
	"encoding/json"
	"net"
	"testing"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type mockNetConn struct {
	net.Conn
	readBuf  *bytes.Buffer
	writeBuf *bytes.Buffer
	closed   bool
}

func newMockNetConn() *mockNetConn {
	return &mockNetConn{
		readBuf:  &bytes.Buffer{},
		writeBuf: &bytes.Buffer{},
	}
}

func (m *mockNetConn) Read(b []byte) (n int, err error) {
	return m.readBuf.Read(b)
}

func (m *mockNetConn) Write(b []byte) (n int, err error) {
	return m.writeBuf.Write(b)
}

func (m *mockNetConn) Close() error {
	m.closed = true
	return nil
}

func (m *mockNetConn) SetWriteDeadline(t time.Time) error { return nil }

func TestRespondError_Network(t *testing.T) {
	mc := newMockNetConn()
	conn := ipc.NewConnWriter(mc)
	models.RespondError(conn, 123, "test error")

	var resp ipc.Response[any]
	err := json.NewDecoder(mc.writeBuf).Decode(&resp)
	require.NoError(t, err)

	assert.Equal(t, 123, resp.ID)
	assert.Equal(t, "test error", resp.Error)
	assert.Nil(t, resp.Result)
}

func TestRespond_Network(t *testing.T) {
	mc := newMockNetConn()
	conn := ipc.NewConnWriter(mc)
	result := models.SuccessResult{Success: true, Message: "test"}
	models.Respond(conn, 123, result)

	var resp ipc.Response[models.SuccessResult]
	err := json.NewDecoder(mc.writeBuf).Decode(&resp)
	require.NoError(t, err)

	assert.Equal(t, 123, resp.ID)
	assert.Empty(t, resp.Error)
	require.NotNil(t, resp.Result)
	assert.True(t, resp.Result.Success)
	assert.Equal(t, "test", resp.Result.Message)
}

func TestHandleGetState(t *testing.T) {
	manager := &Manager{
		state: &NetworkState{
			NetworkStatus: StatusWiFi,
			WiFiSSID:      "TestNetwork",
			WiFiConnected: true,
		},
	}

	mc := newMockNetConn()
	conn := ipc.NewConnWriter(mc)
	req := ipc.Request{ID: 123, Method: "network.getState"}

	handleGetState(conn, req, manager)

	var resp ipc.Response[NetworkState]
	err := json.NewDecoder(mc.writeBuf).Decode(&resp)
	require.NoError(t, err)

	assert.Equal(t, 123, resp.ID)
	assert.Empty(t, resp.Error)
	require.NotNil(t, resp.Result)
	assert.Equal(t, StatusWiFi, resp.Result.NetworkStatus)
	assert.Equal(t, "TestNetwork", resp.Result.WiFiSSID)
}

func TestHandleGetWiFiNetworks(t *testing.T) {
	manager := &Manager{
		state: &NetworkState{
			WiFiNetworks: []WiFiNetwork{
				{SSID: "Network1", Signal: 90},
				{SSID: "Network2", Signal: 80},
			},
		},
	}

	mc := newMockNetConn()
	conn := ipc.NewConnWriter(mc)
	req := ipc.Request{ID: 123, Method: "network.wifi.networks"}

	handleGetWiFiNetworks(conn, req, manager)

	var resp ipc.Response[[]WiFiNetwork]
	err := json.NewDecoder(mc.writeBuf).Decode(&resp)
	require.NoError(t, err)

	assert.Equal(t, 123, resp.ID)
	assert.Empty(t, resp.Error)
	require.NotNil(t, resp.Result)
	assert.Len(t, *resp.Result, 2)
	assert.Equal(t, "Network1", (*resp.Result)[0].SSID)
}

func TestHandleConnectWiFi(t *testing.T) {
	t.Run("missing ssid parameter", func(t *testing.T) {
		manager := &Manager{
			state: &NetworkState{},
		}

		mc := newMockNetConn()
		conn := ipc.NewConnWriter(mc)
		req := ipc.Request{
			ID:     123,
			Method: "network.wifi.connect",
			Params: map[string]any{},
		}

		handleConnectWiFi(conn, req, manager)

		var resp ipc.Response[any]
		err := json.NewDecoder(mc.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Contains(t, resp.Error, "missing or invalid 'ssid' parameter")
	})
}

func TestHandleSetPreference(t *testing.T) {
	t.Run("missing preference parameter", func(t *testing.T) {
		manager := &Manager{
			state: &NetworkState{},
		}

		mc := newMockNetConn()
		conn := ipc.NewConnWriter(mc)
		req := ipc.Request{
			ID:     123,
			Method: "network.preference.set",
			Params: map[string]any{},
		}

		handleSetPreference(conn, req, manager)

		var resp ipc.Response[any]
		err := json.NewDecoder(mc.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Contains(t, resp.Error, "missing or invalid 'preference' parameter")
	})
}

func TestHandleHotspotRequests(t *testing.T) {
	t.Run("configure requires ssid", func(t *testing.T) {
		manager := &Manager{state: &NetworkState{}}
		mc := newMockNetConn()
		conn := ipc.NewConnWriter(mc)
		req := ipc.Request{
			ID:     123,
			Method: "network.hotspot.configure",
			Params: map[string]any{},
		}

		handleConfigureHotspot(conn, req, manager)

		var resp ipc.Response[any]
		err := json.NewDecoder(mc.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Contains(t, resp.Error, "missing or invalid 'ssid' parameter")
	})

	t.Run("configure dispatches request", func(t *testing.T) {
		iwdBackend, err := NewIWDBackend()
		require.NoError(t, err)
		backend := &testHotspotBackend{IWDBackend: iwdBackend}
		manager := NewTestManager(backend, &NetworkState{})
		mc := newMockNetConn()
		conn := ipc.NewConnWriter(mc)
		req := ipc.Request{
			ID:     123,
			Method: "network.hotspot.configure",
			Params: map[string]any{
				"ssid":     "DMS Hotspot",
				"password": "hunter2-password",
				"device":   "wlan0",
				"band":     "bg",
			},
		}

		HandleRequest(conn, req, manager)

		var resp ipc.Response[models.SuccessResult]
		err = json.NewDecoder(mc.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Empty(t, resp.Error)
		require.NotNil(t, resp.Result)
		assert.True(t, resp.Result.Success)
		assert.True(t, backend.configureCalled)
		assert.Equal(t, HotspotRequest{
			SSID:     "DMS Hotspot",
			Password: "hunter2-password",
			Device:   "wlan0",
			Band:     "bg",
		}, backend.configureReq)
	})

	t.Run("start dispatches without payload", func(t *testing.T) {
		iwdBackend, err := NewIWDBackend()
		require.NoError(t, err)
		backend := &testHotspotBackend{IWDBackend: iwdBackend}
		manager := NewTestManager(backend, &NetworkState{})
		mc := newMockNetConn()
		conn := ipc.NewConnWriter(mc)
		req := ipc.Request{ID: 123, Method: "network.hotspot.start"}

		HandleRequest(conn, req, manager)

		var resp ipc.Response[models.SuccessResult]
		err = json.NewDecoder(mc.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Empty(t, resp.Error)
		assert.True(t, backend.startCalled)
	})

	t.Run("stop dispatches", func(t *testing.T) {
		iwdBackend, err := NewIWDBackend()
		require.NoError(t, err)
		backend := &testHotspotBackend{IWDBackend: iwdBackend}
		manager := NewTestManager(backend, &NetworkState{})
		mc := newMockNetConn()
		conn := ipc.NewConnWriter(mc)
		req := ipc.Request{ID: 123, Method: "network.hotspot.stop"}

		HandleRequest(conn, req, manager)

		var resp ipc.Response[models.SuccessResult]
		err = json.NewDecoder(mc.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Empty(t, resp.Error)
		assert.True(t, backend.stopCalled)
	})

	t.Run("getSecrets dispatches", func(t *testing.T) {
		iwdBackend, err := NewIWDBackend()
		require.NoError(t, err)
		backend := &testHotspotBackend{IWDBackend: iwdBackend, secrets: "hunter2-password"}
		manager := NewTestManager(backend, &NetworkState{})
		mc := newMockNetConn()
		conn := ipc.NewConnWriter(mc)
		req := ipc.Request{ID: 123, Method: "network.hotspot.getSecrets"}

		HandleRequest(conn, req, manager)

		var resp ipc.Response[map[string]string]
		err = json.NewDecoder(mc.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Empty(t, resp.Error)
		assert.True(t, backend.getSecretsCalled)
		require.NotNil(t, resp.Result)
		assert.Equal(t, "hunter2-password", (*resp.Result)["password"])
	})

	t.Run("unsupported backend returns error", func(t *testing.T) {
		manager := &Manager{state: &NetworkState{}}
		mc := newMockNetConn()
		conn := ipc.NewConnWriter(mc)
		req := ipc.Request{ID: 123, Method: "network.hotspot.start"}

		HandleRequest(conn, req, manager)

		var resp ipc.Response[any]
		err := json.NewDecoder(mc.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Contains(t, resp.Error, ErrHotspotNotSupported.Error())
	})
}

func TestHandleGetNetworkInfo(t *testing.T) {
	t.Run("missing ssid parameter", func(t *testing.T) {
		manager := &Manager{
			state: &NetworkState{},
		}

		mc := newMockNetConn()
		conn := ipc.NewConnWriter(mc)
		req := ipc.Request{
			ID:     123,
			Method: "network.info",
			Params: map[string]any{},
		}

		handleGetNetworkInfo(conn, req, manager)

		var resp ipc.Response[any]
		err := json.NewDecoder(mc.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Contains(t, resp.Error, "missing or invalid 'ssid' parameter")
	})
}

func TestHandleRequest(t *testing.T) {
	manager := &Manager{
		state: &NetworkState{
			NetworkStatus: StatusWiFi,
		},
	}

	t.Run("unknown method", func(t *testing.T) {
		mc := newMockNetConn()
		conn := ipc.NewConnWriter(mc)
		req := ipc.Request{
			ID:     123,
			Method: "network.unknown",
		}

		HandleRequest(conn, req, manager)

		var resp ipc.Response[any]
		err := json.NewDecoder(mc.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Contains(t, resp.Error, "unknown method")
	})

	t.Run("valid method - getState", func(t *testing.T) {
		mc := newMockNetConn()
		conn := ipc.NewConnWriter(mc)
		req := ipc.Request{
			ID:     123,
			Method: "network.getState",
		}

		HandleRequest(conn, req, manager)

		var resp ipc.Response[NetworkState]
		err := json.NewDecoder(mc.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Empty(t, resp.Error)
	})
}
