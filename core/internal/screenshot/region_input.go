package screenshot

import (
	"math"

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
		if r.selection.dragging {
			r.updateSelectionCurrent(r.activeSurface, r.pointerX, r.pointerY)
		}
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

		r.updateSelectionCurrent(r.activeSurface, e.SurfaceX, e.SurfaceY)
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
				r.selection.anchorX = r.pointerX + float64(r.activeSurface.output.x)
				r.selection.anchorY = r.pointerY + float64(r.activeSurface.output.y)
				r.selection.currentX = r.selection.anchorX
				r.selection.currentY = r.selection.anchorY
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

func (r *RegionSelector) updateSelectionCurrent(os *OutputSurface, surfaceX, surfaceY float64) {
	if os == nil || os.output == nil || !r.selection.dragging {
		return
	}

	curX := surfaceX + float64(os.output.x)
	curY := surfaceY + float64(os.output.y)
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
	for _, surface := range r.surfaces {
		r.redrawSurface(surface)
	}
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
	if r.screenshoter != nil && r.screenshoter.config.Mode == ModeScroll && r.selectionSpansOutputs() {
		r.clampSelectionToSurface()
	}

	if r.selectionSpansOutputs() {
		r.finishSelectionAcrossOutputs()
		return
	}

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

func (r *RegionSelector) clampSelectionToSurface() {
	os := r.selection.surface
	if os == nil || os.output == nil {
		return
	}

	minX := float64(os.output.x)
	minY := float64(os.output.y)
	maxX := minX + float64(os.logicalW)
	maxY := minY + float64(os.logicalH)
	r.selection.currentX = math.Max(minX, math.Min(maxX, r.selection.currentX))
	r.selection.currentY = math.Max(minY, math.Min(maxY, r.selection.currentY))
}

func (r *RegionSelector) selectionSpansOutputs() bool {
	if !r.selection.hasSelection || r.selection.surface == nil {
		return false
	}

	os := r.selection.surface
	minX := math.Min(r.selection.anchorX, r.selection.currentX)
	minY := math.Min(r.selection.anchorY, r.selection.currentY)
	maxX := math.Max(r.selection.anchorX, r.selection.currentX)
	maxY := math.Max(r.selection.anchorY, r.selection.currentY)
	return minX < float64(os.output.x) ||
		minY < float64(os.output.y) ||
		maxX > float64(os.output.x)+float64(os.logicalW) ||
		maxY > float64(os.output.y)+float64(os.logicalH)
}

func (r *RegionSelector) finishSelectionAcrossOutputs() {
	primary := r.selection.surface
	if primary == nil || primary.screenBuf == nil || primary.logicalW <= 0 || primary.logicalH <= 0 {
		r.running = false
		return
	}

	minX := math.Min(r.selection.anchorX, r.selection.currentX)
	minY := math.Min(r.selection.anchorY, r.selection.currentY)
	maxX := math.Max(r.selection.anchorX, r.selection.currentX)
	maxY := math.Max(r.selection.anchorY, r.selection.currentY)
	primaryScale := float64(primary.screenBuf.Width) / float64(primary.logicalW)
	targetW := int(math.Round((maxX - minX) * primaryScale))
	targetH := int(math.Round((maxY - minY) * primaryScale))
	if targetW <= 0 || targetH <= 0 {
		r.running = false
		return
	}

	composite, err := CreateShmBuffer(targetW, targetH, targetW*4)
	if err != nil {
		r.running = false
		return
	}
	composite.Clear()

	for _, os := range r.surfaces {
		src := r.getSourceBuffer(os)
		if src == nil || os.logicalW <= 0 || os.logicalH <= 0 {
			continue
		}

		ix1 := math.Max(minX, float64(os.output.x))
		iy1 := math.Max(minY, float64(os.output.y))
		ix2 := math.Min(maxX, float64(os.output.x)+float64(os.logicalW))
		iy2 := math.Min(maxY, float64(os.output.y)+float64(os.logicalH))
		if ix1 >= ix2 || iy1 >= iy2 {
			continue
		}

		scaleX := float64(src.Width) / float64(os.logicalW)
		scaleY := float64(src.Height) / float64(os.logicalH)
		srcX := int(math.Floor((ix1 - float64(os.output.x)) * scaleX))
		srcY := int(math.Floor((iy1 - float64(os.output.y)) * scaleY))
		srcRight := int(math.Ceil((ix2 - float64(os.output.x)) * scaleX))
		srcBottom := int(math.Ceil((iy2 - float64(os.output.y)) * scaleY))
		srcX = clamp(srcX, 0, src.Width)
		srcY = clamp(srcY, 0, src.Height)
		srcRight = clamp(srcRight, 0, src.Width)
		srcBottom = clamp(srcBottom, 0, src.Height)
		if srcX >= srcRight || srcY >= srcBottom {
			continue
		}

		dstX := int(math.Round((ix1 - minX) * primaryScale))
		dstY := int(math.Round((iy1 - minY) * primaryScale))
		dstW := int(math.Round((ix2 - ix1) * primaryScale))
		dstH := int(math.Round((iy2 - iy1) * primaryScale))
		blitSelectionPiece(composite, src, srcX, srcY, srcRight-srcX, srcBottom-srcY, dstX, dstY, dstW, dstH)
	}

	r.capturedBuffer = composite
	r.capturedRegion = Region{X: 0, Y: 0, Width: int32(targetW), Height: int32(targetH), Output: primary.output.name}
	r.result = Region{
		X:      int32(math.Round((minX-float64(primary.output.x))*primaryScale)) + primary.output.x,
		Y:      int32(math.Round((minY-float64(primary.output.y))*primaryScale)) + primary.output.y,
		Width:  int32(targetW),
		Height: int32(targetH),
		Output: primary.output.name,
	}
	r.running = false
}

func blitSelectionPiece(dst, src *ShmBuffer, srcX, srcY, srcW, srcH, dstX, dstY, dstW, dstH int) {
	if srcW <= 0 || srcH <= 0 || dstW <= 0 || dstH <= 0 {
		return
	}
	for y := 0; y < dstH; y++ {
		canvasY := dstY + y
		if canvasY < 0 || canvasY >= dst.Height {
			continue
		}
		sourceY := srcY + y*srcH/dstH
		for x := 0; x < dstW; x++ {
			canvasX := dstX + x
			if canvasX < 0 || canvasX >= dst.Width {
				continue
			}
			sourceX := srcX + x*srcW/dstW
			si := sourceY*src.Stride + sourceX*4
			di := canvasY*dst.Stride + canvasX*4
			if si+3 >= len(src.Data()) || di+3 >= len(dst.Data()) {
				continue
			}
			dst.Data()[di+0] = src.Data()[si+0]
			dst.Data()[di+1] = src.Data()[si+1]
			dst.Data()[di+2] = src.Data()[si+2]
			dst.Data()[di+3] = src.Data()[si+3]
		}
	}
}
