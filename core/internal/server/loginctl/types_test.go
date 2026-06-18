package loginctl

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestEventType_Constants(t *testing.T) {
	assert.Equal(t, EventType("state_changed"), EventStateChanged)
}

func TestSessionState_Struct(t *testing.T) {
	state := SessionState{
		SessionID:   "1",
		Locked:      false,
		Active:      true,
		SessionType: "wayland",
		User:        1000,
		UserName:    "testuser",
	}

	assert.Equal(t, "1", state.SessionID)
	assert.True(t, state.Active)
	assert.False(t, state.Locked)
	assert.Equal(t, "wayland", state.SessionType)
	assert.Equal(t, uint32(1000), state.User)
	assert.Equal(t, "testuser", state.UserName)
}

func TestSessionEvent_Struct(t *testing.T) {
	state := SessionState{
		SessionID: "1",
		Locked:    true,
	}

	event := SessionEvent{
		Type: EventStateChanged,
		Data: state,
	}

	assert.Equal(t, EventStateChanged, event.Type)
	assert.Equal(t, "1", event.Data.SessionID)
	assert.True(t, event.Data.Locked)
}
