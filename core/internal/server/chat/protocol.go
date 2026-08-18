// Package chat hosts chat provider bridges.
//
// A bridge is an external program that translates one messaging service into
// newline-delimited JSON (see docs/CHAT-PLUGINS.md). This package spawns them,
// keeps them alive, writes everything they report into the shared store, and
// exposes chat.* methods to the shell. Bridges own protocol knowledge and
// credentials; everything else is here so it gets written once.
package chat

import "encoding/json"

// ProtocolVersion is the contract version this host speaks. A bridge announces
// its own in the ready event, and one we do not recognise is refused rather
// than parsed on a guess.
const ProtocolVersion = 1

// Methods the host calls on a bridge.
const (
	MethodConfigure  = "configure"
	MethodSend       = "send"
	MethodMarkRead   = "markRead"
	MethodFetchMedia = "fetchMedia"
	MethodHistory    = "history"
	MethodSearch     = "search"
	MethodLogin      = "login"
	MethodLogout     = "logout"
	MethodRevoke     = "revoke"
	MethodShutdown   = "shutdown"
)

// Events a bridge pushes to the host.
const (
	EventReady    = "ready"
	EventState    = "state"
	EventAuth     = "auth"
	EventChat     = "chat"
	EventChats    = "chats"
	EventMessage  = "message"
	EventMessages = "messages"
	EventStatus   = "status"
	EventDeleted  = "deleted"
	EventSync     = "sync"
	EventLog      = "log"
)

// Capabilities a bridge may declare. The UI hides affordances a provider has
// not claimed, so an unsupported action is never offered rather than failing
// when it is used.
const (
	CapSend     = "send"
	CapMarkRead = "markRead"
	CapMedia    = "media"
	CapReply    = "reply"
	CapRevoke   = "revoke"
	CapSearch   = "search"
	CapThreads  = "threads"
	CapRichText = "richText"
	CapPresence = "presence"
	CapGroups   = "groups"
)

// bridgeCall is what the host writes to a bridge's stdin.
type bridgeCall struct {
	ID     int            `json:"id"`
	Method string         `json:"method"`
	Params map[string]any `json:"params,omitempty"`
}

// bridgeError is the failure detail on a call reply.
type bridgeError struct {
	Code    string `json:"code"`
	Message string `json:"message,omitempty"`
}

func (e *bridgeError) String() string {
	if e == nil {
		return ""
	}
	if e.Message != "" {
		return e.Code + ": " + e.Message
	}
	return e.Code
}

// bridgeFrame is one line of a bridge's stdout. It is either a reply to a call
// (Event empty, ID set) or an unprompted event (Event set).
//
// One struct rather than two because the two share a stream and are told apart
// by which fields are populated -- decoding into a single shape keeps that
// decision in one place.
type bridgeFrame struct {
	// Reply fields.
	ID     int             `json:"id"`
	OK     *bool           `json:"ok"`
	Result json.RawMessage `json:"result"`
	Error  *bridgeError    `json:"error"`

	// Event fields.
	Event        string   `json:"event"`
	Protocol     int      `json:"protocol"`
	Capabilities []string `json:"capabilities"`
	State        string   `json:"state"`

	// Auth.
	Method string `json:"method"`
	QR     string `json:"qr"`
	Code   string `json:"code"`
	URL    string `json:"url"`

	// Payloads. Singular and batch forms are both accepted; the batch forms
	// exist so a history sync costs one transaction instead of thousands.
	Chat     *wireChat     `json:"chat"`
	Chats    []wireChat    `json:"chats"`
	Message  *wireMessage  `json:"message"`
	Messages []wireMessage `json:"messages"`

	// Status / deletion.
	ChatID    string `json:"chatId"`
	MessageID string `json:"messageId"`
	Status    string `json:"status"`

	// Sync progress.
	Done  int `json:"done"`
	Total int `json:"total"`

	// Log. Carried as "text" rather than "message" so the key never collides
	// with the message event's object of the same name.
	Level string `json:"level"`
	Text  string `json:"text"`
}

func (f bridgeFrame) isReply() bool { return f.Event == "" && f.ID != 0 }

// wireChat is a chat as a bridge sends it.
//
// Unread is a pointer so "the bridge did not mention unread" is distinguishable
// from "the bridge says zero" -- the former must not clear a badge the host
// derived itself.
type wireChat struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	IsGroup  bool   `json:"isGroup"`
	LastTS   int64  `json:"lastTs"`
	LastText string `json:"lastText"`
	Unread   *int   `json:"unread"`
	// Pointers so "the bridge did not mention this" is distinguishable from
	// "the bridge says false" -- otherwise a partial update unarchives a chat.
	Archived     *bool    `json:"archived"`
	Muted        *bool    `json:"muted"`
	AvatarPath   string   `json:"avatarPath"`
	Subject      string   `json:"subject"`
	Participants []string `json:"participants"`
	Folder       string   `json:"folder"`
	// Handles are the other identifiers this conversation answers to -- a phone
	// number, an email address, a username. Only the bridge knows them.
	Handles []string `json:"handles"`
	// Tags say what kind of conversation this is: archived, status, channel,
	// broadcast, business, and whatever else the service distinguishes.
	Tags []string `json:"tags"`
}

// wireMessage is a message as a bridge sends it. Media arrives as a path the
// bridge wrote, a small base64 thumbnail, or a ref to fetch later -- never as
// a full inline payload.
type wireMessage struct {
	ID         string `json:"id"`
	ChatID     string `json:"chatId"`
	TS         int64  `json:"ts"`
	FromMe     bool   `json:"fromMe"`
	SenderID   string `json:"senderId"`
	SenderName string `json:"senderName"`
	// SenderAvatarPath is optional; groups without per-sender pictures simply
	// fall back to an initial.
	SenderAvatarPath string   `json:"senderAvatarPath"`
	Kind             string   `json:"kind"`
	Text             string   `json:"text"`
	BodyHTML         string   `json:"bodyHtml"`
	Status           string   `json:"status"`
	ReplyTo          string   `json:"replyTo"`
	CC               []string `json:"cc"`
	BCC              []string `json:"bcc"`

	LinkURL   string `json:"linkUrl"`
	LinkTitle string `json:"linkTitle"`
	LinkDesc  string `json:"linkDesc"`
	LinkImage string `json:"linkImage"`

	MediaPath  string `json:"mediaPath"`
	MediaBytes string `json:"mediaBytes"`
	MediaRef   string `json:"mediaRef"`
	MediaMime  string `json:"mediaMime"`
	MediaW     int    `json:"mediaW"`
	MediaH     int    `json:"mediaH"`
	FileName   string `json:"fileName"`
	FileSize   int64  `json:"fileSize"`
	Duration   int    `json:"duration"`
}

// sendResult is what a bridge returns from a successful send.
type sendResult struct {
	MessageID string `json:"messageId"`
}

// fetchMediaResult is what a bridge returns from a successful fetchMedia.
type fetchMediaResult struct {
	Path  string `json:"path"`
	Bytes string `json:"bytes"`
	Mime  string `json:"mime"`
}
