package shm

import (
	"encoding/binary"
	"math"
	"testing"
)

func make10BitBuffer(t *testing.T, format PixelFormat, v uint32) *Buffer {
	t.Helper()
	buf, err := CreateBuffer(1, 1, 4)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { buf.Close() })
	buf.Format = format
	binary.LittleEndian.PutUint32(buf.Data(), v)
	return buf
}

func TestConvert10To8(t *testing.T) {
	const r10, g10, b10 = uint32(1023), uint32(512), uint32(0)

	cases := []struct {
		name   string
		format PixelFormat
		v      uint32
		want   [4]uint8
		want8  PixelFormat
	}{
		{"XRGB2101010", FormatXRGB2101010, r10<<20 | g10<<10 | b10, [4]uint8{0, 128, 255, 255}, FormatXRGB8888},
		{"XBGR2101010", FormatXBGR2101010, b10<<20 | g10<<10 | r10, [4]uint8{255, 128, 0, 255}, FormatXBGR8888},
		{"ARGB2101010", FormatARGB2101010, 3<<30 | r10<<20 | g10<<10 | b10, [4]uint8{0, 128, 255, 255}, FormatARGB8888},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			buf := make10BitBuffer(t, tc.format, tc.v)
			buf.Convert10To8()

			if buf.Format != tc.want8 {
				t.Errorf("format = %#x, want %#x", buf.Format, tc.want8)
			}
			var got [4]uint8
			copy(got[:], buf.Data())
			if got != tc.want {
				t.Errorf("pixel = %v, want %v", got, tc.want)
			}
		})
	}
}

func TestConvert10To8NoopOn8Bit(t *testing.T) {
	buf := make10BitBuffer(t, FormatXRGB8888, 0x11223344)
	buf.Convert10To8()

	if binary.LittleEndian.Uint32(buf.Data()) != 0x11223344 {
		t.Error("8-bit buffer was modified")
	}
}

func pqInverse(nits float64) float64 {
	y := math.Pow(nits/10000, pqM1)
	return math.Pow((pqC1+pqC2*y)/(1+pqC3*y), pqM2)
}

func srgbDecode(c uint8) float64 {
	l := float64(c) / 255
	if l <= 0.04045 {
		return l / 12.92
	}
	return math.Pow((l+0.055)/1.055, 2.4)
}

// sRGB -> linear BT.709 -> BT.2020 (ITU-R BT.2087) -> PQ at refLum -> 10-bit code
func pq2020Code(srgb [3]uint8, refLum float64) [3]uint32 {
	r, g, b := srgbDecode(srgb[0]), srgbDecode(srgb[1]), srgbDecode(srgb[2])
	lin := [3]float64{
		0.6274*r + 0.3293*g + 0.0433*b,
		0.0691*r + 0.9195*g + 0.0114*b,
		0.0164*r + 0.0880*g + 0.8956*b,
	}
	var code [3]uint32
	for i, l := range lin {
		code[i] = uint32(math.Round(pqInverse(l*refLum) * 1023))
	}
	return code
}

func TestConvertPQ2020ToSRGB(t *testing.T) {
	const refLum = 203.0

	cases := []struct {
		name string
		rgb  [3]uint8
	}{
		{"white", [3]uint8{255, 255, 255}},
		{"gray", [3]uint8{128, 128, 128}},
		{"red", [3]uint8{255, 0, 0}},
		{"teal", [3]uint8{0, 160, 200}},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			code := pq2020Code(tc.rgb, refLum)
			buf := make10BitBuffer(t, FormatXRGB2101010, code[0]<<20|code[1]<<10|code[2])
			buf.ConvertPQ2020ToSRGB(refLum)

			if buf.Format != FormatXRGB8888 {
				t.Fatalf("format = %#x, want %#x", buf.Format, FormatXRGB8888)
			}
			data := buf.Data()
			got := [3]uint8{data[2], data[1], data[0]}
			for i := range got {
				if d := int(got[i]) - int(tc.rgb[i]); d < -3 || d > 3 {
					t.Fatalf("rgb = %v, want %v (±3)", got, tc.rgb)
				}
			}
		})
	}
}

func TestConvertPQ2020ToSRGBClipsHighlights(t *testing.T) {
	code := uint32(math.Round(pqInverse(1000) * 1023))
	buf := make10BitBuffer(t, FormatXRGB2101010, code<<20|code<<10|code)
	buf.ConvertPQ2020ToSRGB(203)

	data := buf.Data()
	if data[0] != 255 || data[1] != 255 || data[2] != 255 {
		t.Errorf("1000 cd/m² white = %v, want clipped to 255", data[:3])
	}
}
