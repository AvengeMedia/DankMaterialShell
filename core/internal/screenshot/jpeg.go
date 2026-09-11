package screenshot

import (
	"bytes"
	"errors"
	"fmt"
	"image/jpeg"
	"io"
	"sync"
)

const (
	jpegMCU      = 16
	jpegBandRows = 4 * jpegMCU
)

// EncodeBufferJPEG encodes MCU-aligned bands in parallel and splices the scans
// with restart markers. Valid because stdlib uses the same huffman and quant
// tables for every band, byte-aligns each scan end, and DC prediction resets
// at restart markers; decoded output is identical to a serial encode.
func EncodeBufferJPEG(w io.Writer, buf *ShmBuffer, format uint32, quality int) error {
	if buf.Width <= 0 || buf.Height <= 0 {
		return errors.New("jpeg: empty image")
	}

	bands := (buf.Height + jpegBandRows - 1) / jpegBandRows
	if bands < 2 {
		return EncodeJPEG(w, BufferToImageWithFormat(buf, format), quality)
	}

	parts := make([][]byte, bands)
	errs := make([]error, bands)
	var wg sync.WaitGroup
	for b := range bands {
		wg.Go(func() {
			y0 := b * jpegBandRows
			y1 := min(y0+jpegBandRows, buf.Height)
			var out bytes.Buffer
			errs[b] = jpeg.Encode(&out, bufferRowsToRGBA(buf, format, y0, y1), &jpeg.Options{Quality: quality})
			parts[b] = out.Bytes()
		})
	}
	wg.Wait()
	if err := errors.Join(errs...); err != nil {
		return err
	}

	return spliceJPEGBands(w, parts, buf.Width, buf.Height)
}

func jpegSegments(data []byte) (header, scan []byte, err error) {
	if len(data) < 4 || data[0] != 0xff || data[1] != 0xd8 {
		return nil, nil, errors.New("jpeg: missing SOI")
	}
	if data[len(data)-2] != 0xff || data[len(data)-1] != 0xd9 {
		return nil, nil, errors.New("jpeg: missing EOI")
	}

	i := 2
	for i+4 <= len(data) {
		if data[i] != 0xff {
			return nil, nil, fmt.Errorf("jpeg: expected marker at %d", i)
		}
		segEnd := i + 2 + (int(data[i+2])<<8 | int(data[i+3]))
		if segEnd > len(data) {
			return nil, nil, fmt.Errorf("jpeg: segment overruns at %d", i)
		}
		if data[i+1] == 0xda {
			return data[:segEnd], data[segEnd : len(data)-2], nil
		}
		i = segEnd
	}
	return nil, nil, errors.New("jpeg: no SOS")
}

func patchSOFHeight(header []byte, height int) error {
	for i := 2; i+8 <= len(header); {
		if header[i] != 0xff {
			return fmt.Errorf("jpeg: expected marker at %d", i)
		}
		if m := header[i+1]; m >= 0xc0 && m <= 0xc2 {
			header[i+5] = byte(height >> 8)
			header[i+6] = byte(height)
			return nil
		}
		i += 2 + (int(header[i+2])<<8 | int(header[i+3]))
	}
	return errors.New("jpeg: no SOF")
}

func spliceJPEGBands(w io.Writer, parts [][]byte, width, height int) error {
	header, firstScan, err := jpegSegments(parts[0])
	if err != nil {
		return err
	}
	header = bytes.Clone(header)
	if err := patchSOFHeight(header, height); err != nil {
		return err
	}

	mcusPerRow := (width + jpegMCU - 1) / jpegMCU
	interval := jpegBandRows / jpegMCU * mcusPerRow
	sos := bytes.LastIndex(header, []byte{0xff, 0xda})
	dri := []byte{0xff, 0xdd, 0x00, 0x04, byte(interval >> 8), byte(interval)}

	pieces := [][]byte{header[:sos], dri, header[sos:], firstScan}
	for b := 1; b < len(parts); b++ {
		_, scan, err := jpegSegments(parts[b])
		if err != nil {
			return err
		}
		pieces = append(pieces, []byte{0xff, 0xd0 | byte((b-1)%8)}, scan)
	}
	pieces = append(pieces, []byte{0xff, 0xd9})

	for _, p := range pieces {
		if _, err := w.Write(p); err != nil {
			return err
		}
	}
	return nil
}
