package screenshot

import (
	"context"
	"errors"
	"image"
	"math"
)

func aqueousWindowGeometry(model aqueousSnapshotModel, seatName string) (*WindowGeometry, error) {
	seat, err := model.Seat(seatName)
	if err != nil {
		return nil, err
	}
	if seat.FocusKind != "window" {
		return nil, errors.New("no active window: seat focus is not a window")
	}
	window := model.Entities["window:"+seat.Window]
	if window == nil || !window.Visible || window.Minimized || !window.CanActivate {
		return nil, errors.New("no eligible active window")
	}
	output := model.Entities["output:"+window.Output]
	if output == nil || !output.Enabled || !output.Powered {
		return nil, errors.New("active window output is unavailable")
	}
	box, bounds := window.OuterGeometry, output.Bounds
	if box == nil || bounds == nil || !box.valid() || !bounds.valid() || box.Width <= 0 || box.Height <= 0 || output.Scale <= 0 || math.IsInf(output.Scale, 0) || math.IsNaN(output.Scale) {
		return nil, errors.New("invalid active window geometry")
	}
	return &WindowGeometry{X: int32(box.X), Y: int32(box.Y), Width: int32(box.Width), Height: int32(box.Height), Output: output.Name, Scale: output.Scale, OutputX: int32(bounds.X), OutputY: int32(bounds.Y)}, nil
}

func aqueousCropRect(geom *WindowGeometry, pixels image.Rectangle) image.Rectangle {
	left := math.Floor((float64(geom.X) - float64(geom.OutputX)) * geom.Scale)
	top := math.Floor((float64(geom.Y) - float64(geom.OutputY)) * geom.Scale)
	right := math.Ceil((float64(geom.X) + float64(geom.Width) - float64(geom.OutputX)) * geom.Scale)
	bottom := math.Ceil((float64(geom.Y) + float64(geom.Height) - float64(geom.OutputY)) * geom.Scale)
	return image.Rect(int(left), int(top), int(right), int(bottom)).Intersect(pixels)
}

func aqueousFocusedOutput(seatName string) (string, error) {
	model, err := aqueousSnapshot(context.Background())
	if err != nil {
		return "", err
	}
	seat, err := model.Seat(seatName)
	if err != nil {
		return "", err
	}
	output := model.Entities["output:"+seat.Output]
	if output == nil || !output.Enabled || !output.Powered {
		return "", errors.New("selected output is unavailable")
	}
	return output.Name, nil
}

func (s *Screenshoter) captureAqueousWindow() (*CaptureResult, error) {
	model, err := aqueousSnapshot(context.Background())
	if err != nil {
		return nil, err
	}
	geom, err := aqueousWindowGeometry(model, s.config.Seat)
	if err != nil {
		return nil, err
	}
	region := Region{X: geom.X, Y: geom.Y, Width: geom.Width, Height: geom.Height, Output: geom.Output}
	if s.config.Geometry {
		return geometryResult(region), nil
	}
	output := s.findOutputByName(geom.Output)
	if output == nil {
		return nil, errors.New("active window output disappeared")
	}
	result, err := s.captureWholeOutput(output)
	if err != nil {
		return nil, err
	}
	defer result.Buffer.Close()
	rect := aqueousCropRect(geom, image.Rect(0, 0, result.Buffer.Width, result.Buffer.Height))
	if rect.Empty() {
		return nil, errors.New("active window is outside the output")
	}
	bpp := PixelFormat(result.Format).BytesPerPixel()
	cropped, err := CreateShmBuffer(rect.Dx(), rect.Dy(), rect.Dx()*bpp)
	if err != nil {
		return nil, err
	}
	src, dst := result.Buffer.Data(), cropped.Data()
	for y := 0; y < rect.Dy(); y++ {
		start := (rect.Min.Y+y)*result.Buffer.Stride + rect.Min.X*bpp
		copy(dst[y*cropped.Stride:y*cropped.Stride+rect.Dx()*bpp], src[start:start+rect.Dx()*bpp])
	}
	cropped.Format = PixelFormat(result.Format)
	return &CaptureResult{Buffer: cropped, Region: region, Format: result.Format, Scale: geom.Scale, CICP: result.CICP}, nil
}
