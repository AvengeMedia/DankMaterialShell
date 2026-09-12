// Package icc provides a pure-Go ICC color profile parser and gamma ramp generator.
// It supports ICC v2/v4 profile binary format and generates wlr-gamma-control
// compatible gamma ramps for display calibration.
package icc

import (
	"encoding/binary"
	"errors"
	"fmt"
	"math"
	"os"
	"unicode/utf16"
)

// CurveType represents the type of a tone reproduction curve.
type CurveType int

const (
	// CurveIdentity represents an identity curve (count=0, output equals input).
	CurveIdentity CurveType = iota
	// CurveParametric represents a single gamma value (count=1).
	CurveParametric
	// CurveTable represents a lookup table (count>1).
	CurveTable
)

// Profile represents a parsed ICC color profile.
type Profile struct {
	Size        uint32
	Version     string        // "2.1.0", "4.3.0"
	Class       string        // "mntr", "scnr", "prtr"
	ColorSpace  string        // "RGB", "CMYK"
	Description string        // from desc tag
	Matrix      [3][3]float64 // rXYZ, gXYZ, bXYZ columns
	HasMatrix   bool
	TRC         [3]Curve // rTRC, gTRC, bTRC
	HasTRC      bool
	VCGT        *VCGT // video card gamma table
	HasVCGT     bool
	WhitePoint  [3]float64 // XYZ of white point
}

// Curve represents a tone reproduction curve.
type Curve struct {
	Type    CurveType // Parametric or Table
	Gamma   float64   // if Parametric (count=1)
	Entries []uint16  // if Table (0-65535), evenly spaced 0.0 to 1.0
}

// VCGT represents a video card gamma table.
type VCGT struct {
	Channels int      // 3 for RGB
	Entries  int      // number of entries per channel
	Red      []uint16 // 0-65535
	Green    []uint16
	Blue     []uint16
}

// GammaRamp is the output format for wlr-gamma-control.
type GammaRamp struct {
	Red   []uint16
	Green []uint16
	Blue  []uint16
}

// tagEntry represents a single entry in the ICC tag table.
type tagEntry struct {
	sig    [4]byte
	offset uint32
	size   uint32
}

// tag signatures
var (
	sigDesc = [4]byte{'d', 'e', 's', 'c'}
	sigRXYZ = [4]byte{'r', 'X', 'Y', 'Z'}
	sigGXYZ = [4]byte{'g', 'X', 'Y', 'Z'}
	sigBXYZ = [4]byte{'b', 'X', 'Y', 'Z'}
	sigRTRC = [4]byte{'r', 'T', 'R', 'C'}
	sigGTRC = [4]byte{'g', 'T', 'R', 'C'}
	sigBTRC = [4]byte{'b', 'T', 'R', 'C'}
	sigVCGT = [4]byte{'v', 'c', 'g', 't'}
	sigWtpt = [4]byte{'w', 't', 'p', 't'}
)

// ParseFile reads and parses an ICC profile from a file path.
func ParseFile(path string) (*Profile, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("icc: failed to read file: %w", err)
	}
	return ParseBytes(data)
}

// ParseBytes parses an ICC profile from raw bytes.
func ParseBytes(data []byte) (*Profile, error) {
	if len(data) < 128 {
		return nil, errors.New("icc: profile data too short for header (< 128 bytes)")
	}

	p := &Profile{}

	// Parse header
	p.Size = binary.BigEndian.Uint32(data[0:4])

	// Verify we have enough data
	if uint32(len(data)) < p.Size {
		return nil, fmt.Errorf("icc: profile data shorter than declared size: got %d, declared %d", len(data), p.Size)
	}

	// Parse version (bytes 8-11)
	versionRaw := binary.BigEndian.Uint32(data[8:12])
	major := (versionRaw >> 24) & 0xFF
	minor := (versionRaw >> 20) & 0x0F
	bugfix := (versionRaw >> 16) & 0x0F
	p.Version = fmt.Sprintf("%d.%d.%d", major, minor, bugfix)

	// Parse device class (bytes 12-15)
	p.Class = string(data[12:16])

	// Parse color space (bytes 16-19)
	p.ColorSpace = string(data[16:20])
	// Trim whitespace from color space
	p.ColorSpace = trimASCII(p.ColorSpace)

	// Parse tag table
	if len(data) < 132 {
		return nil, errors.New("icc: profile data too short for tag table")
	}

	tagCount := binary.BigEndian.Uint32(data[128:132])
	tagTableEnd := uint32(132) + tagCount*12
	if uint32(len(data)) < tagTableEnd {
		return nil, fmt.Errorf("icc: profile data too short for %d tag entries", tagCount)
	}

	// Read tag entries
	tags := make([]tagEntry, tagCount)
	for i := uint32(0); i < tagCount; i++ {
		off := uint32(132) + i*12
		copy(tags[i].sig[:], data[off:off+4])
		tags[i].offset = binary.BigEndian.Uint32(data[off+4 : off+8])
		tags[i].size = binary.BigEndian.Uint32(data[off+8 : off+12])
	}

	// Build a map of tag signatures to entries
	tagMap := make(map[[4]byte]tagEntry)
	for _, t := range tags {
		tagMap[t.sig] = t
	}

	// Parse description
	if entry, ok := tagMap[sigDesc]; ok {
		desc, err := parseDescription(data, entry)
		if err == nil {
			p.Description = desc
		}
	}

	// Parse matrix columns (rXYZ, gXYZ, bXYZ)
	rXYZ, hasR := tagMap[sigRXYZ]
	gXYZ, hasG := tagMap[sigGXYZ]
	bXYZ, hasB := tagMap[sigBXYZ]
	if hasR && hasG && hasB {
		rx, ry, rz, err := parseXYZType(data, rXYZ)
		if err == nil {
			gx, gy, gz, err := parseXYZType(data, gXYZ)
			if err == nil {
				bx, by, bz, err := parseXYZType(data, bXYZ)
				if err == nil {
					p.Matrix[0] = [3]float64{rx, ry, rz}
					p.Matrix[1] = [3]float64{gx, gy, gz}
					p.Matrix[2] = [3]float64{bx, by, bz}
					p.HasMatrix = true
				}
			}
		}
	}

	// Parse TRC curves (rTRC, gTRC, bTRC)
	rTRC, hasRTRC := tagMap[sigRTRC]
	gTRC, hasGTRC := tagMap[sigGTRC]
	bTRC, hasBTRC := tagMap[sigBTRC]
	if hasRTRC && hasGTRC && hasBTRC {
		rc, err := parseCurveType(data, rTRC)
		if err == nil {
			gc, err := parseCurveType(data, gTRC)
			if err == nil {
				bc, err := parseCurveType(data, bTRC)
				if err == nil {
					p.TRC[0] = rc
					p.TRC[1] = gc
					p.TRC[2] = bc
					p.HasTRC = true
				}
			}
		}
	}

	// Parse vcgt
	if entry, ok := tagMap[sigVCGT]; ok {
		vcgt, err := parseVCGT(data, entry)
		if err == nil {
			p.VCGT = vcgt
			p.HasVCGT = true
		}
	}

	// Parse white point
	if entry, ok := tagMap[sigWtpt]; ok {
		x, y, z, err := parseXYZType(data, entry)
		if err == nil {
			p.WhitePoint = [3]float64{x, y, z}
		}
	}

	return p, nil
}

// trimASCII trims spaces from a 4-byte ASCII field.
func trimASCII(s string) string {
	i := 0
	for i < len(s) && s[i] == ' ' {
		i++
	}
	j := len(s)
	for j > i && s[j-1] == ' ' {
		j--
	}
	return s[i:j]
}

// readS15Fixed16 reads a signed 15.16 fixed-point number from big-endian bytes.
// Go's int32 cast handles two's complement correctly for negative values.
func readS15Fixed16(data []byte, offset int) float64 {
	if offset+4 > len(data) {
		return 0
	}
	raw := binary.BigEndian.Uint32(data[offset : offset+4])
	signed := int32(raw)
	return float64(signed) / 65536.0
}

// parseDescription parses the desc tag (textDescriptionType or mluc).
func parseDescription(data []byte, entry tagEntry) (string, error) {
	if int(entry.offset)+int(entry.size) > len(data) {
		return "", errors.New("icc: desc tag out of bounds")
	}

	if entry.size < 4 {
		return "", errors.New("icc: desc tag too short")
	}

	sig := string(data[entry.offset : entry.offset+4])

	switch sig {
	case "desc":
		// textDescriptionType: 'desc' + reserved(4) + stringLength(4) + ascii string
		if entry.size < 12 {
			return "", errors.New("icc: textDescriptionType too short")
		}
		strLen := binary.BigEndian.Uint32(data[entry.offset+8 : entry.offset+12])
		if strLen == 0 {
			return "", nil
		}
		// Compute in int so a large length cannot wrap past the buffer end.
		strStart := int(entry.offset) + 12
		strEnd := strStart + int(strLen)
		if strEnd > len(data) {
			strEnd = len(data)
		}
		if strStart < 0 || strStart > strEnd {
			return "", errors.New("icc: textDescriptionType string out of bounds")
		}
		// strLen includes null terminator
		s := data[strStart:strEnd]
		// Trim null terminator
		for i, b := range s {
			if b == 0 {
				s = s[:i]
				break
			}
		}
		return string(s), nil

	case "mluc":
		// mluc: 'mluc' + reserved(4) + numRecords(4) + recordSize(4) + records
		if entry.size < 16 {
			return "", errors.New("icc: mluc type too short")
		}
		numRecords := binary.BigEndian.Uint32(data[entry.offset+8 : entry.offset+12])
		recordSize := binary.BigEndian.Uint32(data[entry.offset+12 : entry.offset+16])
		if numRecords == 0 {
			return "", nil
		}
		// Read first record
		if recordSize < 12 {
			return "", errors.New("icc: mluc record size too small")
		}
		recordStart := entry.offset + 16
		if int(recordStart)+12 > len(data) {
			return "", errors.New("icc: mluc record out of bounds")
		}
		strLen := binary.BigEndian.Uint32(data[recordStart+4 : recordStart+8])
		strOff := binary.BigEndian.Uint32(data[recordStart+8 : recordStart+12])
		// Decode UTF-16BE
		if strLen < 2 {
			return "", nil
		}
		// String offset is absolute from profile start. Compute in int so a
		// large offset/length cannot wrap past the buffer end.
		strStart := int(entry.offset) + int(strOff)
		strEnd := strStart + int(strLen)
		if strEnd > len(data) {
			strEnd = len(data)
		}
		if strStart < 0 || strStart > strEnd {
			return "", errors.New("icc: mluc string out of bounds")
		}
		return decodeUTF16BE(data[strStart:strEnd]), nil

	default:
		return "", fmt.Errorf("icc: unknown desc type signature: %q", sig)
	}
}

// decodeUTF16BE decodes a big-endian UTF-16 byte slice to a Go string.
func decodeUTF16BE(data []byte) string {
	if len(data) < 2 {
		return ""
	}
	u16s := make([]uint16, 0, len(data)/2)
	for i := 0; i+1 < len(data); i += 2 {
		code := uint16(data[i])<<8 | uint16(data[i+1])
		if code == 0 {
			break
		}
		u16s = append(u16s, code)
	}
	return string(utf16.Decode(u16s))
}

// parseXYZType parses an XYZType tag (20 bytes: 'XYZ ' + reserved(4) + 3 × s15Fixed16).
func parseXYZType(data []byte, entry tagEntry) (float64, float64, float64, error) {
	if int(entry.offset)+20 > len(data) {
		return 0, 0, 0, errors.New("icc: XYZType tag out of bounds")
	}
	sig := string(data[entry.offset : entry.offset+4])
	if sig != "XYZ " {
		return 0, 0, 0, fmt.Errorf("icc: expected XYZ type signature, got %q", sig)
	}
	x := readS15Fixed16(data, int(entry.offset)+8)
	y := readS15Fixed16(data, int(entry.offset)+12)
	z := readS15Fixed16(data, int(entry.offset)+16)
	return x, y, z, nil
}

// parseCurveType parses a curveType tag.
func parseCurveType(data []byte, entry tagEntry) (Curve, error) {
	if int(entry.offset)+4 > len(data) {
		return Curve{}, errors.New("icc: curveType tag out of bounds")
	}
	sig := string(data[entry.offset : entry.offset+4])
	if sig != "curv" {
		return Curve{}, fmt.Errorf("icc: expected curv type signature, got %q", sig)
	}
	if int(entry.offset)+12 > len(data) {
		return Curve{}, errors.New("icc: curveType tag too short")
	}

	count := binary.BigEndian.Uint32(data[entry.offset+8 : entry.offset+12])

	c := Curve{}

	switch count {
	case 0:
		// Identity curve
		c.Type = CurveIdentity
		c.Gamma = 1.0

	case 1:
		// Single gamma value (u16Fixed16Number)
		c.Type = CurveParametric
		if int(entry.offset)+14 > len(data) {
			return Curve{}, errors.New("icc: curveType too short for gamma value")
		}
		// Read 2 bytes as uint16, divide by 256.0
		gammaRaw := binary.BigEndian.Uint16(data[entry.offset+12 : entry.offset+14])
		c.Gamma = float64(gammaRaw) / 256.0

	default:
		// Table of uint16 entries
		c.Type = CurveTable
		needed := int(entry.offset) + 12 + int(count)*2
		if needed > len(data) {
			return Curve{}, fmt.Errorf("icc: curveType table out of bounds: need %d, have %d", needed, len(data))
		}
		c.Entries = make([]uint16, count)
		for i := uint32(0); i < count; i++ {
			off := int(entry.offset) + 12 + int(i)*2
			c.Entries[i] = binary.BigEndian.Uint16(data[off : off+2])
		}
	}

	return c, nil
}

// parseVCGT parses a videoCardGammaType tag.
func parseVCGT(data []byte, entry tagEntry) (*VCGT, error) {
	if int(entry.offset)+int(entry.size) > len(data) {
		return nil, errors.New("icc: vcgt tag out of bounds")
	}

	// Minimum header: 'vcgt'(4) + reserved(4) + tagType(4) + channels(2) + count(2) + entrySize(2) = 18
	if entry.size < 18 {
		return nil, errors.New("icc: vcgt tag too short")
	}

	sig := string(data[entry.offset : entry.offset+4])
	if sig != "vcgt" {
		return nil, fmt.Errorf("icc: expected vcgt signature, got %q", sig)
	}

	tagType := binary.BigEndian.Uint32(data[entry.offset+8 : entry.offset+12])

	switch tagType {
	case 0:
		// Table type
		channels := int(binary.BigEndian.Uint16(data[entry.offset+12 : entry.offset+14]))
		count := int(binary.BigEndian.Uint16(data[entry.offset+14 : entry.offset+16]))
		entrySize := int(binary.BigEndian.Uint16(data[entry.offset+16 : entry.offset+18]))

		if channels < 1 || count < 1 || entrySize < 1 {
			return nil, fmt.Errorf("icc: vcgt invalid dimensions: channels=%d, count=%d, entrySize=%d", channels, count, entrySize)
		}

		dataStart := int(entry.offset) + 18
		totalBytes := channels * count * entrySize
		if dataStart+totalBytes > len(data) {
			return nil, fmt.Errorf("icc: vcgt data out of bounds: need %d bytes, have %d", totalBytes, len(data)-dataStart)
		}

		vcgt := &VCGT{
			Channels: channels,
			Entries:  count,
			Red:      make([]uint16, count),
			Green:    make([]uint16, count),
			Blue:     make([]uint16, count),
		}

		channels_arr := [3][]uint16{vcgt.Red, vcgt.Green, vcgt.Blue}

		for ch := 0; ch < channels && ch < 3; ch++ {
			for i := 0; i < count; i++ {
				byteOff := dataStart + (ch*count+i)*entrySize
				var val uint16
				switch entrySize {
				case 2:
					val = binary.BigEndian.Uint16(data[byteOff : byteOff+2])
				case 1:
					// u8 entry: scale to u16
					val = uint16(data[byteOff]) * 257 // 257 = 65535/255
				default:
					val = binary.BigEndian.Uint16(data[byteOff : byteOff+2])
				}
				channels_arr[ch][i] = val
			}
		}

		return vcgt, nil

	case 1:
		// Formula type (rarely used, but parse it)
		// 3 channels × (gamma u16Fixed16 + min s15Fixed16 + max s15Fixed16)
		return nil, errors.New("icc: vcgt formula type not supported")

	default:
		return nil, fmt.Errorf("icc: vcgt unknown tag type: %d", tagType)
	}
}

// SampleCurve evaluates a Curve at position t (0.0 to 1.0), returns 0.0 to 1.0.
func SampleCurve(curve Curve, t float64) float64 {
	// Clamp t to [0, 1]
	if t < 0 {
		t = 0
	}
	if t > 1 {
		t = 1
	}

	switch curve.Type {
	case CurveIdentity:
		return t

	case CurveParametric:
		if curve.Gamma == 0 {
			return 0
		}
		return math.Pow(t, 1.0/curve.Gamma)

	case CurveTable:
		if len(curve.Entries) == 0 {
			return t
		}
		if len(curve.Entries) == 1 {
			return float64(curve.Entries[0]) / 65535.0
		}
		// t maps to index in [0, len-1]
		idx := t * float64(len(curve.Entries)-1)
		low := int(idx)
		if low >= len(curve.Entries)-1 {
			low = len(curve.Entries) - 2
		}
		if low < 0 {
			low = 0
		}
		frac := idx - float64(low)
		v0 := float64(curve.Entries[low])
		v1 := float64(curve.Entries[low+1])
		result := (v0 + frac*(v1-v0)) / 65535.0
		if result < 0 {
			result = 0
		}
		if result > 1 {
			result = 1
		}
		return result

	default:
		return t
	}
}

// GenerateGammaRamp creates a wlr-gamma-control compatible ramp from an ICC profile.
// size is the ramp size (typically 256 or 4096).
//
// Strategy:
// 1. If vcgt exists: resample vcgt entries to `size` entries (linear interpolation)
// 2. If no vcgt but TRC exists: use TRC curves (composite all three channels)
// 3. If neither: return identity ramp
func GenerateGammaRamp(size uint32, profile *Profile) (GammaRamp, error) {
	if size == 0 {
		return GammaRamp{}, errors.New("icc: ramp size must be > 0")
	}

	ramp := GammaRamp{
		Red:   make([]uint16, size),
		Green: make([]uint16, size),
		Blue:  make([]uint16, size),
	}

	// Strategy 1: VCGT exists - resample
	if profile.HasVCGT && profile.VCGT != nil {
		vcgt := profile.VCGT
		for i := uint32(0); i < size; i++ {
			t := float64(i) / float64(size-1)
			ramp.Red[i] = resampleVCGT(vcgt.Red, t)
			ramp.Green[i] = resampleVCGT(vcgt.Green, t)
			ramp.Blue[i] = resampleVCGT(vcgt.Blue, t)
		}
		return ramp, nil
	}

	// Strategy 2: TRC exists - use curves
	if profile.HasTRC {
		for i := uint32(0); i < size; i++ {
			t := float64(i) / float64(size-1)
			r := SampleCurve(profile.TRC[0], t)
			g := SampleCurve(profile.TRC[1], t)
			b := SampleCurve(profile.TRC[2], t)
			ramp.Red[i] = uint16Clamp(r * 65535.0)
			ramp.Green[i] = uint16Clamp(g * 65535.0)
			ramp.Blue[i] = uint16Clamp(b * 65535.0)
		}
		return ramp, nil
	}

	// Strategy 3: Identity ramp
	for i := uint32(0); i < size; i++ {
		v := uint16(float64(i) / float64(size-1) * 65535.0)
		ramp.Red[i] = v
		ramp.Green[i] = v
		ramp.Blue[i] = v
	}
	return ramp, nil
}

// resampleVCGT resamples a vcgt channel at position t (0.0 to 1.0) using linear interpolation.
func resampleVCGT(entries []uint16, t float64) uint16 {
	if len(entries) == 0 {
		return uint16Clamp(t * 65535.0)
	}
	if len(entries) == 1 {
		return entries[0]
	}

	idx := t * float64(len(entries)-1)
	low := int(idx)
	if low >= len(entries)-1 {
		low = len(entries) - 2
	}
	if low < 0 {
		low = 0
	}
	frac := idx - float64(low)
	v := float64(entries[low]) + frac*(float64(entries[low+1])-float64(entries[low]))
	return uint16Clamp(v)
}

// uint16Clamp clamps a float64 to [0, 65535] and converts to uint16.
func uint16Clamp(v float64) uint16 {
	if v < 0 {
		return 0
	}
	if v > 65535 {
		return 65535
	}
	return uint16(v + 0.5) // round to nearest
}
