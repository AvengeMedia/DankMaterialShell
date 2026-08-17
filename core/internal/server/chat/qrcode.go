package chat

import (
	"crypto/sha256"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/yeqown/go-qrcode/v2"
	"github.com/yeqown/go-qrcode/writer/standard"
)

// Device-linking by QR is how most messaging services pair a new client, so
// rendering one is host-side work rather than something every bridge author
// has to solve. A bridge sends the payload string; this turns it into an image.

// qrRenderMu serialises rendering.
//
// Challenges rotate every few seconds and more than one panel may ask for the
// same one at once. Without this, one render's cleanup deletes another's
// half-written temp file and the second fails with a bewildering rename error.
var qrRenderMu sync.Mutex

// renderAuthQRCode writes the challenge as a PNG and returns its path.
//
// One image, deliberately: it is drawn black-on-white because every consumer
// puts it on a white plate for scanner contrast. A second white-on-transparent
// variant used to exist for dark surfaces, and picking the wrong one rendered
// white on white -- an invisible code on an apparently blank panel.
func renderAuthQRCode(cacheRoot, provider, payload string) (string, error) {
	if payload == "" {
		return "", fmt.Errorf("no sign-in challenge to render")
	}

	qrRenderMu.Lock()
	defer qrRenderMu.Unlock()

	qrc, err := qrcode.New(payload)
	if err != nil {
		return "", fmt.Errorf("build qr code: %w", err)
	}

	dir := filepath.Join(cacheRoot, "auth")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return "", fmt.Errorf("create qr dir: %w", err)
	}

	// Unique per render, not per payload: the encoder's mask choice is
	// non-deterministic, so reusing a path lets the shell's URL-keyed pixmap
	// cache serve a stale pattern over the new file.
	hash := fmt.Sprintf("%x", sha256.Sum256([]byte(payload)))[:8]
	prefix := sanitize(provider)
	path := filepath.Join(dir, fmt.Sprintf("%s-%s-%d.png", prefix, hash, time.Now().UnixNano()))

	if err := writeQRCodePNG(qrc, path); err != nil {
		return "", err
	}

	pruneOldQRCodes(dir, prefix, path)
	return path, nil
}

// writeQRCodePNG renders to a temp file and renames into place, so the shell's
// Image never observes a partially written PNG.
func writeQRCodePNG(qrc *qrcode.QRCode, path string, opts ...standard.ImageOption) error {
	tmpPath := path + ".tmp"
	opts = append(opts, standard.WithBuiltinImageEncoder(standard.PNG_FORMAT))

	w, err := standard.New(tmpPath, opts...)
	if err != nil {
		return fmt.Errorf("create qr writer: %w", err)
	}
	if err := qrc.Save(w); err != nil {
		os.Remove(tmpPath)
		return fmt.Errorf("save qr code: %w", err)
	}
	if err := os.Rename(tmpPath, path); err != nil {
		os.Remove(tmpPath)
		return fmt.Errorf("move qr code into place: %w", err)
	}
	return nil
}

// pruneOldQRCodes drops this provider's previously rendered challenges.
//
// Each render writes a fresh path, so without this a stubborn sign-in leaves a
// trail of images behind, each holding a linkable credential.
//
// Scoped to the provider's own prefix and never touching .tmp files: a blanket
// sweep would delete another provider's code, or a render still in flight.
func pruneOldQRCodes(dir, prefix, keep string) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}

	for _, entry := range entries {
		name := entry.Name()
		if !strings.HasPrefix(name, prefix+"-") || strings.HasSuffix(name, ".tmp") {
			continue
		}

		path := filepath.Join(dir, name)
		if path != keep {
			os.Remove(path)
		}
	}
}

func sanitize(s string) string {
	out := make([]rune, 0, len(s))
	for _, r := range s {
		switch {
		case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9', r == '-':
			out = append(out, r)
		default:
			out = append(out, '_')
		}
	}
	if len(out) == 0 {
		return "provider"
	}
	return string(out)
}
