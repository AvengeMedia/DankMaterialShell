package screenshot

import (
	"github.com/AvengeMedia/dankgo/wayland/client"
)

func (r *RegionSelector) setupInput() {
	if r.seat == nil {
		return
	}

	r.seat.SetCapabilitiesHandler(func(e client.SeatCapabilitiesEvent) {
		if e.Capabilities&uint32(client.SeatCapabilityPointer) != 0 && r.pointer == nil {
			if pointer, err := r.seat.GetPointer(); err == nil {
				r.pointer = pointer
				r.setupPointerHandlers()
			}
		}
		if e.Capabilities&uint32(client.SeatCapabilityKeyboard) != 0 && r.keyboard == nil {
			if keyboard, err := r.seat.GetKeyboard(); err == nil {
				r.keyboard = keyboard
				r.setupKeyboardHandlers()
			}
		}
	})
}

func (r *RegionSelector) setupPointerHandlers() {
	r.pointer.SetEnterHandler(func(e client.PointerEnterEvent) {
		if r.cursorSurface != nil {
			_ = r.pointer.SetCursor(e.Serial, r.cursorSurface, 12, 12)
		}

		r.activeSurface = nil
		for _, os := range r.surfaces {
			if os.wlSurface.ID() == e.Surface.ID() {
				r.activeSurface = os
				break
			}
		}

		r.pointerX = e.SurfaceX
		r.pointerY = e.SurfaceY
	})

	r.pointer.SetMotionHandler(func(e client.PointerMotionEvent) {
		if r.activeSurface == nil {
			return
		}

		r.pointerX = e.SurfaceX
		r.pointerY = e.SurfaceY

		if !r.selection.dragging {
			return
		}

		curX, curY := e.SurfaceX, e.SurfaceY
		if r.shiftHeld {
			dx := curX - r.selection.anchorX
			dy := curY - r.selection.anchorY
			adx, ady := dx, dy
			if adx < 0 {
				adx = -adx
			}
			if ady < 0 {
				ady = -ady
			}
			size := adx
			if ady > adx {
				size = ady
			}
			if dx < 0 {
				curX = r.selection.anchorX - size
			} else {
				curX = r.selection.anchorX + size
			}
			if dy < 0 {
				curY = r.selection.anchorY - size
			} else {
				curY = r.selection.anchorY + size
			}
		}

		r.selection.currentX = curX
		r.selection.currentY = curY
		if r.selection.surface != nil {
			r.redrawSurface(r.selection.surface)
		}
	})

	r.pointer.SetButtonHandler(func(e client.PointerButtonEvent) {
		if r.activeSurface == nil {
			return
		}

		if r.phase == phaseScroll {
			if e.Button != 0x110 || e.State != 1 || r.activeSurface != r.selection.surface {
				return
			}
			switch r.scrollBarHit(r.pointerX, r.pointerY) {
			case "done":
				r.finishScroll()
			case "cancel":
				r.cancelled = true
				r.running = false
			}
			return
		}

		switch e.Button {
		case 0x110: // BTN_LEFT
			switch e.State {
			case 1: // pressed
				r.preSelect = Region{}
				r.selection.hasSelection = true
				r.selection.dragging = true
				r.selection.surface = r.activeSurface
				r.selection.anchorX = r.pointerX
				r.selection.anchorY = r.pointerY
				r.selection.currentX = r.pointerX
				r.selection.currentY = r.pointerY
				for _, os := range r.surfaces {
					r.redrawSurface(os)
				}
			case 0: // released
				r.selection.dragging = false
				for _, os := range r.surfaces {
					r.redrawSurface(os)
				}
				if r.screenshoter != nil && r.screenshoter.config.NoConfirm && r.selection.hasSelection {
					r.finishSelection()
				}
			}
		default:
			r.cancelled = true
			r.running = false
		}
	})
}

func (r *RegionSelector) setupKeyboardHandlers() {
	r.keyboard.SetModifiersHandler(func(e client.KeyboardModifiersEvent) {
		r.shiftHeld = e.ModsDepressed&1 != 0
	})

	r.keyboard.SetKeyHandler(func(e client.KeyboardKeyEvent) {
		if e.State != 1 {
			return
		}

		if r.phase == phaseScroll {
			switch e.Key {
			case 1:
				r.cancelled = true
				r.running = false
			case 28, 96:
				r.finishScroll()
			}
			return
		}

		switch e.Key {
		case 1:
			r.cancelled = true
			r.running = false
		case 25:
			r.showCapturedCursor = !r.showCapturedCursor
			for _, os := range r.surfaces {
				r.redrawSurface(os)
			}
		case 28, 57, 96:
			if r.selection.hasSelection {
				r.finishSelection()
			}
		}
	})
}

func (r *RegionSelector) selectionDeviceRect() (*OutputSurface, int, int, int, int) {
	if r.selection.surface == nil {
		return nil, 0, 0, 0, 0
	}

	os := r.selection.surface
	bounds, ok := r.selectionRenderBounds(os)
	if !ok {
		return nil, 0, 0, 0, 0
	}

	return os, bounds.x, bounds.y, bounds.w, bounds.h
}

func (r *RegionSelector) finishSelection() {
	os, bx1, by1, w, h := r.selectionDeviceRect()
	if os == nil {
		r.running = false
		return
	}

	if r.screenshoter != nil && r.screenshoter.config.Mode == ModeScroll {
		r.enterScrollPhase(os, bx1, by1, w, h)
		return
	}

	srcBuf := r.getSourceBuffer(os)

	cropped, err := CreateShmBuffer(w, h, w*4)
	if err != nil {
		r.running = false
		return
	}

	srcData := srcBuf.Data()
	dstData := cropped.Data()
	for y := range h {
		srcY := by1 + y
		if os.yInverted {
			srcY = srcBuf.Height - 1 - (by1 + y)
		}
		if srcY < 0 || srcY >= srcBuf.Height {
			continue
		}
		dstY := y
		if os.yInverted {
			dstY = h - 1 - y
		}
		for x := range w {
			srcX := bx1 + x
			if srcX < 0 || srcX >= srcBuf.Width {
				continue
			}
			si := srcY*srcBuf.Stride + srcX*4
			di := dstY*cropped.Stride + x*4
			if si+3 < len(srcData) && di+3 < len(dstData) {
				dstData[di+0] = srcData[si+0]
				dstData[di+1] = srcData[si+1]
				dstData[di+2] = srcData[si+2]
				dstData[di+3] = srcData[si+3]
			}
		}
	}

	r.capturedBuffer = cropped
	r.capturedRegion = Region{
		X:      int32(bx1),
		Y:      int32(by1),
		Width:  int32(w),
		Height: int32(h),
		Output: os.output.name,
	}

	// Also store for "last region" feature with global coords
	r.result = Region{
		X:      int32(bx1) + os.output.x,
		Y:      int32(by1) + os.output.y,
		Width:  int32(w),
		Height: int32(h),
		Output: os.output.name,
	}

	r.running = false
}
