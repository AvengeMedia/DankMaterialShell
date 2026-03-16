package tailscale

import (
	"bytes"
	"context"
	"encoding/json"
	"net"
	"testing"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"tailscale.com/ipn"
	"tailscale.com/ipn/ipnstate"
)

type mockConn struct {
	*bytes.Buffer
}

func (m *mockConn) Close() error                       { return nil }
func (m *mockConn) LocalAddr() net.Addr                { return nil }
func (m *mockConn) RemoteAddr() net.Addr               { return nil }
func (m *mockConn) SetDeadline(t time.Time) error      { return nil }
func (m *mockConn) SetReadDeadline(t time.Time) error  { return nil }
func (m *mockConn) SetWriteDeadline(t time.Time) error { return nil }

func handlerTestManager() *Manager {
	client := &mockClient{
		watchFn: func(ctx context.Context, mask ipn.NotifyWatchOpt) (ipnBusWatcher, error) {
			<-ctx.Done()
			return nil, ctx.Err()
		},
		statusFn: func(ctx context.Context) (*ipnstate.Status, error) {
			return runningStatus(), nil
		},
	}
	m := newManager(client)
	m.RefreshState()
	return m
}

func TestHandleGetStatus(t *testing.T) {
	m := handlerTestManager()
	defer m.Close()

	buf := &bytes.Buffer{}
	conn := &mockConn{Buffer: buf}

	req := models.Request{ID: 1, Method: "tailscale.getStatus"}
	handleGetStatus(conn, req, m)

	var resp models.Response[TailscaleState]
	err := json.NewDecoder(buf).Decode(&resp)
	require.NoError(t, err)
	assert.Equal(t, 1, resp.ID)
	assert.NotNil(t, resp.Result)
	assert.True(t, resp.Result.Connected)
	assert.Equal(t, "cachyos", resp.Result.Self.Hostname)
}

func TestHandleRefresh(t *testing.T) {
	m := handlerTestManager()
	defer m.Close()

	buf := &bytes.Buffer{}
	conn := &mockConn{Buffer: buf}

	req := models.Request{ID: 1, Method: "tailscale.refresh"}
	handleRefresh(conn, req, m)

	var resp models.Response[models.SuccessResult]
	err := json.NewDecoder(buf).Decode(&resp)
	require.NoError(t, err)
	assert.Equal(t, 1, resp.ID)
	assert.NotNil(t, resp.Result)
	assert.True(t, resp.Result.Success)
}

func TestHandleRequest_UnknownMethod(t *testing.T) {
	m := handlerTestManager()
	defer m.Close()

	buf := &bytes.Buffer{}
	conn := &mockConn{Buffer: buf}

	req := models.Request{ID: 1, Method: "tailscale.unknownMethod"}
	HandleRequest(conn, req, m)

	var resp models.Response[any]
	err := json.NewDecoder(buf).Decode(&resp)
	require.NoError(t, err)
	assert.Nil(t, resp.Result)
	assert.NotEmpty(t, resp.Error)
	assert.Contains(t, resp.Error, "unknown method")
}
