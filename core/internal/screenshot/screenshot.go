package screenshot

import (
	"fmt"
	"sync"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/proto/wlr_screencopy"
	wlhelpers "github.com/AvengeMedia/DankMaterialShell/core/internal/wayland/client"
	"github.com/AvengeMedia/DankMaterialShell/core/pkg/go-wayland/wayland/client"
)

type WaylandOutput struct {
	wlOutput        *client.Output
	globalName      uint32
	name            string
	x, y            int32
	width           int32
	height          int32
	scale           int32
	fractionalScale float64
	transform       int32
}

type CaptureResult struct {
	Buffer    *ShmBuffer
	Region    Region
	YInverted bool
	Format    uint32
}

type Screenshoter struct {
	config Config

	display  *client.Display
	registry *client.Registry
	ctx      *client.Context

	compositor *client.Compositor
	shm        *client.Shm
	screencopy *wlr_screencopy.ZwlrScreencopyManagerV1

	outputs   map[uint32]*WaylandOutput
	outputsMu sync.Mutex
}

func New(config Config) *Screenshoter {
	return &Screenshoter{
		config:  config,
		outputs: make(map[uint32]*WaylandOutput),
	}
}

func (s *Screenshoter) Run() (*CaptureResult, error) {
	if err := s.connect(); err != nil {
		return nil, fmt.Errorf("wayland connect: %w", err)
	}
	defer s.cleanup()

	if err := s.setupRegistry(); err != nil {
		return nil, fmt.Errorf("registry setup: %w", err)
	}

	if err := s.roundtrip(); err != nil {
		return nil, fmt.Errorf("roundtrip: %w", err)
	}

	if s.screencopy == nil {
		return nil, fmt.Errorf("compositor does not support wlr-screencopy-unstable-v1")
	}

	if err := s.roundtrip(); err != nil {
		return nil, fmt.Errorf("roundtrip: %w", err)
	}

	switch s.config.Mode {
	case ModeLastRegion:
		return s.captureLastRegion()
	case ModeRegion:
		return s.captureRegion()
	case ModeWindow:
		return s.captureWindow()
	case ModeOutput:
		return s.captureOutput(s.config.OutputName)
	case ModeFullScreen:
		return s.captureFullScreen()
	case ModeAllScreens:
		return s.captureAllScreens()
	default:
		return s.captureRegion()
	}
}

func (s *Screenshoter) captureLastRegion() (*CaptureResult, error) {
	lastRegion := GetLastRegion()
	if lastRegion.IsEmpty() {
		return s.captureRegion()
	}

	output := s.findOutputForRegion(lastRegion)
	if output == nil {
		return s.captureRegion()
	}

	return s.captureRegionOnOutput(output, lastRegion)
}

func (s *Screenshoter) captureRegion() (*CaptureResult, error) {
	selector := NewRegionSelector(s)
	result, cancelled, err := selector.Run()
	if err != nil {
		return nil, fmt.Errorf("region selection: %w", err)
	}
	if cancelled || result == nil {
		return nil, nil
	}

	if err := SaveLastRegion(result.Region); err != nil {
		log.Debug("failed to save last region", "err", err)
	}

	return result, nil
}

func (s *Screenshoter) captureWindow() (*CaptureResult, error) {
	geom, err := GetActiveWindow()
	if err != nil {
		return nil, err
	}

	region := Region{
		X:      geom.X,
		Y:      geom.Y,
		Width:  geom.Width,
		Height: geom.Height,
	}

	var output *WaylandOutput
	if geom.Output != "" {
		output = s.findOutputByName(geom.Output)
	}
	if output == nil {
		output = s.findOutputForRegion(region)
	}
	if output == nil {
		return nil, fmt.Errorf("could not find output for window")
	}

	switch DetectCompositor() {
	case CompositorHyprland:
		return s.captureAndCrop(output, region)
	case CompositorDWL:
		return s.captureDWLWindow(output, region, geom)
	default:
		return s.captureRegionOnOutput(output, region)
	}
}

func (s *Screenshoter) captureDWLWindow(output *WaylandOutput, region Region, geom *WindowGeometry) (*CaptureResult, error) {
	result, err := s.captureWholeOutput(output)
	if err != nil {
		return nil, err
	}

	scale := geom.Scale
	if scale <= 0 || scale == 1.0 {
		if output.fractionalScale > 1.0 {
			scale = output.fractionalScale
		}
	}
	if scale <= 0 {
		scale = 1.0
	}

	localX := int(float64(region.X-geom.OutputX) * scale)
	localY := int(float64(region.Y-geom.OutputY) * scale)
	w := int(float64(region.Width) * scale)
	h := int(float64(region.Height) * scale)

	if localX < 0 {
		w += localX
		localX = 0
	}
	if localY < 0 {
		h += localY
		localY = 0
	}
	if localX+w > result.Buffer.Width {
		w = result.Buffer.Width - localX
	}
	if localY+h > result.Buffer.Height {
		h = result.Buffer.Height - localY
	}

	if w <= 0 || h <= 0 {
		result.Buffer.Close()
		return nil, fmt.Errorf("window not visible on output")
	}

	cropped, err := CreateShmBuffer(w, h, w*4)
	if err != nil {
		result.Buffer.Close()
		return nil, fmt.Errorf("create crop buffer: %w", err)
	}

	srcData := result.Buffer.Data()
	dstData := cropped.Data()

	for y := 0; y < h; y++ {
		srcY := localY + y
		if result.YInverted {
			srcY = result.Buffer.Height - 1 - (localY + y)
		}
		if srcY < 0 || srcY >= result.Buffer.Height {
			continue
		}

		dstY := y
		if result.YInverted {
			dstY = h - 1 - y
		}

		for x := 0; x < w; x++ {
			srcX := localX + x
			if srcX < 0 || srcX >= result.Buffer.Width {
				continue
			}

			si := srcY*result.Buffer.Stride + srcX*4
			di := dstY*cropped.Stride + x*4

			if si+3 >= len(srcData) || di+3 >= len(dstData) {
				continue
			}

			dstData[di+0] = srcData[si+0]
			dstData[di+1] = srcData[si+1]
			dstData[di+2] = srcData[si+2]
			dstData[di+3] = srcData[si+3]
		}
	}

	result.Buffer.Close()
	cropped.Format = PixelFormat(result.Format)

	return &CaptureResult{
		Buffer:    cropped,
		Region:    region,
		YInverted: false,
		Format:    result.Format,
	}, nil
}

func (s *Screenshoter) captureFullScreen() (*CaptureResult, error) {
	output := s.findFocusedOutput()
	if output == nil {
		s.outputsMu.Lock()
		for _, o := range s.outputs {
			output = o
			break
		}
		s.outputsMu.Unlock()
	}

	if output == nil {
		return nil, fmt.Errorf("no output available")
	}

	return s.captureWholeOutput(output)
}

func (s *Screenshoter) captureOutput(name string) (*CaptureResult, error) {
	s.outputsMu.Lock()
	var output *WaylandOutput
	for _, o := range s.outputs {
		if o.name == name {
			output = o
			break
		}
	}
	s.outputsMu.Unlock()

	if output == nil {
		return nil, fmt.Errorf("output %q not found", name)
	}

	return s.captureWholeOutput(output)
}

func (s *Screenshoter) captureAllScreens() (*CaptureResult, error) {
	s.outputsMu.Lock()
	outputs := make([]*WaylandOutput, 0, len(s.outputs))
	for _, o := range s.outputs {
		outputs = append(outputs, o)
	}
	s.outputsMu.Unlock()

	if len(outputs) == 0 {
		return nil, fmt.Errorf("no outputs available")
	}

	if len(outputs) == 1 {
		return s.captureWholeOutput(outputs[0])
	}

	// Capture all outputs first to get actual buffer sizes
	type capturedOutput struct {
		output *WaylandOutput
		result *CaptureResult
		physX  int
		physY  int
	}
	captured := make([]capturedOutput, 0, len(outputs))

	var minX, minY, maxX, maxY int
	first := true

	for _, output := range outputs {
		result, err := s.captureWholeOutput(output)
		if err != nil {
			log.Warn("failed to capture output", "name", output.name, "err", err)
			continue
		}

		outX, outY := output.x, output.y
		scale := float64(output.scale)
		switch DetectCompositor() {
		case CompositorHyprland:
			if hx, hy, _, _, ok := GetHyprlandMonitorGeometry(output.name); ok {
				outX, outY = hx, hy
			}
			if s := GetHyprlandMonitorScale(output.name); s > 0 {
				scale = s
			}
		case CompositorDWL:
			if info, ok := getOutputInfo(output.name); ok {
				outX, outY = info.x, info.y
			}
		}
		if scale <= 0 {
			scale = 1.0
		}

		physX := int(float64(outX) * scale)
		physY := int(float64(outY) * scale)

		captured = append(captured, capturedOutput{
			output: output,
			result: result,
			physX:  physX,
			physY:  physY,
		})

		right := physX + result.Buffer.Width
		bottom := physY + result.Buffer.Height

		if first {
			minX, minY = physX, physY
			maxX, maxY = right, bottom
			first = false
			continue
		}

		if physX < minX {
			minX = physX
		}
		if physY < minY {
			minY = physY
		}
		if right > maxX {
			maxX = right
		}
		if bottom > maxY {
			maxY = bottom
		}
	}

	if len(captured) == 0 {
		return nil, fmt.Errorf("failed to capture any outputs")
	}

	if len(captured) == 1 {
		return captured[0].result, nil
	}

	totalW := maxX - minX
	totalH := maxY - minY

	compositeStride := totalW * 4
	composite, err := CreateShmBuffer(totalW, totalH, compositeStride)
	if err != nil {
		for _, c := range captured {
			c.result.Buffer.Close()
		}
		return nil, fmt.Errorf("create composite buffer: %w", err)
	}

	composite.Clear()

	var format uint32
	for _, c := range captured {
		if format == 0 {
			format = c.result.Format
		}
		s.blitBuffer(composite, c.result.Buffer, c.physX-minX, c.physY-minY, c.result.YInverted)
		c.result.Buffer.Close()
	}

	return &CaptureResult{
		Buffer: composite,
		Region: Region{X: int32(minX), Y: int32(minY), Width: int32(totalW), Height: int32(totalH)},
		Format: format,
	}, nil
}

func (s *Screenshoter) blitBuffer(dst, src *ShmBuffer, dstX, dstY int, yInverted bool) {
	srcData := src.Data()
	dstData := dst.Data()

	for srcY := 0; srcY < src.Height; srcY++ {
		actualSrcY := srcY
		if yInverted {
			actualSrcY = src.Height - 1 - srcY
		}

		dy := dstY + srcY
		if dy < 0 || dy >= dst.Height {
			continue
		}

		srcRowOff := actualSrcY * src.Stride
		dstRowOff := dy * dst.Stride

		for srcX := 0; srcX < src.Width; srcX++ {
			dx := dstX + srcX
			if dx < 0 || dx >= dst.Width {
				continue
			}

			si := srcRowOff + srcX*4
			di := dstRowOff + dx*4

			if si+3 >= len(srcData) || di+3 >= len(dstData) {
				continue
			}

			dstData[di+0] = srcData[si+0]
			dstData[di+1] = srcData[si+1]
			dstData[di+2] = srcData[si+2]
			dstData[di+3] = srcData[si+3]
		}
	}
}

func (s *Screenshoter) captureWholeOutput(output *WaylandOutput) (*CaptureResult, error) {
	cursor := int32(s.config.Cursor)

	frame, err := s.screencopy.CaptureOutput(cursor, output.wlOutput)
	if err != nil {
		return nil, fmt.Errorf("capture output: %w", err)
	}

	result, err := s.processFrame(frame, Region{
		X:      output.x,
		Y:      output.y,
		Width:  output.width,
		Height: output.height,
		Output: output.name,
	})
	if err != nil {
		return nil, err
	}

	if result.YInverted {
		result.Buffer.FlipVertical()
		result.YInverted = false
	}

	if output.transform == TransformNormal {
		return result, nil
	}

	invTransform := InverseTransform(output.transform)
	transformed, err := result.Buffer.ApplyTransform(invTransform)
	if err != nil {
		result.Buffer.Close()
		return nil, fmt.Errorf("apply transform: %w", err)
	}

	if transformed != result.Buffer {
		result.Buffer.Close()
		result.Buffer = transformed
	}

	result.Region.Width = int32(transformed.Width)
	result.Region.Height = int32(transformed.Height)

	return result, nil
}

func (s *Screenshoter) captureAndCrop(output *WaylandOutput, region Region) (*CaptureResult, error) {
	result, err := s.captureWholeOutput(output)
	if err != nil {
		return nil, err
	}

	outX, outY := output.x, output.y
	scale := float64(output.scale)
	if hx, hy, _, _, ok := GetHyprlandMonitorGeometry(output.name); ok {
		outX, outY = hx, hy
	}
	if s := GetHyprlandMonitorScale(output.name); s > 0 {
		scale = s
	}
	if scale <= 0 {
		scale = 1.0
	}

	localX := int(float64(region.X-outX) * scale)
	localY := int(float64(region.Y-outY) * scale)
	w := int(float64(region.Width) * scale)
	h := int(float64(region.Height) * scale)

	cropped, err := CreateShmBuffer(w, h, w*4)
	if err != nil {
		result.Buffer.Close()
		return nil, fmt.Errorf("create crop buffer: %w", err)
	}

	srcData := result.Buffer.Data()
	dstData := cropped.Data()

	for y := 0; y < h; y++ {
		srcY := localY + y
		if result.YInverted {
			srcY = result.Buffer.Height - 1 - (localY + y)
		}
		if srcY < 0 || srcY >= result.Buffer.Height {
			continue
		}

		dstY := y
		if result.YInverted {
			dstY = h - 1 - y
		}

		for x := 0; x < w; x++ {
			srcX := localX + x
			if srcX < 0 || srcX >= result.Buffer.Width {
				continue
			}

			si := srcY*result.Buffer.Stride + srcX*4
			di := dstY*cropped.Stride + x*4

			if si+3 >= len(srcData) || di+3 >= len(dstData) {
				continue
			}

			dstData[di+0] = srcData[si+0]
			dstData[di+1] = srcData[si+1]
			dstData[di+2] = srcData[si+2]
			dstData[di+3] = srcData[si+3]
		}
	}

	result.Buffer.Close()
	cropped.Format = PixelFormat(result.Format)

	return &CaptureResult{
		Buffer:    cropped,
		Region:    region,
		YInverted: false,
		Format:    result.Format,
	}, nil
}

func (s *Screenshoter) captureRegionOnOutput(output *WaylandOutput, region Region) (*CaptureResult, error) {
	if output.transform != TransformNormal {
		return s.captureRegionOnTransformedOutput(output, region)
	}

	scale := output.fractionalScale
	if scale <= 0 && DetectCompositor() == CompositorHyprland {
		scale = GetHyprlandMonitorScale(output.name)
	}
	if scale <= 0 {
		scale = float64(output.scale)
	}
	if scale <= 0 {
		scale = 1.0
	}

	localX := int32(float64(region.X-output.x) * scale)
	localY := int32(float64(region.Y-output.y) * scale)
	w := int32(float64(region.Width) * scale)
	h := int32(float64(region.Height) * scale)

	if DetectCompositor() == CompositorDWL {
		scaledOutW := int32(float64(output.width) * scale)
		scaledOutH := int32(float64(output.height) * scale)
		if localX >= scaledOutW {
			localX = localX % scaledOutW
		}
		if localY >= scaledOutH {
			localY = localY % scaledOutH
		}
		if localX+w > scaledOutW {
			w = scaledOutW - localX
		}
		if localY+h > scaledOutH {
			h = scaledOutH - localY
		}
		if localX < 0 {
			w += localX
			localX = 0
		}
		if localY < 0 {
			h += localY
			localY = 0
		}
	}

	cursor := int32(s.config.Cursor)

	frame, err := s.screencopy.CaptureOutputRegion(cursor, output.wlOutput, localX, localY, w, h)
	if err != nil {
		return nil, fmt.Errorf("capture region: %w", err)
	}

	return s.processFrame(frame, region)
}

func (s *Screenshoter) captureRegionOnTransformedOutput(output *WaylandOutput, region Region) (*CaptureResult, error) {
	result, err := s.captureWholeOutput(output)
	if err != nil {
		return nil, err
	}

	scale := output.fractionalScale
	if scale <= 0 && DetectCompositor() == CompositorHyprland {
		scale = GetHyprlandMonitorScale(output.name)
	}
	if scale <= 0 {
		scale = float64(output.scale)
	}
	if scale <= 0 {
		scale = 1.0
	}

	localX := int(float64(region.X-output.x) * scale)
	localY := int(float64(region.Y-output.y) * scale)
	w := int(float64(region.Width) * scale)
	h := int(float64(region.Height) * scale)

	if localX < 0 {
		w += localX
		localX = 0
	}
	if localY < 0 {
		h += localY
		localY = 0
	}
	if localX+w > result.Buffer.Width {
		w = result.Buffer.Width - localX
	}
	if localY+h > result.Buffer.Height {
		h = result.Buffer.Height - localY
	}

	if w <= 0 || h <= 0 {
		result.Buffer.Close()
		return nil, fmt.Errorf("region not visible on output")
	}

	cropped, err := CreateShmBuffer(w, h, w*4)
	if err != nil {
		result.Buffer.Close()
		return nil, fmt.Errorf("create crop buffer: %w", err)
	}

	srcData := result.Buffer.Data()
	dstData := cropped.Data()

	for y := 0; y < h; y++ {
		srcOff := (localY+y)*result.Buffer.Stride + localX*4
		dstOff := y * cropped.Stride
		if srcOff+w*4 <= len(srcData) && dstOff+w*4 <= len(dstData) {
			copy(dstData[dstOff:dstOff+w*4], srcData[srcOff:srcOff+w*4])
		}
	}

	result.Buffer.Close()
	cropped.Format = PixelFormat(result.Format)

	return &CaptureResult{
		Buffer:    cropped,
		Region:    region,
		YInverted: false,
		Format:    result.Format,
	}, nil
}

func (s *Screenshoter) processFrame(frame *wlr_screencopy.ZwlrScreencopyFrameV1, region Region) (*CaptureResult, error) {
	var buf *ShmBuffer
	var pool *client.ShmPool
	var wlBuf *client.Buffer
	var format PixelFormat
	var yInverted bool
	ready := false
	failed := false

	frame.SetBufferHandler(func(e wlr_screencopy.ZwlrScreencopyFrameV1BufferEvent) {
		format = PixelFormat(e.Format)
		bpp := format.BytesPerPixel()
		if int(e.Stride) < int(e.Width)*bpp {
			log.Error("invalid stride from compositor", "stride", e.Stride, "width", e.Width, "bpp", bpp)
			return
		}
		var err error
		buf, err = CreateShmBuffer(int(e.Width), int(e.Height), int(e.Stride))
		if err != nil {
			log.Error("failed to create buffer", "err", err)
			return
		}
		buf.Format = format
	})

	frame.SetFlagsHandler(func(e wlr_screencopy.ZwlrScreencopyFrameV1FlagsEvent) {
		yInverted = (e.Flags & 1) != 0
	})

	frame.SetBufferDoneHandler(func(e wlr_screencopy.ZwlrScreencopyFrameV1BufferDoneEvent) {
		if buf == nil {
			return
		}

		var err error
		pool, err = s.shm.CreatePool(buf.Fd(), int32(buf.Size()))
		if err != nil {
			log.Error("failed to create pool", "err", err)
			return
		}

		wlBuf, err = pool.CreateBuffer(0, int32(buf.Width), int32(buf.Height), int32(buf.Stride), uint32(format))
		if err != nil {
			pool.Destroy()
			pool = nil
			log.Error("failed to create wl_buffer", "err", err)
			return
		}

		if err := frame.Copy(wlBuf); err != nil {
			log.Error("failed to copy frame", "err", err)
		}
	})

	frame.SetReadyHandler(func(e wlr_screencopy.ZwlrScreencopyFrameV1ReadyEvent) {
		ready = true
	})

	frame.SetFailedHandler(func(e wlr_screencopy.ZwlrScreencopyFrameV1FailedEvent) {
		failed = true
	})

	for !ready && !failed {
		if err := s.ctx.Dispatch(); err != nil {
			frame.Destroy()
			return nil, fmt.Errorf("dispatch: %w", err)
		}
	}

	frame.Destroy()
	if wlBuf != nil {
		wlBuf.Destroy()
	}
	if pool != nil {
		pool.Destroy()
	}

	if failed {
		if buf != nil {
			buf.Close()
		}
		return nil, fmt.Errorf("frame capture failed")
	}

	if format.Is24Bit() {
		converted, newFormat, err := buf.ConvertTo32Bit(format)
		if err != nil {
			buf.Close()
			return nil, fmt.Errorf("convert 24-bit to 32-bit: %w", err)
		}
		if converted != buf {
			buf.Close()
			buf = converted
		}
		format = newFormat
	}

	return &CaptureResult{
		Buffer:    buf,
		Region:    region,
		YInverted: yInverted,
		Format:    uint32(format),
	}, nil
}

func (s *Screenshoter) findOutputByName(name string) *WaylandOutput {
	s.outputsMu.Lock()
	defer s.outputsMu.Unlock()
	for _, o := range s.outputs {
		if o.name == name {
			return o
		}
	}
	return nil
}

func (s *Screenshoter) findOutputForRegion(region Region) *WaylandOutput {
	s.outputsMu.Lock()
	defer s.outputsMu.Unlock()

	cx := region.X + region.Width/2
	cy := region.Y + region.Height/2

	for _, o := range s.outputs {
		x, y, w, h := o.x, o.y, o.width, o.height
		if DetectCompositor() == CompositorHyprland {
			if hx, hy, hw, hh, ok := GetHyprlandMonitorGeometry(o.name); ok {
				x, y, w, h = hx, hy, hw, hh
			}
		}
		if cx >= x && cx < x+w && cy >= y && cy < y+h {
			return o
		}
	}

	for _, o := range s.outputs {
		x, y, w, h := o.x, o.y, o.width, o.height
		if DetectCompositor() == CompositorHyprland {
			if hx, hy, hw, hh, ok := GetHyprlandMonitorGeometry(o.name); ok {
				x, y, w, h = hx, hy, hw, hh
			}
		}
		if region.X >= x && region.X < x+w &&
			region.Y >= y && region.Y < y+h {
			return o
		}
	}

	return nil
}

func (s *Screenshoter) findFocusedOutput() *WaylandOutput {
	if mon := GetFocusedMonitor(); mon != "" {
		s.outputsMu.Lock()
		defer s.outputsMu.Unlock()
		for _, o := range s.outputs {
			if o.name == mon {
				return o
			}
		}
	}
	s.outputsMu.Lock()
	defer s.outputsMu.Unlock()
	for _, o := range s.outputs {
		return o
	}
	return nil
}

func (s *Screenshoter) connect() error {
	display, err := client.Connect("")
	if err != nil {
		return err
	}
	s.display = display
	s.ctx = display.Context()
	return nil
}

func (s *Screenshoter) roundtrip() error {
	return wlhelpers.Roundtrip(s.display, s.ctx)
}

func (s *Screenshoter) setupRegistry() error {
	registry, err := s.display.GetRegistry()
	if err != nil {
		return err
	}
	s.registry = registry

	registry.SetGlobalHandler(func(e client.RegistryGlobalEvent) {
		s.handleGlobal(e)
	})

	registry.SetGlobalRemoveHandler(func(e client.RegistryGlobalRemoveEvent) {
		s.outputsMu.Lock()
		delete(s.outputs, e.Name)
		s.outputsMu.Unlock()
	})

	return nil
}

func (s *Screenshoter) handleGlobal(e client.RegistryGlobalEvent) {
	switch e.Interface {
	case client.CompositorInterfaceName:
		comp := client.NewCompositor(s.ctx)
		if err := s.registry.Bind(e.Name, e.Interface, e.Version, comp); err == nil {
			s.compositor = comp
		}

	case client.ShmInterfaceName:
		shm := client.NewShm(s.ctx)
		if err := s.registry.Bind(e.Name, e.Interface, e.Version, shm); err == nil {
			s.shm = shm
		}

	case client.OutputInterfaceName:
		output := client.NewOutput(s.ctx)
		version := e.Version
		if version > 4 {
			version = 4
		}
		if err := s.registry.Bind(e.Name, e.Interface, version, output); err == nil {
			s.outputsMu.Lock()
			s.outputs[e.Name] = &WaylandOutput{
				wlOutput:        output,
				globalName:      e.Name,
				scale:           1,
				fractionalScale: 1.0,
			}
			s.outputsMu.Unlock()
			s.setupOutputHandlers(e.Name, output)
		}

	case wlr_screencopy.ZwlrScreencopyManagerV1InterfaceName:
		sc := wlr_screencopy.NewZwlrScreencopyManagerV1(s.ctx)
		version := e.Version
		if version > 3 {
			version = 3
		}
		if err := s.registry.Bind(e.Name, e.Interface, version, sc); err == nil {
			s.screencopy = sc
		}
	}
}

func (s *Screenshoter) setupOutputHandlers(name uint32, output *client.Output) {
	output.SetGeometryHandler(func(e client.OutputGeometryEvent) {
		s.outputsMu.Lock()
		if o, ok := s.outputs[name]; ok {
			o.x, o.y = e.X, e.Y
			o.transform = int32(e.Transform)
		}
		s.outputsMu.Unlock()
	})

	output.SetModeHandler(func(e client.OutputModeEvent) {
		if e.Flags&uint32(client.OutputModeCurrent) == 0 {
			return
		}
		s.outputsMu.Lock()
		if o, ok := s.outputs[name]; ok {
			o.width, o.height = e.Width, e.Height
		}
		s.outputsMu.Unlock()
	})

	output.SetScaleHandler(func(e client.OutputScaleEvent) {
		s.outputsMu.Lock()
		if o, ok := s.outputs[name]; ok {
			o.scale = e.Factor
			o.fractionalScale = float64(e.Factor)
		}
		s.outputsMu.Unlock()
	})

	output.SetNameHandler(func(e client.OutputNameEvent) {
		s.outputsMu.Lock()
		if o, ok := s.outputs[name]; ok {
			o.name = e.Name
		}
		s.outputsMu.Unlock()
	})
}

func (s *Screenshoter) cleanup() {
	if s.screencopy != nil {
		s.screencopy.Destroy()
	}
	if s.display != nil {
		s.ctx.Close()
	}
}

func (s *Screenshoter) GetOutputs() []*WaylandOutput {
	s.outputsMu.Lock()
	defer s.outputsMu.Unlock()
	out := make([]*WaylandOutput, 0, len(s.outputs))
	for _, o := range s.outputs {
		out = append(out, o)
	}
	return out
}

func ListOutputs() ([]Output, error) {
	sc := New(DefaultConfig())
	if err := sc.connect(); err != nil {
		return nil, err
	}
	defer sc.cleanup()

	if err := sc.setupRegistry(); err != nil {
		return nil, err
	}
	if err := sc.roundtrip(); err != nil {
		return nil, err
	}
	if err := sc.roundtrip(); err != nil {
		return nil, err
	}

	sc.outputsMu.Lock()
	defer sc.outputsMu.Unlock()

	compositor := DetectCompositor()
	result := make([]Output, 0, len(sc.outputs))
	for _, o := range sc.outputs {
		out := Output{
			Name:            o.name,
			X:               o.x,
			Y:               o.y,
			Width:           o.width,
			Height:          o.height,
			Scale:           o.scale,
			FractionalScale: o.fractionalScale,
			Transform:       o.transform,
		}

		switch compositor {
		case CompositorHyprland:
			if hx, hy, hw, hh, ok := GetHyprlandMonitorGeometry(o.name); ok {
				out.X, out.Y = hx, hy
				out.Width, out.Height = hw, hh
			}
			if s := GetHyprlandMonitorScale(o.name); s > 0 {
				out.FractionalScale = s
			}
		}

		result = append(result, out)
	}
	return result, nil
}
