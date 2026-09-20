package matugen

import (
	"image"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestStageImageSourceRasterizesSVG(t *testing.T) {
	svgPath := filepath.Join(t.TempDir(), "wall.svg")
	svg := `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100"><rect width="200" height="100" fill="#3355ff"/><circle cx="60" cy="50" r="40" fill="#ff8800"/></svg>`
	if err := os.WriteFile(svgPath, []byte(svg), 0o644); err != nil {
		t.Fatal(err)
	}

	opts := &Options{Kind: "image", Value: svgPath}
	sourceImage, cleanup, err := stageImageSource(opts)
	if err != nil {
		t.Fatalf("stageImageSource: %v", err)
	}
	assert.Equal(t, svgPath, sourceImage)
	assert.NotEqual(t, svgPath, opts.Value)

	f, err := os.Open(opts.Value)
	if err != nil {
		t.Fatal(err)
	}
	img, format, err := image.Decode(f)
	f.Close()
	if err != nil {
		t.Fatalf("decode raster: %v", err)
	}
	assert.Equal(t, "png", format)
	assert.Equal(t, sourceSampleMaxDim, img.Bounds().Dx())
	assert.Equal(t, sourceSampleMaxDim/2, img.Bounds().Dy())
	r, g, b, _ := img.At(500, 10).RGBA()
	assert.Equal(t, [3]uint8{0x33, 0x55, 0xff}, [3]uint8{uint8(r >> 8), uint8(g >> 8), uint8(b >> 8)})

	seed, err := ExtractSourceColor(opts.Value)
	assert.NoError(t, err)
	assert.NotEmpty(t, seed)

	cleanup()
	_, statErr := os.Stat(opts.Value)
	assert.True(t, os.IsNotExist(statErr))
}

func TestStageImageSourcePassesRasterThrough(t *testing.T) {
	opts := &Options{Kind: "image", Value: "/wallpapers/x.jpg"}
	sourceImage, cleanup, err := stageImageSource(opts)
	assert.NoError(t, err)
	assert.Equal(t, "/wallpapers/x.jpg", opts.Value)
	assert.Equal(t, "/wallpapers/x.jpg", sourceImage)
	cleanup()
}
