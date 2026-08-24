package shm

import (
	"encoding/binary"
	"fmt"
	"math"

	"golang.org/x/sys/unix"
)

type PixelFormat uint32

const (
	FormatARGB8888    PixelFormat = 0
	FormatXRGB8888    PixelFormat = 1
	FormatABGR8888    PixelFormat = 0x34324241
	FormatXBGR8888    PixelFormat = 0x34324258
	FormatRGB888      PixelFormat = 0x34324752
	FormatBGR888      PixelFormat = 0x34324742
	FormatARGB2101010 PixelFormat = 0x30335241
	FormatXRGB2101010 PixelFormat = 0x30335258
	FormatABGR2101010 PixelFormat = 0x30334241
	FormatXBGR2101010 PixelFormat = 0x30334258
)

func (f PixelFormat) BytesPerPixel() int {
	switch f {
	case FormatRGB888, FormatBGR888:
		return 3
	default:
		return 4
	}
}

func (f PixelFormat) Is24Bit() bool {
	return f == FormatRGB888 || f == FormatBGR888
}

func (f PixelFormat) Is10Bit() bool {
	switch f {
	case FormatARGB2101010, FormatXRGB2101010, FormatABGR2101010, FormatXBGR2101010:
		return true
	default:
		return false
	}
}

func (f PixelFormat) To8Bit() PixelFormat {
	switch f {
	case FormatARGB2101010:
		return FormatARGB8888
	case FormatXRGB2101010:
		return FormatXRGB8888
	case FormatABGR2101010:
		return FormatABGR8888
	case FormatXBGR2101010:
		return FormatXBGR8888
	default:
		return f
	}
}

type Buffer struct {
	fd     int
	data   []byte
	size   int
	Width  int
	Height int
	Stride int
	Format PixelFormat
}

func CreateBuffer(width, height, stride int) (*Buffer, error) {
	size := stride * height

	fd, err := CreateAnonFd("dms-shm")
	if err != nil {
		return nil, fmt.Errorf("create shm fd: %w", err)
	}

	if err := unix.Ftruncate(fd, int64(size)); err != nil {
		unix.Close(fd)
		return nil, fmt.Errorf("ftruncate: %w", err)
	}

	data, err := unix.Mmap(fd, 0, size, unix.PROT_READ|unix.PROT_WRITE, unix.MAP_SHARED)
	if err != nil {
		unix.Close(fd)
		return nil, fmt.Errorf("mmap: %w", err)
	}

	return &Buffer{
		fd:     fd,
		data:   data,
		size:   size,
		Width:  width,
		Height: height,
		Stride: stride,
	}, nil
}

func (b *Buffer) Fd() int      { return b.fd }
func (b *Buffer) Size() int    { return b.size }
func (b *Buffer) Data() []byte { return b.data }

func (b *Buffer) Close() error {
	var firstErr error

	if b.data != nil {
		if err := unix.Munmap(b.data); err != nil {
			firstErr = fmt.Errorf("munmap: %w", err)
		}
		b.data = nil
	}

	if b.fd >= 0 {
		if err := unix.Close(b.fd); err != nil && firstErr == nil {
			firstErr = fmt.Errorf("close: %w", err)
		}
		b.fd = -1
	}

	return firstErr
}

func (b *Buffer) ConvertTo32Bit(srcFormat PixelFormat) (*Buffer, PixelFormat, error) {
	if !srcFormat.Is24Bit() {
		return b, srcFormat, nil
	}

	dstFormat := FormatXRGB8888
	dstStride := b.Width * 4

	dst, err := CreateBuffer(b.Width, b.Height, dstStride)
	if err != nil {
		return nil, srcFormat, err
	}
	dst.Format = dstFormat

	srcData := b.data
	dstData := dst.data

	// DRM format names are counterintuitive on little-endian:
	// RGB888 memory layout: B, G, R (name is logical order, not memory)
	// BGR888 memory layout: R, G, B
	isBGRMemory := srcFormat == FormatRGB888

	for y := 0; y < b.Height; y++ {
		srcRow := y * b.Stride
		dstRow := y * dstStride
		for x := 0; x < b.Width; x++ {
			si := srcRow + x*3
			di := dstRow + x*4
			if isBGRMemory {
				// RGB888: src memory is B,G,R -> dst XRGB8888 memory B,G,R,X
				dstData[di+0] = srcData[si+0]
				dstData[di+1] = srcData[si+1]
				dstData[di+2] = srcData[si+2]
			} else {
				// BGR888: src memory is R,G,B -> dst XRGB8888 memory B,G,R,X
				dstData[di+0] = srcData[si+2]
				dstData[di+1] = srcData[si+1]
				dstData[di+2] = srcData[si+0]
			}
			dstData[di+3] = 0xFF
		}
	}

	return dst, dstFormat, nil
}

// Convert10To8 rewrites 2101010 pixels as their 8888 counterpart in place.
// Channel byte order is unchanged (XRGB2101010 -> XRGB8888, XBGR2101010 -> XBGR8888, ...).
func (b *Buffer) Convert10To8() {
	if !b.Format.Is10Bit() {
		return
	}

	hasAlpha := b.Format == FormatARGB2101010 || b.Format == FormatABGR2101010
	for y := 0; y < b.Height; y++ {
		row := y * b.Stride
		for x := 0; x < b.Width; x++ {
			off := row + x*4
			if off+4 > len(b.data) {
				continue
			}
			v := binary.LittleEndian.Uint32(b.data[off:])
			a := uint8(0xFF)
			if hasAlpha {
				a = uint8((v >> 30) * 85)
			}
			b.data[off+0] = uint8(v >> 2)
			b.data[off+1] = uint8(v >> 12)
			b.data[off+2] = uint8(v >> 22)
			b.data[off+3] = a
		}
	}
	b.Format = b.Format.To8Bit()
}

// SMPTE ST 2084 constants
const (
	pqM1 = 2610.0 / 16384
	pqM2 = 128.0 * 2523 / 4096
	pqC1 = 3424.0 / 4096
	pqC2 = 32.0 * 2413 / 4096
	pqC3 = 32.0 * 2392 / 4096
)

// pqEOTF maps a normalized PQ signal to luminance in cd/m² (SMPTE ST 2084).
func pqEOTF(n float64) float64 {
	p := math.Pow(n, 1/pqM2)
	num := math.Max(p-pqC1, 0)
	return 10000 * math.Pow(num/(pqC2-pqC3*p), 1/pqM1)
}

func srgbEncodeLUT() *[4096]uint8 {
	lut := &[4096]uint8{}
	for i := range lut {
		l := float64(i) / 4095
		v := 1.055*math.Pow(l, 1/2.4) - 0.055
		if l <= 0.0031308 {
			v = 12.92 * l
		}
		lut[i] = uint8(v*255 + 0.5)
	}
	return lut
}

// ConvertPQ2020ToSRGB rewrites 2101010 PQ/BT.2020 pixels as their sRGB 8888
// counterpart in place, treating refLum cd/m² as SDR reference white (203 per
// ITU-R BT.2408 when unset); brighter highlights clip to white. Channel byte
// order is unchanged; the gamut matrix is from ITU-R BT.2087.
func (b *Buffer) ConvertPQ2020ToSRGB(refLum float64) {
	if !b.Format.Is10Bit() {
		return
	}
	if refLum <= 0 {
		refLum = 203
	}

	var toLinear [1024]float64
	for i := range toLinear {
		toLinear[i] = pqEOTF(float64(i)/1023) / refLum
	}
	srgb := srgbEncodeLUT()
	enc := func(l float64) uint8 {
		switch {
		case l <= 0:
			return 0
		case l >= 1:
			return 255
		default:
			return srgb[int(l*4095+0.5)]
		}
	}

	hasAlpha := b.Format == FormatARGB2101010 || b.Format == FormatABGR2101010
	rLow := b.Format == FormatABGR2101010 || b.Format == FormatXBGR2101010
	for y := 0; y < b.Height; y++ {
		row := y * b.Stride
		for x := 0; x < b.Width; x++ {
			off := row + x*4
			if off+4 > len(b.data) {
				continue
			}
			v := binary.LittleEndian.Uint32(b.data[off:])
			c0, c1, c2 := toLinear[v&0x3FF], toLinear[(v>>10)&0x3FF], toLinear[(v>>20)&0x3FF]
			r, g, bl := c2, c1, c0
			if rLow {
				r, bl = c0, c2
			}
			e0 := enc(-0.0182*r - 0.1006*g + 1.1187*bl)
			e1 := enc(-0.1246*r + 1.1329*g - 0.0083*bl)
			e2 := enc(1.6605*r - 0.5876*g - 0.0728*bl)
			if rLow {
				e0, e2 = e2, e0
			}
			a := uint8(0xFF)
			if hasAlpha {
				a = uint8((v >> 30) * 85)
			}
			b.data[off+0], b.data[off+1], b.data[off+2], b.data[off+3] = e0, e1, e2, a
		}
	}
	b.Format = b.Format.To8Bit()
}

func (b *Buffer) GetPixelRGBA(x, y int) (r, g, b2, a uint8) {
	if x < 0 || x >= b.Width || y < 0 || y >= b.Height {
		return
	}

	off := y*b.Stride + x*4
	if off+3 >= len(b.data) {
		return
	}

	switch b.Format {
	case FormatXBGR8888, FormatABGR8888:
		return b.data[off], b.data[off+1], b.data[off+2], 0xFF
	default:
		return b.data[off+2], b.data[off+1], b.data[off], 0xFF
	}
}

func (b *Buffer) GetPixelBGRA(x, y int) (b2, g, r, a uint8) {
	if x < 0 || x >= b.Width || y < 0 || y >= b.Height {
		return
	}

	off := y*b.Stride + x*4
	if off+3 >= len(b.data) {
		return
	}

	return b.data[off], b.data[off+1], b.data[off+2], b.data[off+3]
}

func (b *Buffer) ConvertBGRAtoRGBA() {
	for y := 0; y < b.Height; y++ {
		rowOff := y * b.Stride
		for x := 0; x < b.Width; x++ {
			off := rowOff + x*4
			if off+3 >= len(b.data) {
				continue
			}
			b.data[off], b.data[off+2] = b.data[off+2], b.data[off]
		}
	}
}

func (b *Buffer) FlipVertical() {
	tmp := make([]byte, b.Stride)
	for y := 0; y < b.Height/2; y++ {
		topOff := y * b.Stride
		botOff := (b.Height - 1 - y) * b.Stride
		copy(tmp, b.data[topOff:topOff+b.Stride])
		copy(b.data[topOff:topOff+b.Stride], b.data[botOff:botOff+b.Stride])
		copy(b.data[botOff:botOff+b.Stride], tmp)
	}
}

func (b *Buffer) Clear() {
	for i := range b.data {
		b.data[i] = 0
	}
}

func (b *Buffer) CopyFrom(src *Buffer) {
	copy(b.data, src.data)
}

const (
	TransformNormal     = 0
	Transform90         = 1
	Transform180        = 2
	Transform270        = 3
	TransformFlipped    = 4
	TransformFlipped90  = 5
	TransformFlipped180 = 6
	TransformFlipped270 = 7
)

func (b *Buffer) ApplyTransform(transform int32) (*Buffer, error) {
	if transform == TransformNormal {
		return b, nil
	}

	var newW, newH int
	switch transform {
	case Transform90, Transform270, TransformFlipped90, TransformFlipped270:
		newW, newH = b.Height, b.Width
	default:
		newW, newH = b.Width, b.Height
	}

	newBuf, err := CreateBuffer(newW, newH, newW*4)
	if err != nil {
		return nil, err
	}
	newBuf.Format = b.Format

	srcData := b.data
	dstData := newBuf.data

	for sy := 0; sy < b.Height; sy++ {
		for sx := 0; sx < b.Width; sx++ {
			var dx, dy int

			switch transform {
			case Transform90: // 90° CCW
				dx = sy
				dy = b.Width - 1 - sx
			case Transform180:
				dx = b.Width - 1 - sx
				dy = b.Height - 1 - sy
			case Transform270: // 270° CCW = 90° CW
				dx = b.Height - 1 - sy
				dy = sx
			case TransformFlipped:
				dx = b.Width - 1 - sx
				dy = sy
			case TransformFlipped90:
				dx = sy
				dy = sx
			case TransformFlipped180:
				dx = sx
				dy = b.Height - 1 - sy
			case TransformFlipped270:
				dx = b.Height - 1 - sy
				dy = b.Width - 1 - sx
			default:
				dx, dy = sx, sy
			}

			si := sy*b.Stride + sx*4
			di := dy*newBuf.Stride + dx*4

			if si+3 < len(srcData) && di+3 < len(dstData) {
				dstData[di+0] = srcData[si+0]
				dstData[di+1] = srcData[si+1]
				dstData[di+2] = srcData[si+2]
				dstData[di+3] = srcData[si+3]
			}
		}
	}

	return newBuf, nil
}

func InverseTransform(transform int32) int32 {
	switch transform {
	case Transform90:
		return Transform270
	case Transform270:
		return Transform90
	case TransformFlipped90:
		return TransformFlipped270
	case TransformFlipped270:
		return TransformFlipped90
	default:
		return transform
	}
}
