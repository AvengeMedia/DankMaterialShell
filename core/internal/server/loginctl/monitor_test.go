package loginctl

import (
	"os"
	"sync"
	"testing"
	"time"

	"github.com/godbus/dbus/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestManager_HandleDBusSignal_Lock(t *testing.T) {
	manager := &Manager{
		state: &SessionState{
			Locked:     false,
			LockedHint: false,
		},
		stateMutex: sync.RWMutex{},
		dirty:      make(chan struct{}, 1),
	}

	sig := &dbus.Signal{
		Name: "org.freedesktop.login1.Session.Lock",
	}

	manager.handleDBusSignal(sig)

	manager.stateMutex.RLock()
	defer manager.stateMutex.RUnlock()
	assert.True(t, manager.state.Locked)
	assert.True(t, manager.state.LockedHint)
}

func TestManager_HandleDBusSignal_Unlock(t *testing.T) {
	manager := &Manager{
		state: &SessionState{
			Locked:     true,
			LockedHint: true,
		},
		stateMutex: sync.RWMutex{},
		dirty:      make(chan struct{}, 1),
	}

	sig := &dbus.Signal{
		Name: "org.freedesktop.login1.Session.Unlock",
	}

	manager.handleDBusSignal(sig)

	manager.stateMutex.RLock()
	defer manager.stateMutex.RUnlock()
	assert.False(t, manager.state.Locked)
	assert.False(t, manager.state.LockedHint)
}

func TestManager_HandleDBusSignal_PrepareForSleep(t *testing.T) {
	t.Run("preparing for sleep - true", func(t *testing.T) {
		manager := &Manager{
			state: &SessionState{
				PreparingForSleep: false,
			},
			stateMutex: sync.RWMutex{},
			dirty:      make(chan struct{}, 1),
		}

		sig := &dbus.Signal{
			Name: "org.freedesktop.login1.Manager.PrepareForSleep",
			Body: []any{true},
		}

		manager.handleDBusSignal(sig)

		manager.stateMutex.RLock()
		defer manager.stateMutex.RUnlock()
		assert.True(t, manager.state.PreparingForSleep)
	})

	t.Run("preparing for sleep - false", func(t *testing.T) {
		manager := &Manager{
			state: &SessionState{
				PreparingForSleep: true,
			},
			stateMutex: sync.RWMutex{},
			dirty:      make(chan struct{}, 1),
		}

		sig := &dbus.Signal{
			Name: "org.freedesktop.login1.Manager.PrepareForSleep",
			Body: []any{false},
		}

		manager.handleDBusSignal(sig)

		manager.stateMutex.RLock()
		defer manager.stateMutex.RUnlock()
		assert.False(t, manager.state.PreparingForSleep)
	})

	t.Run("empty body", func(t *testing.T) {
		manager := &Manager{
			state: &SessionState{
				PreparingForSleep: false,
			},
			stateMutex: sync.RWMutex{},
			dirty:      make(chan struct{}, 1),
		}

		sig := &dbus.Signal{
			Name: "org.freedesktop.login1.Manager.PrepareForSleep",
			Body: []any{},
		}

		manager.handleDBusSignal(sig)

		manager.stateMutex.RLock()
		defer manager.stateMutex.RUnlock()
		assert.False(t, manager.state.PreparingForSleep)
	})
}

func TestManager_PrepareForSleep_ReleasesWhenAlreadyLocked(t *testing.T) {
	f, err := os.CreateTemp(t.TempDir(), "inhibit")
	require.NoError(t, err)

	manager := &Manager{
		state: &SessionState{
			Locked: true,
		},
		stateMutex:  sync.RWMutex{},
		dirty:       make(chan struct{}, 1),
		inhibitFile: f,
	}
	manager.lockBeforeSuspend.Store(true)

	manager.handleDBusSignal(&dbus.Signal{
		Name: "org.freedesktop.login1.Manager.PrepareForSleep",
		Body: []any{true},
	})

	manager.stateMutex.RLock()
	assert.True(t, manager.state.PreparingForSleep)
	manager.stateMutex.RUnlock()
	assert.True(t, manager.inSleepCycle.Load())
	assert.Nil(t, manager.inhibitFile)
}

func TestManager_PrepareForSleep_ReleasesWhenPrelockedReady(t *testing.T) {
	f, err := os.CreateTemp(t.TempDir(), "inhibit")
	require.NoError(t, err)

	manager := &Manager{
		state:       &SessionState{},
		stateMutex:  sync.RWMutex{},
		dirty:       make(chan struct{}, 1),
		inhibitFile: f,
	}
	manager.lockBeforeSuspend.Store(true)
	manager.prelockedReady.Store(true)

	manager.handleDBusSignal(&dbus.Signal{
		Name: "org.freedesktop.login1.Manager.PrepareForSleep",
		Body: []any{true},
	})

	assert.Nil(t, manager.inhibitFile)
	assert.False(t, manager.prelockedReady.Load())
}

func TestManager_PrepareForSleep_KeepsInhibitorUntilLockerReady(t *testing.T) {
	f, err := os.CreateTemp(t.TempDir(), "inhibit")
	require.NoError(t, err)

	manager := &Manager{
		state:         &SessionState{},
		stateMutex:    sync.RWMutex{},
		dirty:         make(chan struct{}, 1),
		inhibitFile:   f,
		fallbackDelay: time.Hour,
	}
	manager.lockBeforeSuspend.Store(true)

	manager.handleDBusSignal(&dbus.Signal{
		Name: "org.freedesktop.login1.Manager.PrepareForSleep",
		Body: []any{true},
	})

	assert.Same(t, f, manager.inhibitFile)
	assert.True(t, manager.inSleepCycle.Load())

	manager.signalLockerReady()

	require.Eventually(t, func() bool {
		manager.inhibitMu.Lock()
		defer manager.inhibitMu.Unlock()
		return manager.inhibitFile == nil
	}, time.Second, 5*time.Millisecond)
}

func TestManager_MarkLockerReady_ClearedOnUnlock(t *testing.T) {
	manager := &Manager{
		state: &SessionState{
			Locked:     true,
			LockedHint: true,
		},
		stateMutex: sync.RWMutex{},
		dirty:      make(chan struct{}, 1),
	}
	manager.markLockerReady()
	assert.True(t, manager.prelockedReady.Load())

	manager.handleDBusSignal(&dbus.Signal{
		Name: "org.freedesktop.login1.Session.Unlock",
	})

	assert.False(t, manager.prelockedReady.Load())
	assert.False(t, manager.state.Locked)
}

func TestManager_HandlePropertiesChanged(t *testing.T) {
	t.Run("active property changed", func(t *testing.T) {
		manager := &Manager{
			state: &SessionState{
				Active: false,
			},
			stateMutex: sync.RWMutex{},
			dirty:      make(chan struct{}, 1),
		}

		sig := &dbus.Signal{
			Name: "org.freedesktop.DBus.Properties.PropertiesChanged",
			Body: []any{
				"org.freedesktop.login1.Session",
				map[string]dbus.Variant{
					"Active": dbus.MakeVariant(true),
				},
			},
		}

		manager.handlePropertiesChanged(sig)

		manager.stateMutex.RLock()
		defer manager.stateMutex.RUnlock()
		assert.True(t, manager.state.Active)
	})

	t.Run("idle hint property changed", func(t *testing.T) {
		manager := &Manager{
			state: &SessionState{
				IdleHint: false,
			},
			stateMutex: sync.RWMutex{},
			dirty:      make(chan struct{}, 1),
		}

		sig := &dbus.Signal{
			Name: "org.freedesktop.DBus.Properties.PropertiesChanged",
			Body: []any{
				"org.freedesktop.login1.Session",
				map[string]dbus.Variant{
					"IdleHint": dbus.MakeVariant(true),
				},
			},
		}

		manager.handlePropertiesChanged(sig)

		manager.stateMutex.RLock()
		defer manager.stateMutex.RUnlock()
		assert.True(t, manager.state.IdleHint)
	})

	t.Run("idle since hint property changed", func(t *testing.T) {
		manager := &Manager{
			state: &SessionState{
				IdleSinceHint: 0,
			},
			stateMutex: sync.RWMutex{},
			dirty:      make(chan struct{}, 1),
		}

		sig := &dbus.Signal{
			Name: "org.freedesktop.DBus.Properties.PropertiesChanged",
			Body: []any{
				"org.freedesktop.login1.Session",
				map[string]dbus.Variant{
					"IdleSinceHint": dbus.MakeVariant(uint64(123456789)),
				},
			},
		}

		manager.handlePropertiesChanged(sig)

		manager.stateMutex.RLock()
		defer manager.stateMutex.RUnlock()
		assert.Equal(t, uint64(123456789), manager.state.IdleSinceHint)
	})

	t.Run("locked hint property changed", func(t *testing.T) {
		manager := &Manager{
			state: &SessionState{
				LockedHint: false,
				Locked:     false,
			},
			stateMutex: sync.RWMutex{},
			dirty:      make(chan struct{}, 1),
		}

		sig := &dbus.Signal{
			Name: "org.freedesktop.DBus.Properties.PropertiesChanged",
			Body: []any{
				"org.freedesktop.login1.Session",
				map[string]dbus.Variant{
					"LockedHint": dbus.MakeVariant(true),
				},
			},
		}

		manager.handlePropertiesChanged(sig)

		manager.stateMutex.RLock()
		defer manager.stateMutex.RUnlock()
		assert.True(t, manager.state.LockedHint)
		assert.True(t, manager.state.Locked)
	})

	t.Run("wrong interface", func(t *testing.T) {
		manager := &Manager{
			state: &SessionState{
				Active: false,
			},
			stateMutex: sync.RWMutex{},
			dirty:      make(chan struct{}, 1),
		}

		sig := &dbus.Signal{
			Name: "org.freedesktop.DBus.Properties.PropertiesChanged",
			Body: []any{
				"org.freedesktop.SomeOtherInterface",
				map[string]dbus.Variant{
					"Active": dbus.MakeVariant(true),
				},
			},
		}

		manager.handlePropertiesChanged(sig)

		manager.stateMutex.RLock()
		defer manager.stateMutex.RUnlock()
		assert.False(t, manager.state.Active)
	})

	t.Run("empty body", func(t *testing.T) {
		manager := &Manager{
			state:      &SessionState{},
			stateMutex: sync.RWMutex{},
			dirty:      make(chan struct{}, 1),
		}

		sig := &dbus.Signal{
			Name: "org.freedesktop.DBus.Properties.PropertiesChanged",
			Body: []any{},
		}

		assert.NotPanics(t, func() {
			manager.handlePropertiesChanged(sig)
		})
	})

	t.Run("multiple properties changed", func(t *testing.T) {
		manager := &Manager{
			state: &SessionState{
				Active:   false,
				IdleHint: false,
			},
			stateMutex: sync.RWMutex{},
			dirty:      make(chan struct{}, 1),
		}

		sig := &dbus.Signal{
			Name: "org.freedesktop.DBus.Properties.PropertiesChanged",
			Body: []any{
				"org.freedesktop.login1.Session",
				map[string]dbus.Variant{
					"Active":   dbus.MakeVariant(true),
					"IdleHint": dbus.MakeVariant(true),
				},
			},
		}

		manager.handlePropertiesChanged(sig)

		manager.stateMutex.RLock()
		defer manager.stateMutex.RUnlock()
		assert.True(t, manager.state.Active)
		assert.True(t, manager.state.IdleHint)
	})
}
