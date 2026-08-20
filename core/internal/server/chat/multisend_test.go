package chat

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/chat"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// Sending several files must record several messages. Recording one row while
// the provider sent three showed a single attachment in the conversation when
// three had actually gone out.
func TestSendRecordsOneMessagePerAttachment(t *testing.T) {
	root := t.TempDir()

	// A distinct id per send, as a real provider gives. The shared echo script
	// answers with a constant one, which would collapse every attachment into a
	// single row and hide exactly the bug this is checking for.
	writePlugin(t, root, "echo", "", `#!/bin/sh
echo '{"event":"ready","protocol":1,"capabilities":["send","media"]}'
echo '{"event":"state","state":"connected"}'
echo '{"event":"chat","chat":{"id":"c1","name":"Ada","lastTs":1000}}'
n=0
while IFS= read -r line; do
  id=$(printf '%s' "$line" | sed -n 's/.*"id":\([0-9]*\).*/\1/p')
  case "$line" in
    *'"method":"send"'*)
      n=$((n+1))
      echo "{\"id\":$id,\"ok\":true,\"result\":{\"messageId\":\"sent-$n\"}}"
      ;;
    *'"method":"shutdown"'*) echo "{\"id\":$id,\"ok\":true}"; exit 0 ;;
    *) echo "{\"id\":$id,\"ok\":true}" ;;
  esac
done
`)

	m := newTestManager(t, root)
	ctx := context.Background()
	require.NoError(t, m.SetEnabled(ctx, "echo", true, nil))

	eventually(t, "the bridge to connect", func() bool {
		p := m.Providers(ctx)
		return len(p) == 1 && p[0].State == chat.StateConnected
	})

	b, err := m.bridgeFor("echo")
	require.NoError(t, err)
	eventually(t, "capabilities", func() bool { return b.HasCapability(CapSend) })

	files := make([]string, 3)
	for i := range files {
		files[i] = filepath.Join(t.TempDir(), "file.png")
		require.NoError(t, os.WriteFile(files[i], []byte("data"), 0o600))
	}

	before, _, err := m.Store().Page(ctx, "echo", "c1", 0, 100)
	require.NoError(t, err)

	for i, path := range files {
		caption := ""
		if i == 0 {
			caption = "three files"
		}
		_, err := m.sendOne(ctx, b, "echo", "c1", caption, "", path)
		require.NoError(t, err)
	}

	time.Sleep(300 * time.Millisecond)
	after, _, err := m.Store().Page(ctx, "echo", "c1", 0, 100)
	require.NoError(t, err)

	mine := 0
	withMedia := 0
	for _, msg := range after {
		if msg.FromMe {
			mine++
			if msg.MediaPath != "" {
				withMedia++
			}
		}
	}

	assert.Equal(t, 3, mine, "one message per file, not one for the batch")
	assert.Equal(t, 3, withMedia, "each carries its own attachment so it renders")
	assert.Equal(t, len(before)+3, len(after))
}
