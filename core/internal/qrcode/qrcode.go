package qrcode

import (
	"bytes"
	"fmt"
	"image"
	"image/color"
	_ "image/jpeg"
	_ "image/png"
	"os"
	"strings"

	qr "github.com/yeqown/go-qrcode/v2"
	"github.com/yeqown/go-qrcode/writer/standard"
)

type TermOptions struct {
	ECC       string
	Version   int
	QuietZone int
	Invert    bool
	Fg        string
	Bg        string
}

type ImageOptions struct {
	ECC         string
	Version     int
	ModuleSize  int
	Fg          string
	Bg          string
	Transparent bool
	Border      int
	Shape       string
	Logo        string
	LogoScale   int
}

var wifiEscaper = strings.NewReplacer(`\`, `\\`, `;`, `\;`, `,`, `\,`, `:`, `\:`, `"`, `\"`)

func WiFiString(security, ssid, password string, hidden bool) string {
	if security == "" {
		security = "WPA"
	}
	var b strings.Builder
	fmt.Fprintf(&b, "WIFI:T:%s;S:%s;", security, wifiEscaper.Replace(ssid))
	if !strings.EqualFold(security, "nopass") {
		fmt.Fprintf(&b, "P:%s;", wifiEscaper.Replace(password))
	}
	if hidden {
		b.WriteString("H:true;")
	}
	b.WriteString(";")
	return b.String()
}

// Colors are painted explicitly on both halves of each ▀ cell so polarity
// does not depend on the terminal theme.
func RenderTerminal(text string, opt TermOptions) (string, error) {
	fg, err := parseColor(opt.Fg, color.RGBA{A: 255})
	if err != nil {
		return "", err
	}
	bg, err := parseColor(opt.Bg, color.RGBA{R: 255, G: 255, B: 255, A: 255})
	if err != nil {
		return "", err
	}
	if opt.Invert {
		fg, bg = bg, fg
	}

	mat, err := encode(text, opt.ECC, opt.Version)
	if err != nil {
		return "", err
	}
	grid := bitmapWithQuietZone(mat, opt.QuietZone)

	var b strings.Builder
	for y := 0; y < len(grid); y += 2 {
		for x := range grid[y] {
			top := moduleColor(grid[y][x], fg, bg)
			bottom := bg
			if y+1 < len(grid) {
				bottom = moduleColor(grid[y+1][x], fg, bg)
			}
			fmt.Fprintf(&b, "\x1b[38;2;%d;%d;%dm\x1b[48;2;%d;%d;%dm▀", top.R, top.G, top.B, bottom.R, bottom.G, bottom.B)
		}
		b.WriteString("\x1b[0m\n")
	}
	return b.String(), nil
}

func RenderPNG(text string, opt ImageOptions) ([]byte, error) {
	encOpts, err := encodeOptions(opt.ECC, opt.Version)
	if err != nil {
		return nil, err
	}
	imgOpts, err := imageOptions(opt)
	if err != nil {
		return nil, err
	}

	q, err := qr.NewWith(text, encOpts...)
	if err != nil {
		return nil, err
	}

	var buf bytes.Buffer
	w := standard.NewWithWriter(nopCloser{&buf}, imgOpts...)
	if err := q.Save(w); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func encodeOptions(ecc string, version int) ([]qr.EncodeOption, error) {
	eccOpt, err := eccOption(ecc)
	if err != nil {
		return nil, err
	}
	opts := []qr.EncodeOption{eccOpt}
	switch {
	case version == 0:
	case version >= 1 && version <= 40:
		opts = append(opts, qr.WithVersion(version))
	default:
		return nil, fmt.Errorf("QR version must be 1-40, got %d", version)
	}
	return opts, nil
}

func eccOption(level string) (qr.EncodeOption, error) {
	switch strings.ToUpper(level) {
	case "", "M":
		return qr.WithErrorCorrectionLevel(qr.ErrorCorrectionMedium), nil
	case "L":
		return qr.WithErrorCorrectionLevel(qr.ErrorCorrectionLow), nil
	case "Q":
		return qr.WithErrorCorrectionLevel(qr.ErrorCorrectionQuart), nil
	case "H":
		return qr.WithErrorCorrectionLevel(qr.ErrorCorrectionHighest), nil
	default:
		return nil, fmt.Errorf("invalid error correction level %q (want L, M, Q, or H)", level)
	}
}

func imageOptions(opt ImageOptions) ([]standard.ImageOption, error) {
	if opt.ModuleSize < 0 || opt.ModuleSize > 255 {
		return nil, fmt.Errorf("module size must be 0-255, got %d", opt.ModuleSize)
	}

	opts := []standard.ImageOption{standard.WithBuiltinImageEncoder(standard.PNG_FORMAT)}
	if opt.ModuleSize > 0 {
		opts = append(opts, standard.WithQRWidth(uint8(opt.ModuleSize)))
	}
	if opt.Border >= 0 {
		opts = append(opts, standard.WithBorderWidth(opt.Border))
	}

	switch {
	case opt.Transparent:
		opts = append(opts, standard.WithBgTransparent())
	case opt.Bg != "":
		c, err := parseColor(opt.Bg, color.RGBA{})
		if err != nil {
			return nil, err
		}
		opts = append(opts, standard.WithBgColor(c))
	}
	if opt.Fg != "" {
		c, err := parseColor(opt.Fg, color.RGBA{})
		if err != nil {
			return nil, err
		}
		opts = append(opts, standard.WithFgColor(c))
	}

	switch strings.ToLower(opt.Shape) {
	case "", "square":
	case "circle":
		opts = append(opts, standard.WithCircleShape())
	default:
		return nil, fmt.Errorf("invalid shape %q (want square or circle)", opt.Shape)
	}

	if opt.Logo != "" {
		img, err := loadImage(opt.Logo)
		if err != nil {
			return nil, err
		}
		opts = append(opts, standard.WithLogoImage(img))
		if opt.LogoScale > 0 {
			opts = append(opts, standard.WithLogoSizeMultiplier(opt.LogoScale))
		}
	}
	return opts, nil
}

func encode(text, ecc string, version int) (qr.Matrix, error) {
	opts, err := encodeOptions(ecc, version)
	if err != nil {
		return qr.Matrix{}, err
	}
	q, err := qr.NewWith(text, opts...)
	if err != nil {
		return qr.Matrix{}, err
	}
	mw := &matrixWriter{}
	if err := q.Save(mw); err != nil {
		return qr.Matrix{}, err
	}
	return mw.mat, nil
}

func bitmapWithQuietZone(mat qr.Matrix, quiet int) [][]bool {
	if quiet < 0 {
		quiet = 0
	}
	src := mat.Bitmap()
	h := len(src)
	w := 0
	if h > 0 {
		w = len(src[0])
	}
	out := make([][]bool, h+quiet*2)
	for y := range out {
		out[y] = make([]bool, w+quiet*2)
	}
	for y := range h {
		for x := range w {
			out[y+quiet][x+quiet] = src[y][x]
		}
	}
	return out
}

func moduleColor(dark bool, fg, bg color.RGBA) color.RGBA {
	if dark {
		return fg
	}
	return bg
}

func parseColor(hex string, def color.RGBA) (color.RGBA, error) {
	hex = strings.TrimPrefix(strings.TrimSpace(hex), "#")
	if hex == "" {
		return def, nil
	}
	if len(hex) == 3 {
		hex = fmt.Sprintf("%c%c%c%c%c%c", hex[0], hex[0], hex[1], hex[1], hex[2], hex[2])
	}
	var r, g, b int
	if len(hex) != 6 {
		return def, fmt.Errorf("invalid color %q (want #RGB or #RRGGBB)", hex)
	}
	if _, err := fmt.Sscanf(hex, "%02x%02x%02x", &r, &g, &b); err != nil {
		return def, fmt.Errorf("invalid color %q (want #RGB or #RRGGBB)", hex)
	}
	return color.RGBA{R: uint8(r), G: uint8(g), B: uint8(b), A: 255}, nil
}

func loadImage(path string) (image.Image, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	img, _, err := image.Decode(f)
	if err != nil {
		return nil, fmt.Errorf("decode %s: %w", path, err)
	}
	return img, nil
}

type matrixWriter struct{ mat qr.Matrix }

func (w *matrixWriter) Write(m qr.Matrix) error { w.mat = m; return nil }
func (w *matrixWriter) Close() error            { return nil }

type nopCloser struct{ *bytes.Buffer }

func (nopCloser) Close() error { return nil }
