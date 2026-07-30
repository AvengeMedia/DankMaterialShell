package network

import (
	"crypto/sha256"
	"fmt"
	"os"
	"time"

	"github.com/yeqown/go-qrcode/v2"
	"github.com/yeqown/go-qrcode/writer/standard"
)

const textQRCodeTmpPrefix = "/tmp/dank-text-qrcode-"

func generateTextQRCode(text string) ([2]string, error) {
	qrc, err := qrcode.New(text)
	if err != nil {
		return [2]string{}, fmt.Errorf("failed to create QR code for text: %w", err)
	}

	pathThemed, pathNormal := textQRCodePaths(text)

	if err := saveQRCodePNG(qrc, pathThemed, standard.WithBgTransparent(), standard.WithFgColorRGBHex("#ffffff")); err != nil {
		return [2]string{}, err
	}
	if err := saveQRCodePNG(qrc, pathNormal); err != nil {
		return [2]string{}, err
	}

	return [2]string{pathThemed, pathNormal}, nil
}

// Write to a temp file and rename into place so the shell's Image never
// observes a partially written PNG.
func saveQRCodePNG(qrc *qrcode.QRCode, path string, opts ...standard.ImageOption) error {
	tmpPath := path + ".tmp"
	opts = append(opts, standard.WithBuiltinImageEncoder(standard.PNG_FORMAT))

	w, err := standard.New(tmpPath, opts...)
	if err != nil {
		return fmt.Errorf("failed to create QR code writer: %w", err)
	}
	if err := qrc.Save(w); err != nil {
		os.Remove(tmpPath)
		return fmt.Errorf("failed to save QR code: %w", err)
	}
	if err := os.Rename(tmpPath, path); err != nil {
		os.Remove(tmpPath)
		return fmt.Errorf("failed to move QR code into place: %w", err)
	}
	return nil
}

// Paths are unique per generation, not per text: the library's mask selection
// is non-deterministic, so regenerating the same text produces different
// bytes, and reusing a path lets the shell's URL-keyed pixmap cache serve a
// stale pattern over the new file.
func textQRCodePaths(text string) (themed, normal string) {
	hash := fmt.Sprintf("%x", sha256.Sum256([]byte(text)))[:8]
	nonce := time.Now().UnixNano()
	themed = fmt.Sprintf("%s%s-%d-themed.png", textQRCodeTmpPrefix, hash, nonce)
	normal = fmt.Sprintf("%s%s-%d-normal.png", textQRCodeTmpPrefix, hash, nonce)
	return
}
