package chat

import (
	"context"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/notify"
)

// NotifyAppName is deliberately distinct from the shell's own "DMS", so a user
// can write a notification rule that mutes chats without muting everything else
// the shell says.
const NotifyAppName = "DMS Chats"

// NotifyPolicy decides which arriving messages are worth interrupting someone
// for. It is the whole reason a bridge never calls notify-send itself: get this
// wrong once and a first login fires several hundred notifications at a user.
type NotifyPolicy struct {
	store *HistoryStore
	media *Media

	// StartedAt is when the host came up. Anything older is backfill.
	StartedAt time.Time

	// Enabled turns chat notifications off entirely.
	Enabled bool
	// Preview shows the message body; off shows only that something arrived.
	Preview bool
	// Groups notifies for group conversations.
	Groups bool
	// Archived notifies for archived conversations.
	Archived bool

	// focused is the chat currently on screen, pushed down by the shell. A
	// message you are already looking at should not also buzz.
	focused focusKey
}

type focusKey struct {
	provider string
	chatID   string
}

// NewNotifyPolicy returns a policy with the conservative defaults: notify, with
// previews, for direct messages only.
func NewNotifyPolicy(store *HistoryStore, media *Media) *NotifyPolicy {
	return &NotifyPolicy{
		store:     store,
		media:     media,
		StartedAt: time.Now(),
		Enabled:   true,
		Preview:   true,
		Groups:    true,
		Archived:  false,
	}
}

// SetFocus records which chat is on screen. An empty chatID means none is.
func (p *NotifyPolicy) SetFocus(provider, chatID string) {
	p.focused = focusKey{provider: provider, chatID: chatID}
}

// Focused reports the chat currently on screen.
func (p *NotifyPolicy) Focused() (provider, chatID string) {
	return p.focused.provider, p.focused.chatID
}

// suppressionReason returns why a message should not notify, or "" to notify.
//
// The order matters: the cheap, certain checks come before anything that hits
// the database.
func (p *NotifyPolicy) suppressionReason(ctx context.Context, m Message, providerName string) string {
	if !p.Enabled {
		return "notifications disabled"
	}

	// Your own messages, including ones echoed back from another device.
	if m.FromMe {
		return "own message"
	}

	// Bookkeeping rows are not something a person said.
	if isProtocolKind(m.Kind) {
		return "protocol message"
	}

	// Backfill. History sync delivers messages that predate the host starting;
	// without this, a first login notifies for the user's entire history.
	if m.TS > 0 && !time.UnixMilli(m.TS).After(p.StartedAt) {
		return "backfill"
	}

	// The conversation is already on screen.
	if p.focused.provider == m.Provider && p.focused.chatID == m.ChatID {
		return "chat focused"
	}

	if p.store != nil {
		if p.store.IsMuted(ctx, m.Provider, m.ChatID) {
			return "chat muted"
		}
		// Archiving is how a user says "keep this out of my way".
		if !p.Archived && p.store.IsArchived(ctx, m.Provider, m.ChatID) {
			return "chat archived"
		}
	}

	if !p.Groups && p.isGroup(ctx, m) {
		return "group message"
	}

	return ""
}

func (p *NotifyPolicy) isGroup(ctx context.Context, m Message) bool {
	if p.store == nil {
		return false
	}
	c, err := p.store.ChatByID(ctx, m.Provider, m.ChatID)
	return err == nil && c.IsGroup
}

// Notify raises a desktop notification for an arriving message unless policy
// suppresses it. Reports whether a notification was actually shown.
func (p *NotifyPolicy) Notify(ctx context.Context, m Message, providerName string) bool {
	if reason := p.suppressionReason(ctx, m, providerName); reason != "" {
		log.Debugf("chat: suppressed notification for %s/%s: %s", m.Provider, m.ChatID, reason)
		return false
	}

	title := p.titleFor(ctx, m, providerName)

	body := "New message"
	if p.Preview {
		if preview := m.Preview(); preview != "" {
			body = preview
			// In a group, who spoke matters as much as what they said.
			if m.SenderName != "" && p.isGroup(ctx, m) {
				body = m.SenderName + ": " + body
			}
		}
	}

	n := notify.Notification{
		AppName: NotifyAppName,
		Icon:    "material:chat",
		Summary: title,
		Body:    body,
	}

	// An image attachment shows as the notification's own preview. Only for
	// already-cached files -- notifying must never trigger a download.
	if p.Preview && m.Kind == KindImage && m.MediaPath != "" {
		n.FilePath = m.MediaPath
	}

	if err := notify.Send(n); err != nil {
		log.Warnf("chat: notification failed: %v", err)
		return false
	}
	return true
}

// titleFor names the conversation, falling back through sender then provider so
// a notification is never headed by a raw identifier.
func (p *NotifyPolicy) titleFor(ctx context.Context, m Message, providerName string) string {
	if p.store != nil {
		if c, err := p.store.ChatByID(ctx, m.Provider, m.ChatID); err == nil && c.Name != "" {
			return c.Name
		}
	}
	if m.SenderName != "" {
		return m.SenderName
	}
	if providerName != "" {
		return providerName
	}
	return "Message"
}
