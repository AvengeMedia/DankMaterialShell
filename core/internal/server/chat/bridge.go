package chat

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os/exec"
	"sync"
	"syscall"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/chat"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
)

const (
	// Bridges may emit large frames during history sync; a batch of messages
	// with inline thumbnails is comfortably past bufio's default.
	maxFrameSize = 16 << 20

	// Restart backoff. A bridge that cannot start -- a missing binary, a bad
	// interpreter -- should not be respawned in a hot loop.
	minRestartDelay = 1 * time.Second
	maxRestartDelay = 30 * time.Second

	// How long a bridge gets to honour shutdown before it is signalled.
	shutdownGrace = 3 * time.Second

	// How long a call waits before giving up on a bridge that never replies.
	callTimeout = 60 * time.Second
)

var errBridgeDown = errors.New("bridge is not running")

// bridge is one running provider process.
//
// The zero value is not usable; construct with newBridge. All exported methods
// are safe for concurrent use.
type bridge struct {
	provider Provider
	events   chan<- ingestEvent

	mu       sync.Mutex
	cmd      *exec.Cmd
	stdin    io.WriteCloser
	running  bool
	stopping bool

	// pending maps an in-flight call id to the channel waiting for its reply.
	pending  map[int]chan bridgeFrame
	nextCall int

	// State the bridge has reported about itself.
	state        string
	capabilities []string
	protocol     int
	restarts     int
	lastError    string
	startedAt    time.Time

	// The most recent sign-in challenge. Kept because the auth event is a
	// one-shot push, but the panel showing it may be opened long afterwards.
	authMethod  string
	authPayload string

	// stderrTail keeps the last few lines the bridge complained about, so a
	// crash can be explained without the user having to reproduce it under
	// `dms chat tail`.
	stderrTail []string

	cancel context.CancelFunc
	done   chan struct{}

	// taps receive a copy of every frame in both directions, for `dms chat tail`.
	tapMu sync.Mutex
	taps  map[int]chan TapLine
	nextT int
}

// TapLine is one observed protocol line, for live debugging.
type TapLine struct {
	Provider  string `json:"provider"`
	Direction string `json:"direction"` // "in", "out", or "stderr"
	Line      string `json:"line"`
	At        int64  `json:"at"`
}

func newBridge(p Provider, events chan<- ingestEvent) *bridge {
	return &bridge{
		provider: p,
		events:   events,
		pending:  map[int]chan bridgeFrame{},
		taps:     map[int]chan TapLine{},
		state:    chat.StateDisconnected,
	}
}

// Start launches the bridge and supervises it until Stop is called.
//
// Returns as soon as the process is spawned; the supervision loop continues in
// the background and restarts the process if it exits on its own.
func (b *bridge) Start(ctx context.Context) error {
	b.mu.Lock()
	if b.running {
		b.mu.Unlock()
		return nil
	}
	b.stopping = false
	b.running = true
	ctx, b.cancel = context.WithCancel(ctx)
	b.done = make(chan struct{})
	b.mu.Unlock()

	go b.supervise(ctx)
	return nil
}

// supervise runs the bridge, restarting it with backoff whenever it exits for
// a reason other than us stopping it.
func (b *bridge) supervise(ctx context.Context) {
	defer close(b.done)

	delay := minRestartDelay
	for {
		if ctx.Err() != nil {
			return
		}

		start := time.Now()
		err := b.runOnce(ctx)

		b.mu.Lock()
		stopping := b.stopping
		b.mu.Unlock()

		if stopping || ctx.Err() != nil {
			return
		}

		if err != nil {
			log.Warnf("chat: bridge %s exited: %v", b.provider.ID, err)
			b.setLastError(err.Error())
		} else {
			log.Infof("chat: bridge %s exited", b.provider.ID)
		}

		b.setState(chat.StateDisconnected)

		// A bridge that stayed up a while hit a transient fault; reset the
		// backoff so a long-lived provider recovers promptly.
		if time.Since(start) > 30*time.Second {
			delay = minRestartDelay
		}

		b.mu.Lock()
		b.restarts++
		b.mu.Unlock()

		select {
		case <-time.After(delay):
		case <-ctx.Done():
			return
		}

		delay *= 2
		if delay > maxRestartDelay {
			delay = maxRestartDelay
		}
	}
}

// runOnce spawns the bridge and pumps its output until it exits.
func (b *bridge) runOnce(ctx context.Context) error {
	if len(b.provider.Bridge) == 0 {
		return fmt.Errorf("provider %s declares no bridge command", b.provider.ID)
	}

	cmd := exec.CommandContext(ctx, b.provider.Bridge[0], b.provider.Bridge[1:]...)
	cmd.Dir = b.provider.Dir
	// Give the child its own process group so a shutdown signal reaches
	// anything it spawned, not just the bridge itself.
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}

	stdin, err := cmd.StdinPipe()
	if err != nil {
		return fmt.Errorf("stdin pipe: %w", err)
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return fmt.Errorf("stdout pipe: %w", err)
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return fmt.Errorf("stderr pipe: %w", err)
	}

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("start bridge: %w", err)
	}

	b.mu.Lock()
	b.cmd = cmd
	b.stdin = stdin
	b.startedAt = time.Now()
	b.mu.Unlock()

	log.Infof("chat: bridge %s started (pid %d)", b.provider.ID, cmd.Process.Pid)
	b.setState(chat.StateConnecting)

	go b.pumpStderr(stderr)

	// Configure before anything else, so the bridge has its settings and media
	// directory before it reports ready.
	go b.sendConfigure()

	err = b.pumpStdout(stdout)

	// Fail anything still waiting: a caller blocked on a dead bridge would
	// otherwise hang until its own timeout.
	b.failPending(errBridgeDown)

	waitErr := cmd.Wait()
	if err != nil {
		return err
	}
	return waitErr
}

// pumpStdout reads protocol frames until the stream closes.
func (b *bridge) pumpStdout(r io.Reader) error {
	scanner := bufio.NewScanner(r)
	scanner.Buffer(make([]byte, 0, 64*1024), maxFrameSize)

	for scanner.Scan() {
		line := scanner.Bytes()
		if len(line) == 0 {
			continue
		}

		b.tap("out", string(line))

		var frame bridgeFrame
		if err := json.Unmarshal(line, &frame); err != nil {
			// One malformed line should not take down a working session --
			// most often it is a bridge accidentally logging to stdout.
			log.Warnf("chat: bridge %s sent an unparseable line: %v", b.provider.ID, err)
			continue
		}

		if frame.isReply() {
			b.deliverReply(frame)
			continue
		}
		b.handleEvent(frame)
	}
	return scanner.Err()
}

// pumpStderr forwards a bridge's diagnostics to the log and keeps a short tail.
func (b *bridge) pumpStderr(r io.Reader) {
	scanner := bufio.NewScanner(r)
	scanner.Buffer(make([]byte, 0, 4096), 1<<20)

	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			continue
		}

		log.Debugf("chat[%s]: %s", b.provider.ID, line)
		b.tap("stderr", line)

		b.mu.Lock()
		b.stderrTail = append(b.stderrTail, line)
		if len(b.stderrTail) > 20 {
			b.stderrTail = b.stderrTail[len(b.stderrTail)-20:]
		}
		b.mu.Unlock()
	}
}

// handleEvent turns an unprompted bridge event into an ingest event.
func (b *bridge) handleEvent(f bridgeFrame) {
	switch f.Event {
	case EventReady:
		if f.Protocol != 0 && f.Protocol != ProtocolVersion {
			// Refuse rather than guess: a version we do not know may reuse the
			// same field names with different meanings.
			err := fmt.Errorf("bridge speaks protocol %d, host speaks %d", f.Protocol, ProtocolVersion)
			log.Errorf("chat: bridge %s refused: %v", b.provider.ID, err)
			b.setLastError(err.Error())
			b.Stop()
			return
		}
		b.mu.Lock()
		b.protocol = f.Protocol
		b.capabilities = f.Capabilities
		b.mu.Unlock()
		log.Infof("chat: bridge %s ready, capabilities %v", b.provider.ID, f.Capabilities)

	case EventState:
		b.setState(f.State)
		// Signing in invalidates any challenge still on screen.
		if f.State == chat.StateConnected {
			b.mu.Lock()
			b.authMethod, b.authPayload = "", ""
			b.mu.Unlock()
		}

	case EventAuth:
		payload := f.QR
		if payload == "" {
			payload = f.Code
		}
		if payload == "" {
			payload = f.URL
		}

		method := f.Method
		if method == "" {
			method = "qr"
		}

		b.mu.Lock()
		b.authMethod = method
		b.authPayload = payload
		b.mu.Unlock()

	case EventLog:
		// A bridge's own log lines, promoted so they are visible without stderr.
		switch f.Level {
		case "error":
			log.Errorf("chat[%s]: %s", b.provider.ID, f.Text)
		case "warn":
			log.Warnf("chat[%s]: %s", b.provider.ID, f.Text)
		default:
			log.Debugf("chat[%s]: %s", b.provider.ID, f.Text)
		}
		return
	}

	select {
	case b.events <- ingestEvent{provider: b.provider.ID, frame: f}:
	default:
		// The ingest queue is deep; a full one means the store cannot keep up.
		// Dropping is better than blocking the bridge's only reader.
		log.Warnf("chat: ingest queue full, dropped %s event from %s", f.Event, b.provider.ID)
	}
}

// ---------------------------------------------------------------- calls

// call sends a method to the bridge and waits for its reply.
func (b *bridge) call(ctx context.Context, method string, params map[string]any) (bridgeFrame, error) {
	b.mu.Lock()
	if !b.running || b.stdin == nil {
		b.mu.Unlock()
		return bridgeFrame{}, errBridgeDown
	}

	b.nextCall++
	id := b.nextCall
	reply := make(chan bridgeFrame, 1)
	b.pending[id] = reply
	stdin := b.stdin
	b.mu.Unlock()

	defer func() {
		b.mu.Lock()
		delete(b.pending, id)
		b.mu.Unlock()
	}()

	// Compact, single line: a pretty-printed object would split across lines
	// and desync the bridge's reader for the rest of the session.
	payload, err := json.Marshal(bridgeCall{ID: id, Method: method, Params: params})
	if err != nil {
		return bridgeFrame{}, err
	}

	b.tap("in", string(payload))

	if _, err := stdin.Write(append(payload, '\n')); err != nil {
		return bridgeFrame{}, fmt.Errorf("write to bridge: %w", err)
	}

	timeout := time.NewTimer(callTimeout)
	defer timeout.Stop()

	select {
	case f := <-reply:
		if f.OK != nil && !*f.OK {
			return f, fmt.Errorf("%s", f.Error.String())
		}
		return f, nil
	case <-timeout.C:
		return bridgeFrame{}, fmt.Errorf("bridge %s did not answer %s in time", b.provider.ID, method)
	case <-ctx.Done():
		return bridgeFrame{}, ctx.Err()
	}
}

// notify sends a method without waiting for its reply.
//
// Used where the local state change is what matters and the bridge call is
// best-effort -- a read receipt the provider cannot post should not leave the
// user staring at an error.
func (b *bridge) notify(method string, params map[string]any) {
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), callTimeout)
		defer cancel()
		if _, err := b.call(ctx, method, params); err != nil {
			log.Warnf("chat: bridge %s %s failed: %v", b.provider.ID, method, err)
		}
	}()
}

func (b *bridge) deliverReply(f bridgeFrame) {
	b.mu.Lock()
	reply, ok := b.pending[f.ID]
	b.mu.Unlock()

	if !ok {
		// A late reply to a call that already timed out. Expected, not an error.
		log.Debugf("chat: bridge %s replied to unknown call %d", b.provider.ID, f.ID)
		return
	}

	select {
	case reply <- f:
	default:
	}
}

func (b *bridge) failPending(err error) {
	b.mu.Lock()
	pending := b.pending
	b.pending = map[int]chan bridgeFrame{}
	b.mu.Unlock()

	failed := false
	for range pending {
		failed = true
		break
	}
	if failed {
		log.Debugf("chat: bridge %s failing in-flight calls: %v", b.provider.ID, err)
	}
	for _, ch := range pending {
		close(ch)
	}
}

// sendConfigure hands the bridge its settings and media directory.
func (b *bridge) sendConfigure() {
	ctx, cancel := context.WithTimeout(context.Background(), callTimeout)
	defer cancel()

	params := map[string]any{
		"settings": b.provider.Settings,
		"mediaDir": b.provider.MediaDir,
	}
	if _, err := b.call(ctx, MethodConfigure, params); err != nil {
		log.Warnf("chat: bridge %s rejected configure: %v", b.provider.ID, err)
	}
}

// Reconfigure pushes changed settings down to a running bridge.
//
// Settings flow down the pipe rather than the bridge reading the shell's
// config file, which is what lets a bridge be developed and tested entirely
// outside DMS.
func (b *bridge) Reconfigure(settings map[string]any) {
	b.mu.Lock()
	b.provider.Settings = settings
	running := b.running
	b.mu.Unlock()

	if running {
		go b.sendConfigure()
	}
}

// ---------------------------------------------------------------- lifecycle

// Stop asks the bridge to exit, escalating to signals if it does not.
func (b *bridge) Stop() {
	b.mu.Lock()
	if !b.running {
		b.mu.Unlock()
		return
	}
	b.stopping = true
	cmd := b.cmd
	stdin := b.stdin
	cancel := b.cancel
	done := b.done
	b.mu.Unlock()

	// Ask nicely first, so a bridge can log out cleanly rather than leaving a
	// half-open session behind.
	if stdin != nil {
		ctx, c := context.WithTimeout(context.Background(), shutdownGrace)
		_, _ = b.call(ctx, MethodShutdown, nil)
		c()
		_ = stdin.Close()
	}

	if cmd != nil && cmd.Process != nil {
		exited := make(chan struct{})
		go func() {
			select {
			case <-done:
			case <-time.After(shutdownGrace):
			}
			close(exited)
		}()
		<-exited

		// Signal the whole process group: a bridge that spawned helpers should
		// not leave them orphaned.
		if pgid, err := syscall.Getpgid(cmd.Process.Pid); err == nil {
			_ = syscall.Kill(-pgid, syscall.SIGTERM)
		} else {
			_ = cmd.Process.Signal(syscall.SIGTERM)
		}
	}

	if cancel != nil {
		cancel() // CommandContext escalates to SIGKILL
	}

	b.mu.Lock()
	b.running = false
	b.stdin = nil
	b.mu.Unlock()

	b.setState(chat.StateDisconnected)
	b.failPending(errBridgeDown)
}

func (b *bridge) setState(state string) {
	if state == "" {
		return
	}

	b.mu.Lock()
	changed := b.state != state
	b.state = state
	b.mu.Unlock()

	if changed {
		select {
		case b.events <- ingestEvent{
			provider: b.provider.ID,
			frame:    bridgeFrame{Event: EventState, State: state},
			internal: true,
		}:
		default:
		}
	}
}

func (b *bridge) setLastError(msg string) {
	b.mu.Lock()
	b.lastError = msg
	b.mu.Unlock()
}

// Status is a snapshot of a bridge for the settings UI and the CLI.
func (b *bridge) Status() ProviderStatus {
	b.mu.Lock()
	defer b.mu.Unlock()

	caps := make([]string, len(b.capabilities))
	copy(caps, b.capabilities)
	tail := make([]string, len(b.stderrTail))
	copy(tail, b.stderrTail)

	var pid int
	if b.cmd != nil && b.cmd.Process != nil && b.running {
		pid = b.cmd.Process.Pid
	}

	return ProviderStatus{
		ID:           b.provider.ID,
		Name:         b.provider.Name,
		Icon:         b.provider.Icon,
		Enabled:      true,
		Running:      b.running,
		State:        b.state,
		Capabilities: caps,
		Protocol:     b.protocol,
		Restarts:     b.restarts,
		LastError:    b.lastError,
		PID:          pid,
		StderrTail:   tail,
		AuthMethod:   b.authMethod,
		AuthPayload:  b.authPayload,
	}
}

// AuthChallenge returns the pending sign-in challenge, if any.
func (b *bridge) AuthChallenge() (method, payload string) {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.authMethod, b.authPayload
}

// HasCapability reports whether the bridge declared a capability.
func (b *bridge) HasCapability(cap string) bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	for _, c := range b.capabilities {
		if c == cap {
			return true
		}
	}
	return false
}

// ---------------------------------------------------------------- tap

// Tap returns a channel of every protocol line in both directions, plus stderr.
// The returned function detaches the tap.
func (b *bridge) Tap() (<-chan TapLine, func()) {
	ch := make(chan TapLine, 256)

	b.tapMu.Lock()
	b.nextT++
	id := b.nextT
	b.taps[id] = ch
	b.tapMu.Unlock()

	return ch, func() {
		b.tapMu.Lock()
		delete(b.taps, id)
		close(ch)
		b.tapMu.Unlock()
	}
}

func (b *bridge) tap(direction, line string) {
	b.tapMu.Lock()
	defer b.tapMu.Unlock()

	if len(b.taps) == 0 {
		return
	}

	entry := TapLine{
		Provider:  b.provider.ID,
		Direction: direction,
		Line:      line,
		At:        time.Now().UnixMilli(),
	}
	for _, ch := range b.taps {
		select {
		case ch <- entry:
		default:
			// A slow observer must never stall the bridge.
		}
	}
}
