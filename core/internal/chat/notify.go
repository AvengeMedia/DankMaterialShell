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

// NotifyPrefs is the effective notification policy for one provider.
//
// Held per provider rather than globally because the right answer differs: a
// work account may want silence while a family one does not, and a single
// global setting lets the noisiest provider decide for all of them.
type NotifyPrefs struct {
	// Enabled turns notifications off for this provider entirely.
	Enabled bool `json:"enabled"`
	// Preview shows the message body; off shows only that something arrived.
	Preview bool `json:"preview"`
	// Groups notifies for group conversations.
	Groups bool `json:"groups"`
	// Archived notifies for conversations the user has put away.
	Archived bool `json:"archived"`
	// DoNotDisturb silences the provider without discarding the settings above,
	// so turning it back off restores what the user had chosen.
	DoNotDisturb bool `json:"doNotDisturb"`
	// MutedTags silences whole categories a provider defines -- a service's
	// statuses or channels, a mail account's labels -- without silencing the
	// provider itself. Which tags exist is up to the provider, so this is a
	// list rather than a fixed set of flags.
	MutedTags []string `json:"mutedTags,omitempty"`
}

// DefaultNotifyPrefs is the conservative starting point: notify with previews
// for direct and group messages, but stay quiet for archived conversations.
func DefaultNotifyPrefs() NotifyPrefs {
	return NotifyPrefs{Enabled: true, Preview: true, Groups: true, Archived: false}
}

// NotifyPolicy decides which arriving messages are worth interrupting someone
// for. It is the whole reason a bridge never calls notify-send itself: get this
// wrong once and a first login fires several hundred notifications at a user.
type NotifyPolicy struct {
	store *HistoryStore
	media *Media

	// StartedAt is when the host came up. Anything older is backfill.
	StartedAt time.Time

	// focused is the chat currently on screen, pushed down by the shell. A
	// message you are already looking at should not also buzz.
	focused focusKey
}

type focusKey struct {
	provider string
	chatID   string
}

// NewNotifyPolicy returns a policy anchored at the current time, so anything
// older than this instant counts as backfill.
func NewNotifyPolicy(store *HistoryStore, media *Media) *NotifyPolicy {
	return &NotifyPolicy{
		store:     store,
		media:     media,
		StartedAt: time.Now(),
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
func (p *NotifyPolicy) suppressionReason(ctx context.Context, m Message, prefs NotifyPrefs) string {
	if prefs.DoNotDisturb {
		return "do not disturb"
	}
	if !prefs.Enabled {
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
		if !prefs.Archived && p.store.IsArchived(ctx, m.Provider, m.ChatID) {
			return "chat archived"
		}
	}

	if !prefs.Groups && p.isGroup(ctx, m) {
		return "group message"
	}

	if tag := p.mutedTag(ctx, m, prefs); tag != "" {
		return "muted tag: " + tag
	}

	return ""
}

// mutedTag returns the tag that silences this message, or "".
func (p *NotifyPolicy) mutedTag(ctx context.Context, m Message, prefs NotifyPrefs) string {
	if len(prefs.MutedTags) == 0 || p.store == nil {
		return ""
	}

	c, err := p.store.ChatByID(ctx, m.Provider, m.ChatID)
	if err != nil {
		return ""
	}

	for _, tag := range c.Tags {
		for _, muted := range prefs.MutedTags {
			if tag == muted {
				return tag
			}
		}
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
func (p *NotifyPolicy) Notify(ctx context.Context, m Message, providerName string, prefs NotifyPrefs) bool {
	if reason := p.suppressionReason(ctx, m, prefs); reason != "" {
		log.Debugf("chat: suppressed notification for %s/%s: %s", m.Provider, m.ChatID, reason)
		return false
	}

	title := p.titleFor(ctx, m, providerName)

	body := "New message"
	if prefs.Preview {
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
	if prefs.Preview && m.Kind == KindImage && m.MediaPath != "" {
		n.FilePath = m.MediaPath
	}

	// Send returns the notification id, which chat has no use for: these are
	// fire-and-forget and never replaced or recalled.
	if _, err := notify.Send(n); err != nil {
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
