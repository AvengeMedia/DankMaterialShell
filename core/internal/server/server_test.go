package server

import (
	"encoding/json"
	"fmt"
	"net"
	"os"
	"testing"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/network"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

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

func TestCupsCapabilityIsSticky(t *testing.T) {
	originalEverAvailable := cupsEverAvailable
	originalSubscriberCount := cupsSubscriberCount
	defer func() {
		cupsEverAvailable = originalEverAvailable
		cupsSubscriberCount = originalSubscriberCount
	}()

	cupsEverAvailable = false
	assert.NotContains(t, getCapabilities().Capabilities, "cups")

	cupsEverAvailable = true
	cupsSubscriberCount = 1
	assert.Contains(t, getCapabilities().Capabilities, "cups")

	releaseCupsSubscriber()
	assert.Equal(t, 0, cupsSubscriberCount)
	assert.Contains(t, getCapabilities().Capabilities, "cups", "capability must survive the manager shutting down")

	releaseCupsSubscriber()
	assert.Equal(t, 0, cupsSubscriberCount, "release must not drive the subscriber count negative")
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

func (m *mockConn) SetWriteDeadline(t time.Time) error { return nil }

func TestRespondError(t *testing.T) {
	mc := &mockConn{}
	models.RespondError(models.NewConn(mc), 123, "test error")

	var resp models.Response[any]
	err := json.Unmarshal(mc.written, &resp)
	require.NoError(t, err)

	assert.Equal(t, 123, resp.ID)
	assert.Equal(t, "test error", resp.Error)
	assert.Nil(t, resp.Result)
}

func TestRespond(t *testing.T) {
	mc := &mockConn{}
	result := map[string]string{"foo": "bar"}
	models.Respond(models.NewConn(mc), 123, result)

	var resp models.Response[map[string]string]
	err := json.Unmarshal(mc.written, &resp)
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
