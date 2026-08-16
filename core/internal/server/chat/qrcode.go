package chat

import (
	"crypto/sha256"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/yeqown/go-qrcode/v2"
	"github.com/yeqown/go-qrcode/writer/standard"
)

// Device-linking by QR is how most messaging services pair a new client, so
// rendering one is host-side work rather than something every bridge author
// has to solve. A bridge sends the payload string; this turns it into an image.

// renderAuthQRCode writes the challenge as two PNGs -- one for dark surfaces,
// one for light -- and returns their paths.
func renderAuthQRCode(cacheRoot, provider, payload string) (themed, normal string, err error) {
	if payload == "" {
		return "", "", fmt.Errorf("no sign-in challenge to render")
	}

	qrc, err := qrcode.New(payload)
	if err != nil {
		return "", "", fmt.Errorf("build qr code: %w", err)
	}

	dir := filepath.Join(cacheRoot, "auth")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return "", "", fmt.Errorf("create qr dir: %w", err)
	}

	// Paths are unique per render, not per payload: the encoder's mask choice
	// is non-deterministic, so reusing a path lets the shell's URL-keyed pixmap
	// cache serve a stale pattern over the new file.
	hash := fmt.Sprintf("%x", sha256.Sum256([]byte(payload)))[:8]
	nonce := time.Now().UnixNano()
	base := filepath.Join(dir, fmt.Sprintf("%s-%s-%d", sanitize(provider), hash, nonce))

	themed = base + "-themed.png"
	normal = base + "-normal.png"

	if err := writeQRCodePNG(qrc, themed, standard.WithBgTransparent(), standard.WithFgColorRGBHex("#ffffff")); err != nil {
		return "", "", err
	}
	if err := writeQRCodePNG(qrc, normal); err != nil {
		os.Remove(themed)
		return "", "", err
	}

	pruneOldQRCodes(dir, themed, normal)
	return themed, normal, nil
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

// pruneOldQRCodes drops previously rendered challenges. Each render is written
// to a fresh path, so without this a stubborn sign-in leaves a trail of images
// behind, each holding a linkable credential.
func pruneOldQRCodes(dir string, keep ...string) {
	kept := map[string]bool{}
	for _, k := range keep {
		kept[k] = true
	}

	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	for _, entry := range entries {
		path := filepath.Join(dir, entry.Name())
		if !kept[path] {
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
