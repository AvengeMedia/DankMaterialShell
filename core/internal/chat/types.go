// Package chat is the provider-neutral half of the chat system: the message
// store, the media cache and the notification policy.
//
// Nothing here knows what WhatsApp or IMAP is. Providers live in out-of-process
// bridges that speak newline-delimited JSON (see docs/CHAT-PLUGINS.md); this
// package is what their events get written into. Keeping it protocol-free is
// what lets a bridge author write a few hundred lines instead of reimplementing
// pagination, dedup and media caching for every new service.
package chat

import "strings"

// Message kinds. The first eight are content; the last three are protocol
// noise that a conversation can accumulate.
const (
	KindText        = "text"
	KindImage       = "image"
	KindVideo       = "video"
	KindAudio       = "audio"
	KindDocument    = "document"
	KindSticker     = "sticker"
	KindLocation    = "location"
	KindContact     = "contact"
	KindSystem      = "system"
	KindDeleted     = "deleted"
	KindUnsupported = "unsupported"
)

// Delivery statuses, in ratchet order. A message never moves backwards through
// this list -- see statusRank and the upsert in store.go.
const (
	StatusPending   = "pending"
	StatusSent      = "sent"
	StatusDelivered = "delivered"
	StatusRead      = "read"
	StatusFailed    = "failed"
)

// Connection states a bridge reports.
const (
	StateConnecting   = "connecting"
	StateConnected    = "connected"
	StateDisconnected = "disconnected"
	StateNeedsLogin   = "needsLogin"
)

// isProtocolKind reports whether a kind is bookkeeping rather than something a
// person wrote.
//
// This matters more than it looks. History sync on several services flags
// protocol rows as being from you, so counting them as participation would drag
// every noisy announcement channel into "conversations you take part in". It is
// also why these kinds never raise a notification.
func isProtocolKind(kind string) bool {
	switch kind {
	case KindSystem, KindDeleted, KindUnsupported:
		return true
	}
	return false
}

// statusRank orders the delivery ladder. Unknown values rank below everything,
// so a bridge sending garbage cannot knock a message back down.
func statusRank(status string) int {
	switch status {
	case StatusPending:
		return 1
	case StatusFailed:
		return 2
	case StatusSent:
		return 3
	case StatusDelivered:
		return 4
	case StatusRead:
		return 5
	}
	return 0
}

// Chat is one conversation. The trailing three fields exist for mail-shaped
// providers, where a "chat" is a thread; chat-shaped providers leave them empty
// and the UI hides them.
type Chat struct {
	Provider     string   `json:"provider"`
	ID           string   `json:"id"`
	Name         string   `json:"name"`
	IsGroup      bool     `json:"isGroup"`
	LastTS       int64    `json:"lastTs"`
	LastText     string   `json:"lastText"`
	Unread       int      `json:"unread"`
	Muted        bool     `json:"muted"`
	Archived     bool     `json:"archived"`
	ReadUpTo     int64    `json:"readUpTo"`
	AvatarPath   string   `json:"avatarPath,omitempty"`
	Subject      string   `json:"subject,omitempty"`
	Participants []string `json:"participants,omitempty"`
	Folder       string   `json:"folder,omitempty"`

	// Handles are the other identifiers this conversation answers to: a phone
	// number, an email address, a username. Declared by the bridge, because
	// only it knows what its service uses -- WhatsApp ids, for instance, are
	// now privacy identifiers rather than phone numbers, so parsing the id
	// would find nothing.
	Handles []string `json:"handles,omitempty"`

	// Tags are what a provider says this conversation is: archived, muted,
	// status, channel, broadcast, business, and whatever else a service has a
	// notion of. Free-form on purpose -- the shell cannot know what categories
	// a future provider will have, so it lists whatever turns up and lets the
	// user filter on it.
	Tags []string `json:"tags,omitempty"`

	// MyLastTS is when you last wrote in this chat, ignoring protocol rows.
	// Derived on read; bridges never set it.
	MyLastTS int64 `json:"myLastTs"`
}

// Message is one message. Media is referenced by path, never carried inline:
// MediaPath points at a file in the cache, and MediaRef is an opaque handle the
// bridge gets back if the user asks for the full-size version later.
type Message struct {
	Provider   string `json:"provider"`
	ChatID     string `json:"chatId"`
	ID         string `json:"id"`
	TS         int64  `json:"ts"`
	FromMe     bool   `json:"fromMe"`
	SenderID   string `json:"senderId,omitempty"`
	SenderName string `json:"senderName,omitempty"`
	// SenderAvatarPath is the sender's picture, for group conversations where
	// several people speak. Per message rather than per chat, since a group has
	// no single face.
	SenderAvatarPath string   `json:"senderAvatarPath,omitempty"`
	Kind             string   `json:"kind"`
	Text             string   `json:"text"`
	BodyHTML         string   `json:"bodyHtml,omitempty"`
	Status           string   `json:"status"`
	ReplyTo          string   `json:"replyTo,omitempty"`
	CC               []string `json:"cc,omitempty"`
	BCC              []string `json:"bcc,omitempty"`

	// A link the message is about, with whatever the provider knew about it.
	// Sent by the provider rather than fetched here: fetching would leak the
	// fact that the message was read to whoever hosts the page.
	LinkURL   string `json:"linkUrl,omitempty"`
	LinkTitle string `json:"linkTitle,omitempty"`
	LinkDesc  string `json:"linkDesc,omitempty"`
	LinkImage string `json:"linkImage,omitempty"`

	MediaPath string `json:"mediaPath,omitempty"`
	MediaRef  string `json:"mediaRef,omitempty"`
	MediaMime string `json:"mediaMime,omitempty"`
	MediaW    int    `json:"mediaW,omitempty"`
	MediaH    int    `json:"mediaH,omitempty"`
	FileName  string `json:"fileName,omitempty"`
	FileSize  int64  `json:"fileSize,omitempty"`
	Duration  int    `json:"duration,omitempty"`
}

// SearchHit is a message match with enough chat context to render a result row
// without a second lookup.
type SearchHit struct {
	Message
	ChatName string `json:"chatName"`
}

// placeholderFor is the preview text for a message with no words in it -- used
// in the chat list and in notification bodies.
func placeholderFor(kind string) string {
	switch kind {
	case KindImage:
		return "📷 Photo"
	case KindVideo:
		return "🎥 Video"
	case KindAudio:
		return "🎤 Voice message"
	case KindDocument:
		return "📄 Document"
	case KindSticker:
		return "🌟 Sticker"
	case KindLocation:
		return "📍 Location"
	case KindContact:
		return "👤 Contact"
	case KindDeleted:
		return "🚫 Deleted message"
	}
	return ""
}

// Preview is what the chat list and notifications show for a message.
//
// A caption always wins. Failing that, an attachment with a name shows the name
// -- "📄 report.pdf" tells you far more than "📄 Document" does.
func (m Message) Preview() string {
	if m.Text != "" {
		return m.Text
	}

	placeholder := placeholderFor(m.Kind)
	if m.FileName != "" {
		if placeholder != "" {
			icon, _, _ := strings.Cut(placeholder, " ")
			return icon + " " + m.FileName
		}
		return m.FileName
	}
	return placeholder
}
