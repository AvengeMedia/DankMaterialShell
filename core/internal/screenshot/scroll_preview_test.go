package screenshot

import (
	"testing"
)

func createMockScrollSurface(bufW, bufH, logicalW, logicalH int) *OutputSurface {
	return &OutputSurface{
		logicalW: logicalW,
		logicalH: logicalH,
		output: &WaylandOutput{
			fractionalScale: float64(bufW) / float64(logicalW),
		},
		screenBuf: &ShmBuffer{
			Width:  bufW,
			Height: bufH,
			Stride: bufW * 4,
		},
		screenFormat: uint32(FormatXRGB8888),
	}
}

func TestScrollPreviewPanelLayoutRight(t *testing.T) {
	os := createMockScrollSurface(1920, 1080, 1920, 1080)
	st := newStitcher(600 * 4)
	st.canvas = make([]byte, 600*4*1200)
	st.cols = make([]rowCols, 1200)

	r := &RegionSelector{
		scroll: &scrollSession{
			holeX:  100,
			holeY:  100,
			holeW:  600,
			holeH:  800,
			frameW: 600,
			st:     st,
		},
	}

	x, y, w, h, startRow, previewRows, ok := r.scrollPreviewPanel(os)
	if !ok {
		t.Fatalf("expected scrollPreviewPanel to succeed, got ok=false")
	}
	if startRow != 0 || previewRows != 1200 {
		t.Errorf("expected full canvas window (0, 1200), got (%d, %d)", startRow, previewRows)
	}

	// Selection is at x=100..700. Right gap is 1920 - 700 = 1220; left gap is 100.
	// Panel must be placed to the right of the hole.
	if x <= r.scroll.holeX+r.scroll.holeW {
		t.Errorf("panel x=%d should be to the right of hole end %d", x, r.scroll.holeX+r.scroll.holeW)
	}
	if x+w > 1920 {
		t.Errorf("panel right edge %d exceeds screen width 1920", x+w)
	}
	if y < 0 || y+h > 1080 {
		t.Errorf("panel y=%d h=%d out of screen bounds [0, 1080]", y, h)
	}
	if y < 0 || y+h > 1080 || w <= 0 || h <= 0 {
		t.Errorf("invalid dimensions w=%d h=%d", w, h)
	}
}

func TestScrollPreviewPanelLayoutLeft(t *testing.T) {
	os := createMockScrollSurface(1920, 1080, 1920, 1080)
	st := newStitcher(600 * 4)
	st.canvas = make([]byte, 600*4*1200)
	st.cols = make([]rowCols, 1200)

	r := &RegionSelector{
		scroll: &scrollSession{
			holeX:  1220,
			holeY:  100,
			holeW:  600,
			holeH:  800,
			frameW: 600,
			st:     st,
		},
	}

	x, y, w, h, _, _, ok := r.scrollPreviewPanel(os)
	if !ok {
		t.Fatalf("expected scrollPreviewPanel to succeed, got ok=false")
	}

	// Selection is at x=1220..1820. Left gap is 1220; right gap is 100.
	// Panel must be placed to the left of the hole.
	if x+w >= r.scroll.holeX {
		t.Errorf("panel right edge %d should be to the left of hole start %d", x+w, r.scroll.holeX)
	}
	if x < 0 {
		t.Errorf("panel left edge %d is negative", x)
	}
	if y < 0 || y+h > 1080 {
		t.Errorf("panel y=%d h=%d out of screen bounds [0, 1080]", y, h)
	}
}

func TestScrollPreviewPanelInsufficientSpace(t *testing.T) {
	os := createMockScrollSurface(1920, 1080, 1920, 1080)
	st := newStitcher(1880 * 4)
	st.canvas = make([]byte, 1880*4*2000)
	st.cols = make([]rowCols, 2000)

	r := &RegionSelector{
		scroll: &scrollSession{
			holeX:  20,
			holeY:  20,
			holeW:  1880,
			holeH:  1040,
			frameW: 1880,
			st:     st,
		},
	}

	_, _, _, _, _, _, ok := r.scrollPreviewPanel(os)
	if ok {
		t.Fatalf("expected scrollPreviewPanel to return false when side gaps are too small")
	}
}

func TestScrollPreviewPanelBoundedTailLongCapture(t *testing.T) {
	os := createMockScrollSurface(1920, 1080, 1920, 1080)
	st := newStitcher(600 * 4)
	totalRows := 10000
	st.canvas = make([]byte, 600*4*totalRows)
	st.cols = make([]rowCols, totalRows)

	r := &RegionSelector{
		scroll: &scrollSession{
			holeX:  100,
			holeY:  100,
			holeW:  600,
			holeH:  800,
			frameW: 600,
			st:     st,
		},
	}

	x, y, w, h, startRow, previewRows, ok := r.scrollPreviewPanel(os)
	if !ok {
		t.Fatalf("expected scrollPreviewPanel to succeed on long capture, got ok=false")
	}

	if startRow <= 0 {
		t.Errorf("expected startRow > 0 for 10000-row capture, got %d", startRow)
	}
	if startRow+previewRows != totalRows {
		t.Errorf("expected startRow (%d) + previewRows (%d) == %d", startRow, previewRows, totalRows)
	}
	if y < 0 || y+h > 1080 || w <= 0 || h <= 0 {
		t.Errorf("invalid dimensions w=%d, h=%d", w, h)
	}
	if x <= r.scroll.holeX+r.scroll.holeW {
		t.Errorf("panel x=%d should be to the right of hole end", x)
	}
}

func TestScrollBarHitPreview(t *testing.T) {
	os := createMockScrollSurface(1920, 1080, 1920, 1080)
	r := &RegionSelector{
		selection: SelectionState{
			surface: os,
		},
		scroll: &scrollSession{
			doneX:      100,
			doneY:      1000,
			doneW:      60,
			btnH:       24,
			cancelX:    180,
			cancelY:    1000,
			cancelW:    70,
			previewX:   800,
			previewY:   200,
			previewW:   200,
			previewH:   300,
			hasPreview: true,
		},
	}

	tests := []struct {
		name string
		x, y float64
		want string
	}{
		{"done hit", 120, 1010, "done"},
		{"cancel hit", 200, 1010, "cancel"},
		{"preview hit", 900, 350, "preview"},
		{"miss", 500, 500, ""},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := r.scrollBarHit(tc.x, tc.y)
			if got != tc.want {
				t.Errorf("scrollBarHit(%.1f, %.1f) = %q, want %q", tc.x, tc.y, got, tc.want)
			}
		})
	}
}

func TestDrawScrollPreviewRendering(t *testing.T) {
	bufW, bufH := 1920, 1080
	renderBuf, err := CreateShmBuffer(bufW, bufH, bufW*4)
	if err != nil {
		t.Fatalf("CreateShmBuffer: %v", err)
	}
	defer renderBuf.Close()

	os := &OutputSurface{
		logicalW:     bufW,
		logicalH:     bufH,
		screenBuf:    renderBuf,
		screenFormat: uint32(FormatXRGB8888),
		output:       &WaylandOutput{fractionalScale: 1.0},
	}

	sourceW, sourceRows := 400, 800
	st := newStitcher(sourceW * 4)
	st.canvas = make([]byte, sourceW*4*sourceRows)
	st.cols = make([]rowCols, sourceRows)
	for y := range sourceRows {
		for x := range sourceW {
			idx := (y*sourceW + x) * 4
			st.canvas[idx+0] = 50  // B
			st.canvas[idx+1] = 150 // G
			st.canvas[idx+2] = 200 // R
			st.canvas[idx+3] = 255 // A
		}
	}

	r := &RegionSelector{
		selection: SelectionState{
			surface: os,
		},
		scroll: &scrollSession{
			holeX:  100,
			holeY:  100,
			holeW:  500,
			holeH:  600,
			frameW: sourceW,
			format: PixelFormat(FormatXRGB8888),
			st:     st,
		},
	}

	r.updateScrollPreviewLayout(os)
	if !r.scroll.hasPreview {
		t.Fatalf("expected hasPreview=true")
	}

	data := renderBuf.Data()
	r.drawScrollPreview(data, renderBuf.Stride, bufW, bufH, os)

	// Sample center of preview image
	padding := int(float64(scrollPreviewPaddingLogical))
	centerX := r.scroll.previewX + padding + (r.scroll.previewW-padding*2)/2
	centerY := r.scroll.previewY + padding + (r.scroll.previewH-padding*2)/2

	pixelIdx := centerY*renderBuf.Stride + centerX*4
	b := data[pixelIdx+0]
	g := data[pixelIdx+1]
	red := data[pixelIdx+2]
	a := data[pixelIdx+3]

	if red != 200 || g != 150 || b != 50 || a != 255 {
		t.Errorf("center pixel = (%d, %d, %d, %d), want (200, 150, 50, 255)", red, g, b, a)
	}

	// Sample top-left border of preview panel
	borderIdx := r.scroll.previewY*renderBuf.Stride + r.scroll.previewX*4
	if data[borderIdx+0] != 255 || data[borderIdx+1] != 255 || data[borderIdx+2] != 255 {
		t.Errorf("border pixel = (%d, %d, %d), want white (255, 255, 255)",
			data[borderIdx+2], data[borderIdx+1], data[borderIdx+0])
	}
}
