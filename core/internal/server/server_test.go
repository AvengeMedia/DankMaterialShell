package server

import (
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"testing"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/network"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestGetSocketDir(t *testing.T) {
	tests := []struct {
		name           string
		xdgRuntimeDir  string
		uid            int
		expectedSubstr string
	}{
		{
			name:           "uses XDG_RUNTIME_DIR when set",
			xdgRuntimeDir:  "/run/user/1000",
			expectedSubstr: "/run/user/1000",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.xdgRuntimeDir != "" {
				t.Setenv("XDG_RUNTIME_DIR", tt.xdgRuntimeDir)
			}

			result := getSocketDir()
			assert.Contains(t, result, tt.expectedSubstr)
		})
	}
}

func TestGetSocketPath(t *testing.T) {
	path := GetSocketPath()
	assert.Contains(t, path, "danklinux-")
	assert.Contains(t, path, ".sock")
	assert.Contains(t, path, fmt.Sprintf("%d", os.Getpid()))
}

func TestGetCapabilities(t *testing.T) {
	originalNetworkManager := networkManager
	defer func() { networkManager = originalNetworkManager }()

	t.Run("capabilities without network manager", func(t *testing.T) {
		networkManager = nil
		caps := getCapabilities()
		assert.Contains(t, caps.Capabilities, "plugins")
		assert.NotContains(t, caps.Capabilities, "network")
	})

	t.Run("capabilities with network manager", func(t *testing.T) {
		networkManager = &network.Manager{}
		caps := getCapabilities()
		assert.Contains(t, caps.Capabilities, "plugins")
		assert.Contains(t, caps.Capabilities, "network")
	})
}

type mockConn struct {
	net.Conn
	written []byte
}

func (m *mockConn) Write(b []byte) (n int, err error) {
	m.written = append(m.written, b...)
	return len(b), nil
}

func (m *mockConn) Close() error {
	return nil
}

func TestRespondError(t *testing.T) {
	conn := &mockConn{}
	models.RespondError(conn, 123, "test error")

	var resp models.Response[any]
	err := json.Unmarshal(conn.written, &resp)
	require.NoError(t, err)

	assert.Equal(t, 123, resp.ID)
	assert.Equal(t, "test error", resp.Error)
	assert.Nil(t, resp.Result)
}

func TestRespond(t *testing.T) {
	conn := &mockConn{}
	result := map[string]string{"foo": "bar"}
	models.Respond(conn, 123, result)

	var resp models.Response[map[string]string]
	err := json.Unmarshal(conn.written, &resp)
	require.NoError(t, err)

	assert.Equal(t, 123, resp.ID)
	assert.Empty(t, resp.Error)
	require.NotNil(t, resp.Result)
	assert.Equal(t, "bar", (*resp.Result)["foo"])
}

func TestRequest_JSON(t *testing.T) {
	jsonStr := `{"id":123,"method":"test.method","params":{"key":"value"}}`
	var req models.Request
	err := json.Unmarshal([]byte(jsonStr), &req)
	require.NoError(t, err)

	assert.Equal(t, 123, req.ID)
	assert.Equal(t, "test.method", req.Method)
	assert.Equal(t, "value", req.Params["key"])
}

func TestResponse_JSON(t *testing.T) {
	t.Run("success response", func(t *testing.T) {
		result := "success"
		resp := models.Response[string]{
			ID:     123,
			Result: &result,
		}

		data, err := json.Marshal(resp)
		require.NoError(t, err)

		var decoded models.Response[string]
		err = json.Unmarshal(data, &decoded)
		require.NoError(t, err)

		assert.Equal(t, 123, decoded.ID)
		assert.Equal(t, "success", *decoded.Result)
		assert.Empty(t, decoded.Error)
	})

	t.Run("error response", func(t *testing.T) {
		resp := models.Response[any]{
			ID:    123,
			Error: "test error",
		}

		data, err := json.Marshal(resp)
		require.NoError(t, err)

		var decoded models.Response[any]
		err = json.Unmarshal(data, &decoded)
		require.NoError(t, err)

		assert.Equal(t, 123, decoded.ID)
		assert.Equal(t, "test error", decoded.Error)
		assert.Nil(t, decoded.Result)
	})
}

func TestCleanupStaleSockets(t *testing.T) {
	tempDir := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", tempDir)

	staleSocket := filepath.Join(tempDir, "danklinux-4194305.sock")
	err := os.WriteFile(staleSocket, []byte{}, 0o600)
	require.NoError(t, err)

	activeSocket := filepath.Join(tempDir, fmt.Sprintf("danklinux-%d.sock", os.Getpid()))
	err = os.WriteFile(activeSocket, []byte{}, 0o600)
	require.NoError(t, err)

	cleanupStaleSockets()

	_, err = os.Stat(staleSocket)
	assert.True(t, os.IsNotExist(err))

	_, err = os.Stat(activeSocket)
	assert.NoError(t, err)
}
