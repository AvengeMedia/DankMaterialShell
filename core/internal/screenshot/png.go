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

type pngSource struct {
	pix           []byte
	stride        int
	width, height int
	depth         byte
	colorType     byte
	srcBpp        int
	dstBpp        int
}

func pngSourceOf(pix []byte, stride, width, height int, depth byte, opaque bool) pngSource {
	s := pngSource{pix: pix, stride: stride, width: width, height: height, depth: depth}
	s.srcBpp = 4 * int(depth) / 8
	s.dstBpp, s.colorType = s.srcBpp, pngColorRGBA
	if opaque {
		s.dstBpp, s.colorType = 3*int(depth)/8, pngColorRGB
	}
	return s
}

func newPNGSource(img image.Image) pngSource {
	b := img.Bounds()
	switch src := img.(type) {
	case *image.RGBA:
		if src.Opaque() {
			return pngSourceOf(src.Pix, src.Stride, b.Dx(), b.Dy(), 8, true)
		}
	case *image.NRGBA:
		return pngSourceOf(src.Pix, src.Stride, b.Dx(), b.Dy(), 8, src.Opaque())
	case *image.NRGBA64:
		return pngSourceOf(src.Pix, src.Stride, b.Dx(), b.Dy(), 16, src.Opaque())
	}
	nrgba := image.NewNRGBA(image.Rect(0, 0, b.Dx(), b.Dy()))
	draw.Draw(nrgba, nrgba.Rect, img, b.Min, draw.Src)
	return newPNGSource(nrgba)
}

func (s pngSource) row(y int, scratch []byte) []byte {
	src := s.pix[y*s.stride : y*s.stride+s.width*s.srcBpp]
	switch s.dstBpp {
	case s.srcBpp:
		return src
	case 3:
		for x := 0; x < s.width; x++ {
			d, p := scratch[x*3:x*3+3], src[x*4:x*4+4]
			d[0], d[1], d[2] = p[0], p[1], p[2]
		}
	default:
		for x := 0; x < s.width; x++ {
			copy(scratch[x*s.dstBpp:(x+1)*s.dstBpp], src[x*s.srcBpp:])
		}
	}
	return scratch
}

func (s pngSource) filterBand(y0, y1 int) []byte {
	rowLen := s.width * s.dstBpp
	out := make([]byte, (rowLen+1)*(y1-y0))
	scratch := make([]byte, rowLen)
	bpp := s.dstBpp
	for y := y0; y < y1; y++ {
		line := out[(y-y0)*(rowLen+1):][:rowLen+1]
		line[0] = pngFilterSub
		row := s.row(y, scratch)
		copy(line[1:1+bpp], row[:bpp])
		cur, prev, dst := row[bpp:], row[:rowLen-bpp], line[1+bpp:]
		prev, dst = prev[:len(cur)], dst[:len(cur)]
		for i := range cur {
			dst[i] = cur[i] - prev[i]
		}
	}
	return out
}

type pngBand struct {
	data  []byte
	adler uint32
	size  int
}

func (s pngSource) compressBand(y0, y1 int, final bool) (pngBand, error) {
	raw := s.filterBand(y0, y1)
	var buf bytes.Buffer
	fw, err := flate.NewWriter(&buf, flate.BestSpeed)
	if err != nil {
		return pngBand{}, err
	}
	if _, err := fw.Write(raw); err != nil {
		return pngBand{}, err
	}
	if final {
		err = fw.Close()
	} else {
		err = fw.Flush()
	}
	return pngBand{data: buf.Bytes(), adler: adler32.Checksum(raw), size: len(raw)}, err
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

// encodePNG deflates row bands in parallel into a single zlib stream; extraChunks go right after IHDR.
func encodePNG(w io.Writer, img image.Image, extraChunks ...[]byte) error {
	src := newPNGSource(img)
	if src.width <= 0 || src.height <= 0 {
		return errors.New("png: empty image")
	}

	bands := min(runtime.GOMAXPROCS(0), max(1, src.height/pngMinBandRows))
	results := make([]pngBand, bands)
	errs := make([]error, bands)
	var wg sync.WaitGroup
	for b := range bands {
		wg.Go(func() {
			y0, y1 := src.height*b/bands, src.height*(b+1)/bands
			results[b], errs[b] = src.compressBand(y0, y1, b == bands-1)
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
	if err := writeChunk(w, "IHDR", src.ihdr()); err != nil {
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
