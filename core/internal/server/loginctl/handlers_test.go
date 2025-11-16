package loginctl

import (
	"bytes"
	"encoding/json"
	"net"
	"sync"
	"testing"
	"time"

	mockdbus "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/github.com/godbus/dbus/v5"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/godbus/dbus/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
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

func TestRespondError_Loginctl(t *testing.T) {
	conn := newMockNetConn()
	models.RespondError(conn, 123, "test error")

	var resp models.Response[any]
	err := json.NewDecoder(conn.writeBuf).Decode(&resp)
	require.NoError(t, err)

	assert.Equal(t, 123, resp.ID)
	assert.Equal(t, "test error", resp.Error)
	assert.Nil(t, resp.Result)
}

func TestRespond_Loginctl(t *testing.T) {
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
		state: &SessionState{
			SessionID:    "1",
			Locked:       false,
			Active:       true,
			SessionType:  "wayland",
			SessionClass: "user",
			UserName:     "testuser",
		},
		stateMutex: sync.RWMutex{},
	}

	conn := newMockNetConn()
	req := Request{ID: 123, Method: "loginctl.getState"}

	handleGetState(conn, req, manager)

	var resp models.Response[SessionState]
	err := json.NewDecoder(conn.writeBuf).Decode(&resp)
	require.NoError(t, err)

	assert.Equal(t, 123, resp.ID)
	assert.Empty(t, resp.Error)
	require.NotNil(t, resp.Result)
	assert.Equal(t, "1", resp.Result.SessionID)
	assert.False(t, resp.Result.Locked)
	assert.True(t, resp.Result.Active)
}

func TestHandleLock(t *testing.T) {
	t.Run("successful lock", func(t *testing.T) {
		mockSessionObj := mockdbus.NewMockBusObject(t)
		mockCall := &dbus.Call{Err: nil}
		mockSessionObj.EXPECT().Call("org.freedesktop.login1.Session.Lock", dbus.Flags(0)).Return(mockCall)

		manager := &Manager{
			state:      &SessionState{},
			stateMutex: sync.RWMutex{},
			sessionObj: mockSessionObj,
		}

		conn := newMockNetConn()
		req := Request{ID: 123, Method: "loginctl.lock"}
		handleLock(conn, req, manager)

		var resp models.Response[SuccessResult]
		err := json.NewDecoder(conn.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Empty(t, resp.Error)
		require.NotNil(t, resp.Result)
		assert.True(t, resp.Result.Success)
		assert.Equal(t, "locked", resp.Result.Message)
	})

	t.Run("lock fails", func(t *testing.T) {
		mockSessionObj := mockdbus.NewMockBusObject(t)
		mockCall := &dbus.Call{Err: assert.AnError}
		mockSessionObj.EXPECT().Call("org.freedesktop.login1.Session.Lock", dbus.Flags(0)).Return(mockCall)

		manager := &Manager{
			state:      &SessionState{},
			stateMutex: sync.RWMutex{},
			sessionObj: mockSessionObj,
		}

		conn := newMockNetConn()
		req := Request{ID: 123, Method: "loginctl.lock"}
		handleLock(conn, req, manager)

		var resp models.Response[SuccessResult]
		err := json.NewDecoder(conn.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Contains(t, resp.Error, "failed to lock session")
	})
}

func TestHandleUnlock(t *testing.T) {
	t.Run("successful unlock", func(t *testing.T) {
		mockSessionObj := mockdbus.NewMockBusObject(t)
		mockCall := &dbus.Call{Err: nil}
		mockSessionObj.EXPECT().Call("org.freedesktop.login1.Session.Unlock", dbus.Flags(0)).Return(mockCall)

		manager := &Manager{
			state:      &SessionState{},
			stateMutex: sync.RWMutex{},
			sessionObj: mockSessionObj,
		}

		conn := newMockNetConn()
		req := Request{ID: 123, Method: "loginctl.unlock"}
		handleUnlock(conn, req, manager)

		var resp models.Response[SuccessResult]
		err := json.NewDecoder(conn.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Empty(t, resp.Error)
		require.NotNil(t, resp.Result)
		assert.True(t, resp.Result.Success)
		assert.Equal(t, "unlocked", resp.Result.Message)
	})

	t.Run("unlock fails", func(t *testing.T) {
		mockSessionObj := mockdbus.NewMockBusObject(t)
		mockCall := &dbus.Call{Err: assert.AnError}
		mockSessionObj.EXPECT().Call("org.freedesktop.login1.Session.Unlock", dbus.Flags(0)).Return(mockCall)

		manager := &Manager{
			state:      &SessionState{},
			stateMutex: sync.RWMutex{},
			sessionObj: mockSessionObj,
		}

		conn := newMockNetConn()
		req := Request{ID: 123, Method: "loginctl.unlock"}
		handleUnlock(conn, req, manager)

		var resp models.Response[SuccessResult]
		err := json.NewDecoder(conn.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Contains(t, resp.Error, "failed to unlock session")
	})
}

func TestHandleActivate(t *testing.T) {
	t.Run("successful activate", func(t *testing.T) {
		mockSessionObj := mockdbus.NewMockBusObject(t)
		mockCall := &dbus.Call{Err: nil}
		mockSessionObj.EXPECT().Call("org.freedesktop.login1.Session.Activate", dbus.Flags(0)).Return(mockCall)

		manager := &Manager{
			state:      &SessionState{},
			stateMutex: sync.RWMutex{},
			sessionObj: mockSessionObj,
		}

		conn := newMockNetConn()
		req := Request{ID: 123, Method: "loginctl.activate"}
		handleActivate(conn, req, manager)

		var resp models.Response[SuccessResult]
		err := json.NewDecoder(conn.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Empty(t, resp.Error)
		require.NotNil(t, resp.Result)
		assert.True(t, resp.Result.Success)
		assert.Equal(t, "activated", resp.Result.Message)
	})

	t.Run("activate fails", func(t *testing.T) {
		mockSessionObj := mockdbus.NewMockBusObject(t)
		mockCall := &dbus.Call{Err: assert.AnError}
		mockSessionObj.EXPECT().Call("org.freedesktop.login1.Session.Activate", dbus.Flags(0)).Return(mockCall)

		manager := &Manager{
			state:      &SessionState{},
			stateMutex: sync.RWMutex{},
			sessionObj: mockSessionObj,
		}

		conn := newMockNetConn()
		req := Request{ID: 123, Method: "loginctl.activate"}
		handleActivate(conn, req, manager)

		var resp models.Response[SuccessResult]
		err := json.NewDecoder(conn.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Contains(t, resp.Error, "failed to activate session")
	})
}

func TestHandleSetIdleHint(t *testing.T) {
	t.Run("missing idle parameter", func(t *testing.T) {
		manager := &Manager{
			state:      &SessionState{},
			stateMutex: sync.RWMutex{},
		}

		conn := newMockNetConn()
		req := Request{
			ID:     123,
			Method: "loginctl.setIdleHint",
			Params: map[string]interface{}{},
		}

		handleSetIdleHint(conn, req, manager)

		var resp models.Response[any]
		err := json.NewDecoder(conn.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Contains(t, resp.Error, "missing or invalid 'idle' parameter")
	})

	t.Run("successful set idle hint true", func(t *testing.T) {
		mockSessionObj := mockdbus.NewMockBusObject(t)
		mockCall := &dbus.Call{Err: nil}
		mockSessionObj.EXPECT().Call("org.freedesktop.login1.Session.SetIdleHint", dbus.Flags(0), true).Return(mockCall)

		manager := &Manager{
			state:      &SessionState{},
			stateMutex: sync.RWMutex{},
			sessionObj: mockSessionObj,
		}

		conn := newMockNetConn()
		req := Request{
			ID:     123,
			Method: "loginctl.setIdleHint",
			Params: map[string]interface{}{
				"idle": true,
			},
		}

		handleSetIdleHint(conn, req, manager)

		var resp models.Response[SuccessResult]
		err := json.NewDecoder(conn.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Empty(t, resp.Error)
		require.NotNil(t, resp.Result)
		assert.True(t, resp.Result.Success)
		assert.Equal(t, "idle hint set", resp.Result.Message)
	})

	t.Run("set idle hint fails", func(t *testing.T) {
		mockSessionObj := mockdbus.NewMockBusObject(t)
		mockCall := &dbus.Call{Err: assert.AnError}
		mockSessionObj.EXPECT().Call("org.freedesktop.login1.Session.SetIdleHint", dbus.Flags(0), false).Return(mockCall)

		manager := &Manager{
			state:      &SessionState{},
			stateMutex: sync.RWMutex{},
			sessionObj: mockSessionObj,
		}

		conn := newMockNetConn()
		req := Request{
			ID:     123,
			Method: "loginctl.setIdleHint",
			Params: map[string]interface{}{
				"idle": false,
			},
		}

		handleSetIdleHint(conn, req, manager)

		var resp models.Response[SuccessResult]
		err := json.NewDecoder(conn.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Contains(t, resp.Error, "failed to set idle hint")
	})
}

func TestHandleTerminate(t *testing.T) {
	t.Run("successful terminate", func(t *testing.T) {
		mockSessionObj := mockdbus.NewMockBusObject(t)
		mockCall := &dbus.Call{Err: nil}
		mockSessionObj.EXPECT().Call("org.freedesktop.login1.Session.Terminate", dbus.Flags(0)).Return(mockCall)

		manager := &Manager{
			state:      &SessionState{},
			stateMutex: sync.RWMutex{},
			sessionObj: mockSessionObj,
		}

		conn := newMockNetConn()
		req := Request{ID: 123, Method: "loginctl.terminate"}
		handleTerminate(conn, req, manager)

		var resp models.Response[SuccessResult]
		err := json.NewDecoder(conn.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Empty(t, resp.Error)
		require.NotNil(t, resp.Result)
		assert.True(t, resp.Result.Success)
		assert.Equal(t, "terminated", resp.Result.Message)
	})

	t.Run("terminate fails", func(t *testing.T) {
		mockSessionObj := mockdbus.NewMockBusObject(t)
		mockCall := &dbus.Call{Err: assert.AnError}
		mockSessionObj.EXPECT().Call("org.freedesktop.login1.Session.Terminate", dbus.Flags(0)).Return(mockCall)

		manager := &Manager{
			state:      &SessionState{},
			stateMutex: sync.RWMutex{},
			sessionObj: mockSessionObj,
		}

		conn := newMockNetConn()
		req := Request{ID: 123, Method: "loginctl.terminate"}
		handleTerminate(conn, req, manager)

		var resp models.Response[SuccessResult]
		err := json.NewDecoder(conn.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Contains(t, resp.Error, "failed to terminate session")
	})
}

func TestHandleRequest(t *testing.T) {
	manager := &Manager{
		state: &SessionState{
			SessionID: "1",
			Locked:    false,
		},
		stateMutex: sync.RWMutex{},
	}

	t.Run("unknown method", func(t *testing.T) {
		conn := newMockNetConn()
		req := Request{
			ID:     123,
			Method: "loginctl.unknown",
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
			Method: "loginctl.getState",
		}

		HandleRequest(conn, req, manager)

		var resp models.Response[SessionState]
		err := json.NewDecoder(conn.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
		assert.Empty(t, resp.Error)
	})

	t.Run("lock method", func(t *testing.T) {
		mockSessionObj := mockdbus.NewMockBusObject(t)
		mockCall := &dbus.Call{Err: nil}
		mockSessionObj.EXPECT().Call("org.freedesktop.login1.Session.Lock", mock.Anything).Return(mockCall)

		manager.sessionObj = mockSessionObj

		conn := newMockNetConn()
		req := Request{
			ID:     123,
			Method: "loginctl.lock",
		}

		HandleRequest(conn, req, manager)

		var resp models.Response[any]
		err := json.NewDecoder(conn.writeBuf).Decode(&resp)
		require.NoError(t, err)

		assert.Equal(t, 123, resp.ID)
	})
}

func TestHandleSubscribe(t *testing.T) {
	manager := &Manager{
		state: &SessionState{
			SessionID: "1",
			Locked:    false,
		},
		stateMutex: sync.RWMutex{},
	}

	conn := newMockNetConn()
	req := Request{ID: 123, Method: "loginctl.subscribe"}

	done := make(chan bool)
	go func() {
		handleSubscribe(conn, req, manager)
		done <- true
	}()

	time.Sleep(50 * time.Millisecond)

	conn.Close()

	if conn.writeBuf.Len() > 0 {
		var resp models.Response[SessionEvent]
		err := json.NewDecoder(conn.writeBuf).Decode(&resp)
		if err == nil {
			assert.Equal(t, 123, resp.ID)
			require.NotNil(t, resp.Result)
			assert.Equal(t, EventStateChanged, resp.Result.Type)
			assert.Equal(t, "1", resp.Result.Data.SessionID)
		}
	}

	select {
	case <-done:
	case <-time.After(100 * time.Millisecond):
	}
}
