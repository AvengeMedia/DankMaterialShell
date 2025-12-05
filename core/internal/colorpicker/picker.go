package colorpicker

import (
	"fmt"
	"math"
	"sync"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/proto/keyboard_shortcuts_inhibit"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/proto/wlr_layer_shell"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/proto/wlr_screencopy"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/proto/wp_viewporter"
	"github.com/AvengeMedia/DankMaterialShell/core/pkg/go-wayland/wayland/client"
)

type Config struct {
	Format       OutputFormat
	CustomFormat string
	Lowercase    bool
	Autocopy     bool
	Notify       bool
}

type Output struct {
	wlOutput        *client.Output
	name            string
	globalName      uint32
	x, y            int32
	width           int32
	height          int32
	scale           int32
	fractionalScale float64
}

type LayerSurface struct {
	output     *Output
	state      *SurfaceState
	wlSurface  *client.Surface
	layerSurf  *wlr_layer_shell.ZwlrLayerSurfaceV1
	viewport   *wp_viewporter.WpViewport
	wlPool     *client.ShmPool
	wlBuffer   *client.Buffer
	configured bool
	hidden     bool
}

type Picker struct {
	config Config

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

	outputs   map[uint32]*Output
	outputsMu sync.Mutex

	surfaces      []*LayerSurface
	activeSurface *LayerSurface

	running     bool
	pickedColor *Color
	err         error
}

func New(config Config) *Picker {
	return &Picker{
		config:  config,
		outputs: make(map[uint32]*Output),
	}
}

func (p *Picker) Run() (*Color, error) {
	if err := p.connect(); err != nil {
		return nil, fmt.Errorf("wayland connect: %w", err)
	}
	defer p.cleanup()

	if err := p.setupRegistry(); err != nil {
		return nil, fmt.Errorf("registry setup: %w", err)
	}

	if err := p.roundtrip(); err != nil {
		return nil, fmt.Errorf("roundtrip: %w", err)
	}

	if p.screencopy == nil {
		return nil, fmt.Errorf("compositor does not support wlr-screencopy-unstable-v1")
	}

	if p.layerShell == nil {
		return nil, fmt.Errorf("compositor does not support wlr-layer-shell-unstable-v1")
	}

	if p.seat == nil {
		return nil, fmt.Errorf("no seat available")
	}

	if err := p.roundtrip(); err != nil {
		return nil, fmt.Errorf("roundtrip: %w", err)
	}

	if err := p.createSurfaces(); err != nil {
		return nil, fmt.Errorf("create surfaces: %w", err)
	}

	if err := p.roundtrip(); err != nil {
		return nil, fmt.Errorf("roundtrip: %w", err)
	}

	p.running = true
	for p.running {
		if err := p.ctx.Dispatch(); err != nil {
			p.err = err
			break
		}

		p.checkDone()
	}

	if p.err != nil {
		return nil, p.err
	}

	return p.pickedColor, nil
}

func (p *Picker) checkDone() {
	for _, ls := range p.surfaces {
		picked, cancelled := ls.state.IsDone()
		switch {
		case cancelled:
			p.running = false
			return
		case picked:
			color, ok := ls.state.PickColor()
			if ok {
				p.pickedColor = &color
			}
			p.running = false
			return
		}
	}
}

func (p *Picker) connect() error {
	display, err := client.Connect("")
	if err != nil {
		return err
	}
	p.display = display
	p.ctx = display.Context()
	return nil
}

func (p *Picker) roundtrip() error {
	callback, err := p.display.Sync()
	if err != nil {
		return err
	}

	done := make(chan struct{})
	callback.SetDoneHandler(func(e client.CallbackDoneEvent) {
		close(done)
	})

	for {
		select {
		case <-done:
			return nil
		default:
			if err := p.ctx.Dispatch(); err != nil {
				return err
			}
		}
	}
}

func (p *Picker) setupRegistry() error {
	registry, err := p.display.GetRegistry()
	if err != nil {
		return err
	}
	p.registry = registry

	registry.SetGlobalHandler(func(e client.RegistryGlobalEvent) {
		p.handleGlobal(e)
	})

	registry.SetGlobalRemoveHandler(func(e client.RegistryGlobalRemoveEvent) {
		p.outputsMu.Lock()
		delete(p.outputs, e.Name)
		p.outputsMu.Unlock()
	})

	return nil
}

func (p *Picker) handleGlobal(e client.RegistryGlobalEvent) {
	switch e.Interface {
	case client.CompositorInterfaceName:
		compositor := client.NewCompositor(p.ctx)
		if err := p.registry.Bind(e.Name, e.Interface, e.Version, compositor); err == nil {
			p.compositor = compositor
		}

	case client.ShmInterfaceName:
		shm := client.NewShm(p.ctx)
		if err := p.registry.Bind(e.Name, e.Interface, e.Version, shm); err == nil {
			p.shm = shm
		}

	case client.SeatInterfaceName:
		seat := client.NewSeat(p.ctx)
		if err := p.registry.Bind(e.Name, e.Interface, e.Version, seat); err == nil {
			p.seat = seat
			p.setupInput()
		}

	case client.OutputInterfaceName:
		output := client.NewOutput(p.ctx)
		version := e.Version
		if version > 4 {
			version = 4
		}
		if err := p.registry.Bind(e.Name, e.Interface, version, output); err == nil {
			p.outputsMu.Lock()
			p.outputs[e.Name] = &Output{
				wlOutput:        output,
				globalName:      e.Name,
				scale:           1,
				fractionalScale: 1.0,
			}
			p.outputsMu.Unlock()
			p.setupOutputHandlers(e.Name, output)
		}

	case wlr_layer_shell.ZwlrLayerShellV1InterfaceName:
		layerShell := wlr_layer_shell.NewZwlrLayerShellV1(p.ctx)
		version := e.Version
		if version > 4 {
			version = 4
		}
		if err := p.registry.Bind(e.Name, e.Interface, version, layerShell); err == nil {
			p.layerShell = layerShell
		}

	case wlr_screencopy.ZwlrScreencopyManagerV1InterfaceName:
		screencopy := wlr_screencopy.NewZwlrScreencopyManagerV1(p.ctx)
		version := e.Version
		if version > 3 {
			version = 3
		}
		if err := p.registry.Bind(e.Name, e.Interface, version, screencopy); err == nil {
			p.screencopy = screencopy
		}

	case wp_viewporter.WpViewporterInterfaceName:
		viewporter := wp_viewporter.NewWpViewporter(p.ctx)
		if err := p.registry.Bind(e.Name, e.Interface, e.Version, viewporter); err == nil {
			p.viewporter = viewporter
		}

	case keyboard_shortcuts_inhibit.ZwpKeyboardShortcutsInhibitManagerV1InterfaceName:
		mgr := keyboard_shortcuts_inhibit.NewZwpKeyboardShortcutsInhibitManagerV1(p.ctx)
		if err := p.registry.Bind(e.Name, e.Interface, e.Version, mgr); err == nil {
			p.shortcutsInhibitMgr = mgr
		}
	}
}

func (p *Picker) setupOutputHandlers(name uint32, output *client.Output) {
	output.SetGeometryHandler(func(e client.OutputGeometryEvent) {
		p.outputsMu.Lock()
		if o, ok := p.outputs[name]; ok {
			o.x = e.X
			o.y = e.Y
		}
		p.outputsMu.Unlock()
	})

	output.SetModeHandler(func(e client.OutputModeEvent) {
		if e.Flags&uint32(client.OutputModeCurrent) == 0 {
			return
		}
		p.outputsMu.Lock()
		if o, ok := p.outputs[name]; ok {
			o.width = e.Width
			o.height = e.Height
		}
		p.outputsMu.Unlock()
	})

	output.SetScaleHandler(func(e client.OutputScaleEvent) {
		p.outputsMu.Lock()
		if o, ok := p.outputs[name]; ok {
			o.scale = e.Factor
			o.fractionalScale = float64(e.Factor)
		}
		p.outputsMu.Unlock()
	})

	output.SetNameHandler(func(e client.OutputNameEvent) {
		p.outputsMu.Lock()
		if o, ok := p.outputs[name]; ok {
			o.name = e.Name
		}
		p.outputsMu.Unlock()
	})
}

func (p *Picker) createSurfaces() error {
	p.outputsMu.Lock()
	outputs := make([]*Output, 0, len(p.outputs))
	for _, o := range p.outputs {
		outputs = append(outputs, o)
	}
	p.outputsMu.Unlock()

	for _, output := range outputs {
		ls, err := p.createLayerSurface(output)
		if err != nil {
			return fmt.Errorf("output %s: %w", output.name, err)
		}
		p.surfaces = append(p.surfaces, ls)
	}

	return nil
}

func (p *Picker) createLayerSurface(output *Output) (*LayerSurface, error) {
	surface, err := p.compositor.CreateSurface()
	if err != nil {
		return nil, fmt.Errorf("create surface: %w", err)
	}

	layerSurf, err := p.layerShell.GetLayerSurface(
		surface,
		output.wlOutput,
		uint32(wlr_layer_shell.ZwlrLayerShellV1LayerOverlay),
		"dms-colorpicker",
	)
	if err != nil {
		return nil, fmt.Errorf("get layer surface: %w", err)
	}

	ls := &LayerSurface{
		output:    output,
		state:     NewSurfaceState(p.config.Format, p.config.Lowercase),
		wlSurface: surface,
		layerSurf: layerSurf,
		hidden:    true, // Start hidden, will show overlay when pointer enters
	}

	if p.viewporter != nil {
		vp, err := p.viewporter.GetViewport(surface)
		if err == nil {
			ls.viewport = vp
		}
	}

	if err := layerSurf.SetAnchor(
		uint32(wlr_layer_shell.ZwlrLayerSurfaceV1AnchorTop) |
			uint32(wlr_layer_shell.ZwlrLayerSurfaceV1AnchorBottom) |
			uint32(wlr_layer_shell.ZwlrLayerSurfaceV1AnchorLeft) |
			uint32(wlr_layer_shell.ZwlrLayerSurfaceV1AnchorRight),
	); err != nil {
		log.Warn("failed to set layer anchor", "err", err)
	}
	if err := layerSurf.SetExclusiveZone(-1); err != nil {
		log.Warn("failed to set exclusive zone", "err", err)
	}
	if err := layerSurf.SetKeyboardInteractivity(uint32(wlr_layer_shell.ZwlrLayerSurfaceV1KeyboardInteractivityExclusive)); err != nil {
		log.Warn("failed to set keyboard interactivity", "err", err)
	}

	layerSurf.SetConfigureHandler(func(e wlr_layer_shell.ZwlrLayerSurfaceV1ConfigureEvent) {
		if err := layerSurf.AckConfigure(e.Serial); err != nil {
			log.Warn("failed to ack configure", "err", err)
		}
		if err := ls.state.OnLayerConfigure(int(e.Width), int(e.Height)); err != nil {
			log.Warn("failed to handle layer configure", "err", err)
		}
		ls.configured = true

		scale := p.computeSurfaceScale(ls)
		ls.state.SetScale(scale)

		if !ls.state.IsReady() {
			p.captureForSurface(ls)
		} else {
			p.redrawSurface(ls)
		}

		// Request shortcut inhibition once surface is configured
		p.ensureShortcutsInhibitor(ls)
	})

	layerSurf.SetClosedHandler(func(e wlr_layer_shell.ZwlrLayerSurfaceV1ClosedEvent) {
		p.running = false
	})

	if err := surface.Commit(); err != nil {
		log.Warn("failed to commit surface", "err", err)
	}
	return ls, nil
}

func (p *Picker) computeSurfaceScale(ls *LayerSurface) int32 {
	out := ls.output
	if out == nil || out.fractionalScale <= 0 {
		return 1
	}

	scale := int32(math.Ceil(out.fractionalScale))
	if scale <= 0 {
		scale = 1
	}
	return scale
}

func (p *Picker) ensureShortcutsInhibitor(ls *LayerSurface) {
	if p.shortcutsInhibitMgr == nil || p.seat == nil || p.shortcutsInhibitor != nil {
		return
	}

	inhibitor, err := p.shortcutsInhibitMgr.InhibitShortcuts(ls.wlSurface, p.seat)
	if err != nil {
		log.Debug("failed to create shortcuts inhibitor", "err", err)
		return
	}

	p.shortcutsInhibitor = inhibitor

	inhibitor.SetActiveHandler(func(e keyboard_shortcuts_inhibit.ZwpKeyboardShortcutsInhibitorV1ActiveEvent) {
		log.Debug("shortcuts inhibitor active")
	})

	inhibitor.SetInactiveHandler(func(e keyboard_shortcuts_inhibit.ZwpKeyboardShortcutsInhibitorV1InactiveEvent) {
		log.Debug("shortcuts inhibitor deactivated by compositor")
	})
}

func (p *Picker) captureForSurface(ls *LayerSurface) {
	frame, err := p.screencopy.CaptureOutput(0, ls.output.wlOutput)
	if err != nil {
		return
	}

	frame.SetBufferHandler(func(e wlr_screencopy.ZwlrScreencopyFrameV1BufferEvent) {
		if err := ls.state.OnScreencopyBuffer(PixelFormat(e.Format), int(e.Width), int(e.Height), int(e.Stride)); err != nil {
			log.Error("failed to create screencopy buffer", "err", err)
		}
	})

	frame.SetBufferDoneHandler(func(e wlr_screencopy.ZwlrScreencopyFrameV1BufferDoneEvent) {
		screenBuf := ls.state.ScreenBuffer()
		if screenBuf == nil {
			return
		}

		pool, err := p.shm.CreatePool(screenBuf.Fd(), int32(screenBuf.Size()))
		if err != nil {
			return
		}

		wlBuffer, err := pool.CreateBuffer(0, int32(screenBuf.Width), int32(screenBuf.Height), int32(screenBuf.Stride), uint32(ls.state.screenFormat))
		if err != nil {
			pool.Destroy()
			return
		}

		if err := frame.Copy(wlBuffer); err != nil {
			log.Error("failed to copy frame", "err", err)
		}
		pool.Destroy()
	})

	frame.SetFlagsHandler(func(e wlr_screencopy.ZwlrScreencopyFrameV1FlagsEvent) {
		ls.state.OnScreencopyFlags(e.Flags)
	})

	frame.SetReadyHandler(func(e wlr_screencopy.ZwlrScreencopyFrameV1ReadyEvent) {
		ls.state.OnScreencopyReady()
		scale := p.computeSurfaceScale(ls)
		ls.state.SetScale(scale)
		frame.Destroy()
		p.redrawSurface(ls)
	})

	frame.SetFailedHandler(func(e wlr_screencopy.ZwlrScreencopyFrameV1FailedEvent) {
		frame.Destroy()
	})
}

func (p *Picker) redrawSurface(ls *LayerSurface) {
	var renderBuf *ShmBuffer
	if ls.hidden {
		// When hidden, just show the screenshot without overlay
		renderBuf = ls.state.RedrawScreenOnly()
	} else {
		renderBuf = ls.state.Redraw()
	}
	if renderBuf == nil {
		return
	}

	if ls.wlPool != nil {
		ls.wlPool.Destroy()
		ls.wlPool = nil
	}
	if ls.wlBuffer != nil {
		ls.wlBuffer.Destroy()
		ls.wlBuffer = nil
	}

	pool, err := p.shm.CreatePool(renderBuf.Fd(), int32(renderBuf.Size()))
	if err != nil {
		return
	}
	ls.wlPool = pool

	wlBuffer, err := pool.CreateBuffer(0, int32(renderBuf.Width), int32(renderBuf.Height), int32(renderBuf.Stride), uint32(FormatARGB8888))
	if err != nil {
		return
	}
	ls.wlBuffer = wlBuffer

	logicalW, logicalH := ls.state.LogicalSize()
	if logicalW == 0 || logicalH == 0 {
		logicalW = int(ls.output.width)
		logicalH = int(ls.output.height)
	}

	scale := ls.state.Scale()
	if scale <= 0 {
		scale = 1
	}

	if ls.viewport != nil {
		srcW := float64(renderBuf.Width) / float64(scale)
		srcH := float64(renderBuf.Height) / float64(scale)
		if err := ls.viewport.SetSource(0, 0, srcW, srcH); err != nil {
			log.Warn("failed to set viewport source", "err", err)
		}
		if err := ls.viewport.SetDestination(int32(logicalW), int32(logicalH)); err != nil {
			log.Warn("failed to set viewport destination", "err", err)
		}
		if err := ls.wlSurface.SetBufferScale(scale); err != nil {
			log.Warn("failed to set buffer scale", "err", err)
		}
	} else {
		if err := ls.wlSurface.SetBufferScale(scale); err != nil {
			log.Warn("failed to set buffer scale", "err", err)
		}
	}

	if err := ls.wlSurface.Attach(wlBuffer, 0, 0); err != nil {
		log.Warn("failed to attach buffer", "err", err)
	}
	if err := ls.wlSurface.Damage(0, 0, int32(logicalW), int32(logicalH)); err != nil {
		log.Warn("failed to damage surface", "err", err)
	}
	if err := ls.wlSurface.Commit(); err != nil {
		log.Warn("failed to commit surface", "err", err)
	}

	ls.state.SwapBuffers()
}

func (p *Picker) hideSurface(ls *LayerSurface) {
	if ls == nil || ls.wlSurface == nil || ls.hidden {
		return
	}
	ls.hidden = true
	// Redraw without the crosshair overlay
	p.redrawSurface(ls)
}

func (p *Picker) setupInput() {
	if p.seat == nil {
		return
	}

	p.seat.SetCapabilitiesHandler(func(e client.SeatCapabilitiesEvent) {
		if e.Capabilities&uint32(client.SeatCapabilityPointer) != 0 && p.pointer == nil {
			pointer, err := p.seat.GetPointer()
			if err == nil {
				p.pointer = pointer
				p.setupPointerHandlers()
			}
		}
		if e.Capabilities&uint32(client.SeatCapabilityKeyboard) != 0 && p.keyboard == nil {
			keyboard, err := p.seat.GetKeyboard()
			if err == nil {
				p.keyboard = keyboard
				p.setupKeyboardHandlers()
			}
		}
	})
}

func (p *Picker) setupPointerHandlers() {
	p.pointer.SetEnterHandler(func(e client.PointerEnterEvent) {
		if err := p.pointer.SetCursor(e.Serial, nil, 0, 0); err != nil {
			log.Debug("failed to hide cursor", "err", err)
		}

		p.activeSurface = nil
		for _, ls := range p.surfaces {
			if ls.wlSurface.ID() == e.Surface.ID() {
				p.activeSurface = ls
				break
			}
		}
		if p.activeSurface == nil {
			return
		}

		// If surface was hidden, mark it as visible again
		if p.activeSurface.hidden {
			p.activeSurface.hidden = false
		}

		p.activeSurface.state.OnPointerMotion(e.SurfaceX, e.SurfaceY)
		p.redrawSurface(p.activeSurface)
	})

	p.pointer.SetLeaveHandler(func(e client.PointerLeaveEvent) {
		for _, ls := range p.surfaces {
			if ls.wlSurface.ID() == e.Surface.ID() {
				p.hideSurface(ls)
				break
			}
		}
	})

	p.pointer.SetMotionHandler(func(e client.PointerMotionEvent) {
		if p.activeSurface == nil {
			return
		}
		p.activeSurface.state.OnPointerMotion(e.SurfaceX, e.SurfaceY)
		p.redrawSurface(p.activeSurface)
	})

	p.pointer.SetButtonHandler(func(e client.PointerButtonEvent) {
		if p.activeSurface == nil {
			return
		}
		p.activeSurface.state.OnPointerButton(e.Button, e.State)
	})
}

func (p *Picker) setupKeyboardHandlers() {
	p.keyboard.SetKeyHandler(func(e client.KeyboardKeyEvent) {
		for _, ls := range p.surfaces {
			ls.state.OnKey(e.Key, e.State)
		}
	})
}

func (p *Picker) cleanup() {
	for _, ls := range p.surfaces {
		if ls.wlBuffer != nil {
			ls.wlBuffer.Destroy()
		}
		if ls.wlPool != nil {
			ls.wlPool.Destroy()
		}
		if ls.viewport != nil {
			ls.viewport.Destroy()
		}
		if ls.layerSurf != nil {
			ls.layerSurf.Destroy()
		}
		if ls.wlSurface != nil {
			ls.wlSurface.Destroy()
		}
		if ls.state != nil {
			ls.state.Destroy()
		}
	}

	if p.shortcutsInhibitor != nil {
		if err := p.shortcutsInhibitor.Destroy(); err != nil {
			log.Debug("failed to destroy shortcuts inhibitor", "err", err)
		}
		p.shortcutsInhibitor = nil
	}

	if p.shortcutsInhibitMgr != nil {
		if err := p.shortcutsInhibitMgr.Destroy(); err != nil {
			log.Debug("failed to destroy shortcuts inhibit manager", "err", err)
		}
		p.shortcutsInhibitMgr = nil
	}

	if p.viewporter != nil {
		p.viewporter.Destroy()
	}

	if p.screencopy != nil {
		p.screencopy.Destroy()
	}

	if p.pointer != nil {
		p.pointer.Release()
	}

	if p.keyboard != nil {
		p.keyboard.Release()
	}

	if p.display != nil {
		p.ctx.Close()
	}
}
