package screenshot

import (
	"math/rand"
	"slices"
	"testing"
)

// mirrors handleScrollFrame's stitch logic so glides run without a compositor
type simSession struct {
	prevSig        []float32
	prevPlaced     bool
	unmatched      bool
	unmatchedTicks int
	st             *stitcher
}

func (s *simSession) observe(rows []byte) {
	cols := s.st.rowSamples(rows)
	sig := s.st.frameSig(rows)
	dup := duplicateFrame(sig, s.prevSig)
	s.prevSig = sig

	switch {
	case dup && s.unmatched:
		s.unmatchedTicks++
		if s.unmatchedTicks < scrollSeamTicks {
			return
		}
		if _, placed := s.st.pushFrame(rows, cols); !placed {
			s.st.seamAppend(rows, cols)
		}
		s.prevPlaced = true
		s.unmatched = false
		s.unmatchedTicks = 0
	case dup && s.prevPlaced:
		return
	default:
		_, placed := s.st.pushFrame(rows, cols)
		s.prevPlaced = placed
		s.unmatched = !placed
		s.unmatchedTicks = 0
	}
}

// the page at a fractional scroll offset, as a compositor renders mid-glide
func fractionalFrame(page []byte, stride, frameH int, offset float64) []byte {
	top := int(offset)
	frac := offset - float64(top)
	out := make([]byte, frameH*stride)
	for y := 0; y < frameH; y++ {
		a := page[(top+y)*stride : (top+y+1)*stride]
		b := page[(top+y+1)*stride : (top+y+2)*stride]
		row := out[y*stride : (y+1)*stride]
		for x := range row {
			row[x] = byte(float64(a[x])*(1-frac) + float64(b[x])*frac)
		}
	}
	return out
}

// blank gaps between paragraphs plus identical card blocks repeated around
func webbyPage(rng *rand.Rand, stride, rows int) []byte {
	page := make([]byte, rows*stride)
	card := make([]byte, 40*stride)
	rng.Read(card)

	row := 0
	for row < rows {
		switch rng.Intn(4) {
		case 0: // blank gap
			row += 10 + rng.Intn(20)
		case 1: // repeated card block
			n := copy(page[row*stride:], card)
			row += n / stride
		default: // paragraph of distinct rows
			n := (8 + rng.Intn(22)) * stride
			if row*stride+n > len(page) {
				n = len(page) - row*stride
			}
			rng.Read(page[row*stride : row*stride+n])
			row += n / stride
		}
	}
	return page
}

// screen-fixed sidebar in the unsampled outer 8% plus per-frame hover noise
func addFixedChrome(rng *rand.Rand, frame []byte, stride, frameH int, sidebar []byte) {
	sbw := len(sidebar) / frameH
	for y := 0; y < frameH; y++ {
		copy(frame[y*stride:y*stride+sbw], sidebar[y*sbw:(y+1)*sbw])
	}
	hoverTop := 40 + rng.Intn(frameH-80)
	for y := hoverTop; y < hoverTop+24; y++ {
		off := y*stride + stride/3
		for x := 0; x < 60; x++ {
			frame[off+x] ^= 0x08
		}
	}
}

// starting at the page bottom and scrolling up must prepend, never stall
func TestScrollSimulationBottomUp(t *testing.T) {
	const stride = 2048
	const frameH = 240
	rng := rand.New(rand.NewSource(99))
	page := webbyPage(rng, stride, 4000)

	st := newStitcher(stride)
	sidebar := make([]byte, frameH*140)
	rng.Read(sidebar)

	sim := &simSession{st: st}

	pos := 3700.0
	capture := func() []byte {
		f := fractionalFrame(page, stride, frameH, pos)
		addFixedChrome(rng, f, stride, frameH, sidebar)
		return f
	}
	glide := func(target float64) {
		for i := 0; ; i++ {
			step := (target - pos) * 0.45
			if step > -1 && step < 1 {
				break
			}
			pos += step
			if i%4 != 3 {
				pos = float64(int(pos))
			}
			sim.observe(capture())
		}
		pos = target
		sim.observe(capture())
		sim.observe(capture())
	}

	sim.observe(capture())
	for _, target := range []float64{3640, 3560, 3460, 3340, 3240} {
		glide(target)
	}

	wantRows := (3700 + frameH) - 3240
	got := sim.st.rows()
	if got < wantRows-stitchMinAppend || got > wantRows+2 {
		t.Fatalf("canvas has %d rows, want ~%d (upward scrolling must prepend)", got, wantRows)
	}
	topPage := 3240 + (wantRows - got)
	for _, cr := range []int{0, 100, 300} {
		if !rowMatchesPage(sim.st.canvas, page, stride, cr, topPage+cr) {
			t.Fatalf("canvas row %d does not map onto page row %d", cr, topPage+cr)
		}
	}
}

// exact page row or a blend of neighbors, allowing a one-row offset
func rowMatchesPage(canvas, page []byte, stride, canvasRow, pageRow int) bool {
	for x := 200; x < stride-1400; x++ {
		c := int(canvas[canvasRow*stride+x])
		lo, hi := 255, 0
		for k := pageRow - 1; k <= pageRow+1; k++ {
			v := int(page[k*stride+x])
			lo, hi = min(lo, v), max(hi, v)
		}
		if c < lo-1 || c > hi+1 {
			return false
		}
	}
	return true
}

// a fling past a full frame height must seam a new segment, not go dead
func TestScrollSimulationFastFlingRecovers(t *testing.T) {
	const stride = 2048
	const frameH = 240
	rng := rand.New(rand.NewSource(7))
	page := webbyPage(rng, stride, 4000)

	sim := &simSession{st: newStitcher(stride)}
	frame := func(top int) []byte {
		return slices.Clone(page[top*stride : (top+frameH)*stride])
	}
	rest := func(top int) {
		for range scrollSeamTicks + 2 {
			sim.observe(frame(top))
		}
	}

	rest(0)
	sim.observe(frame(60))
	sim.observe(frame(130))
	rest(130)
	firstRange := 130 + frameH

	sim.observe(frame(900))
	sim.observe(frame(1400))
	rest(1800)

	sim.observe(frame(1860))
	sim.observe(frame(1930))
	rest(1930)

	wantRows := firstRange + (1930 - 1800) + frameH
	if got := sim.st.rows(); got != wantRows {
		t.Fatalf("canvas has %d rows, want %d (first range %d + new segment)", got, wantRows, firstRange)
	}
	seamStart := firstRange
	if !slices.Equal(sim.st.canvas[seamStart*stride:], page[1800*stride:(1930+frameH)*stride]) {
		t.Fatal("new segment content wrong after fling recovery")
	}
}

// eased glides with up/down scrubbing must cover the range exactly once
func TestScrollSimulationSmoothGlide(t *testing.T) {
	const stride = 2048
	const frameH = 240
	rng := rand.New(rand.NewSource(99))
	page := webbyPage(rng, stride, 4000)

	st := newStitcher(stride)
	sidebar := make([]byte, frameH*140)
	rng.Read(sidebar)

	sim := &simSession{st: st}

	pos := 0.0
	capture := func() []byte {
		f := fractionalFrame(page, stride, frameH, pos)
		addFixedChrome(rng, f, stride, frameH, sidebar)
		return f
	}
	glide := func(target float64) {
		for i := 0; ; i++ {
			step := (target - pos) * 0.45
			if step > -1 && step < 1 {
				break
			}
			pos += step
			// mostly snapped to device pixels, with the odd fractional frame
			if i%4 != 3 {
				pos = float64(int(pos))
			}
			sim.observe(capture())
		}
		pos = target
		sim.observe(capture())
		sim.observe(capture())
	}

	sim.observe(capture())
	for _, target := range []float64{160, 330, 480, 650, 800, 960, 1100} {
		glide(target)
	}
	for _, target := range []float64{700, 300, 900, 1100} {
		glide(target)
	}

	wantRows := 1100 + frameH
	got := sim.st.rows()
	if got < wantRows-stitchMinAppend || got > wantRows+2 {
		t.Fatalf("canvas has %d rows, want ~%d (more = duplicated bands, fewer = gaps)", got, wantRows)
	}

	hoverLo, hoverHi := stride/3, stride/3+60
	mismatched := 0
	for row := 0; row < min(got, wantRows); row += 7 {
		off := row * stride
		a1, b1 := sim.st.canvas[off+200:off+hoverLo], page[off+200:off+hoverLo]
		a2, b2 := sim.st.canvas[off+hoverHi:off+stride], page[off+hoverHi:off+stride]
		if !slices.Equal(a1, b1) || !slices.Equal(a2, b2) {
			mismatched++
		}
	}
	if mismatched > (wantRows/7)/20 {
		t.Fatalf("%d of %d sampled rows mismatch page content (mid-animation pixels baked in)", mismatched, wantRows/7)
	}
}
