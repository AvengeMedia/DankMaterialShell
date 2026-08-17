package chat

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// The suppression ladder is tested directly rather than through Notify, which
// needs a session bus. Getting this wrong is what turns a first login into
// several hundred notifications, so each rule gets its own case.
func TestSuppressionLadder(t *testing.T) {
	ctx := context.Background()
	store := newStore(t)
	started := time.Now()

	require.NoError(t, store.TouchChat(ctx, prov, "dm", "Ada", "", started.UnixMilli(), false, false))
	require.NoError(t, store.TouchChat(ctx, prov, "group", "Team", "", started.UnixMilli(), true, false))
	require.NoError(t, store.TouchChat(ctx, prov, "muted", "Noisy", "", started.UnixMilli(), false, false))
	require.NoError(t, store.SetMuted(ctx, prov, "muted", true))
	require.NoError(t, store.TouchChat(ctx, prov, "filed", "Away", "", started.UnixMilli(), false, false))
	require.NoError(t, store.SetArchived(ctx, prov, "filed", true))

	// A message that arrived after start, from someone else, in a normal chat.
	fresh := func(chatID string) Message {
		return Message{
			Provider: prov, ChatID: chatID, ID: "m1", Kind: KindText, Text: "hi",
			TS: started.Add(time.Minute).UnixMilli(),
		}
	}

	newPolicy := func() *NotifyPolicy {
		p := NewNotifyPolicy(store, nil)
		p.StartedAt = started
		return p
	}

	// Prefs travel with each call now, so every case states the policy it is
	// exercising instead of mutating shared state.
	defaults := DefaultNotifyPrefs()

	t.Run("notifies for a normal incoming message", func(t *testing.T) {
		assert.Empty(t, newPolicy().suppressionReason(ctx, fresh("dm"), defaults))
	})

	t.Run("disabled", func(t *testing.T) {
		prefs := defaults
		prefs.Enabled = false
		assert.Equal(t, "notifications disabled", newPolicy().suppressionReason(ctx, fresh("dm"), prefs))
	})

	t.Run("do not disturb outranks everything else", func(t *testing.T) {
		prefs := defaults
		prefs.DoNotDisturb = true
		assert.Equal(t, "do not disturb", newPolicy().suppressionReason(ctx, fresh("dm"), prefs))
	})

	t.Run("own message", func(t *testing.T) {
		m := fresh("dm")
		m.FromMe = true
		assert.Equal(t, "own message", newPolicy().suppressionReason(ctx, m, defaults))
	})

	t.Run("protocol kinds", func(t *testing.T) {
		for _, kind := range []string{KindSystem, KindDeleted, KindUnsupported} {
			m := fresh("dm")
			m.Kind = kind
			assert.Equal(t, "protocol message", newPolicy().suppressionReason(ctx, m, defaults), kind)
		}
	})

	t.Run("backfill predating startup", func(t *testing.T) {
		m := fresh("dm")
		m.TS = started.Add(-time.Hour).UnixMilli()
		assert.Equal(t, "backfill", newPolicy().suppressionReason(ctx, m, defaults))
	})

	t.Run("focused chat", func(t *testing.T) {
		p := newPolicy()
		p.SetFocus(prov, "dm")
		assert.Equal(t, "chat focused", p.suppressionReason(ctx, fresh("dm"), defaults))
		assert.Empty(t, p.suppressionReason(ctx, fresh("group"), defaults),
			"focusing one chat does not mute the others")
	})

	t.Run("muted chat", func(t *testing.T) {
		assert.Equal(t, "chat muted", newPolicy().suppressionReason(ctx, fresh("muted"), defaults))
	})

	t.Run("archived chat", func(t *testing.T) {
		assert.Equal(t, "chat archived", newPolicy().suppressionReason(ctx, fresh("filed"), defaults))

		prefs := defaults
		prefs.Archived = true
		assert.Empty(t, newPolicy().suppressionReason(ctx, fresh("filed"), prefs),
			"archived chats notify when the user opts in")
	})

	t.Run("group messages when groups are off", func(t *testing.T) {
		assert.Empty(t, newPolicy().suppressionReason(ctx, fresh("group"), defaults))

		prefs := defaults
		prefs.Groups = false
		assert.Equal(t, "group message", newPolicy().suppressionReason(ctx, fresh("group"), prefs))
		assert.Empty(t, newPolicy().suppressionReason(ctx, fresh("dm"), prefs),
			"turning off groups leaves direct messages alone")
	})
}

// Focus is scoped per provider: the same chat id in two services is two chats.
func TestFocusIsProviderScoped(t *testing.T) {
	ctx := context.Background()
	store := newStore(t)

	p := NewNotifyPolicy(store, nil)
	p.StartedAt = time.Now().Add(-time.Hour)
	p.SetFocus("alpha", "shared")

	provider, chatID := p.Focused()
	assert.Equal(t, "alpha", provider)
	assert.Equal(t, "shared", chatID)

	m := Message{Provider: "beta", ChatID: "shared", ID: "m1", Kind: KindText,
		Text: "hi", TS: time.Now().UnixMilli()}
	assert.Empty(t, p.suppressionReason(ctx, m, DefaultNotifyPrefs()))
}

func TestMessagePreview(t *testing.T) {
	assert.Equal(t, "hello", Message{Kind: KindText, Text: "hello"}.Preview())
	assert.Equal(t, "📷 Photo", Message{Kind: KindImage}.Preview())
	assert.Equal(t, "🎤 Voice message", Message{Kind: KindAudio}.Preview())
	assert.Equal(t, "caption", Message{Kind: KindImage, Text: "caption"}.Preview(),
		"a caption wins over the placeholder")
	assert.Equal(t, "📄 report.pdf", Message{Kind: KindDocument, FileName: "report.pdf"}.Preview(),
		"a named attachment shows its name, not a generic label")
	assert.Empty(t, Message{Kind: KindText}.Preview())
}
