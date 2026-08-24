package freedesktop

import (
	"sync"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestManager_GetState(t *testing.T) {
	state := &FreedeskState{
		Accounts: AccountsState{
			Available: true,
			UserName:  "testuser",
			RealName:  "Test User",
			UID:       1000,
		},
		Settings: SettingsState{
			Available:   true,
			ColorScheme: 1,
		},
	}

	manager := &Manager{
		state:      state,
		stateMutex: sync.RWMutex{},
	}

	result := manager.GetState()
	assert.True(t, result.Accounts.Available)
	assert.Equal(t, "testuser", result.Accounts.UserName)
	assert.Equal(t, "Test User", result.Accounts.RealName)
	assert.Equal(t, uint64(1000), result.Accounts.UID)
	assert.True(t, result.Settings.Available)
	assert.Equal(t, uint32(1), result.Settings.ColorScheme)
}

func TestManager_GetState_ThreadSafe(t *testing.T) {
	manager := &Manager{
		state: &FreedeskState{
			Accounts: AccountsState{
				Available: true,
				UserName:  "testuser",
			},
			Settings: SettingsState{
				Available:   true,
				ColorScheme: 1,
			},
		},
		stateMutex: sync.RWMutex{},
	}

	done := make(chan bool)
	for range 10 {
		go func() {
			state := manager.GetState()
			assert.True(t, state.Accounts.Available)
			assert.Equal(t, "testuser", state.Accounts.UserName)
			done <- true
		}()
	}

	for range 10 {
		<-done
	}
}

func TestManager_Close(t *testing.T) {
	manager := &Manager{
		state:       &FreedeskState{},
		stateMutex:  sync.RWMutex{},
		systemConn:  nil,
		sessionConn: nil,
	}

	assert.NotPanics(t, func() {
		manager.Close()
	})
}

func TestNewManager(t *testing.T) {
	t.Run("attempts to create manager", func(t *testing.T) {
		manager, err := NewManager()
		if err != nil {
			assert.Nil(t, manager)
		} else {
			assert.NotNil(t, manager)
			assert.NotNil(t, manager.state)
			assert.NotNil(t, manager.systemConn)

			manager.Close()
		}
	})
}

func TestManager_GetState_EmptyState(t *testing.T) {
	manager := &Manager{
		state:      &FreedeskState{},
		stateMutex: sync.RWMutex{},
	}

	result := manager.GetState()
	assert.False(t, result.Accounts.Available)
	assert.Empty(t, result.Accounts.UserName)
	assert.False(t, result.Settings.Available)
	assert.Equal(t, uint32(0), result.Settings.ColorScheme)
}

func TestManager_AccountsState_Modification(t *testing.T) {
	manager := &Manager{
		state: &FreedeskState{
			Accounts: AccountsState{
				Available: true,
				UserName:  "testuser",
			},
		},
		stateMutex: sync.RWMutex{},
	}

	state := manager.GetState()
	state.Accounts.UserName = "modifieduser"

	original := manager.GetState()
	assert.Equal(t, "testuser", original.Accounts.UserName)
}

func TestManager_SettingsState_Modification(t *testing.T) {
	manager := &Manager{
		state: &FreedeskState{
			Settings: SettingsState{
				Available:   true,
				ColorScheme: 0,
			},
		},
		stateMutex: sync.RWMutex{},
	}

	state := manager.GetState()
	state.Settings.ColorScheme = 1

	original := manager.GetState()
	assert.Equal(t, uint32(0), original.Settings.ColorScheme)
}

func TestManager_SelfEcho_ConsumesRegisteredWrites(t *testing.T) {
	manager := &Manager{state: &FreedeskState{}}

	manager.ExpectColorSchemeEcho("prefer-dark")
	manager.ExpectColorSchemeEcho("default")

	assert.True(t, manager.consumeSelfEcho(1))
	assert.True(t, manager.consumeSelfEcho(0))
	assert.False(t, manager.consumeSelfEcho(1))
	assert.False(t, manager.consumeSelfEcho(0))
}

func TestManager_SelfEcho_ExternalChangePassesThrough(t *testing.T) {
	manager := &Manager{state: &FreedeskState{}}

	manager.ExpectColorSchemeEcho("prefer-dark")

	assert.False(t, manager.consumeSelfEcho(2))
	assert.True(t, manager.consumeSelfEcho(1))
}

func TestManager_SelfEcho_ConsumesOnePerRegistration(t *testing.T) {
	manager := &Manager{state: &FreedeskState{}}

	manager.ExpectColorSchemeEcho("prefer-dark")
	manager.ExpectColorSchemeEcho("prefer-dark")

	assert.True(t, manager.consumeSelfEcho(1))
	assert.True(t, manager.consumeSelfEcho(1))
	assert.False(t, manager.consumeSelfEcho(1))
}

func TestManager_SelfEcho_SchemeMapping(t *testing.T) {
	manager := &Manager{state: &FreedeskState{}}

	manager.ExpectColorSchemeEcho("prefer-light")
	assert.True(t, manager.consumeSelfEcho(2))

	manager.ExpectColorSchemeEcho("default")
	assert.True(t, manager.consumeSelfEcho(0))
}
