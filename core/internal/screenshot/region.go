package screenshot

import (
	"fmt"
	"sync"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/proto/keyboard_shortcuts_inhibit"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/proto/wlr_layer_shell"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/proto/wlr_screencopy"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/proto/wp_viewporter"
	wlhelpers "github.com/AvengeMedia/DankMaterialShell/core/internal/wayland/client"
	"github.com/AvengeMedia/DankMaterialShell/core/pkg/go-wayland/wayland/client"
)

type SelectionState struct {
	hasSelection bool           // There's a selection to display (pre-loaded or user-drawn)
	dragging     bool           // User is actively drawing a new selection
	surface      *OutputSurface // Surface where selection was made
	// Surface-local logical coordinates (from pointer events)
	anchorX  float64
	anchorY  float64
	currentX float64
	currentY float64
}

type RenderSlot struct {
	shm   *ShmBuffer
	pool  *client.ShmPool
	wlBuf *client.Buffer
	busy  bool
}

type OutputSurface struct {
	output            *WaylandOutput
	wlSurface         *client.Surface
	layerSurf         *wlr_layer_shell.ZwlrLayerSurfaceV1
	viewport          *wp_viewporter.WpViewport
	screenBuf         *ShmBuffer
	screenBufNoCursor *ShmBuffer
	screenFormat      uint32
	logicalW          int
	logicalH          int
	configured        bool
	yInverted         bool

	// Triple-buffered render slots
	slots      [3]*RenderSlot
	slotsReady bool
}

type PreCapture struct {
	screenBuf         *ShmBuffer
	screenBufNoCursor *ShmBuffer
	format            uint32
	yInverted         bool
}

type RegionSelector struct {
	screenshoter *Screenshoter

	display  *client.Display
	registry *client.Registry
	ctx      *client.Context

	compositor *client.Compositor
	shm        *client.Shm
	seat       *client.Seat
	pointer    *client.Pointer
	keyboard   *client.Keyboard
	layerShell *wlr_layer_shell.ZwlrLayerShellV1
	screencopy *wlr_screencopy.ZwlrScreencopyManagerV1
	viewporter *wp_viewporter.WpViewporter

	shortcutsInhibitMgr *keyboard_shortcuts_inhibit.ZwpKeyboardShortcutsInhibitManagerV1
	shortcutsInhibitor  *keyboard_shortcuts_inhibit.ZwpKeyboardShortcutsInhibitorV1

	outputs    map[uint32]*WaylandOutput
	outputsMu  sync.Mutex
	preCapture map[*WaylandOutput]*PreCapture

	surfaces      []*OutputSurface
	activeSurface *OutputSurface

	// Cursor surface for crosshair
	cursorSurface *client.Surface
	cursorBuffer  *ShmBuffer
	cursorWlBuf   *client.Buffer
	cursorPool    *client.ShmPool

	selection          SelectionState
	pointerX           float64
	pointerY           float64
	preSelect          Region
	showCapturedCursor bool
	shiftHeld          bool

	running   bool
	cancelled bool
	result    Region

	capturedBuffer *ShmBuffer
	capturedRegion Region
}

func NewRegionSelector(s *Screenshoter) *RegionSelector {
	return &RegionSelector{
		screenshoter:       s,
		outputs:            make(map[uint32]*WaylandOutput),
		preCapture:         make(map[*WaylandOutput]*PreCapture),
		showCapturedCursor: s.config.Cursor == CursorOn,
	}
}

func (r *RegionSelector) Run() (*CaptureResult, bool, error) {
	r.preSelect = GetLastRegion()

	if err := r.connect(); err != nil {
		return nil, false, fmt.Errorf("wayland connect: %w", err)
	}
	defer r.cleanup()

	if err := r.setupRegistry(); err != nil {
		return nil, false, fmt.Errorf("registry setup: %w", err)
	}

	if err := r.roundtrip(); err != nil {
		return nil, false, fmt.Errorf("roundtrip after registry: %w", err)
	}

	switch {
	case r.screencopy == nil:
		return nil, false, fmt.Errorf("compositor does not support wlr-screencopy-unstable-v1")
	case r.layerShell == nil:
		return nil, false, fmt.Errorf("compositor does not support wlr-layer-shell-unstable-v1")
	case r.seat == nil:
		return nil, false, fmt.Errorf("no seat available")
	case r.compositor == nil:
		return nil, false, fmt.Errorf("compositor not available")
	case r.shm == nil:
		return nil, false, fmt.Errorf("wl_shm not available")
	case len(r.outputs) == 0:
		return nil, false, fmt.Errorf("no outputs available")
	}

	if err := r.roundtrip(); err != nil {
		return nil, false, fmt.Errorf("roundtrip after protocol check: %w", err)
	}

	if err := r.preCaptureAllOutputs(); err != nil {
		return nil, false, fmt.Errorf("pre-capture: %w", err)
	}

	if err := r.createSurfaces(); err != nil {
		return nil, false, fmt.Errorf("create surfaces: %w", err)
	}

	_ = r.createCursor()

	if err := r.roundtrip(); err != nil {
		return nil, false, fmt.Errorf("roundtrip after surfaces: %w", err)
	}

	r.running = true
	for r.running {
		if err := r.ctx.Dispatch(); err != nil {
			return nil, false, fmt.Errorf("dispatch: %w", err)
		}
	}

	if r.cancelled || r.capturedBuffer == nil {
		return nil, r.cancelled, nil
	}

	yInverted := false
	var format uint32
	if r.selection.surface != nil {
		yInverted = r.selection.surface.yInverted
		format = r.selection.surface.screenFormat
	}

	return &CaptureResult{
		Buffer:    r.capturedBuffer,
		Region:    r.result,
		YInverted: yInverted,
		Format:    format,
	}, false, nil
}

func (r *RegionSelector) connect() error {
	display, err := client.Connect("")
	if err != nil {
		return err
	}
	r.display = display
	r.ctx = display.Context()
	return nil
}

func (r *RegionSelector) roundtrip() error {
	return wlhelpers.Roundtrip(r.display, r.ctx)
}

func (r *RegionSelector) setupRegistry() error {
	registry, err := r.display.GetRegistry()
	if err != nil {
		return err
	}
	r.registry = registry

	registry.SetGlobalHandler(func(e client.RegistryGlobalEvent) {
		r.handleGlobal(e)
	})

	registry.SetGlobalRemoveHandler(func(e client.RegistryGlobalRemoveEvent) {
		r.outputsMu.Lock()
		delete(r.outputs, e.Name)
		r.outputsMu.Unlock()
	})

	return nil
}

func (r *RegionSelector) handleGlobal(e client.RegistryGlobalEvent) {
	switch e.Interface {
	case client.CompositorInterfaceName:
		comp := client.NewCompositor(r.ctx)
		if err := r.registry.Bind(e.Name, e.Interface, e.Version, comp); err == nil {
			r.compositor = comp
		}

	case client.ShmInterfaceName:
		shm := client.NewShm(r.ctx)
		if err := r.registry.Bind(e.Name, e.Interface, e.Version, shm); err == nil {
			r.shm = shm
		}

	case client.SeatInterfaceName:
		seat := client.NewSeat(r.ctx)
		if err := r.registry.Bind(e.Name, e.Interface, e.Version, seat); err == nil {
			r.seat = seat
			r.setupInput()
		}

	case client.OutputInterfaceName:
		output := client.NewOutput(r.ctx)
		version := e.Version
		if version > 4 {
			version = 4
		}
		if err := r.registry.Bind(e.Name, e.Interface, version, output); err == nil {
			r.outputsMu.Lock()
			r.outputs[e.Name] = &WaylandOutput{
				wlOutput:        output,
				globalName:      e.Name,
				scale:           1,
				fractionalScale: 1.0,
			}
			r.outputsMu.Unlock()
			r.setupOutputHandlers(e.Name, output)
		}

	case wlr_layer_shell.ZwlrLayerShellV1InterfaceName:
		ls := wlr_layer_shell.NewZwlrLayerShellV1(r.ctx)
		version := e.Version
		if version > 4 {
			version = 4
		}
		if err := r.registry.Bind(e.Name, e.Interface, version, ls); err == nil {
			r.layerShell = ls
		}

	case wlr_screencopy.ZwlrScreencopyManagerV1InterfaceName:
		sc := wlr_screencopy.NewZwlrScreencopyManagerV1(r.ctx)
		version := e.Version
		if version > 3 {
			version = 3
		}
		if err := r.registry.Bind(e.Name, e.Interface, version, sc); err == nil {
			r.screencopy = sc
		}

	case wp_viewporter.WpViewporterInterfaceName:
		vp := wp_viewporter.NewWpViewporter(r.ctx)
		if err := r.registry.Bind(e.Name, e.Interface, e.Version, vp); err == nil {
			r.viewporter = vp
		}

	case keyboard_shortcuts_inhibit.ZwpKeyboardShortcutsInhibitManagerV1InterfaceName:
		mgr := keyboard_shortcuts_inhibit.NewZwpKeyboardShortcutsInhibitManagerV1(r.ctx)
		if err := r.registry.Bind(e.Name, e.Interface, e.Version, mgr); err == nil {
			r.shortcutsInhibitMgr = mgr
		}
	}
}

func (r *RegionSelector) setupOutputHandlers(name uint32, output *client.Output) {
	output.SetGeometryHandler(func(e client.OutputGeometryEvent) {
		r.outputsMu.Lock()
		if o, ok := r.outputs[name]; ok {
			o.x = e.X
			o.y = e.Y
			o.transform = int32(e.Transform)
		}
		r.outputsMu.Unlock()
	})

	output.SetModeHandler(func(e client.OutputModeEvent) {
		if e.Flags&uint32(client.OutputModeCurrent) == 0 {
			return
		}
		r.outputsMu.Lock()
		if o, ok := r.outputs[name]; ok {
			o.width = e.Width
			o.height = e.Height
		}
		r.outputsMu.Unlock()
	})

	output.SetScaleHandler(func(e client.OutputScaleEvent) {
		r.outputsMu.Lock()
		if o, ok := r.outputs[name]; ok {
			o.scale = e.Factor
			o.fractionalScale = float64(e.Factor)
		}
		r.outputsMu.Unlock()
	})

	output.SetNameHandler(func(e client.OutputNameEvent) {
		r.outputsMu.Lock()
		if o, ok := r.outputs[name]; ok {
			o.name = e.Name
		}
		r.outputsMu.Unlock()
	})
}

func (r *RegionSelector) preCaptureAllOutputs() error {
	r.outputsMu.Lock()
	outputs := make([]*WaylandOutput, 0, len(r.outputs))
	for _, o := range r.outputs {
		outputs = append(outputs, o)
	}
	r.outputsMu.Unlock()

	pending := len(outputs) * 2
	done := make(chan struct{}, pending)

	for _, output := range outputs {
		pc := &PreCapture{}
		r.preCapture[output] = pc

		r.preCaptureOutput(output, pc, true, func() { done <- struct{}{} })
		r.preCaptureOutput(output, pc, false, func() { done <- struct{}{} })
	}

	for i := 0; i < pending; i++ {
		if err := r.ctx.Dispatch(); err != nil {
			return err
		}
		select {
		case <-done:
		default:
			i--
		}
	}
	return nil
}

func (r *RegionSelector) preCaptureOutput(output *WaylandOutput, pc *PreCapture, withCursor bool, onReady func()) {
	cursor := int32(0)
	if withCursor {
		cursor = 1
	}

	frame, err := r.screencopy.CaptureOutput(cursor, output.wlOutput)
	if err != nil {
		log.Error("screencopy capture failed", "err", err)
		onReady()
		return
	}

	var capturedBuf *ShmBuffer

	var capturedFormat PixelFormat
	frame.SetBufferHandler(func(e wlr_screencopy.ZwlrScreencopyFrameV1BufferEvent) {
		capturedFormat = PixelFormat(e.Format)
		bpp := capturedFormat.BytesPerPixel()
		if int(e.Stride) < int(e.Width)*bpp {
			log.Error("invalid stride from compositor", "stride", e.Stride, "width", e.Width, "bpp", bpp)
			return
		}
		buf, err := CreateShmBuffer(int(e.Width), int(e.Height), int(e.Stride))
		if err != nil {
			log.Error("create screen buffer failed", "err", err)
			return
		}

		capturedBuf = buf
		buf.Format = capturedFormat

		pool, err := r.shm.CreatePool(buf.Fd(), int32(buf.Size()))
		if err != nil {
			log.Error("create shm pool failed", "err", err)
			return
		}

		wlBuf, err := pool.CreateBuffer(0, int32(buf.Width), int32(buf.Height), int32(buf.Stride), e.Format)
		if err != nil {
			log.Error("create wl_buffer failed", "err", err)
			pool.Destroy()
			return
		}

		if err := frame.Copy(wlBuf); err != nil {
			log.Error("frame copy failed", "err", err)
		}
		pool.Destroy()
	})

	frame.SetFlagsHandler(func(e wlr_screencopy.ZwlrScreencopyFrameV1FlagsEvent) {
		if withCursor {
			pc.yInverted = (e.Flags & 1) != 0
		}
	})

	frame.SetReadyHandler(func(e wlr_screencopy.ZwlrScreencopyFrameV1ReadyEvent) {
		frame.Destroy()

		if capturedBuf == nil {
			onReady()
			return
		}

		if capturedFormat.Is24Bit() {
			converted, newFormat, err := capturedBuf.ConvertTo32Bit(capturedFormat)
			if err != nil {
				log.Error("convert 24-bit to 32-bit failed", "err", err)
			} else if converted != capturedBuf {
				capturedBuf.Close()
				capturedBuf = converted
				capturedFormat = newFormat
			}
		}

		pc.format = uint32(capturedFormat)

		if pc.yInverted {
			capturedBuf.FlipVertical()
			pc.yInverted = false
		}

		if output.transform != TransformNormal {
			invTransform := InverseTransform(output.transform)
			transformed, err := capturedBuf.ApplyTransform(invTransform)
			if err != nil {
				log.Error("apply transform failed", "err", err)
			} else if transformed != capturedBuf {
				capturedBuf.Close()
				capturedBuf = transformed
			}
		}

		if withCursor {
			pc.screenBuf = capturedBuf
		} else {
			pc.screenBufNoCursor = capturedBuf
		}

		onReady()
	})

	frame.SetFailedHandler(func(e wlr_screencopy.ZwlrScreencopyFrameV1FailedEvent) {
		log.Error("screencopy failed")
		frame.Destroy()
		onReady()
	})
}

func (r *RegionSelector) createSurfaces() error {
	r.outputsMu.Lock()
	outputs := make([]*WaylandOutput, 0, len(r.outputs))
	for _, o := range r.outputs {
		outputs = append(outputs, o)
	}
	r.outputsMu.Unlock()

	for _, output := range outputs {
		os, err := r.createOutputSurface(output)
		if err != nil {
			return fmt.Errorf("output %s: %w", output.name, err)
		}
		r.surfaces = append(r.surfaces, os)
	}

	return nil
}

func (r *RegionSelector) createCursor() error {
	const size = 24
	const hotspot = size / 2

	surface, err := r.compositor.CreateSurface()
	if err != nil {
		return fmt.Errorf("create cursor surface: %w", err)
	}
	r.cursorSurface = surface

	buf, err := CreateShmBuffer(size, size, size*4)
	if err != nil {
		return fmt.Errorf("create cursor buffer: %w", err)
	}
	r.cursorBuffer = buf

	// Draw crosshair
	data := buf.Data()
	for y := 0; y < size; y++ {
		for x := 0; x < size; x++ {
			off := (y*size + x) * 4
			// Vertical line
			if x >= hotspot-1 && x <= hotspot && y >= 2 && y < size-2 {
				data[off+0] = 255 // B
				data[off+1] = 255 // G
				data[off+2] = 255 // R
				data[off+3] = 255 // A
				continue
			}
			// Horizontal line
			if y >= hotspot-1 && y <= hotspot && x >= 2 && x < size-2 {
				data[off+0] = 255
				data[off+1] = 255
				data[off+2] = 255
				data[off+3] = 255
				continue
			}
			// Transparent
			data[off+0] = 0
			data[off+1] = 0
			data[off+2] = 0
			data[off+3] = 0
		}
	}

	pool, err := r.shm.CreatePool(buf.Fd(), int32(buf.Size()))
	if err != nil {
		return fmt.Errorf("create cursor pool: %w", err)
	}
	r.cursorPool = pool

	wlBuf, err := pool.CreateBuffer(0, size, size, size*4, uint32(FormatARGB8888))
	if err != nil {
		return fmt.Errorf("create cursor wl_buffer: %w", err)
	}
	r.cursorWlBuf = wlBuf

	if err := surface.Attach(wlBuf, 0, 0); err != nil {
		return fmt.Errorf("attach cursor: %w", err)
	}
	if err := surface.Damage(0, 0, size, size); err != nil {
		return fmt.Errorf("damage cursor: %w", err)
	}
	if err := surface.Commit(); err != nil {
		return fmt.Errorf("commit cursor: %w", err)
	}

	return nil
}

func (r *RegionSelector) createOutputSurface(output *WaylandOutput) (*OutputSurface, error) {
	surface, err := r.compositor.CreateSurface()
	if err != nil {
		return nil, fmt.Errorf("create surface: %w", err)
	}

	layerSurf, err := r.layerShell.GetLayerSurface(
		surface,
		output.wlOutput,
		uint32(wlr_layer_shell.ZwlrLayerShellV1LayerOverlay),
		"dms-screenshot",
	)
	if err != nil {
		return nil, fmt.Errorf("get layer surface: %w", err)
	}

	os := &OutputSurface{
		output:    output,
		wlSurface: surface,
		layerSurf: layerSurf,
	}

	if r.viewporter != nil {
		vp, err := r.viewporter.GetViewport(surface)
		if err == nil {
			os.viewport = vp
		}
	}

	if err := layerSurf.SetAnchor(
		uint32(wlr_layer_shell.ZwlrLayerSurfaceV1AnchorTop) |
			uint32(wlr_layer_shell.ZwlrLayerSurfaceV1AnchorBottom) |
			uint32(wlr_layer_shell.ZwlrLayerSurfaceV1AnchorLeft) |
			uint32(wlr_layer_shell.ZwlrLayerSurfaceV1AnchorRight),
	); err != nil {
		return nil, fmt.Errorf("set anchor: %w", err)
	}
	if err := layerSurf.SetExclusiveZone(-1); err != nil {
		return nil, fmt.Errorf("set exclusive zone: %w", err)
	}
	if err := layerSurf.SetKeyboardInteractivity(uint32(wlr_layer_shell.ZwlrLayerSurfaceV1KeyboardInteractivityExclusive)); err != nil {
		return nil, fmt.Errorf("set keyboard interactivity: %w", err)
	}

	layerSurf.SetConfigureHandler(func(e wlr_layer_shell.ZwlrLayerSurfaceV1ConfigureEvent) {
		if err := layerSurf.AckConfigure(e.Serial); err != nil {
			log.Error("ack configure failed", "err", err)
			return
		}
		os.logicalW = int(e.Width)
		os.logicalH = int(e.Height)
		os.configured = true
		r.captureForSurface(os)
		r.ensureShortcutsInhibitor(os)
	})

	layerSurf.SetClosedHandler(func(e wlr_layer_shell.ZwlrLayerSurfaceV1ClosedEvent) {
		r.running = false
		r.cancelled = true
	})

	if err := surface.Commit(); err != nil {
		return nil, fmt.Errorf("surface commit: %w", err)
	}

	return os, nil
}

func (r *RegionSelector) ensureShortcutsInhibitor(os *OutputSurface) {
	if r.shortcutsInhibitMgr == nil || r.seat == nil || r.shortcutsInhibitor != nil {
		return
	}
	inhibitor, err := r.shortcutsInhibitMgr.InhibitShortcuts(os.wlSurface, r.seat)
	if err == nil {
		r.shortcutsInhibitor = inhibitor
	}
}

func (r *RegionSelector) captureForSurface(os *OutputSurface) {
	pc := r.preCapture[os.output]
	if pc == nil {
		return
	}

	os.screenBuf = pc.screenBuf
	os.screenBufNoCursor = pc.screenBufNoCursor
	os.screenFormat = pc.format
	os.yInverted = pc.yInverted

	if os.logicalW > 0 && os.screenBuf != nil {
		os.output.fractionalScale = float64(os.screenBuf.Width) / float64(os.logicalW)
	}

	r.initRenderBuffer(os)
	r.applyPreSelection(os)
	r.redrawSurface(os)
}

func (r *RegionSelector) initRenderBuffer(os *OutputSurface) {
	if os.screenBuf == nil {
		return
	}

	for i := 0; i < 3; i++ {
		slot := &RenderSlot{}

		buf, err := CreateShmBuffer(os.screenBuf.Width, os.screenBuf.Height, os.screenBuf.Stride)
		if err != nil {
			log.Error("create render slot buffer failed", "err", err)
			return
		}
		slot.shm = buf

		pool, err := r.shm.CreatePool(buf.Fd(), int32(buf.Size()))
		if err != nil {
			log.Error("create render slot pool failed", "err", err)
			buf.Close()
			return
		}
		slot.pool = pool

		wlBuf, err := pool.CreateBuffer(0, int32(buf.Width), int32(buf.Height), int32(buf.Stride), os.screenFormat)
		if err != nil {
			log.Error("create render slot wl_buffer failed", "err", err)
			pool.Destroy()
			buf.Close()
			return
		}
		slot.wlBuf = wlBuf

		slotRef := slot
		wlBuf.SetReleaseHandler(func(e client.BufferReleaseEvent) {
			slotRef.busy = false
		})

		os.slots[i] = slot
	}
	os.slotsReady = true
}

func (os *OutputSurface) acquireFreeSlot() *RenderSlot {
	for _, slot := range os.slots {
		if slot != nil && !slot.busy {
			return slot
		}
	}
	return nil
}

func (r *RegionSelector) applyPreSelection(os *OutputSurface) {
	if r.preSelect.IsEmpty() || os.screenBuf == nil || r.selection.hasSelection {
		return
	}

	if r.preSelect.Output != "" && r.preSelect.Output != os.output.name {
		return
	}

	scaleX := float64(os.logicalW) / float64(os.screenBuf.Width)
	scaleY := float64(os.logicalH) / float64(os.screenBuf.Height)

	x1 := float64(r.preSelect.X-os.output.x) * scaleX
	y1 := float64(r.preSelect.Y-os.output.y) * scaleY
	x2 := float64(r.preSelect.X-os.output.x+r.preSelect.Width) * scaleX
	y2 := float64(r.preSelect.Y-os.output.y+r.preSelect.Height) * scaleY

	r.selection.hasSelection = true
	r.selection.dragging = false
	r.selection.surface = os
	r.selection.anchorX = x1
	r.selection.anchorY = y1
	r.selection.currentX = x2
	r.selection.currentY = y2
	r.activeSurface = os
}

func (r *RegionSelector) getSourceBuffer(os *OutputSurface) *ShmBuffer {
	if !r.showCapturedCursor && os.screenBufNoCursor != nil {
		return os.screenBufNoCursor
	}
	return os.screenBuf
}

func (r *RegionSelector) redrawSurface(os *OutputSurface) {
	srcBuf := r.getSourceBuffer(os)
	if srcBuf == nil || !os.slotsReady {
		return
	}

	slot := os.acquireFreeSlot()
	if slot == nil {
		return
	}

	slot.shm.CopyFrom(srcBuf)

	// Draw overlay (dimming + selection) into this slot
	r.drawOverlay(os, slot.shm)

	if os.viewport != nil {
		_ = os.wlSurface.SetBufferScale(1)
		_ = os.viewport.SetSource(0, 0, float64(slot.shm.Width), float64(slot.shm.Height))
		_ = os.viewport.SetDestination(int32(os.logicalW), int32(os.logicalH))
	} else {
		bufferScale := os.output.scale
		if bufferScale <= 0 {
			bufferScale = 1
		}
		_ = os.wlSurface.SetBufferScale(bufferScale)
	}

	_ = os.wlSurface.Attach(slot.wlBuf, 0, 0)
	_ = os.wlSurface.Damage(0, 0, int32(os.logicalW), int32(os.logicalH))
	_ = os.wlSurface.Commit()

	// Mark this slot as busy until compositor releases it
	slot.busy = true
}

func (r *RegionSelector) cleanup() {
	if r.cursorWlBuf != nil {
		r.cursorWlBuf.Destroy()
	}
	if r.cursorPool != nil {
		r.cursorPool.Destroy()
	}
	if r.cursorSurface != nil {
		r.cursorSurface.Destroy()
	}
	if r.cursorBuffer != nil {
		r.cursorBuffer.Close()
	}

	for _, os := range r.surfaces {
		for _, slot := range os.slots {
			if slot == nil {
				continue
			}
			if slot.wlBuf != nil {
				slot.wlBuf.Destroy()
			}
			if slot.pool != nil {
				slot.pool.Destroy()
			}
			if slot.shm != nil {
				slot.shm.Close()
			}
		}
		if os.viewport != nil {
			os.viewport.Destroy()
		}
		if os.layerSurf != nil {
			os.layerSurf.Destroy()
		}
		if os.wlSurface != nil {
			os.wlSurface.Destroy()
		}
		if os.screenBuf != nil {
			os.screenBuf.Close()
		}
		if os.screenBufNoCursor != nil {
			os.screenBufNoCursor.Close()
		}
	}

	if r.shortcutsInhibitor != nil {
		_ = r.shortcutsInhibitor.Destroy()
	}
	if r.shortcutsInhibitMgr != nil {
		_ = r.shortcutsInhibitMgr.Destroy()
	}
	if r.viewporter != nil {
		r.viewporter.Destroy()
	}
	if r.screencopy != nil {
		r.screencopy.Destroy()
	}
	if r.pointer != nil {
		r.pointer.Release()
	}
	if r.keyboard != nil {
		r.keyboard.Release()
	}
	if r.display != nil {
		r.ctx.Close()
	}
}
