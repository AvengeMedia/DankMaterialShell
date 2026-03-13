package tailscale

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"testing"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
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

func TestHandleGetStatus(t *testing.T) {
	server, transport := newTestServerTransport(sampleLocalAPIResponse)
	defer server.Close()

	m := newTestManager(transport)
	defer m.Close()

	err := m.poll()
	require.NoError(t, err)

	buf := &bytes.Buffer{}
	conn := &mockConn{Buffer: buf}

	req := models.Request{
		ID:     1,
		Method: "tailscale.getStatus",
	}

	handleGetStatus(conn, req, m)

	var resp models.Response[TailscaleState]
	err = json.NewDecoder(buf).Decode(&resp)
	require.NoError(t, err)
	assert.Equal(t, 1, resp.ID)
	assert.NotNil(t, resp.Result)
	assert.True(t, resp.Result.Connected)
	assert.Equal(t, "cachyos", resp.Result.Self.Hostname)
	assert.Len(t, resp.Result.Peers, 2)
}

func TestHandleRefresh(t *testing.T) {
	server, transport := newTestServerTransport(sampleLocalAPIResponse)
	defer server.Close()

	m := newTestManager(transport)
	defer m.Close()

	buf := &bytes.Buffer{}
	conn := &mockConn{Buffer: buf}

	req := models.Request{
		ID:     1,
		Method: "tailscale.refresh",
	}

	handleRefresh(conn, req, m)

	var resp models.Response[models.SuccessResult]
	err := json.NewDecoder(buf).Decode(&resp)
	require.NoError(t, err)
	assert.Equal(t, 1, resp.ID)
	assert.NotNil(t, resp.Result)
	assert.True(t, resp.Result.Success)
	assert.Equal(t, "refreshed", resp.Result.Message)
}

func TestHandleRequest_UnknownMethod(t *testing.T) {
	failTransport := roundTripFunc(func(req *http.Request) (*http.Response, error) {
		return nil, fmt.Errorf("not used")
	})

	m := newTestManager(failTransport)
	defer m.Close()

	buf := &bytes.Buffer{}
	conn := &mockConn{Buffer: buf}

	req := models.Request{
		ID:     1,
		Method: "tailscale.unknownMethod",
	}

	HandleRequest(conn, req, m)

	var resp models.Response[any]
	err := json.NewDecoder(buf).Decode(&resp)
	require.NoError(t, err)
	assert.Nil(t, resp.Result)
	assert.NotEmpty(t, resp.Error)
	assert.Contains(t, resp.Error, "unknown method")
}
