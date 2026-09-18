package network

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestManager_SetConnectionPreference(t *testing.T) {
	t.Run("invalid preference", func(t *testing.T) {
		manager := &Manager{
			state: &NetworkState{
				Preference: PreferenceAuto,
			},
		}

		err := manager.SetConnectionPreference(ConnectionPreference("invalid"))
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "invalid preference")
	})
}

// Note: Full testing of priority operations would require mocking NetworkManager
// D-Bus interfaces. The tests above cover the basic logic and error handling.
// Integration tests would be needed for complete coverage of network connection
// priority updates and reactivation.
