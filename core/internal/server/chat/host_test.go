package chat

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/chat"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// writePlugin lays down a plugin directory with a manifest and an executable
// bridge script, mimicking what an installed chat plugin looks like on disk.
func writePlugin(t *testing.T, root, id, manifestExtra, script string) string {
	t.Helper()

	dir := filepath.Join(root, id)
	require.NoError(t, os.MkdirAll(filepath.Join(dir, "bin"), 0o755))

	manifest := `{
  "id": "` + id + `",
  "name": "` + id + ` Chat",
  "description": "test provider",
  "version": "1.0.0",
  "author": "test",
  "type": "chat",
  "bridge": ["./bin/bridge"]` + manifestExtra + `
}`
	require.NoError(t, os.WriteFile(filepath.Join(dir, "plugin.json"), []byte(manifest), 0o644))

	if script != "" {
		bridge := filepath.Join(dir, "bin", "bridge")
		require.NoError(t, os.WriteFile(bridge, []byte(script), 0o755))
	}
	return dir
}

func TestDiscoverProvidersFindsChatPlugins(t *testing.T) {
	root := t.TempDir()

	writePlugin(t, root, "alpha", "", "#!/bin/sh\ncat >/dev/null\n")

	// A plugin of some other type must be ignored.
	other := filepath.Join(root, "widgetThing")
	require.NoError(t, os.MkdirAll(other, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(other, "plugin.json"),
		[]byte(`{"id":"widgetThing","name":"W","type":"widget","component":"./W.qml"}`), 0o644))

	// A directory with no manifest at all.
	require.NoError(t, os.MkdirAll(filepath.Join(root, "empty"), 0o755))

	providers := discoverProviders(root)
	require.Len(t, providers, 1)
	assert.Equal(t, "alpha", providers[0].ID)
	assert.Equal(t, "alpha Chat", providers[0].Name)
	assert.Equal(t, filepath.Join(root, "alpha", "bin", "bridge"), providers[0].Bridge[0])
}

// A chat plugin with no bridge command cannot be run, so it is not a provider.
func TestDiscoverRejectsBridgelessPlugin(t *testing.T) {
	root := t.TempDir()

	dir := filepath.Join(root, "broken")
	require.NoError(t, os.MkdirAll(dir, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(dir, "plugin.json"),
		[]byte(`{"id":"broken","name":"B","type":"chat"}`), 0o644))

	assert.Empty(t, discoverProviders(root))
}

// A manifest must not be able to point the host at a binary outside its own
// directory. A bare command name is still allowed, so a plugin may depend on
// something on PATH.
func TestResolveBridgeContainsPathTraversal(t *testing.T) {
	dir := "/plugins/mychat"

	_, err := resolveBridge(dir, []string{"../../../bin/sh"})
	assert.Error(t, err, "must not escape the plugin directory")

	_, err = resolveBridge(dir, []string{"/bin/sh"})
	assert.Error(t, err, "must not name an absolute path")

	argv, err := resolveBridge(dir, []string{"./bin/bridge", "--flag"})
	require.NoError(t, err)
	assert.Equal(t, []string{"/plugins/mychat/bin/bridge", "--flag"}, argv)

	argv, err = resolveBridge(dir, []string{"python3", "main.py"})
	require.NoError(t, err)
	assert.Equal(t, []string{"python3", "main.py"}, argv,
		"a bare command name is left for PATH resolution")
}

// newTestManager builds a manager rooted entirely in temp dirs, so a test never
// touches the developer's real chat history.
func newTestManager(t *testing.T, pluginRoot string) *Manager {
	t.Helper()

	store, err := chat.OpenHistory(filepath.Join(t.TempDir(), "h.db"))
	require.NoError(t, err)

	media := chat.NewMedia(t.TempDir(), 0)
	notify := chat.NewNotifyPolicy(store, media)

	m := &Manager{
		store:         store,
		media:         media,
		notify:        notify,
		userPluginDir: pluginRoot,
		providers:     map[string]Provider{},
		bridges:       map[string]*bridge{},
		enabled:       map[string]bool{},
		sync:          map[string]SyncProgress{},
		// Notifications off: there is no session bus under test.
		prefs:     map[string]chat.NotifyPrefs{},
		events:    make(chan ingestEvent, ingestQueueDepth),
		dirty:     make(chan struct{}, 1),
		stopChan:  make(chan struct{}),
		startedAt: time.Now(),
	}
	m.Rescan()

	m.wg.Add(2)
	go m.ingestLoop()
	go m.broadcastLoop()

	t.Cleanup(func() { m.Close() })
	return m
}

// eventually polls until cond holds, so a test never depends on a fixed sleep.
func eventually(t *testing.T, msg string, cond func() bool) {
	t.Helper()
	deadline := time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) {
		if cond() {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("timed out waiting for %s", msg)
}

// A bridge that announces itself, sends a chat and a message, then answers a
// send call -- the full happy path through spawn, ingest and call.
const echoScript = `#!/bin/sh
echo '{"event":"ready","protocol":1,"capabilities":["send","markRead"]}'
echo '{"event":"state","state":"connected"}'
echo '{"event":"chat","chat":{"id":"c1","name":"Ada","lastTs":1000,"lastText":"hi"}}'
echo '{"event":"message","message":{"id":"m1","chatId":"c1","ts":1000,"text":"hi","kind":"text"}}'
while IFS= read -r line; do
  id=$(printf '%s' "$line" | sed -n 's/.*"id":\([0-9]*\).*/\1/p')
  case "$line" in
    *'"method":"send"'*)
      echo '{"event":"message","message":{"id":"m2","chatId":"c1","ts":2000,"text":"echo","fromMe":false,"kind":"text"}}'
      echo "{\"id\":$id,\"ok\":true,\"result\":{\"messageId\":\"sent-1\"}}"
      ;;
    *'"method":"shutdown"'*) echo "{\"id\":$id,\"ok\":true}"; exit 0 ;;
    *) echo "{\"id\":$id,\"ok\":true}" ;;
  esac
done
`

func TestBridgeLifecycleAndIngest(t *testing.T) {
	root := t.TempDir()
	writePlugin(t, root, "echo", "", echoScript)

	m := newTestManager(t, root)
	ctx := context.Background()

	providers := m.Providers(ctx)
	require.Len(t, providers, 1)
	assert.False(t, providers[0].Enabled, "a discovered provider starts stopped")
	assert.Equal(t, chat.StateDisconnected, providers[0].State)

	require.NoError(t, m.SetEnabled(ctx, "echo", true, map[string]any{"greeting": "hi"}))

	eventually(t, "the bridge to report connected", func() bool {
		p := m.Providers(ctx)
		return len(p) == 1 && p[0].State == chat.StateConnected
	})

	status := m.Providers(ctx)[0]
	assert.True(t, status.Running)
	assert.Positive(t, status.PID)
	assert.Equal(t, []string{"send", "markRead"}, status.Capabilities)

	eventually(t, "the announced chat to be stored", func() bool {
		chats, err := m.Store().Chats(ctx, 10)
		return err == nil && len(chats) == 1
	})

	chats, err := m.Store().Chats(ctx, 10)
	require.NoError(t, err)
	assert.Equal(t, "Ada", chats[0].Name)
	assert.Equal(t, "echo", chats[0].Provider)

	msgs, _, err := m.Store().Page(ctx, "echo", "c1", 0, 10)
	require.NoError(t, err)
	require.Len(t, msgs, 1)
	assert.Equal(t, "hi", msgs[0].Text)

	// Disabling stops the process.
	pid := status.PID
	require.NoError(t, m.SetEnabled(ctx, "echo", false, nil))

	eventually(t, "the bridge process to exit", func() bool {
		return !processAlive(pid)
	})
	assert.False(t, m.Providers(ctx)[0].Running)
}

// A bridge announcing a protocol version the host does not know is refused
// rather than parsed on a guess.
func TestUnknownProtocolIsRefused(t *testing.T) {
	root := t.TempDir()
	writePlugin(t, root, "future", "", `#!/bin/sh
echo '{"event":"ready","protocol":99}'
echo '{"event":"state","state":"connected"}'
cat >/dev/null
`)

	m := newTestManager(t, root)
	ctx := context.Background()
	require.NoError(t, m.SetEnabled(ctx, "future", true, nil))

	eventually(t, "the bridge to be refused", func() bool {
		p := m.Providers(ctx)
		return len(p) == 1 && p[0].LastError != ""
	})

	assert.Contains(t, m.Providers(ctx)[0].LastError, "protocol 99")
}

// Sending writes a pending row immediately, then reconciles it to the id the
// bridge assigned -- without leaving a duplicate behind.
func TestSendReconcilesPendingMessage(t *testing.T) {
	root := t.TempDir()
	writePlugin(t, root, "echo", "", echoScript)

	m := newTestManager(t, root)
	ctx := context.Background()
	require.NoError(t, m.SetEnabled(ctx, "echo", true, nil))

	eventually(t, "the bridge to connect", func() bool {
		p := m.Providers(ctx)
		return len(p) == 1 && p[0].State == chat.StateConnected
	})

	b, err := m.bridgeFor("echo")
	require.NoError(t, err)
	eventually(t, "capabilities to arrive", func() bool { return b.HasCapability(CapSend) })

	frame, err := b.call(ctx, MethodSend, map[string]any{"chatId": "c1", "text": "hello"})
	require.NoError(t, err)

	var res sendResult
	require.NoError(t, json.Unmarshal(frame.Result, &res))
	assert.Equal(t, "sent-1", res.MessageID)
}

// A bridge that never answers must not wedge a caller forever.
func TestCallOnStoppedBridgeFails(t *testing.T) {
	root := t.TempDir()
	writePlugin(t, root, "echo", "", echoScript)

	m := newTestManager(t, root)

	_, err := m.bridgeFor("echo")
	assert.ErrorContains(t, err, "not enabled")

	_, err = m.bridgeFor("nope")
	assert.ErrorContains(t, err, "unknown chat provider")
}

// Uninstalling a plugin stops its bridge and drops it from the provider list.
func TestRescanDropsRemovedPlugins(t *testing.T) {
	root := t.TempDir()
	dir := writePlugin(t, root, "echo", "", echoScript)

	m := newTestManager(t, root)
	ctx := context.Background()
	require.NoError(t, m.SetEnabled(ctx, "echo", true, nil))

	eventually(t, "the bridge to connect", func() bool {
		p := m.Providers(ctx)
		return len(p) == 1 && p[0].State == chat.StateConnected
	})
	pid := m.Providers(ctx)[0].PID

	require.NoError(t, os.RemoveAll(dir))
	m.Rescan()

	assert.Empty(t, m.Providers(ctx))
	eventually(t, "the orphaned bridge to exit", func() bool { return !processAlive(pid) })
}

// Batched messages are stored in one go; this is the history-sync path.
func TestBatchIngest(t *testing.T) {
	root := t.TempDir()
	writePlugin(t, root, "sync", "", `#!/bin/sh
echo '{"event":"ready","protocol":1,"capabilities":[]}'
echo '{"event":"sync","done":0,"total":3}'
echo '{"event":"messages","messages":[{"id":"a","chatId":"c1","ts":100,"text":"1"},{"id":"b","chatId":"c1","ts":200,"text":"2"},{"id":"c","chatId":"c1","ts":300,"text":"3"}]}'
echo '{"event":"sync","done":3,"total":3}'
cat >/dev/null
`)

	m := newTestManager(t, root)
	ctx := context.Background()
	require.NoError(t, m.SetEnabled(ctx, "sync", true, nil))

	eventually(t, "the batch to be stored", func() bool {
		msgs, _, err := m.Store().Page(ctx, "sync", "c1", 0, 10)
		return err == nil && len(msgs) == 3
	})

	msgs, _, err := m.Store().Page(ctx, "sync", "c1", 0, 10)
	require.NoError(t, err)
	assert.Equal(t, "1", msgs[0].Text, "batches land in chronological order")
	assert.Equal(t, "3", msgs[2].Text)

	m.mu.RLock()
	_, syncing := m.sync["sync"]
	m.mu.RUnlock()
	assert.False(t, syncing, "a completed sync clears its progress")
}

// A line that is not JSON -- most often a bridge logging to stdout by mistake
// -- must not take down an otherwise working session.
func TestGarbageOnStdoutIsSurvivable(t *testing.T) {
	root := t.TempDir()
	writePlugin(t, root, "noisy", "", `#!/bin/sh
echo 'starting up, please wait'
echo '{"event":"ready","protocol":1,"capabilities":[]}'
echo 'not json either'
echo '{"event":"chat","chat":{"id":"c1","name":"Still Works","lastTs":1000}}'
cat >/dev/null
`)

	m := newTestManager(t, root)
	ctx := context.Background()
	require.NoError(t, m.SetEnabled(ctx, "noisy", true, nil))

	eventually(t, "the chat after the garbage to be stored", func() bool {
		chats, err := m.Store().Chats(ctx, 10)
		return err == nil && len(chats) == 1
	})

	chats, err := m.Store().Chats(ctx, 10)
	require.NoError(t, err)
	assert.Equal(t, "Still Works", chats[0].Name)
}

// A bridge that omits unread must not clear a badge the host derived itself.
func TestChatUpsertPreservesDerivedUnread(t *testing.T) {
	root := t.TempDir()
	m := newTestManager(t, root)
	ctx := context.Background()

	require.NoError(t, m.store.TouchChat(ctx, "p", "c1", "Chat", "hi", 100, false, true))
	require.NoError(t, m.store.TouchChat(ctx, "p", "c1", "Chat", "hi", 200, false, true))

	m.ingestChats(ctx, "p", []wireChat{{ID: "c1", Name: "Chat Renamed", LastTS: 300}})

	c, err := m.store.ChatByID(ctx, "p", "c1")
	require.NoError(t, err)
	assert.Equal(t, 2, c.Unread, "an unread-less update leaves the count alone")
	assert.Equal(t, "Chat Renamed", c.Name)

	zero := 0
	m.ingestChats(ctx, "p", []wireChat{{ID: "c1", Unread: &zero, LastTS: 300}})

	c, err = m.store.ChatByID(ctx, "p", "c1")
	require.NoError(t, err)
	assert.Zero(t, c.Unread, "an explicit zero does clear it")
}

func processAlive(pid int) bool {
	if pid <= 0 {
		return false
	}
	proc, err := os.FindProcess(pid)
	if err != nil {
		return false
	}
	return proc.Signal(os.Signal(nil)) == nil
}
