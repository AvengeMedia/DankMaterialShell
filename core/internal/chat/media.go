package chat

import (
	"context"
	"encoding/base64"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// Media owns the on-disk attachment cache.
//
// Binary data never travels as a message payload -- bridges hand over a path or
// a small base64 thumbnail, and everything downstream deals in absolute paths
// that QML can bind straight to an Image source. This mirrors how the clipboard
// serves decoded images.
type Media struct {
	root    string
	maxSize int64
}

// DefaultMaxCacheSize is the eviction threshold when the user has not chosen
// one. Attachment caches grow without bound otherwise; the previous chat
// implementation never evicted at all.
const DefaultMaxCacheSize = 512 << 20 // 512 MiB

// NewMedia returns a cache rooted at root. A maxSize of zero means the default.
func NewMedia(root string, maxSize int64) *Media {
	if maxSize <= 0 {
		maxSize = DefaultMaxCacheSize
	}
	return &Media{root: root, maxSize: maxSize}
}

// Root is the cache directory.
func (m *Media) Root() string { return m.root }

// DirFor is the directory handed to a provider's bridge at configure time, for
// bridges that would rather write attachment files themselves.
func (m *Media) DirFor(provider string) string {
	return filepath.Join(m.root, sanitizeComponent(provider))
}

// EnsureDirFor creates and returns a provider's media directory.
func (m *Media) EnsureDirFor(provider string) (string, error) {
	dir := m.DirFor(provider)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return "", fmt.Errorf("create media dir: %w", err)
	}
	return dir, nil
}

// Store writes attachment bytes for a message and returns the file path.
//
// Keyed by message id so a redelivery of the same message reuses the same file
// rather than accumulating copies.
func (m *Media) Store(provider, messageID, mimeType string, data []byte) (string, error) {
	dir, err := m.EnsureDirFor(provider)
	if err != nil {
		return "", err
	}

	path := filepath.Join(dir, sanitizeComponent(messageID)+extensionFor(mimeType))
	if err := os.WriteFile(path, data, 0o600); err != nil {
		return "", fmt.Errorf("write media: %w", err)
	}
	return path, nil
}

// StoreBase64 decodes an inline thumbnail from a bridge event and caches it.
func (m *Media) StoreBase64(provider, messageID, mimeType, encoded string) (string, error) {
	data, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return "", fmt.Errorf("decode media: %w", err)
	}
	return m.Store(provider, messageID, mimeType, data)
}

// Adopt takes a path a bridge wrote and returns the path to record.
//
// A bridge that wrote into its own media directory already put the file where
// we want it; anything else gets copied in, so the cache stays self-contained
// and evictable. A missing file is reported rather than silently recorded,
// since a dangling path renders as a broken image forever.
func (m *Media) Adopt(provider, messageID, mimeType, path string) (string, error) {
	if path == "" {
		return "", nil
	}

	info, err := os.Stat(path)
	if err != nil {
		return "", fmt.Errorf("media path unreadable: %w", err)
	}
	if info.IsDir() {
		return "", fmt.Errorf("media path is a directory: %s", path)
	}

	if within(m.DirFor(provider), path) {
		return path, nil
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("read media: %w", err)
	}
	if mimeType == "" {
		mimeType = mimeForExtension(filepath.Ext(path))
	}
	return m.Store(provider, messageID, mimeType, data)
}

// KindForPath guesses a message kind from a file's extension.
//
// Used when recording what the user just sent: the store has to know it is an
// image for the bubble to render it, and the file is all there is to go on.
func KindForPath(path string) string {
	mime := mimeForExtension(filepath.Ext(path))
	switch {
	case strings.HasPrefix(mime, "image/"):
		return KindImage
	case strings.HasPrefix(mime, "video/"):
		return KindVideo
	case strings.HasPrefix(mime, "audio/"):
		return KindAudio
	}
	return KindDocument
}

// MimeForPath is the mime type implied by a file's extension, or "".
func MimeForPath(path string) string {
	return mimeForExtension(filepath.Ext(path))
}

// Size reports the cache's total size on disk.
func (m *Media) Size() (int64, error) {
	var total int64
	err := filepath.WalkDir(m.root, func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}
		info, err := d.Info()
		if err != nil {
			return nil
		}
		total += info.Size()
		return nil
	})
	if os.IsNotExist(err) {
		return 0, nil
	}
	return total, err
}

// GC evicts least-recently-modified files until the cache fits under its limit.
//
// Files still referenced by a message are evictable: the bridge can re-fetch
// them through the message's media ref, so losing a cached copy costs a
// download rather than the attachment itself. Files the store no longer
// references at all go first.
func (m *Media) GC(ctx context.Context, store *HistoryStore) (freed int64, err error) {
	type entry struct {
		path       string
		size       int64
		modUnix    int64
		referenced bool
	}

	referenced := map[string]bool{}
	if store != nil {
		paths, err := store.MediaPaths(ctx)
		if err != nil {
			return 0, err
		}
		for _, p := range paths {
			referenced[p] = true
		}
	}

	var entries []entry
	var total int64
	err = filepath.WalkDir(m.root, func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}
		info, ierr := d.Info()
		if ierr != nil {
			return nil
		}
		entries = append(entries, entry{
			path:       path,
			size:       info.Size(),
			modUnix:    info.ModTime().Unix(),
			referenced: referenced[path],
		})
		total += info.Size()
		return nil
	})
	if os.IsNotExist(err) {
		return 0, nil
	}
	if err != nil {
		return 0, err
	}

	if total <= m.maxSize {
		return 0, nil
	}

	// Unreferenced first, then oldest first.
	sort.Slice(entries, func(i, j int) bool {
		if entries[i].referenced != entries[j].referenced {
			return !entries[i].referenced
		}
		return entries[i].modUnix < entries[j].modUnix
	})

	for _, e := range entries {
		if total <= m.maxSize {
			break
		}
		if err := os.Remove(e.path); err != nil {
			continue
		}
		total -= e.size
		freed += e.size
	}
	return freed, nil
}

// Rename moves a cached attachment from one message id to another.
//
// Sending assigns a placeholder id before the provider answers with a real one;
// without this the file keeps the placeholder's name and the next sweep treats
// it as unreferenced.
func (m *Media) Rename(provider, fromID, toID, path string) (string, error) {
	if path == "" {
		return "", fmt.Errorf("no attachment to move")
	}

	dir := m.DirFor(provider)
	target := filepath.Join(dir, sanitizeComponent(toID)+filepath.Ext(path))
	if target == path {
		return path, nil
	}

	if err := os.Rename(path, target); err != nil {
		return "", fmt.Errorf("move attachment: %w", err)
	}
	return target, nil
}

// PurgeProvider removes a provider's cached attachments.
func (m *Media) PurgeProvider(provider string) error {
	err := os.RemoveAll(m.DirFor(provider))
	if os.IsNotExist(err) {
		return nil
	}
	return err
}

// within reports whether path sits inside dir.
func within(dir, path string) bool {
	rel, err := filepath.Rel(dir, path)
	if err != nil {
		return false
	}
	return rel != ".." && !strings.HasPrefix(rel, ".."+string(filepath.Separator))
}

// sanitizeComponent makes an arbitrary provider or message id safe as one path
// segment. Bridge-supplied ids are untrusted input and routinely contain
// slashes, '@' and ':'.
func sanitizeComponent(s string) string {
	if s == "" {
		return "_"
	}

	var b strings.Builder
	for _, r := range s {
		switch {
		case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9', r == '-', r == '.':
			b.WriteRune(r)
		default:
			b.WriteByte('_')
		}
	}

	out := strings.Trim(b.String(), ".")
	if out == "" {
		return "_"
	}
	if len(out) > 128 {
		out = out[:128]
	}
	return out
}

var mimeExtensions = map[string]string{
	"image/jpeg":      ".jpg",
	"image/png":       ".png",
	"image/gif":       ".gif",
	"image/webp":      ".webp",
	"video/mp4":       ".mp4",
	"video/webm":      ".webm",
	"audio/ogg":       ".ogg",
	"audio/mpeg":      ".mp3",
	"audio/mp4":       ".m4a",
	"application/pdf": ".pdf",
}

func extensionFor(mimeType string) string {
	mimeType = strings.ToLower(strings.TrimSpace(strings.SplitN(mimeType, ";", 2)[0]))
	if ext, ok := mimeExtensions[mimeType]; ok {
		return ext
	}
	if _, sub, ok := strings.Cut(mimeType, "/"); ok && sub != "" {
		if clean := sanitizeComponent(sub); clean != "_" {
			return "." + clean
		}
	}
	return ".bin"
}

func mimeForExtension(ext string) string {
	ext = strings.ToLower(ext)
	for mimeType, e := range mimeExtensions {
		if e == ext {
			return mimeType
		}
	}
	return ""
}
