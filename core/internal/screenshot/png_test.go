package screenshot

import (
	"bytes"
	"hash/adler32"
	"image"
	"image/color"
	"image/draw"
	"image/png"
	"math/rand/v2"
	"testing"
)

func fillNoise(pix []byte, seed uint64) {
	r := rand.New(rand.NewPCG(seed, 7))
	for i := range pix {
		pix[i] = byte(r.IntN(256))
	}
}

func decodeInto(t *testing.T, data []byte, dst draw.Image) {
	t.Helper()
	dec, err := png.Decode(bytes.NewReader(data))
	if err != nil {
		t.Fatalf("decode: %v", err)
	}
	if dec.Bounds().Size() != dst.Bounds().Size() {
		t.Fatalf("size = %v, want %v", dec.Bounds().Size(), dst.Bounds().Size())
	}
	draw.Draw(dst, dst.Bounds(), dec, dec.Bounds().Min, draw.Src)
}

func TestEncodePNGRoundTrip(t *testing.T) {
	sizes := []image.Point{{1, 1}, {3, 1}, {1, 200}, {640, 500}, {257, 130}}

	for _, sz := range sizes {
		rect := image.Rect(0, 0, sz.X, sz.Y)

		t.Run("rgba-opaque", func(t *testing.T) {
			img := image.NewRGBA(rect)
			fillNoise(img.Pix, 1)
			for i := 3; i < len(img.Pix); i += 4 {
				img.Pix[i] = 255
			}
			var buf bytes.Buffer
			if err := EncodePNG(&buf, img); err != nil {
				t.Fatal(err)
			}
			if ct := buf.Bytes()[8+8+9]; ct != pngColorRGB {
				t.Errorf("color type = %d, want RGB", ct)
			}
			got := image.NewRGBA(rect)
			decodeInto(t, buf.Bytes(), got)
			if !bytes.Equal(got.Pix, img.Pix) {
				t.Error("pixels differ")
			}
		})

		t.Run("nrgba-alpha", func(t *testing.T) {
			img := image.NewNRGBA(rect)
			fillNoise(img.Pix, 2)
			var buf bytes.Buffer
			if err := EncodePNG(&buf, img); err != nil {
				t.Fatal(err)
			}
			if ct := buf.Bytes()[8+8+9]; ct != pngColorRGBA {
				t.Errorf("color type = %d, want RGBA", ct)
			}
			got := image.NewNRGBA(rect)
			decodeInto(t, buf.Bytes(), got)
			if !bytes.Equal(got.Pix, img.Pix) {
				t.Error("pixels differ")
			}
		})

		t.Run("nrgba64", func(t *testing.T) {
			for _, opaque := range []bool{true, false} {
				img := image.NewNRGBA64(rect)
				fillNoise(img.Pix, 3)
				if opaque {
					for i := 6; i < len(img.Pix); i += 8 {
						img.Pix[i], img.Pix[i+1] = 0xFF, 0xFF
					}
				}
				var buf bytes.Buffer
				if err := EncodePNG(&buf, img); err != nil {
					t.Fatal(err)
				}
				if depth := buf.Bytes()[8+8+8]; depth != 16 {
					t.Errorf("bit depth = %d, want 16", depth)
				}
				got := image.NewNRGBA64(rect)
				decodeInto(t, buf.Bytes(), got)
				if !bytes.Equal(got.Pix, img.Pix) {
					t.Errorf("pixels differ (opaque=%v)", opaque)
				}
			}
		})

		t.Run("generic-image", func(t *testing.T) {
			img := image.NewRGBA(rect.Add(image.Pt(5, 9)))
			fillNoise(img.Pix, 4)
			img.SetRGBA(5, 9, color.RGBA{10, 20, 30, 128})
			var buf bytes.Buffer
			if err := EncodePNG(&buf, img); err != nil {
				t.Fatal(err)
			}
			got := image.NewNRGBA(rect)
			decodeInto(t, buf.Bytes(), got)
			want := image.NewNRGBA(rect)
			draw.Draw(want, rect, img, img.Rect.Min, draw.Src)
			if !bytes.Equal(got.Pix, want.Pix) {
				t.Error("pixels differ")
			}
		})
	}
}

func TestEncodePNGEmpty(t *testing.T) {
	if err := EncodePNG(&bytes.Buffer{}, image.NewRGBA(image.Rect(0, 0, 0, 0))); err == nil {
		t.Error("expected error for empty image")
	}
}

func TestAdlerCombine(t *testing.T) {
	data := make([]byte, 200000)
	fillNoise(data, 5)
	for _, split := range []int{0, 1, 65520, 65521, 65522, 100000, len(data)} {
		a, b := data[:split], data[split:]
		got := adlerCombine(adler32.Checksum(a), adler32.Checksum(b), len(b))
		if want := adler32.Checksum(data); got != want {
			t.Errorf("split %d: combine = %#x, want %#x", split, got, want)
		}
	}
	if got := adlerCombine(1, adler32.Checksum(data), len(data)); got != adler32.Checksum(data) {
		t.Error("combine with empty prefix must be identity")
	}
}
