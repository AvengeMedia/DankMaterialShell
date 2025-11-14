package evdev

import (
	"errors"
	"testing"

	evdev "github.com/holoplot/go-evdev"
	"github.com/stretchr/testify/assert"

	mocks "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/evdev"
)

func TestManager_Creation(t *testing.T) {
	t.Run("manager created successfully with caps lock off", func(t *testing.T) {
		mockDevice := mocks.NewMockEvdevDevice(t)
		mockDevice.EXPECT().ReadOne().Return(nil, errors.New("test")).Maybe()

		m := &Manager{
			device:      mockDevice,
			state:       State{Available: true, CapsLock: false},
			subscribers: make(map[string]chan State),
			closeChan:   make(chan struct{}),
		}

		assert.NotNil(t, m)
		assert.True(t, m.state.Available)
		assert.False(t, m.state.CapsLock)
	})

	t.Run("manager created successfully with caps lock on", func(t *testing.T) {
		mockDevice := mocks.NewMockEvdevDevice(t)
		mockDevice.EXPECT().ReadOne().Return(nil, errors.New("test")).Maybe()

		m := &Manager{
			device:      mockDevice,
			state:       State{Available: true, CapsLock: true},
			subscribers: make(map[string]chan State),
			closeChan:   make(chan struct{}),
		}

		assert.NotNil(t, m)
		assert.True(t, m.state.Available)
		assert.True(t, m.state.CapsLock)
	})
}

func TestManager_GetState(t *testing.T) {
	mockDevice := mocks.NewMockEvdevDevice(t)
	mockDevice.EXPECT().ReadOne().Return(nil, errors.New("test")).Maybe()

	m := &Manager{
		device:      mockDevice,
		state:       State{Available: true, CapsLock: false},
		subscribers: make(map[string]chan State),
		closeChan:   make(chan struct{}),
	}

	state := m.GetState()
	assert.True(t, state.Available)
	assert.False(t, state.CapsLock)
}

func TestManager_Subscribe(t *testing.T) {
	mockDevice := mocks.NewMockEvdevDevice(t)
	mockDevice.EXPECT().ReadOne().Return(nil, errors.New("test")).Maybe()

	m := &Manager{
		device:      mockDevice,
		state:       State{Available: true, CapsLock: false},
		subscribers: make(map[string]chan State),
		closeChan:   make(chan struct{}),
	}

	ch := m.Subscribe("test-client")
	assert.NotNil(t, ch)
	assert.Len(t, m.subscribers, 1)
}

func TestManager_Unsubscribe(t *testing.T) {
	mockDevice := mocks.NewMockEvdevDevice(t)
	mockDevice.EXPECT().ReadOne().Return(nil, errors.New("test")).Maybe()

	m := &Manager{
		device:      mockDevice,
		state:       State{Available: true, CapsLock: false},
		subscribers: make(map[string]chan State),
		closeChan:   make(chan struct{}),
	}

	ch := m.Subscribe("test-client")
	assert.Len(t, m.subscribers, 1)

	m.Unsubscribe("test-client")
	assert.Len(t, m.subscribers, 0)

	select {
	case _, ok := <-ch:
		assert.False(t, ok, "channel should be closed")
	default:
		t.Error("channel should be closed")
	}
}

func TestManager_ToggleCapsLock(t *testing.T) {
	mockDevice := mocks.NewMockEvdevDevice(t)
	mockDevice.EXPECT().ReadOne().Return(nil, errors.New("test")).Maybe()

	m := &Manager{
		device:      mockDevice,
		state:       State{Available: true, CapsLock: false},
		subscribers: make(map[string]chan State),
		closeChan:   make(chan struct{}),
	}

	ch := m.Subscribe("test-client")

	go func() {
		m.toggleCapsLock()
	}()

	newState := <-ch
	assert.True(t, newState.CapsLock)

	go func() {
		m.toggleCapsLock()
	}()

	newState = <-ch
	assert.False(t, newState.CapsLock)
}

func TestManager_Close(t *testing.T) {
	mockDevice := mocks.NewMockEvdevDevice(t)
	mockDevice.EXPECT().Close().Return(nil).Once()
	mockDevice.EXPECT().ReadOne().Return(nil, errors.New("test")).Maybe()

	m := &Manager{
		device:      mockDevice,
		state:       State{Available: true, CapsLock: false},
		subscribers: make(map[string]chan State),
		closeChan:   make(chan struct{}),
	}

	ch1 := m.Subscribe("client1")
	ch2 := m.Subscribe("client2")

	m.Close()

	select {
	case _, ok := <-ch1:
		assert.False(t, ok, "channel 1 should be closed")
	default:
		t.Error("channel 1 should be closed")
	}

	select {
	case _, ok := <-ch2:
		assert.False(t, ok, "channel 2 should be closed")
	default:
		t.Error("channel 2 should be closed")
	}

	assert.Len(t, m.subscribers, 0)

	m.Close()
}

func TestIsKeyboard(t *testing.T) {
	tests := []struct {
		name     string
		devName  string
		expected bool
	}{
		{"keyboard in name", "AT Translated Set 2 keyboard", true},
		{"kbd in name", "USB kbd", true},
		{"input and key", "input key device", true},
		{"random device", "Mouse", false},
		{"empty name", "", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockDevice := mocks.NewMockEvdevDevice(t)
			mockDevice.EXPECT().Name().Return(tt.devName, nil).Once()

			result := isKeyboard(mockDevice)
			assert.Equal(t, tt.expected, result)
		})
	}
}

func TestIsKeyboard_ErrorHandling(t *testing.T) {
	mockDevice := mocks.NewMockEvdevDevice(t)
	mockDevice.EXPECT().Name().Return("", errors.New("device error")).Once()

	result := isKeyboard(mockDevice)
	assert.False(t, result)
}

func TestManager_MonitorCapsLock(t *testing.T) {
	t.Run("caps lock key press toggles state", func(t *testing.T) {
		mockDevice := mocks.NewMockEvdevDevice(t)

		capsLockEvent := &evdev.InputEvent{
			Type:  evKeyType,
			Code:  keyCapslockKey,
			Value: keyStateOn,
		}

		mockDevice.EXPECT().ReadOne().Return(capsLockEvent, nil).Once()
		mockDevice.EXPECT().ReadOne().Return(nil, errors.New("stop")).Maybe()
		mockDevice.EXPECT().Close().Return(nil).Maybe()

		m := &Manager{
			device:      mockDevice,
			state:       State{Available: true, CapsLock: false},
			subscribers: make(map[string]chan State),
			closeChan:   make(chan struct{}),
		}

		ch := m.Subscribe("test")

		go m.monitorCapsLock()

		state := <-ch
		assert.True(t, state.CapsLock)

		m.Close()
	})
}

func TestIsClosedError(t *testing.T) {
	tests := []struct {
		name     string
		err      error
		expected bool
	}{
		{"nil error", nil, false},
		{"closed error", errors.New("device closed"), true},
		{"bad file descriptor", errors.New("bad file descriptor"), true},
		{"other error", errors.New("some other error"), false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := isClosedError(tt.err)
			assert.Equal(t, tt.expected, result)
		})
	}
}

func TestNotifySubscribers(t *testing.T) {
	mockDevice := mocks.NewMockEvdevDevice(t)
	mockDevice.EXPECT().ReadOne().Return(nil, errors.New("test")).Maybe()
	mockDevice.EXPECT().Close().Return(nil).Maybe()

	m := &Manager{
		device:      mockDevice,
		state:       State{Available: true, CapsLock: false},
		subscribers: make(map[string]chan State),
		closeChan:   make(chan struct{}),
	}

	ch1 := m.Subscribe("client1")
	ch2 := m.Subscribe("client2")

	newState := State{Available: true, CapsLock: true}
	go m.notifySubscribers(newState)

	state1 := <-ch1
	state2 := <-ch2

	assert.Equal(t, newState, state1)
	assert.Equal(t, newState, state2)

	m.Close()
}

func TestReadInitialCapsLockState(t *testing.T) {
	t.Run("caps lock is on", func(t *testing.T) {
		mockDevice := mocks.NewMockEvdevDevice(t)
		ledState := evdev.StateMap{
			ledCapslockKey: true,
		}
		mockDevice.EXPECT().State(evdev.EvType(evLedType)).Return(ledState, nil).Once()

		result := readInitialCapsLockState(mockDevice)
		assert.True(t, result)
	})

	t.Run("caps lock is off", func(t *testing.T) {
		mockDevice := mocks.NewMockEvdevDevice(t)
		ledState := evdev.StateMap{
			ledCapslockKey: false,
		}
		mockDevice.EXPECT().State(evdev.EvType(evLedType)).Return(ledState, nil).Once()

		result := readInitialCapsLockState(mockDevice)
		assert.False(t, result)
	})

	t.Run("error reading LED state", func(t *testing.T) {
		mockDevice := mocks.NewMockEvdevDevice(t)
		mockDevice.EXPECT().State(evdev.EvType(evLedType)).Return(nil, errors.New("read error")).Once()

		result := readInitialCapsLockState(mockDevice)
		assert.False(t, result)
	})
}

func TestHasInputGroupAccess(t *testing.T) {
	result := hasInputGroupAccess()
	t.Logf("hasInputGroupAccess: %v", result)
}
