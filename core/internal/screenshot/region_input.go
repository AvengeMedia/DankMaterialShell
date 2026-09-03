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
		r.cursorSerial = e.Serial
		if r.cursorShape == nil && r.cursorSurface != nil {
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
		r.refreshCursor()
	})

	r.pointer.SetMotionHandler(func(e client.PointerMotionEvent) {
		if r.activeSurface == nil {
			return
		}

		r.pointerX = e.SurfaceX
		r.pointerY = e.SurfaceY

		if r.phase == phaseScroll {
			r.refreshCursor()
			return
		}

		if !r.selection.dragging {
			if r.ctrlHeld && r.selection.hasSelection {
				r.refreshCursor()
			}
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
			case "done", "preview":
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
				pointerX := r.pointerX + float64(r.activeSurface.output.x)
				pointerY := r.pointerY + float64(r.activeSurface.output.y)
				if r.ctrlHeld && r.selection.hasSelection {
					if handle := r.resizeHandleAt(pointerX, pointerY); handle != handleNone {
						if r.beginSelectionResize(handle, pointerX, pointerY) {
							r.refreshCursor()
							break
						}
					}
					if r.beginSelectionMove(pointerX, pointerY) {
						r.selection.dragging = true
						r.refreshCursor()
						break
					}
				}

				r.preSelect = Region{}
				r.movingSelection = false
				r.resizingHandle = handleNone
				r.selection.hasSelection = true
				r.selection.dragging = true
				r.selection.surface = r.activeSurface
				r.selection.anchorX = pointerX
				r.selection.anchorY = pointerY
				r.selection.currentX = r.selection.anchorX
				r.selection.currentY = r.selection.anchorY
				r.refreshCursor()
				for _, os := range r.surfaces {
					r.redrawSurface(os)
				}
			case 0: // released
				r.selection.dragging = false
				r.movingSelection = false
				r.resizingHandle = handleNone
				r.refreshCursor()
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
	if r.movingSelection {
		r.updateMovedSelection(curX, curY)
		return
	}

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

	if r.altHeld {
		if minX, minY, maxX, maxY, ok := surfaceClampBounds(r.selection.surface); ok {
			curX = math.Max(minX, math.Min(maxX, curX))
			curY = math.Max(minY, math.Min(maxY, curY))
		}
	}

	r.selection.currentX = curX
	r.selection.currentY = curY
	for _, surface := range r.surfaces {
		r.redrawSurface(surface)
	}
}

func surfaceClampBounds(os *OutputSurface) (minX, minY, maxX, maxY float64, ok bool) {
	if os == nil || os.output == nil || os.logicalW <= 0 || os.logicalH <= 0 {
		return 0, 0, 0, 0, false
	}
	epsilonX, epsilonY := surfaceEpsilon(os)
	minX = float64(os.output.x)
	minY = float64(os.output.y)
	maxX = minX + float64(os.logicalW) - epsilonX
	maxY = minY + float64(os.logicalH) - epsilonY
	return minX, minY, maxX, maxY, true
}

func (r *RegionSelector) resizeHandleAt(pointerX, pointerY float64) resizeHandle {
	if !r.selection.hasSelection {
		return handleNone
	}

	minX := math.Min(r.selection.anchorX, r.selection.currentX)
	maxX := math.Max(r.selection.anchorX, r.selection.currentX)
	minY := math.Min(r.selection.anchorY, r.selection.currentY)
	maxY := math.Max(r.selection.anchorY, r.selection.currentY)

	const maxDistSq = resizeHitRadius * resizeHitRadius

	distSq := func(cx, cy float64) float64 {
		dx := pointerX - cx
		dy := pointerY - cy
		return dx*dx + dy*dy
	}

	corners := []struct {
		handle resizeHandle
		cx, cy float64
	}{
		{handleTopLeft, minX, minY},
		{handleTopRight, maxX, minY},
		{handleBottomLeft, minX, maxY},
		{handleBottomRight, maxX, maxY},
	}

	bestHandle := handleNone
	bestDist := float64(maxDistSq + 1)

	for _, c := range corners {
		d := distSq(c.cx, c.cy)
		if d <= maxDistSq && d < bestDist {
			bestDist = d
			bestHandle = c.handle
		}
	}

	return bestHandle
}

func (r *RegionSelector) beginSelectionResize(handle resizeHandle, pointerX, pointerY float64) bool {
	if !r.selection.hasSelection || handle == handleNone {
		return false
	}

	minX := math.Min(r.selection.anchorX, r.selection.currentX)
	maxX := math.Max(r.selection.anchorX, r.selection.currentX)
	minY := math.Min(r.selection.anchorY, r.selection.currentY)
	maxY := math.Max(r.selection.anchorY, r.selection.currentY)

	switch handle {
	case handleTopLeft:
		r.selection.anchorX = maxX
		r.selection.anchorY = maxY
		r.selection.currentX = minX
		r.selection.currentY = minY
	case handleTopRight:
		r.selection.anchorX = minX
		r.selection.anchorY = maxY
		r.selection.currentX = maxX
		r.selection.currentY = minY
	case handleBottomLeft:
		r.selection.anchorX = maxX
		r.selection.anchorY = minY
		r.selection.currentX = minX
		r.selection.currentY = maxY
	case handleBottomRight:
		r.selection.anchorX = minX
		r.selection.anchorY = minY
		r.selection.currentX = maxX
		r.selection.currentY = maxY
	}

	r.resizingHandle = handle
	r.movingSelection = false
	r.selection.dragging = true
	return true
}

func (r *RegionSelector) beginSelectionMove(pointerX, pointerY float64) bool {
	if !r.selection.hasSelection {
		return false
	}

	minX := math.Min(r.selection.anchorX, r.selection.currentX)
	minY := math.Min(r.selection.anchorY, r.selection.currentY)
	r.moveOffsetX = pointerX - minX
	r.moveOffsetY = pointerY - minY
	r.movingSelection = true
	return true
}

func (r *RegionSelector) updateMovedSelection(pointerX, pointerY float64) {
	minX := math.Min(r.selection.anchorX, r.selection.currentX)
	minY := math.Min(r.selection.anchorY, r.selection.currentY)
	maxX := math.Max(r.selection.anchorX, r.selection.currentX)
	maxY := math.Max(r.selection.anchorY, r.selection.currentY)
	width := maxX - minX
	height := maxY - minY

	newMinX := pointerX - r.moveOffsetX
	newMinY := pointerY - r.moveOffsetY
	newMinX, newMinY = r.clampMovedSelection(newMinX, newMinY, width, height)
	deltaX := newMinX - minX
	deltaY := newMinY - minY
	r.selection.anchorX += deltaX
	r.selection.currentX += deltaX
	r.selection.anchorY += deltaY
	r.selection.currentY += deltaY
	r.rehomeSelectionSurface()

	for _, surface := range r.surfaces {
		r.redrawSurface(surface)
	}
}

func (r *RegionSelector) rehomeSelectionSurface() {
	minX := math.Min(r.selection.anchorX, r.selection.currentX)
	minY := math.Min(r.selection.anchorY, r.selection.currentY)
	maxX := math.Max(r.selection.anchorX, r.selection.currentX)
	maxY := math.Max(r.selection.anchorY, r.selection.currentY)

	for _, surface := range r.surfaces {
		if surface == nil || surface.output == nil || surface.logicalW <= 0 || surface.logicalH <= 0 {
			continue
		}
		outputMinX := float64(surface.output.x)
		outputMinY := float64(surface.output.y)
		outputMaxX := outputMinX + float64(surface.logicalW)
		outputMaxY := outputMinY + float64(surface.logicalH)
		epsilonX, epsilonY := surfaceEpsilon(surface)
		if minX >= outputMinX && minY >= outputMinY &&
			maxX <= outputMaxX-epsilonX && maxY <= outputMaxY-epsilonY {
			r.selection.surface = surface
			return
		}
	}
}

func (r *RegionSelector) clampMovedSelection(x, y, width, height float64) (float64, float64) {
	var unionMinX, unionMinY, unionMaxX, unionMaxY, unionEpsX, unionEpsY float64
	initialized := false
	for _, surface := range r.surfaces {
		if surface == nil || surface.output == nil || surface.logicalW <= 0 || surface.logicalH <= 0 {
			continue
		}
		outputMinX := float64(surface.output.x)
		outputMinY := float64(surface.output.y)
		outputMaxX := outputMinX + float64(surface.logicalW)
		outputMaxY := outputMinY + float64(surface.logicalH)
		epsilonX, epsilonY := surfaceEpsilon(surface)
		if !initialized {
			unionMinX, unionMinY, unionMaxX, unionMaxY = outputMinX, outputMinY, outputMaxX, outputMaxY
			unionEpsX, unionEpsY = epsilonX, epsilonY
			initialized = true
			continue
		}
		unionMinX = math.Min(unionMinX, outputMinX)
		unionMinY = math.Min(unionMinY, outputMinY)
		unionMaxX = math.Max(unionMaxX, outputMaxX)
		unionMaxY = math.Max(unionMaxY, outputMaxY)
		unionEpsX = math.Max(unionEpsX, epsilonX)
		unionEpsY = math.Max(unionEpsY, epsilonY)
	}
	if !initialized {
		return x, y
	}

	minX, minY := unionMinX, unionMinY
	maxX, maxY := unionMaxX-unionEpsX, unionMaxY-unionEpsY
	if r.altHeld {
		if surfMinX, surfMinY, surfMaxX, surfMaxY, ok := surfaceClampBounds(r.selection.surface); ok {
			if surfMaxX-surfMinX >= width {
				minX, maxX = surfMinX, surfMaxX
			}
			if surfMaxY-surfMinY >= height {
				minY, maxY = surfMinY, surfMaxY
			}
		}
	}

	return clampMoveAxis(x, width, minX, maxX),
		clampMoveAxis(y, height, minY, maxY)
}

func clampMoveAxis(pos, size, lo, hi float64) float64 {
	upper := math.Max(lo, hi-size)
	return math.Max(lo, math.Min(upper, pos))
}

func surfaceEpsilon(surface *OutputSurface) (float64, float64) {
	epsilonX, epsilonY := 1.0, 1.0
	if surface.screenBuf == nil {
		return epsilonX, epsilonY
	}
	if surface.logicalW > 0 && surface.screenBuf.Width > 0 {
		epsilonX = float64(surface.logicalW) / float64(surface.screenBuf.Width)
	}
	if surface.logicalH > 0 && surface.screenBuf.Height > 0 {
		epsilonY = float64(surface.logicalH) / float64(surface.screenBuf.Height)
	}
	return epsilonX, epsilonY
}

func (r *RegionSelector) setupKeyboardHandlers() {
	r.keyboard.SetModifiersHandler(func(e client.KeyboardModifiersEvent) {
		shift := e.ModsDepressed&1 != 0
		ctrl := e.ModsDepressed&4 != 0
		alt := e.ModsDepressed&8 != 0
		changed := shift != r.shiftHeld || ctrl != r.ctrlHeld
		r.shiftHeld = shift
		r.ctrlHeld = ctrl
		r.altHeld = alt
		r.refreshCursor()
		if changed && r.selection.hasSelection {
			for _, os := range r.surfaces {
				r.redrawSurface(os)
			}
		}
	})

	r.keyboard.SetKeyHandler(func(e client.KeyboardKeyEvent) {
		switch e.Key {
		case 29, 97: // Ctrl left/right
			ctrl := e.State != 0
			if ctrl != r.ctrlHeld {
				r.ctrlHeld = ctrl
				r.refreshCursor()
				if r.selection.hasSelection {
					for _, os := range r.surfaces {
						r.redrawSurface(os)
					}
				}
			}
		case 56, 100: // Alt left/right
			r.altHeld = e.State != 0
		}
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
	if r.screenshoter != nil && r.screenshoter.config.Geometry {
		r.running = false
		return
	}

	scrollMode := r.screenshoter != nil && r.screenshoter.config.Mode == ModeScroll
	switch {
	case scrollMode:
		r.clampSelectionToSurface()
	case r.selectionSpansOutputs():
		r.finishSelectionAcrossOutputs()
		return
	}

	os, bx1, by1, w, h := r.selectionDeviceRect()
	if os == nil {
		r.running = false
		return
	}

	if scrollMode {
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
	r.selection.anchorX = math.Max(minX, math.Min(maxX, r.selection.anchorX))
	r.selection.anchorY = math.Max(minY, math.Min(maxY, r.selection.anchorY))
	r.selection.currentX = math.Max(minX, math.Min(maxX, r.selection.currentX))
	r.selection.currentY = math.Max(minY, math.Min(maxY, r.selection.currentY))
}

// selectionExtent is the selection as half-open device pixels on its surface's buffer grid.
type selectionExtent struct {
	surface        *OutputSurface
	x1, y1, x2, y2 int
	scaleX, scaleY float64
}

func (r *RegionSelector) selectionExtent() (selectionExtent, bool) {
	os := r.selection.surface
	if !r.selection.hasSelection || os == nil || os.output == nil || os.screenBuf == nil || os.logicalW <= 0 || os.logicalH <= 0 {
		return selectionExtent{}, false
	}

	scaleX := float64(os.screenBuf.Width) / float64(os.logicalW)
	scaleY := float64(os.screenBuf.Height) / float64(os.logicalH)
	minX := math.Min(r.selection.anchorX, r.selection.currentX) - float64(os.output.x)
	minY := math.Min(r.selection.anchorY, r.selection.currentY) - float64(os.output.y)
	maxX := math.Max(r.selection.anchorX, r.selection.currentX) - float64(os.output.x)
	maxY := math.Max(r.selection.anchorY, r.selection.currentY) - float64(os.output.y)
	return selectionExtent{
		surface: os,
		x1:      int(math.Floor(minX * scaleX)),
		y1:      int(math.Floor(minY * scaleY)),
		x2:      int(math.Floor(maxX*scaleX)) + 1,
		y2:      int(math.Floor(maxY*scaleY)) + 1,
		scaleX:  scaleX,
		scaleY:  scaleY,
	}, true
}

func (e selectionExtent) width() int  { return e.x2 - e.x1 }
func (e selectionExtent) height() int { return e.y2 - e.y1 }

func (e selectionExtent) logical() (x1, y1, x2, y2 float64) {
	ox, oy := float64(e.surface.output.x), float64(e.surface.output.y)
	return ox + float64(e.x1)/e.scaleX, oy + float64(e.y1)/e.scaleY,
		ox + float64(e.x2)/e.scaleX, oy + float64(e.y2)/e.scaleY
}

// outputRect maps os onto the extent's grid; integer math first keeps shared output edges exact.
func (e selectionExtent) outputRect(os *OutputSurface) (x1, y1, x2, y2 float64) {
	dx := int(os.output.x - e.surface.output.x)
	dy := int(os.output.y - e.surface.output.y)
	bw, bh := e.surface.screenBuf.Width, e.surface.screenBuf.Height
	lw, lh := e.surface.logicalW, e.surface.logicalH
	return float64(dx*bw) / float64(lw), float64(dy*bh) / float64(lh),
		float64((dx+os.logicalW)*bw) / float64(lw), float64((dy+os.logicalH)*bh) / float64(lh)
}

func (e selectionExtent) within(os *OutputSurface) bool {
	x1, y1, x2, y2 := e.outputRect(os)
	return float64(e.x1) >= x1 && float64(e.y1) >= y1 && float64(e.x2) <= x2 && float64(e.y2) <= y2
}

func (e selectionExtent) intersects(os *OutputSurface) bool {
	x1, y1, x2, y2 := e.outputRect(os)
	return float64(e.x1) < x2 && float64(e.x2) > x1 && float64(e.y1) < y2 && float64(e.y2) > y1
}

func (r *RegionSelector) selectionSpansOutputs() bool {
	ext, ok := r.selectionExtent()
	return ok && !ext.within(ext.surface)
}

func (r *RegionSelector) finishSelectionAcrossOutputs() {
	ext, ok := r.selectionExtent()
	if !ok || ext.width() <= 0 || ext.height() <= 0 {
		r.running = false
		return
	}

	composite, err := CreateShmBuffer(ext.width(), ext.height(), ext.width()*4)
	if err != nil {
		r.running = false
		return
	}
	composite.Clear()

	primary := ext.surface
	minX, minY, maxX, maxY := ext.logical()
	for _, os := range r.surfaces {
		src := r.getSourceBuffer(os)
		if src == nil || os.output == nil || os.logicalW <= 0 || os.logicalH <= 0 || !ext.intersects(os) {
			continue
		}

		ox, oy := float64(os.output.x), float64(os.output.y)
		ix1 := math.Max(minX, ox)
		iy1 := math.Max(minY, oy)
		ix2 := math.Min(maxX, ox+float64(os.logicalW))
		iy2 := math.Min(maxY, oy+float64(os.logicalH))

		scaleX := float64(src.Width) / float64(os.logicalW)
		scaleY := float64(src.Height) / float64(os.logicalH)
		srcX := clamp(int(math.Floor((ix1-ox)*scaleX)), 0, src.Width)
		srcY := clamp(int(math.Floor((iy1-oy)*scaleY)), 0, src.Height)
		srcRight := clamp(int(math.Ceil((ix2-ox)*scaleX)), 0, src.Width)
		srcBottom := clamp(int(math.Ceil((iy2-oy)*scaleY)), 0, src.Height)

		dstX := int(math.Round((ix1 - minX) * ext.scaleX))
		dstY := int(math.Round((iy1 - minY) * ext.scaleY))
		dstRight := int(math.Round((ix2 - minX) * ext.scaleX))
		dstBottom := int(math.Round((iy2 - minY) * ext.scaleY))
		swapRB := formatIsBGR(os.screenFormat) != formatIsBGR(primary.screenFormat)
		blitSelectionPiece(composite, src, srcX, srcY, srcRight-srcX, srcBottom-srcY, dstX, dstY, dstRight-dstX, dstBottom-dstY, swapRB)
	}

	r.capturedBuffer = composite
	r.capturedRegion = Region{Width: int32(ext.width()), Height: int32(ext.height()), Output: primary.output.name}
	r.result = Region{
		X:      int32(ext.x1) + primary.output.x,
		Y:      int32(ext.y1) + primary.output.y,
		Width:  int32(ext.width()),
		Height: int32(ext.height()),
		// Cross-output regions cannot be replayed by the single-output last mode.
		Output: "",
	}
	r.running = false
}

func blitSelectionPiece(dst, src *ShmBuffer, srcX, srcY, srcW, srcH, dstX, dstY, dstW, dstH int, swapRB bool) {
	if srcW <= 0 || srcH <= 0 || dstW <= 0 || dstH <= 0 {
		return
	}
	c0, c2 := 0, 2
	if swapRB {
		c0, c2 = 2, 0
	}
	srcData, dstData := src.Data(), dst.Data()
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
			if si+3 >= len(srcData) || di+3 >= len(dstData) {
				continue
			}
			dstData[di+0] = srcData[si+c0]
			dstData[di+1] = srcData[si+1]
			dstData[di+2] = srcData[si+c2]
			dstData[di+3] = srcData[si+3]
		}
	}
}
