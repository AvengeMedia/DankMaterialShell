package network

import (
	"bytes"
	"encoding/json"
	"net"
	"testing"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
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

func TestRespondError_Network(t *testing.T) {
	conn := newMockNetConn()
	models.RespondError(conn, 123, "test error")

	var resp models.Response[any]
	err := json.NewDecoder(conn.writeBuf).Decode(&resp)
	require.NoError(t, err)

	assert.Equal(t, 123, resp.ID)
	assert.Equal(t, "test error", resp.Error)
	assert.Nil(t, resp.Result)
}

func TestRespond_Network(t *testing.T) {
	conn := newMockNetConn()
	result := SuccessResult{Success: true, Message: "test"}
	models.Respond(conn, 123, result)

	var resp models.Response[SuccessResult]
	err := json.NewDecoder(conn.writeBuf).Decode(&resp)
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

	conn := newMockNetConn()
	req := Request{ID: 123, Method: "network.getState"}

	handleGetState(conn, req, manager)

	var resp models.Response[NetworkState]
	err := json.NewDecoder(conn.writeBuf).Decode(&resp)
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

	conn := newMockNetConn()
	req := Request{ID: 123, Method: "network.wifi.networks"}

	handleGetWiFiNetworks(conn, req, manager)

	var resp models.Response[[]WiFiNetwork]
	err := json.NewDecoder(conn.writeBuf).Decode(&resp)
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

		conn := newMockNetConn()
		req := Request{
			ID:     123,
			Method: "network.wifi.connect",
			Params: map[string]interface{}{},
		}

		handleConnectWiFi(conn, req, manager)

		var resp models.Response[any]
		err := json.NewDecoder(conn.writeBuf).Decode(&resp)
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

		conn := newMockNetConn()
		req := Request{
			ID:     123,
			Method: "network.preference.set",
			Params: map[string]interface{}{},
		}

		handleSetPreference(conn, req, manager)

		var resp models.Response[any]
		err := json.NewDecoder(conn.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Contains(t, resp.Error, "missing or invalid 'preference' parameter")
	})
}

func TestHandleGetNetworkInfo(t *testing.T) {
	t.Run("missing ssid parameter", func(t *testing.T) {
		manager := &Manager{
			state: &NetworkState{},
		}

		conn := newMockNetConn()
		req := Request{
			ID:     123,
			Method: "network.info",
			Params: map[string]interface{}{},
		}

		handleGetNetworkInfo(conn, req, manager)

		var resp models.Response[any]
		err := json.NewDecoder(conn.writeBuf).Decode(&resp)
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
		conn := newMockNetConn()
		req := Request{
			ID:     123,
			Method: "network.unknown",
		}

		HandleRequest(conn, req, manager)

		var resp models.Response[any]
		err := json.NewDecoder(conn.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Contains(t, resp.Error, "unknown method")
	})

	t.Run("valid method - getState", func(t *testing.T) {
		conn := newMockNetConn()
		req := Request{
			ID:     123,
			Method: "network.getState",
		}

		HandleRequest(conn, req, manager)

		var resp models.Response[NetworkState]
		err := json.NewDecoder(conn.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Empty(t, resp.Error)
	})
}

func TestHandleSubscribe(t *testing.T) {
	// This test is complex due to the streaming nature of subscriptions
	// Better suited as an integration test
	t.Skip("Subscription test requires connection lifecycle management - integration test needed")
}

func TestManager_Subscribe_Unsubscribe(t *testing.T) {
	manager := &Manager{
		state: &NetworkState{},
	}

	t.Run("subscribe creates channel", func(t *testing.T) {
		ch := manager.Subscribe("client1")
		assert.NotNil(t, ch)
		count := 0
		manager.subscribers.Range(func(key string, ch chan NetworkState) bool {
			count++
			return true
		})
		assert.Equal(t, 1, count)
	})

	t.Run("unsubscribe removes channel", func(t *testing.T) {
		manager.Unsubscribe("client1")
		count := 0
		manager.subscribers.Range(func(key string, ch chan NetworkState) bool { count++; return true })
		assert.Equal(t, 0, count)
	})

	t.Run("unsubscribe non-existent client is safe", func(t *testing.T) {
		assert.NotPanics(t, func() {
			manager.Unsubscribe("non-existent")
		})
	})
}
