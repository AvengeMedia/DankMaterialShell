package chat

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/chat"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// The reference bridge is the contract's worked example, so it is worth running
// against the real host rather than trusting that it matches the prose. This
// builds it from source and drives the whole stack: spawn, handshake, seeded
// history, send, delivery ratchet and deferred media.
func TestEchoBridgeEndToEnd(t *testing.T) {
	if testing.Short() {
		t.Skip("builds the reference bridge; skipped under -short")
	}

	src := findEchoSource(t)
	root := t.TempDir()

	dir := filepath.Join(root, "echoChat")
	require.NoError(t, os.MkdirAll(filepath.Join(dir, "bin"), 0o755))

	build := exec.Command("go", "build", "-o", filepath.Join(dir, "bin", "echo-chat-bridge"), ".")
	build.Dir = src
	if out, err := build.CombinedOutput(); err != nil {
		t.Fatalf("could not build the reference bridge: %v\n%s", err, out)
	}

	manifest, err := os.ReadFile(filepath.Join(src, "..", "plugin.json"))
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(dir, "plugin.json"), manifest, 0o644))

	m := newTestManager(t, root)
	ctx := context.Background()

	providers := m.Providers(ctx)
	require.Len(t, providers, 1)
	assert.Equal(t, "echoChat", providers[0].ID)

	require.NoError(t, m.SetEnabled(ctx, "echoChat", true, map[string]any{
		"peerName":   "Grace Hopper",
		"echoPrefix": "heard: ",
	}))

	eventually(t, "the bridge to connect", func() bool {
		p := m.Providers(ctx)
		return len(p) == 1 && p[0].State == chat.StateConnected
	})

	status := m.Providers(ctx)[0]
	assert.Equal(t, ProtocolVersion, status.Protocol)
	assert.Contains(t, status.Capabilities, CapSend)
	assert.Contains(t, status.Capabilities, CapMedia)
	assert.NotContains(t, status.Capabilities, CapRevoke,
		"the reference bridge withholds revoke so capability gating is exercised")

	// Settings reach the bridge down the pipe, not via the shell's config file.
	eventually(t, "the configured contact name to appear", func() bool {
		chats, err := m.Store().ChatsForProvider(ctx, "echoChat", 10)
		if err != nil || len(chats) == 0 {
			return false
		}
		for _, c := range chats {
			if c.Name == "Grace Hopper" {
				return true
			}
		}
		return false
	})

	chats, err := m.Store().ChatsForProvider(ctx, "echoChat", 10)
	require.NoError(t, err)
	require.Len(t, chats, 2, "the reference bridge seeds a direct chat and a group")

	msgs, _, err := m.Store().Page(ctx, "echoChat", "echo-dm", 0, 20)
	require.NoError(t, err)
	require.NotEmpty(t, msgs)

	// The seeded photo carries a ref and no bytes: media is fetched only when
	// the user opens it, which is what keeps a large backfill cheap.
	photo, err := m.Store().MessageByID(ctx, "echoChat", "echo-dm", "echo-photo")
	require.NoError(t, err)
	assert.Equal(t, chat.KindImage, photo.Kind)
	assert.Empty(t, photo.MediaPath, "deferred media is not downloaded up front")
	assert.Equal(t, "demo-gradient", photo.MediaRef)

	// Fetching it on demand caches a real file.
	b, err := m.bridgeFor("echoChat")
	require.NoError(t, err)

	frame, err := b.call(ctx, MethodFetchMedia, map[string]any{
		"chatId": "echo-dm", "messageId": "echo-photo", "ref": photo.MediaRef,
	})
	require.NoError(t, err)
	require.NotEmpty(t, frame.Result)

	// Sending echoes back and walks the delivery ladder.
	_, err = b.call(ctx, MethodSend, map[string]any{"chatId": "echo-dm", "text": "ping"})
	require.NoError(t, err)

	eventually(t, "the echo reply to arrive", func() bool {
		msgs, _, err := m.Store().Page(ctx, "echoChat", "echo-dm", 0, 50)
		if err != nil {
			return false
		}
		for _, msg := range msgs {
			if msg.Text == "heard: ping" {
				return true
			}
		}
		return false
	})

	// An unimplemented method must come back as an error, not a hang.
	_, err = b.call(ctx, "notAThing", nil)
	assert.ErrorContains(t, err, "unknown_method")
}

// findEchoSource locates the reference bridge, walking up from the test's
// working directory so this works regardless of where `go test` was invoked.
func findEchoSource(t *testing.T) string {
	t.Helper()

	dir, err := os.Getwd()
	require.NoError(t, err)

	for i := 0; i < 6; i++ {
		candidate := filepath.Join(dir, "quickshell", "PLUGINS", "EchoChatExample", "src")
		if _, err := os.Stat(filepath.Join(candidate, "main.go")); err == nil {
			return candidate
		}
		dir = filepath.Dir(dir)
	}

	t.Skip("reference bridge source not found; run from within the repository")
	return ""
}
