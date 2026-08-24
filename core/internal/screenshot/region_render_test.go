package screenshot

import (
	"bytes"
	"math/rand"
	"testing"
)

func rectArea(r dirtyRect) int {
	if r.empty() {
		return 0
	}
	return (r.x2 - r.x1) * (r.y2 - r.y1)
}

func TestDirtyRectMinus(t *testing.T) {
	a := dirtyRect{0, 0, 10, 10}
	cases := []struct {
		name  string
		b     dirtyRect
		parts int
		area  int
	}{
		{"disjoint", dirtyRect{20, 20, 30, 30}, 1, 100},
		{"covered", dirtyRect{-1, -1, 11, 11}, 0, 0},
		{"center", dirtyRect{3, 3, 6, 6}, 4, 91},
		{"corner", dirtyRect{5, 5, 20, 20}, 2, 75},
		{"zero", dirtyRect{}, 1, 100},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			parts := a.minus(tc.b)
			if len(parts) != tc.parts {
				t.Fatalf("parts = %d, want %d", len(parts), tc.parts)
			}
			area := 0
			for i, p := range parts {
				area += rectArea(p)
				if !p.intersect(a).equal(p) || !p.intersect(tc.b).empty() {
					t.Errorf("part %v outside a or inside b", p)
				}
				for _, q := range parts[i+1:] {
					if !p.intersect(q).empty() {
						t.Errorf("parts %v and %v overlap", p, q)
					}
				}
			}
			if area != tc.area {
				t.Errorf("area = %d, want %d", area, tc.area)
			}
		})
	}
}

func (d dirtyRect) equal(o dirtyRect) bool { return d == o }

func newOverlayFixture(t testing.TB, w, h int) (*RegionSelector, *OutputSurface) {
	t.Helper()
	src, err := CreateShmBuffer(w, h, w*4+16)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { src.Close() })
	rng := rand.New(rand.NewSource(7))
	rng.Read(src.Data())

	os := &OutputSurface{
		output:       &WaylandOutput{},
		screenBuf:    src,
		screenFormat: uint32(FormatXRGB8888),
		logicalW:     w,
		logicalH:     h,
	}
	r := &RegionSelector{showCapturedCursor: true}
	r.selection.surface = os
	return r, os
}

func newFrameBuffer(t testing.TB, r *RegionSelector, os *OutputSurface) *ShmBuffer {
	t.Helper()
	buf, err := CreateShmBuffer(os.screenBuf.Width, os.screenBuf.Height, os.screenBuf.Stride)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { buf.Close() })
	buf.CopyFrom(os.screenBuf)
	r.dimBackground(buf)
	return buf
}

func (r *RegionSelector) selectRect(x1, y1, x2, y2 float64) {
	r.selection.hasSelection = true
	r.selection.anchorX, r.selection.anchorY = x1, y1
	r.selection.currentX, r.selection.currentY = x2, y2
}

func inRects(x, y int, rects []dirtyRect) bool {
	for _, d := range rects {
		if x >= d.x1 && x < d.x2 && y >= d.y1 && y < d.y2 {
			return true
		}
	}
	return false
}

func TestDrawOverlayIncremental(t *testing.T) {
	const w, h = 160, 120
	r, os := newOverlayFixture(t, w, h)
	incr := newFrameBuffer(t, r, os)
	shown := newFrameBuffer(t, r, os)
	rng := rand.New(rand.NewSource(3))

	var prev *overlay
	for i := range 300 {
		var cur *overlay
		switch rng.Intn(8) {
		case 0:
			r.selection.hasSelection = false
		default:
			r.selectRect(rng.Float64()*w, rng.Float64()*h, rng.Float64()*w, rng.Float64()*h)
			cur = r.overlayFor(os, incr)
		}
		damage := overlayDamage(prev, cur)
		r.drawOverlay(os, incr, prev, cur)

		full := newFrameBuffer(t, r, os)
		r.drawOverlay(os, full, nil, cur)
		if !bytes.Equal(incr.Data(), full.Data()) {
			t.Fatalf("step %d: incremental frame differs from full render (%v -> %v)", i, prev, cur)
		}

		for y := range h {
			for x := range w {
				off := y*full.Stride + x*4
				if bytes.Equal(full.Data()[off:off+4], shown.Data()[off:off+4]) {
					continue
				}
				if !inRects(x, y, damage) {
					t.Fatalf("step %d: pixel %d,%d changed outside damage %v", i, x, y, damage)
				}
			}
		}
		copy(shown.Data(), full.Data())
		prev = cur
	}
}

func BenchmarkDrawOverlayStep(b *testing.B) {
	r, os := newOverlayFixture(b, 2560, 1440)
	buf := newFrameBuffer(b, r, os)
	r.selectRect(10, 10, 2000, 1400)
	prev := r.overlayFor(os, buf)
	r.drawOverlay(os, buf, nil, prev)
	b.ResetTimer()
	for i := range b.N {
		r.selectRect(10, 10, float64(2000+i%8), float64(1400-i%8))
		cur := r.overlayFor(os, buf)
		r.drawOverlay(os, buf, prev, cur)
		prev = cur
	}
}

func BenchmarkDrawOverlayFull(b *testing.B) {
	r, os := newOverlayFixture(b, 2560, 1440)
	buf := newFrameBuffer(b, r, os)
	b.ResetTimer()
	for i := range b.N {
		r.selectRect(10, 10, float64(2000+i%8), float64(1400-i%8))
		cur := r.overlayFor(os, buf)
		r.paintRect(os, buf, dirtyRect{0, 0, buf.Width, buf.Height}, true)
		r.drawOverlay(os, buf, nil, cur)
	}
}
