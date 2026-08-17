// Command echo-chat-bridge is a reference DMS chat provider.
//
// It implements the whole bridge contract (docs/CHAT-PLUGINS.md) against an
// invented service: two conversations, an echo reply to anything you send, a
// fake QR sign-in and a generated image for fetchMedia. It exists so the chat
// stack is runnable end to end without a real provider, and so anyone writing
// one has a working file to copy.
//
// Everything a bridge must get right is here and commented: compact JSON lines
// on stdout, diagnostics on stderr, never exiting on error, and answering
// unknown methods rather than ignoring them.
//
// Build:  go build -o ../bin/echo-chat-bridge .
package main

import (
	"bufio"
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"os"
	"sync"
	"time"
)

// protocolVersion is the contract this bridge speaks. The host refuses a
// version it does not know rather than mis-parsing it.
const protocolVersion = 1

// echoDelay is how long the imaginary other party takes to reply, so the
// pending -> sent -> delivered progression is actually visible in the UI.
const echoDelay = 900 * time.Millisecond

// ---------------------------------------------------------------- protocol

type call struct {
	ID     int             `json:"id"`
	Method string          `json:"method"`
	Params json.RawMessage `json:"params"`
}

type reply struct {
	ID     int      `json:"id"`
	OK     bool     `json:"ok"`
	Result any      `json:"result,omitempty"`
	Error  *errInfo `json:"error,omitempty"`
}

type errInfo struct {
	Code    string `json:"code"`
	Message string `json:"message,omitempty"`
}

type chatObj struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	IsGroup  bool   `json:"isGroup,omitempty"`
	LastTS   int64  `json:"lastTs,omitempty"`
	LastText string `json:"lastText,omitempty"`
	Unread   *int   `json:"unread,omitempty"`
	// Handles are the other identifiers a conversation answers to. DMS matches
	// a typed phone number or address against these; it never picks apart an
	// id, because an id is yours to shape.
	Handles []string `json:"handles,omitempty"`
}

type messageObj struct {
	ID         string `json:"id"`
	ChatID     string `json:"chatId"`
	TS         int64  `json:"ts"`
	FromMe     bool   `json:"fromMe,omitempty"`
	SenderName string `json:"senderName,omitempty"`
	Kind       string `json:"kind,omitempty"`
	Text       string `json:"text,omitempty"`
	Status     string `json:"status,omitempty"`
	ReplyTo    string `json:"replyTo,omitempty"`
	MediaRef   string `json:"mediaRef,omitempty"`
	MediaMime  string `json:"mediaMime,omitempty"`
	MediaW     int    `json:"mediaW,omitempty"`
	MediaH     int    `json:"mediaH,omitempty"`
}

// out serialises stdout. Every frame must be one compact line: a pretty-printed
// object would split across lines and desync the host's reader for the rest of
// the session.
var out = struct {
	mu sync.Mutex
	w  *bufio.Writer
}{w: bufio.NewWriter(os.Stdout)}

func emit(v any) {
	data, err := json.Marshal(v)
	if err != nil {
		logf("error", "could not encode frame: %v", err)
		return
	}

	out.mu.Lock()
	defer out.mu.Unlock()
	out.w.Write(data)
	out.w.WriteByte('\n')
	out.w.Flush()
}

func emitEvent(event string, fields map[string]any) {
	frame := map[string]any{"event": event}
	for k, v := range fields {
		frame[k] = v
	}
	emit(frame)
}

// logf writes a diagnostic. Two channels: stderr, which the host tails into its
// log, and a log event, which surfaces in `dms chat tail`. Never stdout as
// bare text -- that is protocol.
func logf(level, format string, args ...any) {
	msg := fmt.Sprintf(format, args...)
	fmt.Fprintln(os.Stderr, msg)
	emitEvent("log", map[string]any{"level": level, "text": msg})
}

// ---------------------------------------------------------------- state

type bridge struct {
	mu       sync.Mutex
	settings map[string]any
	mediaDir string
	seq      int
	loggedIn bool
}

func (b *bridge) nextID(prefix string) string {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.seq++
	return fmt.Sprintf("%s-%d", prefix, b.seq)
}

func (b *bridge) setting(key string, fallback string) string {
	b.mu.Lock()
	defer b.mu.Unlock()
	if v, ok := b.settings[key].(string); ok && v != "" {
		return v
	}
	return fallback
}

func now() int64 { return time.Now().UnixMilli() }

func main() {
	b := &bridge{settings: map[string]any{}}

	// Announce first. Capabilities are deliberately partial: this provider
	// claims no revoke and no richText, so the UI's capability gating is
	// actually exercised rather than every affordance being on.
	emitEvent("ready", map[string]any{
		"protocol": protocolVersion,
		"capabilities": []string{
			"send", "markRead", "media", "reply", "search", "groups",
		},
	})

	emitEvent("state", map[string]any{"state": "connecting"})

	scanner := bufio.NewScanner(os.Stdin)
	scanner.Buffer(make([]byte, 0, 64*1024), 16<<20)

	for scanner.Scan() {
		line := scanner.Bytes()
		if len(bytes.TrimSpace(line)) == 0 {
			continue
		}

		var c call
		if err := json.Unmarshal(line, &c); err != nil {
			// A malformed call is the host's problem, not ours; log it and
			// keep serving. Exiting here would take out a working session.
			logf("warn", "unparseable call: %v", err)
			continue
		}
		b.dispatch(c)
	}

	if err := scanner.Err(); err != nil {
		logf("error", "stdin closed: %v", err)
	}
}

func (b *bridge) dispatch(c call) {
	switch c.Method {
	case "configure":
		b.handleConfigure(c)
	case "send":
		b.handleSend(c)
	case "markRead":
		emit(reply{ID: c.ID, OK: true})
	case "fetchMedia":
		b.handleFetchMedia(c)
	case "history":
		b.handleHistory(c)
	case "search":
		emit(reply{ID: c.ID, OK: true})
	case "login":
		b.handleLogin(c)
	case "logout":
		b.handleLogout(c)
	case "shutdown":
		emit(reply{ID: c.ID, OK: true})
		emitEvent("state", map[string]any{"state": "disconnected"})
		os.Exit(0)

	default:
		// Answering rather than ignoring is what keeps an old bridge working
		// against a newer host: it learns what is unsupported instead of
		// waiting for a reply that never comes.
		emit(reply{ID: c.ID, OK: false, Error: &errInfo{
			Code:    "unknown_method",
			Message: "echo bridge does not implement " + c.Method,
		}})
	}
}

// ---------------------------------------------------------------- methods

func (b *bridge) handleConfigure(c call) {
	var params struct {
		Settings map[string]any `json:"settings"`
		MediaDir string         `json:"mediaDir"`
	}
	_ = json.Unmarshal(c.Params, &params)

	b.mu.Lock()
	if params.Settings != nil {
		b.settings = params.Settings
	}
	b.mediaDir = params.MediaDir
	first := !b.loggedIn
	b.mu.Unlock()

	emit(reply{ID: c.ID, OK: true})

	// Configure arrives at startup and again on every settings change. Only
	// the first one should bring the connection up.
	if first {
		go b.connect()
	}
}

// connect fakes coming online and seeds the two demo conversations.
func (b *bridge) connect() {
	time.Sleep(200 * time.Millisecond)

	b.mu.Lock()
	b.loggedIn = true
	b.mu.Unlock()

	emitEvent("state", map[string]any{"state": "connected"})

	peer := b.setting("peerName", "Ada Lovelace")
	unread := 1
	ts := now()

	emitEvent("chats", map[string]any{"chats": []chatObj{
		{
			ID: "echo-dm", Name: peer, LastTS: ts, Unread: &unread,
			LastText: "Say anything and I will echo it",
			Handles:  []string{"+15550100"},
		},
		{
			ID: "echo-group", Name: "Echo Group", IsGroup: true,
			LastTS: ts - 60_000, LastText: "A group that echoes too",
		},
		// A contact with no conversation yet: findable by name or number, but
		// deliberately absent from the conversation list until something is
		// actually said. Most of a real address book looks like this.
		{
			ID: "echo-contact", Name: "Katherine Johnson",
			Handles: []string{"+15550199", "katherine@example.com"},
		},
	}})

	// A batch is how backfill is delivered: the host stores it in one
	// transaction and does not notify for each entry.
	emitEvent("messages", map[string]any{"messages": []messageObj{
		{
			ID: "echo-welcome", ChatID: "echo-dm", TS: ts - 120_000,
			SenderName: peer, Kind: "text", Status: "read",
			Text: "This is the Echo reference provider. Anything you send here comes straight back.",
		},
		{
			ID: "echo-photo", ChatID: "echo-dm", TS: ts - 90_000,
			SenderName: peer, Kind: "image", Status: "read",
			Text: "An attachment fetched on demand",
			// No bytes now: a ref means the host only asks for the real image
			// when the user opens it. During a large sync this is the
			// difference between one round trip and thousands.
			MediaRef: "demo-gradient", MediaMime: "image/png", MediaW: 320, MediaH: 200,
		},
		{
			ID: "echo-group-1", ChatID: "echo-group", TS: ts - 60_000,
			SenderName: "Grace", Kind: "text", Status: "read",
			Text: "Group messages carry a sender name.",
		},
	}})

	emitEvent("chat", map[string]any{"chat": chatObj{
		ID: "echo-dm", Name: peer, LastTS: ts, LastText: "Say anything and I will echo it",
	}})
}

func (b *bridge) handleSend(c call) {
	var params struct {
		ChatID      string   `json:"chatId"`
		Text        string   `json:"text"`
		ReplyTo     string   `json:"replyTo"`
		Attachments []string `json:"attachments"`
	}
	if err := json.Unmarshal(c.Params, &params); err != nil {
		emit(reply{ID: c.ID, OK: false, Error: &errInfo{Code: "bad_request", Message: err.Error()}})
		return
	}
	if params.ChatID == "" {
		emit(reply{ID: c.ID, OK: false, Error: &errInfo{Code: "bad_request", Message: "chatId is required"}})
		return
	}

	// A real bridge would hand the message to its service here and return the
	// id the service assigned. The host has already shown a pending bubble;
	// this reply is what turns it into a sent one.
	messageID := b.nextID("echo-sent")
	emit(reply{ID: c.ID, OK: true, Result: map[string]any{"messageId": messageID}})

	go b.echoBack(params.ChatID, params.Text, messageID, len(params.Attachments))
}

// echoBack walks the sent message up the delivery ladder, then answers.
func (b *bridge) echoBack(chatID, text, sentID string, attachments int) {
	time.Sleep(echoDelay / 2)
	emitEvent("status", map[string]any{"messageId": sentID, "status": "delivered"})

	time.Sleep(echoDelay / 2)
	emitEvent("status", map[string]any{"messageId": sentID, "status": "read"})

	body := text
	if body == "" && attachments > 0 {
		body = fmt.Sprintf("(%d attachment(s))", attachments)
	}
	if body == "" {
		return
	}

	peer := b.setting("peerName", "Ada Lovelace")
	prefix := b.setting("echoPrefix", "You said: ")

	msg := messageObj{
		ID: b.nextID("echo-reply"), ChatID: chatID, TS: now(),
		SenderName: peer, Kind: "text", Status: "sent",
		Text: prefix + body, ReplyTo: sentID,
	}
	emitEvent("message", map[string]any{"message": msg})

	// Keep the conversation's activity line in step. The host would derive
	// this anyway; sending it is what a real provider does.
	emitEvent("chat", map[string]any{"chat": chatObj{
		ID: chatID, LastTS: msg.TS, LastText: msg.Text,
	}})
}

// handleFetchMedia answers the deferred-media path. A real bridge downloads the
// attachment here; this one draws it.
func (b *bridge) handleFetchMedia(c call) {
	var params struct {
		MessageID string `json:"messageId"`
		Ref       string `json:"ref"`
	}
	_ = json.Unmarshal(c.Params, &params)

	if params.Ref == "" {
		emit(reply{ID: c.ID, OK: false, Error: &errInfo{
			Code: "no_media", Message: "nothing to fetch"}})
		return
	}

	data, err := gradientPNG(320, 200)
	if err != nil {
		emit(reply{ID: c.ID, OK: false, Error: &errInfo{
			Code: "fetch_failed", Message: err.Error()}})
		return
	}

	// Two ways to hand media back. Writing into mediaDir is the right one for
	// anything sizeable; inline base64 is only acceptable because this image
	// is a few kilobytes.
	b.mu.Lock()
	dir := b.mediaDir
	b.mu.Unlock()

	if dir != "" {
		path := dir + "/" + params.MessageID + ".png"
		if err := os.WriteFile(path, data, 0o600); err == nil {
			emit(reply{ID: c.ID, OK: true, Result: map[string]any{
				"path": path, "mime": "image/png"}})
			return
		}
		logf("warn", "could not write to mediaDir, falling back to inline bytes")
	}

	emit(reply{ID: c.ID, OK: true, Result: map[string]any{
		"bytes": base64.StdEncoding.EncodeToString(data),
		"mime":  "image/png",
	}})
}

// handleHistory is asked to backfill older messages. Answering ok and emitting
// nothing is a valid way to say "there is no more".
func (b *bridge) handleHistory(c call) {
	emit(reply{ID: c.ID, OK: true})
	logf("debug", "history requested; the echo provider has no older messages")
}

func (b *bridge) handleLogin(c call) {
	emit(reply{ID: c.ID, OK: true})

	// A QR sign-in, as WhatsApp and Signal use. The host renders the string as
	// a QR code in its auth panel.
	emitEvent("state", map[string]any{"state": "needsLogin"})
	emitEvent("auth", map[string]any{
		"method": "qr",
		"qr":     "dms-echo-demo-" + fmt.Sprint(now()),
	})

	// Pretend the user scanned it.
	go func() {
		time.Sleep(3 * time.Second)
		logf("info", "demo sign-in completed")
		b.connect()
	}()
}

func (b *bridge) handleLogout(c call) {
	b.mu.Lock()
	b.loggedIn = false
	b.mu.Unlock()

	emit(reply{ID: c.ID, OK: true})
	emitEvent("state", map[string]any{"state": "needsLogin"})
}

// gradientPNG draws a placeholder image, so fetchMedia returns something real.
func gradientPNG(w, h int) ([]byte, error) {
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			img.Set(x, y, color.RGBA{
				R: uint8(255 * x / w),
				G: uint8(255 * y / h),
				B: 200,
				A: 255,
			})
		}
	}

	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}
