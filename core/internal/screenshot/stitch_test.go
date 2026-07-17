package screenshot

import (
	"bytes"
	"math/rand"
	"slices"
	"testing"
)

const (
	testStride = 512
	testFrameH = 240
)

func makePage(t *testing.T, rows int) []byte {
	t.Helper()
	rng := rand.New(rand.NewSource(42))
	page := make([]byte, rows*testStride)
	rng.Read(page)
	return page
}

func frameAt(page []byte, top int) []byte {
	return page[top*testStride : (top+testFrameH)*testStride]
}

func pushFrame(st *stitcher, frame []byte) int {
	n, _ := st.pushFrame(frame, st.rowSamples(frame))
	return n
}

func TestStitchSlidingWindows(t *testing.T) {
	page := makePage(t, 1000)

	for _, delta := range []int{20, 60, 110} {
		st := newStitcher(testStride)
		lastTop := 0
		for top := 0; top+testFrameH <= 900; top += delta {
			lastTop = top
			pushFrame(st, frameAt(page, top))
		}

		wantRows := lastTop + testFrameH
		if st.rows() != wantRows {
			t.Fatalf("delta %d: got %d rows, want %d", delta, st.rows(), wantRows)
		}
		if !bytes.Equal(st.canvas, page[:wantRows*testStride]) {
			t.Fatalf("delta %d: canvas does not match source rows", delta)
		}
	}
}

func TestStitchDropsNoOverlap(t *testing.T) {
	page := makePage(t, 1000)
	st := newStitcher(testStride)

	pushFrame(st, frameAt(page, 0))
	if appended := pushFrame(st, frameAt(page, testFrameH+50)); appended != 0 {
		t.Fatalf("unmatched jump appended %d rows", appended)
	}
	if !bytes.Equal(st.canvas, page[:testFrameH*testStride]) {
		t.Fatal("canvas changed on unmatched frame")
	}
}

func TestStitchNoGrowthCases(t *testing.T) {
	page := makePage(t, 1000)
	blank := make([]byte, testFrameH*testStride)

	cases := []struct {
		name          string
		first, second []byte
	}{
		{"identical frame", frameAt(page, 0), frameAt(page, 0)},
		{"jitter below min append", frameAt(page, 0), frameAt(page, stitchMinAppend-5)},
		{"blank on blank", blank, blank},
	}
	for _, tc := range cases {
		st := newStitcher(testStride)
		pushFrame(st, tc.first)
		if appended := pushFrame(st, tc.second); appended != 0 {
			t.Fatalf("%s: appended %d rows", tc.name, appended)
		}
		if st.rows() != testFrameH {
			t.Fatalf("%s: got %d rows, want %d", tc.name, st.rows(), testFrameH)
		}
	}
}

func TestStitchRevisitNeverDuplicates(t *testing.T) {
	page := makePage(t, 1000)
	st := newStitcher(testStride)

	pushFrame(st, frameAt(page, 0))
	pushFrame(st, frameAt(page, 100))
	pushFrame(st, frameAt(page, 200))

	for _, top := range []int{150, 60, 0, 80, 190} {
		if appended := pushFrame(st, frameAt(page, top)); appended != 0 {
			t.Fatalf("revisited frame at %d appended %d rows", top, appended)
		}
	}
	pushFrame(st, frameAt(page, 300))

	wantRows := 300 + testFrameH
	if st.rows() != wantRows {
		t.Fatalf("got %d rows, want %d", st.rows(), wantRows)
	}
	if !bytes.Equal(st.canvas, page[:wantRows*testStride]) {
		t.Fatal("canvas corrupted by revisited frames")
	}
}

func TestStitchScrollUpPrepends(t *testing.T) {
	page := makePage(t, 1000)
	st := newStitcher(testStride)

	pushFrame(st, frameAt(page, 500))
	if appended := pushFrame(st, frameAt(page, 420)); appended != 80 {
		t.Fatalf("upward frame appended %d rows, want 80", appended)
	}
	pushFrame(st, frameAt(page, 560))

	if !bytes.Equal(st.canvas, page[420*testStride:(560+testFrameH)*testStride]) {
		t.Fatal("canvas does not match page range after prepend + append")
	}
}

func TestStitchNoisyChromeStillMatches(t *testing.T) {
	page := makePage(t, 1000)
	st := newStitcher(testStride)

	addChrome := func(frame []byte, seed byte) []byte {
		f := slices.Clone(frame)
		for y := range testFrameH {
			for x := range 32 {
				f[y*testStride+x] = seed + byte(y)
			}
		}
		for y := 100; y < 124; y++ {
			for x := testStride / 2; x < testStride/2+40; x++ {
				f[y*testStride+x] ^= 0x08
			}
		}
		return f
	}

	pushFrame(st, addChrome(frameAt(page, 0), 1))
	if appended := pushFrame(st, addChrome(frameAt(page, 90), 2)); appended != 90 {
		t.Fatalf("appended %d rows, want 90", appended)
	}
}

func TestStitchMaxRowsCap(t *testing.T) {
	page := makePage(t, 1000)
	st := newStitcher(testStride)
	st.maxRows = testFrameH + 10

	pushFrame(st, frameAt(page, 0))
	if appended := pushFrame(st, frameAt(page, 100)); appended != 10 {
		t.Fatalf("appended %d rows past cap, want 10", appended)
	}
	if !st.full {
		t.Fatal("stitcher not marked full at cap")
	}
	if pushFrame(st, frameAt(page, 300)) != 0 {
		t.Fatal("push after full appended rows")
	}
}
