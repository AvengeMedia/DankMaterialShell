package screenshot

import (
	"github.com/AvengeMedia/DankMaterialShell/core/pkg/go-wayland/wayland/client"
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
		for _, os := range r.surfaces {
			r.redrawSurface(os)
		}
	})

	r.pointer.SetButtonHandler(func(e client.PointerButtonEvent) {
		if r.activeSurface == nil {
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

func (r *RegionSelector) finishSelection() {
	if r.selection.surface == nil {
		r.running = false
		return
	}

	os := r.selection.surface
	srcBuf := r.getSourceBuffer(os)
	if srcBuf == nil {
		r.running = false
		return
	}

	x1, y1 := r.selection.anchorX, r.selection.anchorY
	x2, y2 := r.selection.currentX, r.selection.currentY

	if x1 > x2 {
		x1, x2 = x2, x1
	}
	if y1 > y2 {
		y1, y2 = y2, y1
	}

	scaleX, scaleY := 1.0, 1.0
	if os.logicalW > 0 {
		scaleX = float64(srcBuf.Width) / float64(os.logicalW)
		scaleY = float64(srcBuf.Height) / float64(os.logicalH)
	}

	bx1 := int(x1 * scaleX)
	by1 := int(y1 * scaleY)
	bx2 := int(x2 * scaleX)
	by2 := int(y2 * scaleY)

	// Clamp to buffer bounds
	if bx1 < 0 {
		bx1 = 0
	}
	if by1 < 0 {
		by1 = 0
	}
	if bx2 > srcBuf.Width {
		bx2 = srcBuf.Width
	}
	if by2 > srcBuf.Height {
		by2 = srcBuf.Height
	}

	w, h := bx2-bx1+1, by2-by1+1
	if r.shiftHeld && w != h {
		if w < h {
			h = w
		} else {
			w = h
		}
	}
	if w < 1 {
		w = 1
	}
	if h < 1 {
		h = 1
	}

	// Create cropped buffer and copy pixels directly
	cropped, err := CreateShmBuffer(w, h, w*4)
	if err != nil {
		r.running = false
		return
	}

	srcData := srcBuf.Data()
	dstData := cropped.Data()
	for y := 0; y < h; y++ {
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
		for x := 0; x < w; x++ {
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
