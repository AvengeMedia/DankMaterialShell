package screenshot

import "fmt"

var fontGlyphs = map[rune][12]uint8{
	'0': {0x3C, 0x66, 0x66, 0x6E, 0x76, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x00, 0x00},
	'1': {0x18, 0x38, 0x78, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x7E, 0x00, 0x00},
	'2': {0x3C, 0x66, 0x66, 0x06, 0x0C, 0x18, 0x30, 0x60, 0x66, 0x7E, 0x00, 0x00},
	'3': {0x3C, 0x66, 0x06, 0x06, 0x1C, 0x06, 0x06, 0x06, 0x66, 0x3C, 0x00, 0x00},
	'4': {0x0C, 0x1C, 0x3C, 0x6C, 0xCC, 0xCC, 0xFE, 0x0C, 0x0C, 0x1E, 0x00, 0x00},
	'5': {0x7E, 0x60, 0x60, 0x60, 0x7C, 0x06, 0x06, 0x06, 0x66, 0x3C, 0x00, 0x00},
	'6': {0x1C, 0x30, 0x60, 0x60, 0x7C, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x00, 0x00},
	'7': {0x7E, 0x66, 0x06, 0x06, 0x0C, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00, 0x00},
	'8': {0x3C, 0x66, 0x66, 0x66, 0x3C, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x00, 0x00},
	'9': {0x3C, 0x66, 0x66, 0x66, 0x3E, 0x06, 0x06, 0x06, 0x0C, 0x38, 0x00, 0x00},
	'x': {0x00, 0x00, 0x00, 0x66, 0x66, 0x3C, 0x18, 0x3C, 0x66, 0x66, 0x00, 0x00},
	'E': {0x7E, 0x60, 0x60, 0x60, 0x7C, 0x60, 0x60, 0x60, 0x60, 0x7E, 0x00, 0x00},
	'P': {0x7C, 0x66, 0x66, 0x66, 0x7C, 0x60, 0x60, 0x60, 0x60, 0x60, 0x00, 0x00},
	'S': {0x3C, 0x66, 0x60, 0x60, 0x3C, 0x06, 0x06, 0x06, 0x66, 0x3C, 0x00, 0x00},
	'a': {0x00, 0x00, 0x00, 0x3C, 0x06, 0x3E, 0x66, 0x66, 0x66, 0x3E, 0x00, 0x00},
	'c': {0x00, 0x00, 0x00, 0x3C, 0x66, 0x60, 0x60, 0x60, 0x66, 0x3C, 0x00, 0x00},
	'd': {0x00, 0x00, 0x06, 0x06, 0x06, 0x3E, 0x66, 0x66, 0x66, 0x3E, 0x00, 0x00},
	'e': {0x00, 0x00, 0x00, 0x3C, 0x66, 0x66, 0x7E, 0x60, 0x60, 0x3C, 0x00, 0x00},
	'h': {0x00, 0x60, 0x60, 0x60, 0x7C, 0x66, 0x66, 0x66, 0x66, 0x66, 0x00, 0x00},
	'i': {0x00, 0x18, 0x00, 0x38, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3C, 0x00, 0x00},
	'n': {0x00, 0x00, 0x00, 0x7C, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x00, 0x00},
	'o': {0x00, 0x00, 0x00, 0x3C, 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x00, 0x00},
	'p': {0x00, 0x00, 0x00, 0x7C, 0x66, 0x66, 0x66, 0x7C, 0x60, 0x60, 0x00, 0x00},
	'r': {0x00, 0x00, 0x00, 0x6E, 0x76, 0x60, 0x60, 0x60, 0x60, 0x60, 0x00, 0x00},
	's': {0x00, 0x00, 0x00, 0x3E, 0x60, 0x60, 0x3C, 0x06, 0x06, 0x7C, 0x00, 0x00},
	't': {0x00, 0x18, 0x18, 0x7E, 0x18, 0x18, 0x18, 0x18, 0x18, 0x0E, 0x00, 0x00},
	'u': {0x00, 0x00, 0x00, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x3E, 0x00, 0x00},
	'w': {0x00, 0x00, 0x00, 0x63, 0x63, 0x63, 0x6B, 0x7F, 0x77, 0x63, 0x00, 0x00},
	'l': {0x38, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3C, 0x00, 0x00},
	' ': {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
	':': {0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00},
	'/': {0x00, 0x02, 0x06, 0x0C, 0x18, 0x18, 0x30, 0x60, 0x40, 0x00, 0x00, 0x00},
	'[': {0x3C, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3C, 0x00, 0x00},
	']': {0x3C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x3C, 0x00, 0x00},
}

type OverlayStyle struct {
	BackgroundR, BackgroundG, BackgroundB, BackgroundA uint8
	TextR, TextG, TextB                                uint8
	AccentR, AccentG, AccentB                          uint8
}

var DefaultOverlayStyle = OverlayStyle{
	BackgroundR: 30, BackgroundG: 30, BackgroundB: 30, BackgroundA: 220,
	TextR: 255, TextG: 255, TextB: 255,
	AccentR: 100, AccentG: 180, AccentB: 255,
}

func (r *RegionSelector) drawOverlay(os *OutputSurface, renderBuf *ShmBuffer) {
	data := renderBuf.Data()
	stride := renderBuf.Stride
	w, h := renderBuf.Width, renderBuf.Height
	format := os.screenFormat

	// Dim the entire buffer
	for y := 0; y < h; y++ {
		off := y * stride
		for x := 0; x < w; x++ {
			i := off + x*4
			if i+3 >= len(data) {
				continue
			}
			data[i+0] = uint8(int(data[i+0]) * 3 / 5)
			data[i+1] = uint8(int(data[i+1]) * 3 / 5)
			data[i+2] = uint8(int(data[i+2]) * 3 / 5)
		}
	}

	r.drawHUD(data, stride, w, h, format)

	if !r.selection.hasSelection || r.selection.surface != os {
		return
	}

	scaleX := float64(w) / float64(os.logicalW)
	scaleY := float64(h) / float64(os.logicalH)

	bx1 := int(r.selection.anchorX * scaleX)
	by1 := int(r.selection.anchorY * scaleY)
	bx2 := int(r.selection.currentX * scaleX)
	by2 := int(r.selection.currentY * scaleY)

	if bx1 > bx2 {
		bx1, bx2 = bx2, bx1
	}
	if by1 > by2 {
		by1, by2 = by2, by1
	}

	bx1 = clamp(bx1, 0, w-1)
	by1 = clamp(by1, 0, h-1)
	bx2 = clamp(bx2, 0, w-1)
	by2 = clamp(by2, 0, h-1)

	srcBuf := r.getSourceBuffer(os)
	srcData := srcBuf.Data()
	for y := by1; y <= by2; y++ {
		rowOff := y * stride
		for x := bx1; x <= bx2; x++ {
			si := y*srcBuf.Stride + x*4
			di := rowOff + x*4
			if si+3 >= len(srcData) || di+3 >= len(data) {
				continue
			}
			data[di+0] = srcData[si+0]
			data[di+1] = srcData[si+1]
			data[di+2] = srcData[si+2]
			data[di+3] = srcData[si+3]
		}
	}

	selW, selH := bx2-bx1+1, by2-by1+1
	if r.shiftHeld && selW != selH {
		if selW < selH {
			selH = selW
		} else {
			selW = selH
		}
	}
	r.drawBorder(data, stride, w, h, bx1, by1, selW, selH, format)
	r.drawDimensions(data, stride, w, h, bx1, by1, selW, selH, format)
}

func (r *RegionSelector) drawHUD(data []byte, stride, bufW, bufH int, format uint32) {
	if r.selection.dragging {
		return
	}

	style := LoadOverlayStyle()
	const charW, charH, padding, itemSpacing = 8, 12, 12, 24

	cursorLabel := "hide"
	if !r.showCapturedCursor {
		cursorLabel = "show"
	}
	captureKey := "Space/Enter"
	if r.screenshoter != nil && r.screenshoter.config.NoConfirm {
		captureKey = "Drag+Release"
	}

	items := []struct{ key, desc string }{
		{captureKey, "capture"},
		{"P", cursorLabel + " cursor"},
		{"Esc", "cancel"},
	}

	totalW := 0
	for i, item := range items {
		totalW += len(item.key)*(charW+1) + 4 + len(item.desc)*(charW+1)
		if i < len(items)-1 {
			totalW += itemSpacing
		}
	}

	hudW := totalW + padding*2
	hudH := charH + padding*2
	hudX := (bufW - hudW) / 2
	hudY := bufH - hudH - 20

	r.fillRect(data, stride, bufW, bufH, hudX, hudY, hudW, hudH,
		style.BackgroundR, style.BackgroundG, style.BackgroundB, style.BackgroundA, format)

	tx, ty := hudX+padding, hudY+padding
	for i, item := range items {
		r.drawText(data, stride, bufW, bufH, tx, ty, item.key,
			style.AccentR, style.AccentG, style.AccentB, format)
		tx += len(item.key) * (charW + 1)

		r.drawText(data, stride, bufW, bufH, tx, ty, " "+item.desc,
			style.TextR, style.TextG, style.TextB, format)
		tx += (1 + len(item.desc)) * (charW + 1)

		if i < len(items)-1 {
			tx += itemSpacing
		}
	}
}

func (r *RegionSelector) drawBorder(data []byte, stride, bufW, bufH, x, y, w, h int, format uint32) {
	const thickness = 2
	for i := 0; i < thickness; i++ {
		r.drawHLine(data, stride, bufW, bufH, x-i, y-i, w+2*i, format)
		r.drawHLine(data, stride, bufW, bufH, x-i, y+h+i-1, w+2*i, format)
		r.drawVLine(data, stride, bufW, bufH, x-i, y-i, h+2*i, format)
		r.drawVLine(data, stride, bufW, bufH, x+w+i-1, y-i, h+2*i, format)
	}
}

func (r *RegionSelector) drawHLine(data []byte, stride, bufW, bufH, x, y, length int, _ uint32) {
	if y < 0 || y >= bufH {
		return
	}
	rowOff := y * stride
	for i := 0; i < length; i++ {
		px := x + i
		if px < 0 || px >= bufW {
			continue
		}
		off := rowOff + px*4
		if off+3 >= len(data) {
			continue
		}
		data[off], data[off+1], data[off+2], data[off+3] = 255, 255, 255, 255
	}
}

func (r *RegionSelector) drawVLine(data []byte, stride, bufW, bufH, x, y, length int, _ uint32) {
	if x < 0 || x >= bufW {
		return
	}
	for i := 0; i < length; i++ {
		py := y + i
		if py < 0 || py >= bufH {
			continue
		}
		off := py*stride + x*4
		if off+3 >= len(data) {
			continue
		}
		data[off], data[off+1], data[off+2], data[off+3] = 255, 255, 255, 255
	}
}

func (r *RegionSelector) drawDimensions(data []byte, stride, bufW, bufH, x, y, w, h int, format uint32) {
	text := fmt.Sprintf("%dx%d", w, h)

	const charW, charH = 8, 12
	textW := len(text) * (charW + 1)
	textH := charH

	tx := x + (w-textW)/2
	ty := y + h + 8

	if ty+textH > bufH {
		ty = y - textH - 8
	}
	tx = clamp(tx, 0, bufW-textW)

	r.fillRect(data, stride, bufW, bufH, tx-4, ty-2, textW+8, textH+4, 0, 0, 0, 200, format)
	r.drawText(data, stride, bufW, bufH, tx, ty, text, 255, 255, 255, format)
}

func (r *RegionSelector) fillRect(data []byte, stride, bufW, bufH, x, y, w, h int, cr, cg, cb, ca uint8, format uint32) {
	alpha := float64(ca) / 255.0
	invAlpha := 1.0 - alpha

	c0, c2 := cb, cr
	if format == uint32(FormatABGR8888) || format == uint32(FormatXBGR8888) {
		c0, c2 = cr, cb
	}

	for py := y; py < y+h && py < bufH; py++ {
		if py < 0 {
			continue
		}
		for px := x; px < x+w && px < bufW; px++ {
			if px < 0 {
				continue
			}
			off := py*stride + px*4
			if off+3 >= len(data) {
				continue
			}
			data[off+0] = uint8(float64(data[off+0])*invAlpha + float64(c0)*alpha)
			data[off+1] = uint8(float64(data[off+1])*invAlpha + float64(cg)*alpha)
			data[off+2] = uint8(float64(data[off+2])*invAlpha + float64(c2)*alpha)
			data[off+3] = 255
		}
	}
}

func (r *RegionSelector) drawText(data []byte, stride, bufW, bufH, x, y int, text string, cr, cg, cb uint8, format uint32) {
	for i, ch := range text {
		r.drawChar(data, stride, bufW, bufH, x+i*9, y, ch, cr, cg, cb, format)
	}
}

func (r *RegionSelector) drawChar(data []byte, stride, bufW, bufH, x, y int, ch rune, cr, cg, cb uint8, format uint32) {
	glyph, ok := fontGlyphs[ch]
	if !ok {
		return
	}

	c0, c2 := cb, cr
	if format == uint32(FormatABGR8888) || format == uint32(FormatXBGR8888) {
		c0, c2 = cr, cb
	}

	for row := 0; row < 12; row++ {
		py := y + row
		if py < 0 || py >= bufH {
			continue
		}
		bits := glyph[row]
		for col := 0; col < 8; col++ {
			if (bits & (1 << (7 - col))) == 0 {
				continue
			}
			px := x + col
			if px < 0 || px >= bufW {
				continue
			}
			off := py*stride + px*4
			if off+3 >= len(data) {
				continue
			}
			data[off], data[off+1], data[off+2], data[off+3] = c0, cg, c2, 255
		}
	}
}

func clamp(v, lo, hi int) int {
	switch {
	case v < lo:
		return lo
	case v > hi:
		return hi
	default:
		return v
	}
}
