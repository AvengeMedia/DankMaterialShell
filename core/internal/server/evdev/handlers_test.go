package evdev

import (
	"bytes"
	"encoding/json"
	"errors"
	"net"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	mocks "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/evdev"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
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

func TestHandleRequest(t *testing.T) {
	t.Run("getState request", func(t *testing.T) {
		mockDevice := mocks.NewMockEvdevDevice(t)
		mockDevice.EXPECT().ReadOne().Return(nil, errors.New("test")).Maybe()

		m := &Manager{
			device:      mockDevice,
			state:       State{Available: true, CapsLock: true},
			subscribers: make(map[string]chan State),
			closeChan:   make(chan struct{}),
		}

		conn := newMockNetConn()
		req := Request{
			ID:     123,
			Method: "evdev.getState",
			Params: map[string]interface{}{},
		}

		HandleRequest(conn, req, m)

		var resp models.Response[State]
		err := json.NewDecoder(conn.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.NotNil(t, resp.Result)
		assert.True(t, resp.Result.Available)
		assert.True(t, resp.Result.CapsLock)
	})

	t.Run("unknown method", func(t *testing.T) {
		mockDevice := mocks.NewMockEvdevDevice(t)
		mockDevice.EXPECT().ReadOne().Return(nil, errors.New("test")).Maybe()

		m := &Manager{
			device:      mockDevice,
			state:       State{Available: true, CapsLock: false},
			subscribers: make(map[string]chan State),
			closeChan:   make(chan struct{}),
		}

		conn := newMockNetConn()
		req := Request{
			ID:     456,
			Method: "evdev.unknownMethod",
			Params: map[string]interface{}{},
		}

		HandleRequest(conn, req, m)

		var resp models.Response[any]
		err := json.NewDecoder(conn.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 456, resp.ID)
		assert.NotEmpty(t, resp.Error)
		assert.Contains(t, resp.Error, "unknown method")
	})
}

func TestHandleGetState(t *testing.T) {
	mockDevice := mocks.NewMockEvdevDevice(t)
	mockDevice.EXPECT().ReadOne().Return(nil, errors.New("test")).Maybe()

	m := &Manager{
		device:      mockDevice,
		state:       State{Available: true, CapsLock: false},
		subscribers: make(map[string]chan State),
		closeChan:   make(chan struct{}),
	}

	conn := newMockNetConn()
	req := Request{
		ID:     789,
		Method: "evdev.getState",
		Params: map[string]interface{}{},
	}

	handleGetState(conn, req, m)

	var resp models.Response[State]
	err := json.NewDecoder(conn.writeBuf).Decode(&resp)
	require.NoError(t, err)

	assert.Equal(t, 789, resp.ID)
	assert.NotNil(t, resp.Result)
	assert.True(t, resp.Result.Available)
	assert.False(t, resp.Result.CapsLock)
}
