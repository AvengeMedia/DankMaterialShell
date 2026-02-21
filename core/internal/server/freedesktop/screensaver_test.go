package freedesktop

import (
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestSetScreenLockActive_ChangesState(t *testing.T) {
	manager := &Manager{
		state: &FreedeskState{
			Screensaver: ScreensaverState{Available: true},
		},
		stateMutex: sync.RWMutex{},
	}

	assert.False(t, manager.GetScreensaverState().Active)

	manager.SetScreenLockActive(true)
	assert.True(t, manager.GetScreensaverState().Active)

	manager.SetScreenLockActive(false)
	assert.False(t, manager.GetScreensaverState().Active)
}

func TestSetScreenLockActive_NoChangeNoDuplicate(t *testing.T) {
	ch := make(chan ScreensaverState, 64)
	manager := &Manager{
		state: &FreedeskState{
			Screensaver: ScreensaverState{Available: true, Active: false},
		},
		stateMutex: sync.RWMutex{},
	}
	manager.screensaverSubscribers.Store("test", ch)
	defer manager.screensaverSubscribers.Delete("test")

	// Setting to same value should not notify
	manager.SetScreenLockActive(false)

	select {
	case <-ch:
		t.Fatal("should not have received notification for no-change")
	case <-time.After(50 * time.Millisecond):
		// Expected: no notification
	}
}

func TestSetScreenLockActive_NotifiesSubscribers(t *testing.T) {
	ch := make(chan ScreensaverState, 64)
	manager := &Manager{
		state: &FreedeskState{
			Screensaver: ScreensaverState{Available: true, Active: false},
		},
		stateMutex: sync.RWMutex{},
	}
	manager.screensaverSubscribers.Store("test", ch)
	defer manager.screensaverSubscribers.Delete("test")

	manager.SetScreenLockActive(true)

	select {
	case state := <-ch:
		assert.True(t, state.Active)
	case <-time.After(time.Second):
		t.Fatal("timeout waiting for subscriber notification")
	}
}

func TestSetScreenLockActive_NilSessionConn(t *testing.T) {
	manager := &Manager{
		state: &FreedeskState{
			Screensaver: ScreensaverState{Available: true},
		},
		stateMutex: sync.RWMutex{},
	}

	assert.NotPanics(t, func() {
		manager.SetScreenLockActive(true)
	})
	assert.True(t, manager.GetScreensaverState().Active)
}

func TestGetActive_ReturnsCurrentState(t *testing.T) {
	manager := &Manager{
		state: &FreedeskState{
			Screensaver: ScreensaverState{Available: true, Active: true},
		},
		stateMutex: sync.RWMutex{},
	}

	handler := &screensaverHandler{manager: manager}
	active, dbusErr := handler.GetActive()
	assert.Nil(t, dbusErr)
	assert.True(t, active)
}

func TestScreensaverState_ActiveDefaultsFalse(t *testing.T) {
	state := ScreensaverState{}
	assert.False(t, state.Active)
}
