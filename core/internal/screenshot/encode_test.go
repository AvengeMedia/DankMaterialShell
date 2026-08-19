package screenshot

import (
	"encoding/binary"
	"image"
	"testing"
)

func newTenBitBuffer(t *testing.T, format PixelFormat, v uint32) *ShmBuffer {
	t.Helper()
	buf, err := CreateShmBuffer(1, 1, 4)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { buf.Close() })
	buf.Format = format
	binary.LittleEndian.PutUint32(buf.Data(), v)
	return buf
}

func TestBufferToImageWithFormat10Bit(t *testing.T) {
	const r10, g10, b10 = uint32(1023), uint32(512), uint32(0)

	cases := []struct {
		name   string
		format PixelFormat
		v      uint32
	}{
		{"XRGB2101010", FormatXRGB2101010, r10<<20 | g10<<10 | b10},
		{"XBGR2101010", FormatXBGR2101010, b10<<20 | g10<<10 | r10},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			buf := newTenBitBuffer(t, tc.format, tc.v)
			img := BufferToImageWithFormat(buf, uint32(tc.format))

			want := [4]uint8{255, 128, 0, 255}
			var got [4]uint8
			copy(got[:], img.Pix)
			if got != want {
				t.Errorf("pixel = %v, want %v", got, want)
			}
		})
	}
}

func TestBufferToImageDeep10Bit(t *testing.T) {
	const r10, g10, b10 = uint32(1023), uint32(512), uint32(0)
	buf := newTenBitBuffer(t, FormatXRGB2101010, r10<<20|g10<<10|b10)

	img, ok := BufferToImageDeep(buf, uint32(FormatXRGB2101010)).(*image.NRGBA64)
	if !ok {
		t.Fatal("expected *image.NRGBA64 for 10-bit source")
	}

	want := [4]uint16{0xFFFF, 512<<6 | 512>>4, 0, 0xFFFF}
	for i, w := range want {
		if got := binary.BigEndian.Uint16(img.Pix[i*2:]); got != w {
			t.Errorf("channel %d = %d, want %d", i, got, w)
		}
	}
}

func TestBufferToImageDeep8BitFallback(t *testing.T) {
	buf := newTenBitBuffer(t, FormatXRGB8888, 0)
	if _, ok := BufferToImageDeep(buf, uint32(FormatXRGB8888)).(*image.RGBA); !ok {
		t.Error("expected *image.RGBA for 8-bit source")
	}
}
