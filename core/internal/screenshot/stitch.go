package screenshot

// Frame stitcher after mark-shot's column-sampling design
// (https://github.com/jswysnemc/mark-shot, src/scroll/stitcher_algorithm.cpp).
// Only rows overhanging the captured range are committed; frames that match
// nothing are dropped without touching state.

const (
	stitchMaxCanvasBytes = 256 << 20
	stitchMaxRowsCap     = 30000

	// mark-shot: StitchConfig{100, 9.0f, 15, 1.0f}
	stitchAcceptDiff    = 9.0
	stitchApproxDiff    = 1.0
	stitchMinCompare    = 50
	stitchMinCanvas     = 100
	stitchMinAppend     = 15
	stitchCoarseStep    = 8
	stitchPredictWindow = 160
	stitchBandSamples   = 17

	// mark-shot: kDuplicateAvgDiff=1.1f, kDuplicateMaxDiff=4, 18x24 grid
	stitchDupAvgDiff = 1.1
	stitchDupMaxDiff = 4.0
	stitchSigCols    = 18
	stitchSigRows    = 24

	// blank rows agree at every offset and must not decide a match
	stitchActivityMin = 2.0
	stitchRowMatchTol = 4.0
	stitchMinActive   = 12
)

// mean luminance per band (8-32%, 34-66%, 68-92%); the outer 8% is chrome
type rowCols [3]float32

type stitcher struct {
	stride     int
	sampleOffs [3][]int

	canvas []byte
	cols   []rowCols

	anchor     int
	last       []rowCols
	lastOffset int

	maxRows int
	full    bool
}

func newStitcher(stride int) *stitcher {
	px := stride / 4
	st := &stitcher{
		stride:  stride,
		maxRows: min(stitchMaxCanvasBytes/stride, stitchMaxRowsCap),
	}
	bands := [3][2]float64{{0.08, 0.32}, {0.34, 0.66}, {0.68, 0.92}}
	for b, band := range bands {
		lo := int(float64(px) * band[0])
		hi := max(int(float64(px)*band[1]), lo+1)
		n := min(stitchBandSamples, hi-lo)
		for s := range n {
			st.sampleOffs[b] = append(st.sampleOffs[b], (lo+(hi-lo)*s/n)*4)
		}
	}
	return st
}

func (st *stitcher) rowSamples(data []byte) []rowCols {
	rows := len(data) / st.stride
	cols := make([]rowCols, rows)
	for y := range rows {
		row := data[y*st.stride:]
		for b := range 3 {
			var sum float32
			for _, off := range st.sampleOffs[b] {
				sum += 0.114*float32(row[off]) + 0.587*float32(row[off+1]) + 0.299*float32(row[off+2])
			}
			cols[y][b] = sum / float32(len(st.sampleOffs[b]))
		}
	}
	return cols
}

func (st *stitcher) frameSig(data []byte) []float32 {
	rows := len(data) / st.stride
	px := st.stride / 4
	sig := make([]float32, 0, stitchSigCols*stitchSigRows)
	for gy := range stitchSigRows {
		y := (2*gy + 1) * rows / (2 * stitchSigRows)
		for gx := range stitchSigCols {
			x := (2*gx + 1) * px / (2 * stitchSigCols)
			off := y*st.stride + x*4
			sig = append(sig, 0.114*float32(data[off])+0.587*float32(data[off+1])+0.299*float32(data[off+2]))
		}
	}
	return sig
}

func (st *stitcher) rows() int {
	return len(st.cols)
}

func rowColsDiff(a, b rowCols) float32 {
	return (abs32(a[0]-b[0]) + abs32(a[1]-b[1]) + abs32(a[2]-b[2])) / 3
}

func duplicateFrame(a, b []float32) bool {
	if len(a) != len(b) || len(a) == 0 {
		return false
	}
	var sum, maxDiff float32
	for i := range a {
		d := abs32(a[i] - b[i])
		sum += d
		maxDiff = max(maxDiff, d)
	}
	return sum/float32(len(a)) <= stitchDupAvgDiff && maxDiff <= stitchDupMaxDiff
}

// sticky header/footer zones, per mark-shot: 10% top, 8% bottom, min 16px
func matchIgnores(h int) (top, bottom int) {
	if h < 80 {
		return 0, 0
	}
	return clamp(h/10, 16, h/4), clamp(h*8/100, 16, h/4)
}

func activity(f []rowCols) []bool {
	active := make([]bool, len(f))
	for i := 1; i < len(f); i++ {
		active[i] = rowColsDiff(f[i], f[i-1]) > stitchActivityMin
	}
	return active
}

func (st *stitcher) pushFrame(frame []byte, f []rowCols) (int, bool) {
	if st.full || len(f) == 0 {
		return 0, true
	}

	h := len(f)
	if len(st.cols) == 0 {
		n := st.appendRows(frame, f, 0)
		st.anchor = 0
		st.last = f
		st.lastOffset = 0
		return n, true
	}

	pos, ok := st.locateFrame(f, activity(f))
	if !ok {
		return 0, false
	}

	delta := pos - st.anchor
	added := 0
	if over := pos + h - len(st.cols); over >= stitchMinAppend {
		added += st.appendRows(frame, f, h-over)
	}
	if over := -pos; over >= stitchMinAppend {
		n := st.prependRows(frame, f, over)
		added += n
		pos += n
	}

	st.anchor = pos
	st.last = f
	st.lastOffset = delta
	return added, true
}

// seamAppend starts a new segment after a jump capture couldn't follow.
func (st *stitcher) seamAppend(frame []byte, f []rowCols) int {
	if st.full || len(f) == 0 {
		return 0
	}
	pos := len(st.cols)
	n := st.appendRows(frame, f, 0)
	st.anchor = pos
	st.last = f
	st.lastOffset = 0
	return n
}

func (st *stitcher) locateFrame(f []rowCols, active []bool) (int, bool) {
	d, diff := st.adjacentOffset(f, active)
	pred := st.anchor + d

	if diff <= stitchAcceptDiff {
		if _, ok := st.verifyAt(f, active, pred); ok {
			return pred, true
		}
	}
	if pos, _, ok := st.scanPositions(f, active, pred, true); ok {
		return pos, true
	}
	pos, _, ok := st.scanPositions(f, active, pred, false)
	return pos, ok
}

func (st *stitcher) verifyAt(f []rowCols, active []bool, pos int) (float32, bool) {
	diff, count, activeMatches := st.canvasDiff(f, active, pos)
	ok := count >= stitchMinCanvas && diff <= stitchAcceptDiff && activeMatches >= stitchMinActive
	return diff, ok
}

// signed deltas searched outward from the previous one (mark-shot's
// predictOffsetIter), early-exiting once a diff beats approxDiff
func (st *stitcher) adjacentOffset(f []rowCols, active []bool) (int, float32) {
	h := len(f)
	if len(st.last) != h {
		return 0, float32(1e9)
	}
	limit := max(h-stitchMinCompare-1, 0)

	bestD, bestDiff := 0, float32(1e9)
	countdown := -1
	try := func(d int) bool {
		if d < -limit || d > limit {
			return false
		}
		diff, activeMatches := st.pairDiff(f, active, d)
		if activeMatches >= stitchMinActive && diff < bestDiff {
			bestDiff, bestD = diff, d
		}
		switch {
		case bestDiff < stitchApproxDiff/4:
			return true
		case bestDiff < stitchApproxDiff && countdown < 0:
			countdown = 10
		}
		if countdown > 0 {
			countdown--
		}
		return countdown == 0
	}

	if try(st.lastOffset) {
		return bestD, bestDiff
	}
	for k := 1; ; k++ {
		lo, hi := st.lastOffset-k, st.lastOffset+k
		if lo < -limit && hi > limit {
			break
		}
		if try(hi) || try(lo) {
			break
		}
	}
	return bestD, bestDiff
}

func (st *stitcher) pairDiff(f []rowCols, active []bool, d int) (float32, int) {
	h := len(f)
	top, bottom := matchIgnores(h)
	lo := max(top, -d)
	hi := min(h-bottom, h-d)

	count := hi - lo
	if count < stitchMinCompare {
		return float32(1e9), 0
	}
	var sum float32
	activeMatches := 0
	for i := lo; i < hi; i++ {
		rd := rowColsDiff(f[i], st.last[i+d])
		sum += rd
		if active[i] && rd <= stitchRowMatchTol {
			activeMatches++
		}
	}
	return sum / float32(count), activeMatches
}

func (st *stitcher) canvasDiff(f []rowCols, active []bool, pos int) (float32, int, int) {
	h := len(f)
	top, bottom := matchIgnores(h)
	lo := max(top, -pos)
	hi := min(h-bottom, len(st.cols)-pos)

	count := hi - lo
	if count < 1 {
		return float32(1e9), 0, 0
	}
	var sum float32
	activeMatches := 0
	for i := lo; i < hi; i++ {
		rd := rowColsDiff(f[i], st.cols[pos+i])
		sum += rd
		if active[i] && rd <= stitchRowMatchTol {
			activeMatches++
		}
	}
	return sum / float32(count), count, activeMatches
}

// mark-shot's findEdgePosition (nearOnly: edges + prediction window, 1px) and
// findKnownPosition (coarse sweep refined around the winner)
func (st *stitcher) scanPositions(f []rowCols, active []bool, pred int, nearOnly bool) (int, float32, bool) {
	h := len(f)
	C := len(st.cols)
	minPos := stitchMinCanvas - h
	maxPos := C - stitchMinCanvas

	bestPos, bestDiff := 0, float32(1e9)
	bestDist := 1 << 30
	consider := func(pos int) {
		if pos < minPos || pos > maxPos {
			return
		}
		diff, ok := st.verifyAt(f, active, pos)
		if !ok {
			return
		}
		dist := pos - pred
		if dist < 0 {
			dist = -dist
		}
		better := diff < bestDiff
		if !nearOnly {
			better = dist < bestDist || dist == bestDist && diff < bestDiff
		}
		if better {
			bestPos, bestDiff, bestDist = pos, diff, dist
		}
	}

	if nearOnly {
		for pos := pred - stitchPredictWindow; pos <= pred+stitchPredictWindow; pos++ {
			consider(pos)
		}
		for pos := C - h; pos <= maxPos; pos++ {
			consider(pos)
		}
		for pos := minPos; pos <= 0; pos++ {
			consider(pos)
		}
		if bestDiff > stitchAcceptDiff {
			return 0, 0, false
		}
		return bestPos, bestDiff, true
	}

	for pos := minPos; pos <= maxPos; pos += stitchCoarseStep {
		consider(pos)
	}
	if bestDiff > stitchAcceptDiff {
		return 0, 0, false
	}

	refined, refinedDiff := bestPos, bestDiff
	for pos := bestPos - stitchCoarseStep + 1; pos < bestPos+stitchCoarseStep; pos++ {
		if pos == bestPos {
			continue
		}
		if diff, ok := st.verifyAt(f, active, pos); ok && diff < refinedDiff {
			refined, refinedDiff = pos, diff
		}
	}
	return refined, refinedDiff, true
}

func (st *stitcher) appendRows(frame []byte, f []rowCols, from int) int {
	n := len(f) - from
	if room := st.maxRows - len(st.cols); n > room {
		n = room
		st.full = true
	}
	if n <= 0 {
		st.full = true
		return 0
	}

	st.canvas = append(st.canvas, frame[from*st.stride:(from+n)*st.stride]...)
	st.cols = append(st.cols, f[from:from+n]...)
	return n
}

func (st *stitcher) prependRows(frame []byte, f []rowCols, n int) int {
	if room := st.maxRows - len(st.cols); n > room {
		n = room
		st.full = true
	}
	if n <= 0 {
		st.full = true
		return 0
	}

	canvas := make([]byte, n*st.stride+len(st.canvas))
	copy(canvas, frame[:n*st.stride])
	copy(canvas[n*st.stride:], st.canvas)
	st.canvas = canvas

	cols := make([]rowCols, 0, n+len(st.cols))
	cols = append(cols, f[:n]...)
	st.cols = append(cols, st.cols...)
	return n
}

func abs32(f float32) float32 {
	if f < 0 {
		return -f
	}
	return f
}
