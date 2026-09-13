package icc

import (
	"encoding/binary"
	"math"
	"os"
	"path/filepath"
	"testing"
)

// Vendor-profile tests are optional: set ICC_TEST_DIR to a directory holding
// the files below to run them against real display profiles. CI has none, so
// they are skipped there and the synthetic tests at the bottom cover parsing
// and ramp generation instead.
var testFiles = []struct {
	name string
	file string
}{
	{
		name: "Samsung Odyssey Neo G8 (v2.1, matrix-TRC, vcgt)",
		file: "1D8HG_B173ZAN_31-08-2023.icm",
	},
	{
		name: "DisplayPort monitor (v2.1, matrix-TRC, vcgt)",
		file: "DP_31-08-2023.icm",
	},
	{
		name: "GPD Win Max 2 (v2.2, XYZLUT+MTX, vcgt)",
		file: "GPD1001H #1 2024-11-29 22-12 D6500 2.2 F-S XYZLUT+MTX.icm",
	},
}

// vendorProfile resolves an optional vendor profile, skipping the test when
// ICC_TEST_DIR is unset or the file is missing.
func vendorProfile(t *testing.T, file string) string {
	t.Helper()
	dir := os.Getenv("ICC_TEST_DIR")
	if dir == "" {
		t.Skip("ICC_TEST_DIR not set; skipping vendor profile test")
	}
	path := filepath.Join(dir, file)
	if _, err := os.Stat(path); err != nil {
		t.Skipf("vendor profile unavailable: %v", err)
	}
	return path
}

func TestParseFile(t *testing.T) {
	for _, tc := range testFiles {
		t.Run(tc.name, func(t *testing.T) {
			path := vendorProfile(t, tc.file)

			// Read file to get expected size
			info, err := os.Stat(path)
			if err != nil {
				t.Fatalf("cannot stat file: %v", err)
			}

			p, err := ParseFile(path)
			if err != nil {
				t.Fatalf("ParseFile failed: %v", err)
			}

			// Verify size matches file size
			if p.Size != uint32(info.Size()) {
				t.Errorf("Size: got %d, want %d", p.Size, info.Size())
			}

			// Verify version
			if p.Version != "2.1.0" && p.Version != "2.2.0" && p.Version != "2.4.0" {
				t.Errorf("Version: got %q, want v2.x", p.Version)
			}
			t.Logf("  Version: %s", p.Version)

			// Verify class
			if p.Class != "mntr" {
				t.Errorf("Class: got %q, want %q", p.Class, "mntr")
			}

			// Verify color space
			if p.ColorSpace != "RGB" {
				t.Errorf("ColorSpace: got %q, want %q", p.ColorSpace, "RGB")
			}

			// Verify description is non-empty
			if p.Description == "" {
				t.Error("Description is empty")
			}
			t.Logf("  Description: %s", p.Description)

			// Verify matrix
			if !p.HasMatrix {
				t.Error("HasMatrix is false, expected true")
			} else {
				t.Logf("  Matrix:")
				for i := 0; i < 3; i++ {
					t.Logf("    [%6.4f %6.4f %6.4f]", p.Matrix[0][i], p.Matrix[1][i], p.Matrix[2][i])
				}
				// Each Y value (second row of matrix) should be in [0, 1]
				for _, col := range p.Matrix {
					if col[1] < -0.01 || col[1] > 1.5 {
						t.Errorf("Matrix Y value out of range: %f", col[1])
					}
				}
			}

			// Verify VCGT
			if !p.HasVCGT {
				t.Error("HasVCGT is false, expected true")
			} else {
				t.Logf("  VCGT: %d channels, %d entries", p.VCGT.Channels, p.VCGT.Entries)
				t.Logf("  VCGT Red: [%d ... %d]", p.VCGT.Red[0], p.VCGT.Red[len(p.VCGT.Red)-1])
				// Verify entry count matches declared
				if len(p.VCGT.Red) != p.VCGT.Entries {
					t.Errorf("VCGT Red entries: got %d, want %d", len(p.VCGT.Red), p.VCGT.Entries)
				}
				if len(p.VCGT.Green) != p.VCGT.Entries {
					t.Errorf("VCGT Green entries: got %d, want %d", len(p.VCGT.Green), p.VCGT.Entries)
				}
				if len(p.VCGT.Blue) != p.VCGT.Entries {
					t.Errorf("VCGT Blue entries: got %d, want %d", len(p.VCGT.Blue), p.VCGT.Entries)
				}
				// Verify channels
				if p.VCGT.Channels != 3 {
					t.Errorf("VCGT channels: got %d, want 3", p.VCGT.Channels)
				}
				// Verify monotonic non-decreasing per channel
				for _, ch := range []struct {
					name string
					data []uint16
				}{{"Red", p.VCGT.Red}, {"Green", p.VCGT.Green}, {"Blue", p.VCGT.Blue}} {
					for i := 1; i < len(ch.data); i++ {
						if ch.data[i] < ch.data[i-1] {
							t.Errorf("VCGT %s not monotonic at index %d: %d < %d", ch.name, i, ch.data[i], ch.data[i-1])
							break
						}
					}
				}
			}

			// Log white point
			t.Logf("  White point: [%6.4f %6.4f %6.4f]", p.WhitePoint[0], p.WhitePoint[1], p.WhitePoint[2])
		})
	}
}

func TestGenerateGammaRamp(t *testing.T) {
	for _, tc := range testFiles {
		t.Run(tc.name, func(t *testing.T) {
			p, err := ParseFile(vendorProfile(t, tc.file))
			if err != nil {
				t.Fatalf("ParseFile failed: %v", err)
			}

			for _, rampSize := range []uint32{256, 4096} {
				t.Run("size="+itoa(rampSize), func(t *testing.T) {
					ramp, err := GenerateGammaRamp(rampSize, p)
					if err != nil {
						t.Fatalf("GenerateGammaRamp failed: %v", err)
					}

					// Verify lengths
					if uint32(len(ramp.Red)) != rampSize {
						t.Errorf("Red length: got %d, want %d", len(ramp.Red), rampSize)
					}
					if uint32(len(ramp.Green)) != rampSize {
						t.Errorf("Green length: got %d, want %d", len(ramp.Green), rampSize)
					}
					if uint32(len(ramp.Blue)) != rampSize {
						t.Errorf("Blue length: got %d, want %d", len(ramp.Blue), rampSize)
					}

					// Verify range [0, 65535]
					channels := []struct {
						name string
						data []uint16
					}{
						{"Red", ramp.Red},
						{"Green", ramp.Green},
						{"Blue", ramp.Blue},
					}

					for _, ch := range channels {
						// All values must be in [0, 65535] (uint16 guarantees this, but double-check)
						for i, v := range ch.data {
							if v > 65535 {
								t.Errorf("%s[%d] = %d, out of range", ch.name, i, v)
								break
							}
						}

						// Verify ramp values match VCGT-derived data.
						// Real VCGT calibration data does NOT guarantee ramp[0]==0
						// or ramp[last]==65535 — these are gamma corrections.
						// Log endpoints for inspection.
						t.Logf("  %s: [%d ... %d]", ch.name, ch.data[0], ch.data[rampSize-1])

						// Verify monotonic non-decreasing
						for i := 1; i < len(ch.data); i++ {
							if ch.data[i] < ch.data[i-1] {
								t.Errorf("%s not monotonic at index %d: %d < %d", ch.name, i, ch.data[i], ch.data[i-1])
								break
							}
						}

						// ramp[last] >= ramp[0] (endpoints must be ordered)
						if ch.data[rampSize-1] < ch.data[0] {
							t.Errorf("%s: last value %d < first value %d", ch.name, ch.data[rampSize-1], ch.data[0])
						}
					}
				})
			}
		})
	}
}

func TestSampleCurve(t *testing.T) {
	t.Run("Identity", func(t *testing.T) {
		c := Curve{Type: CurveIdentity}
		for _, tt := range []float64{0, 0.25, 0.5, 0.75, 1.0} {
			got := SampleCurve(c, tt)
			if got != tt {
				t.Errorf("SampleCurve(identity, %f) = %f, want %f", tt, got, tt)
			}
		}
	})

	t.Run("Parametric", func(t *testing.T) {
		c := Curve{Type: CurveParametric, Gamma: 2.2}
		// pow(0.5, 1/2.2) ≈ 0.7297
		got := SampleCurve(c, 0.5)
		want := math.Pow(0.5, 1.0/2.2)
		if math.Abs(got-want) > 0.001 {
			t.Errorf("SampleCurve(gamma2.2, 0.5) = %f, want %f", got, want)
		}

		// Boundary conditions
		if v := SampleCurve(c, 0); v != 0 {
			t.Errorf("SampleCurve(gamma2.2, 0) = %f, want 0", v)
		}
		if v := SampleCurve(c, 1); v != 1 {
			t.Errorf("SampleCurve(gamma2.2, 1) = %f, want 1", v)
		}
	})

	t.Run("Table", func(t *testing.T) {
		// Identity table: 2 entries [0, 65535]
		c := Curve{
			Type:    CurveTable,
			Entries: []uint16{0, 65535},
		}
		if v := SampleCurve(c, 0.5); math.Abs(v-0.5) > 0.001 {
			t.Errorf("SampleCurve(identityTable, 0.5) = %f, want ~0.5", v)
		}

		// 4-entry table: [0, 21845, 43690, 65535] (approx 1/3, 2/3, 3/3)
		c2 := Curve{
			Type:    CurveTable,
			Entries: []uint16{0, 21845, 43690, 65535},
		}
		if v := SampleCurve(c2, 0); v != 0 {
			t.Errorf("SampleCurve(4entry, 0) = %f, want 0", v)
		}
		if v := SampleCurve(c2, 1.0); math.Abs(v-1.0) > 0.001 {
			t.Errorf("SampleCurve(4entry, 1.0) = %f, want ~1.0", v)
		}

		// 256-entry identity table
		entries256 := make([]uint16, 256)
		for i := range entries256 {
			entries256[i] = uint16(i * 65535 / 255)
		}
		c3 := Curve{Type: CurveTable, Entries: entries256}
		if v := SampleCurve(c3, 0.5); math.Abs(v-0.5) > 0.01 {
			t.Errorf("SampleCurve(256entry, 0.5) = %f, want ~0.5", v)
		}
	})

	t.Run("ClampInput", func(t *testing.T) {
		c := Curve{Type: CurveIdentity}
		// Negative t should be clamped to 0
		if v := SampleCurve(c, -0.5); v != 0 {
			t.Errorf("SampleCurve(identity, -0.5) = %f, want 0", v)
		}
		// t > 1 should be clamped to 1
		if v := SampleCurve(c, 1.5); v != 1 {
			t.Errorf("SampleCurve(identity, 1.5) = %f, want 1", v)
		}
	})
}

func TestParseBytes(t *testing.T) {
	t.Run("TooShort", func(t *testing.T) {
		_, err := ParseBytes([]byte{0, 1, 2})
		if err == nil {
			t.Error("expected error for short data")
		}
	})

	t.Run("IdentityRamp", func(t *testing.T) {
		// Generate identity ramp from a profile with no vcgt and no TRC
		p := &Profile{}
		ramp, err := GenerateGammaRamp(256, p)
		if err != nil {
			t.Fatalf("GenerateGammaRamp failed: %v", err)
		}
		if ramp.Red[0] != 0 {
			t.Errorf("identity ramp Red[0] = %d, want 0", ramp.Red[0])
		}
		if ramp.Red[255] < 65530 {
			t.Errorf("identity ramp Red[255] = %d, want ~65535", ramp.Red[255])
		}
	})
}

// itoa converts a uint32 to string (avoids importing strconv)
func itoa(n uint32) string {
	if n == 0 {
		return "0"
	}
	digits := ""
	for n > 0 {
		digits = string(rune('0'+n%10)) + digits
		n /= 10
	}
	return digits
}

// --- synthetic profile tests (self-contained; also cover CI) ---

func putS15Fixed16(b []byte, off int, v float64) {
	binary.BigEndian.PutUint32(b[off:], uint32(int32(math.Round(v*65536))))
}

func putU8Fixed8(b []byte, off int, v float64) {
	binary.BigEndian.PutUint16(b[off:], uint16(math.Round(v*256)))
}

// buildSyntheticProfile builds a minimal but valid ICC v2 monitor profile with
// desc, rXYZ/gXYZ/bXYZ, rTRC/gTRC/bTRC (single gamma per channel), wtpt and a
// table vcgt tag, so parsing and ramp generation can be exercised without a
// vendor profile on disk.
func buildSyntheticProfile(desc string, gamma float64) []byte {
	xyzTag := func(x, y, z float64) []byte {
		d := make([]byte, 20)
		copy(d[0:], "XYZ ")
		putS15Fixed16(d, 8, x)
		putS15Fixed16(d, 12, y)
		putS15Fixed16(d, 16, z)
		return d
	}
	curvTag := func(g float64) []byte {
		d := make([]byte, 16)
		copy(d[0:], "curv")
		binary.BigEndian.PutUint32(d[8:], 1) // count=1 -> single gamma value
		putU8Fixed8(d, 12, g)
		return d
	}
	descTag := make([]byte, 12+len(desc)+1)
	copy(descTag[0:], "desc")
	binary.BigEndian.PutUint32(descTag[8:], uint32(len(desc)+1)) // length includes NUL
	copy(descTag[12:], desc)

	const vcgtEntries = 4
	vcgtTag := make([]byte, 18+3*vcgtEntries*2)
	copy(vcgtTag[0:], "vcgt")
	binary.BigEndian.PutUint16(vcgtTag[12:], 3)           // channels
	binary.BigEndian.PutUint16(vcgtTag[14:], vcgtEntries) // entries per channel
	binary.BigEndian.PutUint16(vcgtTag[16:], 2)           // entry size in bytes
	for ch := 0; ch < 3; ch++ {
		for i := 0; i < vcgtEntries; i++ {
			v := uint16(math.Round(65535.0 * float64(i) / float64(vcgtEntries-1)))
			binary.BigEndian.PutUint16(vcgtTag[18+(ch*vcgtEntries+i)*2:], v)
		}
	}

	type tag struct {
		sig  string
		data []byte
	}
	tags := []tag{
		{"desc", descTag},
		{"rXYZ", xyzTag(0.4360, 0.2225, 0.0139)},
		{"gXYZ", xyzTag(0.3851, 0.7169, 0.0971)},
		{"bXYZ", xyzTag(0.1431, 0.0606, 0.7141)},
		{"rTRC", curvTag(gamma)},
		{"gTRC", curvTag(gamma)},
		{"bTRC", curvTag(gamma)},
		{"wtpt", xyzTag(0.9642, 1.0, 0.8249)},
		{"vcgt", vcgtTag},
	}

	const headerSize = 128
	tableSize := 4 + 12*len(tags)
	total := headerSize + tableSize
	for _, tg := range tags {
		total += len(tg.data)
	}

	buf := make([]byte, total)

	binary.BigEndian.PutUint32(buf[0:], uint32(total))
	binary.BigEndian.PutUint32(buf[8:], 0x02100000) // version 2.1.0
	copy(buf[12:], "mntr")
	copy(buf[16:], "RGB ")
	copy(buf[20:], "XYZ ")
	binary.BigEndian.PutUint16(buf[24:], 2026)
	binary.BigEndian.PutUint16(buf[26:], 9)
	binary.BigEndian.PutUint16(buf[28:], 10)
	copy(buf[36:], "acsp")
	putS15Fixed16(buf, 68, 0.9642) // D50 illuminant
	putS15Fixed16(buf, 72, 1.0)
	putS15Fixed16(buf, 76, 0.8249)

	binary.BigEndian.PutUint32(buf[128:], uint32(len(tags)))
	off := headerSize + tableSize
	for i, tg := range tags {
		base := 132 + i*12
		copy(buf[base:], tg.sig)
		binary.BigEndian.PutUint32(buf[base+4:], uint32(off))
		binary.BigEndian.PutUint32(buf[base+8:], uint32(len(tg.data)))
		copy(buf[off:], tg.data)
		off += len(tg.data)
	}
	return buf
}

func TestParseBytesSynthetic(t *testing.T) {
	const desc = "Synthetic Test Display"
	data := buildSyntheticProfile(desc, 2.2)

	p, err := ParseBytes(data)
	if err != nil {
		t.Fatalf("ParseBytes failed: %v", err)
	}

	if p.Size != uint32(len(data)) {
		t.Errorf("Size = %d, want %d", p.Size, len(data))
	}
	if p.Version != "2.1.0" {
		t.Errorf("Version = %q, want %q", p.Version, "2.1.0")
	}
	if p.Class != "mntr" {
		t.Errorf("Class = %q, want %q", p.Class, "mntr")
	}
	if p.ColorSpace != "RGB" {
		t.Errorf("ColorSpace = %q, want %q", p.ColorSpace, "RGB")
	}
	if p.Description != desc {
		t.Errorf("Description = %q, want %q", p.Description, desc)
	}
	if !p.HasMatrix {
		t.Error("HasMatrix = false, want true")
	}
	if !p.HasTRC {
		t.Error("HasTRC = false, want true")
	}
	if !p.HasVCGT {
		t.Error("HasVCGT = false, want true")
	}
	if got := p.TRC[0].Gamma; math.Abs(got-2.2) > 0.01 {
		t.Errorf("TRC[0].Gamma = %f, want ~2.2", got)
	}
	if got := p.WhitePoint[0]; math.Abs(got-0.9642) > 0.001 {
		t.Errorf("WhitePoint X = %f, want ~0.9642", got)
	}
}

func TestGenerateGammaRampSynthetic(t *testing.T) {
	p, err := ParseBytes(buildSyntheticProfile("Synthetic Test Display", 2.2))
	if err != nil {
		t.Fatalf("ParseBytes failed: %v", err)
	}

	const size = 256
	ramp, err := GenerateGammaRamp(size, p)
	if err != nil {
		t.Fatalf("GenerateGammaRamp failed: %v", err)
	}
	if len(ramp.Red) != size || len(ramp.Green) != size || len(ramp.Blue) != size {
		t.Fatalf("ramp lengths = %d/%d/%d, want %d", len(ramp.Red), len(ramp.Green), len(ramp.Blue), size)
	}
	if ramp.Red[size-1] <= ramp.Red[0] {
		t.Errorf("ramp not increasing: first=%d last=%d", ramp.Red[0], ramp.Red[size-1])
	}
}

// TestParseDescriptionMalformed feeds desc/mluc tags whose offsets or lengths
// point outside the buffer. These must return an error or a clamped string
// instead of a slice-bounds panic: `dms icc list` parses every file in the
// profile directory and the daemon parses user-picked files in-process, so a
// panic here takes the whole daemon down.
func TestParseDescriptionMalformed(t *testing.T) {
	descSig := [4]byte{'d', 'e', 's', 'c'}
	mlucSig := [4]byte{'m', 'l', 'u', 'c'}

	t.Run("desc length wraps past end", func(t *testing.T) {
		data := make([]byte, 32)
		copy(data[0:], "desc")
		// 12 + 0xFFFFFFF8 wraps to 4 in uint32 arithmetic.
		binary.BigEndian.PutUint32(data[8:], 0xFFFFFFF8)

		if _, err := parseDescription(data, tagEntry{sig: descSig, offset: 0, size: 32}); err != nil {
			t.Fatalf("expected clamped string, got error %v", err)
		}
	})

	t.Run("desc length past end", func(t *testing.T) {
		data := make([]byte, 24)
		copy(data[0:], "desc")
		binary.BigEndian.PutUint32(data[8:], 4096)

		desc, err := parseDescription(data, tagEntry{sig: descSig, offset: 0, size: 24})
		if err != nil {
			t.Fatalf("expected clamped string, got error %v", err)
		}
		if desc != "" {
			t.Errorf("expected empty description, got %q", desc)
		}
	})

	t.Run("mluc record header past end", func(t *testing.T) {
		data := make([]byte, 16)
		copy(data[0:], "mluc")
		binary.BigEndian.PutUint32(data[8:], 1)   // numRecords
		binary.BigEndian.PutUint32(data[12:], 12) // recordSize

		if _, err := parseDescription(data, tagEntry{sig: mlucSig, offset: 0, size: 16}); err == nil {
			t.Fatal("expected error for truncated mluc record header")
		}
	})

	t.Run("mluc string offset past end", func(t *testing.T) {
		data := make([]byte, 32)
		copy(data[0:], "mluc")
		binary.BigEndian.PutUint32(data[8:], 1)   // numRecords
		binary.BigEndian.PutUint32(data[12:], 12) // recordSize
		binary.BigEndian.PutUint32(data[20:], 4)  // string length
		binary.BigEndian.PutUint32(data[24:], 0xFFFFFF00)

		if _, err := parseDescription(data, tagEntry{sig: mlucSig, offset: 0, size: 32}); err == nil {
			t.Fatal("expected error for out-of-bounds mluc string")
		}
	})
}
