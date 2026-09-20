package matugen

import (
	"fmt"
	"image"
	"image/png"
	"math"
	"os"
	"path/filepath"
	"strings"

	"github.com/srwiley/oksvg"
	"github.com/srwiley/rasterx"
)

// stageImageSource returns the absolute path templates see as {{image}} and,
// for an SVG, swaps opts.Value for a one-shot PNG raster matugen can decode.
// !TODO: drop the SVG raster once matugen decodes SVG; matugen 4.2.0 (material-colors 0.4.2) panics on an .svg source
func stageImageSource(opts *Options) (sourceImage string, cleanup func(), err error) {
	noop := func() {}
	if opts.Kind != "image" {
		return "", noop, nil
	}
	sourceImage = opts.Value
	if abs, err := filepath.Abs(sourceImage); err == nil {
		sourceImage = abs
	}
	if !strings.EqualFold(filepath.Ext(opts.Value), ".svg") {
		return sourceImage, noop, nil
	}
	raster, err := rasterizeSVGToPNG(opts.Value)
	if err != nil {
		return "", noop, fmt.Errorf("svg source %s: %w", opts.Value, err)
	}
	opts.Value = raster
	return sourceImage, func() { os.Remove(raster) }, nil
}

func rasterizeSVGToPNG(path string) (string, error) {
	img, err := rasterizeSVG(path, sourceSampleMaxDim)
	if err != nil {
		return "", err
	}
	f, err := os.CreateTemp("", "matugen-svg-*.png")
	if err != nil {
		return "", err
	}
	defer f.Close()
	if err := png.Encode(f, img); err != nil {
		os.Remove(f.Name())
		return "", err
	}
	return f.Name(), nil
}

func rasterizeSVG(path string, maxDim int) (image.Image, error) {
	icon, err := oksvg.ReadIcon(path, oksvg.IgnoreErrorMode)
	if err != nil {
		return nil, err
	}
	vw, vh := icon.ViewBox.W, icon.ViewBox.H
	if vw <= 0 || vh <= 0 {
		return nil, fmt.Errorf("no usable viewBox")
	}
	scale := float64(maxDim) / math.Max(vw, vh)
	w, h := max(int(vw*scale), 1), max(int(vh*scale), 1)
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	icon.SetTarget(0, 0, float64(w), float64(h))
	icon.Draw(rasterx.NewDasher(w, h, rasterx.NewScannerGV(w, h, img, img.Bounds())), 1)
	return img, nil
}
