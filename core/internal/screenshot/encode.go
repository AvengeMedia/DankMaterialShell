package screenshot

import (
	"bufio"
	"fmt"
	"image"
	"image/jpeg"
	"image/png"
	"io"
	"os"
	"path/filepath"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
)

func BufferToImage(buf *ShmBuffer) *image.RGBA {
	return BufferToImageWithFormat(buf, uint32(FormatARGB8888))
}

func BufferToImageWithFormat(buf *ShmBuffer, format uint32) *image.RGBA {
	img := image.NewRGBA(image.Rect(0, 0, buf.Width, buf.Height))
	data := buf.Data()

	var swapRB bool
	switch format {
	case uint32(FormatABGR8888), uint32(FormatXBGR8888):
		swapRB = false
	default:
		swapRB = true
	}

	for y := 0; y < buf.Height; y++ {
		srcOff := y * buf.Stride
		dstOff := y * img.Stride
		for x := 0; x < buf.Width; x++ {
			si := srcOff + x*4
			di := dstOff + x*4
			if si+3 >= len(data) || di+3 >= len(img.Pix) {
				continue
			}
			if swapRB {
				img.Pix[di+0] = data[si+2]
				img.Pix[di+1] = data[si+1]
				img.Pix[di+2] = data[si+0]
			} else {
				img.Pix[di+0] = data[si+0]
				img.Pix[di+1] = data[si+1]
				img.Pix[di+2] = data[si+2]
			}
			img.Pix[di+3] = 255
		}
	}
	return img
}

func EncodePNG(w io.Writer, img image.Image) error {
	enc := png.Encoder{CompressionLevel: png.BestSpeed}
	return enc.Encode(w, img)
}

func EncodeJPEG(w io.Writer, img image.Image, quality int) error {
	return jpeg.Encode(w, img, &jpeg.Options{Quality: quality})
}

func EncodePPM(w io.Writer, img *image.RGBA) error {
	bw := bufio.NewWriter(w)
	bounds := img.Bounds()
	if _, err := fmt.Fprintf(bw, "P6\n%d %d\n255\n", bounds.Dx(), bounds.Dy()); err != nil {
		return err
	}
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			off := (y-bounds.Min.Y)*img.Stride + (x-bounds.Min.X)*4
			if err := bw.WriteByte(img.Pix[off+0]); err != nil {
				return err
			}
			if err := bw.WriteByte(img.Pix[off+1]); err != nil {
				return err
			}
			if err := bw.WriteByte(img.Pix[off+2]); err != nil {
				return err
			}
		}
	}
	return bw.Flush()
}

func GenerateFilename(format Format) string {
	t := time.Now()
	ext := "png"
	switch format {
	case FormatJPEG:
		ext = "jpg"
	case FormatPPM:
		ext = "ppm"
	}
	return fmt.Sprintf("screenshot_%s.%s", t.Format("2006-01-02_15-04-05"), ext)
}

func GetOutputDir() string {
	if dir := os.Getenv("DMS_SCREENSHOT_DIR"); dir != "" {
		return dir
	}

	if xdgPics := utils.XDGPicturesDir(); xdgPics != "" {
		screenshotDir := filepath.Join(xdgPics, "Screenshots")
		if err := os.MkdirAll(screenshotDir, 0o755); err == nil {
			return screenshotDir
		}
		return xdgPics
	}

	if home, err := os.UserHomeDir(); err == nil {
		return home
	}
	return "."
}

func WriteToFile(buf *ShmBuffer, path string, format Format, quality int) error {
	return WriteToFileWithFormat(buf, path, format, quality, uint32(FormatARGB8888))
}

func WriteToFileWithFormat(buf *ShmBuffer, path string, format Format, quality int, pixelFormat uint32) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()

	img := BufferToImageWithFormat(buf, pixelFormat)
	switch format {
	case FormatJPEG:
		return EncodeJPEG(f, img, quality)
	case FormatPPM:
		return EncodePPM(f, img)
	default:
		return EncodePNG(f, img)
	}
}
