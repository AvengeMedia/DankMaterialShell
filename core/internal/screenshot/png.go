package screenshot

import (
	"bytes"
	"encoding/binary"
	"errors"
	"hash/adler32"
	"hash/crc32"
	"image"
	"image/draw"
	"io"
	"runtime"
	"sync"

	"github.com/klauspost/compress/flate"
)

var pngSignature = []byte{0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n'}

const (
	pngColorRGB    = 2
	pngColorRGBA   = 6
	pngFilterSub   = 1
	pngMinBandRows = 64
	adlerBase      = 65521
)

// pngSource reads rows in place from pix; pack converts a row to PNG channel order, nil when it already is.
type pngSource struct {
	pix           []byte
	stride        int
	width, height int
	depth         byte
	colorType     byte
	srcBpp        int
	pack          func(dst, src []byte)
}

func (s pngSource) dstBpp() int {
	channels := 4
	if s.colorType == pngColorRGB {
		channels = 3
	}
	return channels * int(s.depth) / 8
}

func packRGBX(dst, src []byte) {
	for x := range len(dst) / 3 {
		d, p := dst[x*3:x*3+3], src[x*4:x*4+4]
		d[0], d[1], d[2] = p[0], p[1], p[2]
	}
}

func packBGRX(dst, src []byte) {
	for x := range len(dst) / 3 {
		d, p := dst[x*3:x*3+3], src[x*4:x*4+4]
		d[0], d[1], d[2] = p[2], p[1], p[0]
	}
}

func packRGBX16(dst, src []byte) {
	for x := range len(dst) / 6 {
		copy(dst[x*6:x*6+6], src[x*8:x*8+6])
	}
}

func pack2101010(swapRB bool) func(dst, src []byte) {
	return func(dst, src []byte) {
		for x := range len(dst) / 6 {
			v := binary.LittleEndian.Uint32(src[x*4:])
			c0, c1, c2 := v&0x3FF, v>>10&0x3FF, v>>20&0x3FF
			if swapRB {
				c0, c2 = c2, c0
			}
			d := dst[x*6 : x*6+6]
			binary.BigEndian.PutUint16(d[0:], uint16(c0<<6|c0>>4))
			binary.BigEndian.PutUint16(d[2:], uint16(c1<<6|c1>>4))
			binary.BigEndian.PutUint16(d[4:], uint16(c2<<6|c2>>4))
		}
	}
}

func newPNGSource(img image.Image) pngSource {
	b := img.Bounds()
	s := pngSource{width: b.Dx(), height: b.Dy(), colorType: pngColorRGBA}
	switch src := img.(type) {
	case *image.RGBA:
		if !src.Opaque() {
			break
		}
		s.pix, s.stride, s.depth, s.srcBpp = src.Pix, src.Stride, 8, 4
		s.colorType, s.pack = pngColorRGB, packRGBX
		return s
	case *image.NRGBA:
		s.pix, s.stride, s.depth, s.srcBpp = src.Pix, src.Stride, 8, 4
		if src.Opaque() {
			s.colorType, s.pack = pngColorRGB, packRGBX
		}
		return s
	case *image.NRGBA64:
		s.pix, s.stride, s.depth, s.srcBpp = src.Pix, src.Stride, 16, 8
		if src.Opaque() {
			s.colorType, s.pack = pngColorRGB, packRGBX16
		}
		return s
	}
	nrgba := image.NewNRGBA(image.Rect(0, 0, s.width, s.height))
	draw.Draw(nrgba, nrgba.Rect, img, b.Min, draw.Src)
	return newPNGSource(nrgba)
}

func newShmPNGSource(buf *ShmBuffer, format uint32) pngSource {
	s := pngSource{pix: buf.Data(), stride: buf.Stride, width: buf.Width, height: buf.Height, depth: 8, colorType: pngColorRGB, srcBpp: 4}
	switch f := PixelFormat(format); {
	case f.Is10Bit():
		s.depth, s.pack = 16, pack2101010(tenBitSwapRB(format))
	case f == FormatABGR8888, f == FormatXBGR8888:
		s.pack = packRGBX
	default:
		s.pack = packBGRX
	}
	return s
}

func (s pngSource) filterRow(y, bpp int, packed, dst []byte) {
	row := s.pix[y*s.stride:][:s.width*s.srcBpp]
	if s.pack != nil {
		s.pack(packed, row)
		row = packed
	}
	copy(dst[:bpp], row[:bpp])
	cur, prev, out := row[bpp:], row[:len(row)-bpp], dst[bpp:]
	prev, out = prev[:len(cur)], out[:len(cur)]
	for i := range cur {
		out[i] = cur[i] - prev[i]
	}
}

type pngBand struct {
	data  []byte
	adler uint32
	size  int
}

func (s pngSource) compressBand(y0, y1 int, final bool) (pngBand, error) {
	bpp := s.dstBpp()
	rowLen := s.width * bpp
	line := make([]byte, rowLen+1)
	line[0] = pngFilterSub
	packed := make([]byte, rowLen)
	var buf bytes.Buffer
	fw, err := flate.NewWriter(&buf, flate.BestSpeed)
	if err != nil {
		return pngBand{}, err
	}
	sum := adler32.New()
	for y := y0; y < y1; y++ {
		s.filterRow(y, bpp, packed, line[1:])
		sum.Write(line)
		if _, err := fw.Write(line); err != nil {
			return pngBand{}, err
		}
	}
	if final {
		err = fw.Close()
	} else {
		err = fw.Flush()
	}
	return pngBand{data: buf.Bytes(), adler: sum.Sum32(), size: len(line) * (y1 - y0)}, err
}

func adlerCombine(a, b uint32, lenB int) uint32 {
	rem := uint32(lenB % adlerBase)
	sum1 := a & 0xffff
	sum2 := (rem * sum1) % adlerBase
	sum1 += (b & 0xffff) + adlerBase - 1
	sum2 += ((a >> 16) & 0xffff) + ((b >> 16) & 0xffff) + adlerBase - rem
	if sum1 >= adlerBase {
		sum1 -= adlerBase
	}
	if sum1 >= adlerBase {
		sum1 -= adlerBase
	}
	if sum2 >= adlerBase<<1 {
		sum2 -= adlerBase << 1
	}
	if sum2 >= adlerBase {
		sum2 -= adlerBase
	}
	return sum1 | sum2<<16
}

func writeChunk(w io.Writer, typ string, parts ...[]byte) error {
	var hdr [8]byte
	total := 0
	for _, p := range parts {
		total += len(p)
	}
	binary.BigEndian.PutUint32(hdr[:4], uint32(total))
	copy(hdr[4:], typ)
	crc := crc32.NewIEEE()
	crc.Write(hdr[4:])
	if _, err := w.Write(hdr[:]); err != nil {
		return err
	}
	for _, p := range parts {
		if _, err := w.Write(p); err != nil {
			return err
		}
		crc.Write(p)
	}
	_, err := w.Write(binary.BigEndian.AppendUint32(nil, crc.Sum32()))
	return err
}

func (s pngSource) ihdr() []byte {
	b := make([]byte, 13)
	binary.BigEndian.PutUint32(b[0:], uint32(s.width))
	binary.BigEndian.PutUint32(b[4:], uint32(s.height))
	b[8], b[9] = s.depth, s.colorType
	return b
}

// encode deflates row bands in parallel into a single zlib stream; extraChunks go right after IHDR.
func (s pngSource) encode(w io.Writer, extraChunks ...[]byte) error {
	if s.width <= 0 || s.height <= 0 {
		return errors.New("png: empty image")
	}

	bands := min(runtime.GOMAXPROCS(0), max(1, s.height/pngMinBandRows))
	results := make([]pngBand, bands)
	errs := make([]error, bands)
	var wg sync.WaitGroup
	for b := range bands {
		wg.Go(func() {
			y0, y1 := s.height*b/bands, s.height*(b+1)/bands
			results[b], errs[b] = s.compressBand(y0, y1, b == bands-1)
		})
	}
	wg.Wait()
	if err := errors.Join(errs...); err != nil {
		return err
	}

	idat := make([][]byte, 0, bands+2)
	idat = append(idat, []byte{0x78, 0x01})
	adler := uint32(1)
	for _, r := range results {
		idat = append(idat, r.data)
		adler = adlerCombine(adler, r.adler, r.size)
	}
	idat = append(idat, binary.BigEndian.AppendUint32(nil, adler))

	if _, err := w.Write(pngSignature); err != nil {
		return err
	}
	if err := writeChunk(w, "IHDR", s.ihdr()); err != nil {
		return err
	}
	for _, c := range extraChunks {
		if _, err := w.Write(c); err != nil {
			return err
		}
	}
	if err := writeChunk(w, "IDAT", idat...); err != nil {
		return err
	}
	return writeChunk(w, "IEND")
}

func EncodePNG(w io.Writer, img image.Image) error {
	return newPNGSource(img).encode(w)
}

func EncodePNGTagged(w io.Writer, img image.Image, cicp *CICP) error {
	return newPNGSource(img).encode(w, cicp.chunks()...)
}

// EncodeBufferPNG reads the capture mapping directly; 10-bit formats are kept as 16-bit channels.
func EncodeBufferPNG(w io.Writer, buf *ShmBuffer, format uint32, cicp *CICP) error {
	return newShmPNGSource(buf, format).encode(w, cicp.chunks()...)
}
