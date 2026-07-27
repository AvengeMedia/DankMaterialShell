package network

import (
	"crypto/sha256"
	"fmt"

	"github.com/yeqown/go-qrcode/v2"
	"github.com/yeqown/go-qrcode/writer/standard"
)

const textQRCodeTmpPrefix = "/tmp/dank-text-qrcode-"

func GenerateTextQRCode(text string) ([2]string, error) {
	qrc, err := qrcode.New(text)
	if err != nil {
		return [2]string{}, fmt.Errorf("failed to create QR code for text: %w", err)
	}

	pathThemed, pathNormal := textQRCodePaths(text)

	wThemed, err := standard.New(
		pathThemed,
		standard.WithBuiltinImageEncoder(standard.PNG_FORMAT),
		standard.WithBgTransparent(),
		standard.WithFgColorRGBHex("#ffffff"),
	)
	if err != nil {
		return [2]string{}, fmt.Errorf("failed to create themed QR code writer: %w", err)
	}
	if err := qrc.Save(wThemed); err != nil {
		return [2]string{}, fmt.Errorf("failed to save themed QR code: %w", err)
	}

	wNormal, err := standard.New(pathNormal, standard.WithBuiltinImageEncoder(standard.PNG_FORMAT))
	if err != nil {
		return [2]string{}, fmt.Errorf("failed to create normal QR code writer: %w", err)
	}
	if err := qrc.Save(wNormal); err != nil {
		return [2]string{}, fmt.Errorf("failed to save normal QR code: %w", err)
	}

	return [2]string{pathThemed, pathNormal}, nil
}

func textQRCodePaths(text string) (themed, normal string) {
	hash := fmt.Sprintf("%x", sha256.Sum256([]byte(text)))[:16]
	themed = fmt.Sprintf("%s%s-themed.png", textQRCodeTmpPrefix, hash)
	normal = fmt.Sprintf("%s%s-normal.png", textQRCodeTmpPrefix, hash)
	return
}
