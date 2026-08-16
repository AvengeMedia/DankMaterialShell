package chat

import (
	"context"
	"encoding/base64"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestStoreWritesUnderProviderDir(t *testing.T) {
	m := NewMedia(t.TempDir(), 0)

	path, err := m.Store("whatsapp", "m1", "image/jpeg", []byte("bytes"))
	require.NoError(t, err)

	assert.Equal(t, ".jpg", filepath.Ext(path))
	assert.Equal(t, m.DirFor("whatsapp"), filepath.Dir(path))

	data, err := os.ReadFile(path)
	require.NoError(t, err)
	assert.Equal(t, "bytes", string(data))

	info, err := os.Stat(path)
	require.NoError(t, err)
	assert.Equal(t, os.FileMode(0o600), info.Mode().Perm(), "attachments are not world-readable")
}

// Message ids come from a bridge and routinely contain slashes and '@'. They
// must never be able to escape the cache directory.
func TestSanitizeContainsUntrustedIDs(t *testing.T) {
	m := NewMedia(t.TempDir(), 0)

	path, err := m.Store("../../etc", "../../../passwd", "image/png", []byte("x"))
	require.NoError(t, err)

	rel, err := filepath.Rel(m.Root(), path)
	require.NoError(t, err)
	assert.False(t, strings.HasPrefix(rel, ".."), "path escaped the cache root: %s", rel)
}

func TestStoreBase64(t *testing.T) {
	m := NewMedia(t.TempDir(), 0)

	encoded := base64.StdEncoding.EncodeToString([]byte("thumb"))
	path, err := m.StoreBase64("p", "m1", "image/png", encoded)
	require.NoError(t, err)

	data, err := os.ReadFile(path)
	require.NoError(t, err)
	assert.Equal(t, "thumb", string(data))

	_, err = m.StoreBase64("p", "m2", "image/png", "not base64!!")
	assert.Error(t, err)
}

// A bridge that already wrote into its own media dir should not have its file
// copied a second time.
func TestAdoptLeavesFilesAlreadyInCache(t *testing.T) {
	m := NewMedia(t.TempDir(), 0)

	dir, err := m.EnsureDirFor("p")
	require.NoError(t, err)
	original := filepath.Join(dir, "already.jpg")
	require.NoError(t, os.WriteFile(original, []byte("x"), 0o600))

	path, err := m.Adopt("p", "m1", "image/jpeg", original)
	require.NoError(t, err)
	assert.Equal(t, original, path)
}

// A file from anywhere else is copied in, so the cache stays self-contained
// and can be evicted as a unit.
func TestAdoptCopiesOutsideFiles(t *testing.T) {
	m := NewMedia(t.TempDir(), 0)

	outside := filepath.Join(t.TempDir(), "photo.png")
	require.NoError(t, os.WriteFile(outside, []byte("payload"), 0o600))

	path, err := m.Adopt("p", "m1", "", outside)
	require.NoError(t, err)
	assert.NotEqual(t, outside, path)
	assert.True(t, within(m.Root(), path))

	data, err := os.ReadFile(path)
	require.NoError(t, err)
	assert.Equal(t, "payload", string(data))
}

// A dangling path renders as a permanently broken image, so it is reported
// rather than quietly recorded.
func TestAdoptRejectsMissingFile(t *testing.T) {
	m := NewMedia(t.TempDir(), 0)

	_, err := m.Adopt("p", "m1", "", "/nonexistent/nope.png")
	assert.Error(t, err)

	path, err := m.Adopt("p", "m1", "", "")
	require.NoError(t, err, "an absent path is simply no media")
	assert.Empty(t, path)
}

func TestGCEvictsUnreferencedFirst(t *testing.T) {
	ctx := context.Background()
	store := newStore(t)

	// Room for roughly two of the three files below.
	m := NewMedia(t.TempDir(), 20)

	keep, err := m.Store("p", "keep", "image/png", make([]byte, 10))
	require.NoError(t, err)
	drop, err := m.Store("p", "drop", "image/png", make([]byte, 10))
	require.NoError(t, err)
	_, err = m.Store("p", "spare", "image/png", make([]byte, 10))
	require.NoError(t, err)

	// Only "keep" is still referenced by a message.
	require.NoError(t, store.PutMessage(ctx, Message{
		Provider: "p", ID: "keep", ChatID: "c1", TS: 100, Kind: KindImage, MediaPath: keep,
	}))

	freed, err := m.GC(ctx, store)
	require.NoError(t, err)
	assert.Positive(t, freed)

	_, err = os.Stat(keep)
	assert.NoError(t, err, "referenced media survives while unreferenced media remains to evict")

	_, dropErr := os.Stat(drop)
	assert.True(t, os.IsNotExist(dropErr), "unreferenced media is evicted first")
}

func TestGCNoopUnderLimit(t *testing.T) {
	m := NewMedia(t.TempDir(), 1<<20)
	_, err := m.Store("p", "m1", "image/png", make([]byte, 10))
	require.NoError(t, err)

	freed, err := m.GC(context.Background(), nil)
	require.NoError(t, err)
	assert.Zero(t, freed)
}

// Eviction within the referenced set is oldest-first.
func TestGCEvictsOldestFirst(t *testing.T) {
	m := NewMedia(t.TempDir(), 20)

	old, err := m.Store("p", "old", "image/png", make([]byte, 10))
	require.NoError(t, err)
	recent, err := m.Store("p", "recent", "image/png", make([]byte, 10))
	require.NoError(t, err)
	_, err = m.Store("p", "newest", "image/png", make([]byte, 10))
	require.NoError(t, err)

	past := time.Now().Add(-48 * time.Hour)
	require.NoError(t, os.Chtimes(old, past, past))
	mid := time.Now().Add(-24 * time.Hour)
	require.NoError(t, os.Chtimes(recent, mid, mid))

	_, err = m.GC(context.Background(), nil)
	require.NoError(t, err)

	_, err = os.Stat(old)
	assert.True(t, os.IsNotExist(err), "oldest evicted first")
}

func TestSizeAndPurgeProvider(t *testing.T) {
	m := NewMedia(t.TempDir(), 0)

	_, err := m.Store("alpha", "m1", "image/png", make([]byte, 100))
	require.NoError(t, err)
	_, err = m.Store("beta", "m2", "image/png", make([]byte, 50))
	require.NoError(t, err)

	size, err := m.Size()
	require.NoError(t, err)
	assert.Equal(t, int64(150), size)

	require.NoError(t, m.PurgeProvider("alpha"))

	size, err = m.Size()
	require.NoError(t, err)
	assert.Equal(t, int64(50), size)

	assert.NoError(t, m.PurgeProvider("never-existed"))
}

func TestExtensionFor(t *testing.T) {
	assert.Equal(t, ".jpg", extensionFor("image/jpeg"))
	assert.Equal(t, ".jpg", extensionFor("image/jpeg; charset=binary"))
	assert.Equal(t, ".png", extensionFor("IMAGE/PNG"))
	assert.Equal(t, ".webm", extensionFor("video/webm"))
	assert.Equal(t, ".bin", extensionFor(""))
	assert.Equal(t, ".bin", extensionFor("nonsense"))
	assert.Equal(t, ".heic", extensionFor("image/heic"), "unknown subtypes still get a usable extension")
}
