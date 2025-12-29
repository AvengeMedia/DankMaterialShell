package colorpicker

import (
	"sync"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestSurfaceState_ConcurrentPointerMotion(t *testing.T) {
	s := NewSurfaceState(FormatHex, false)

	var wg sync.WaitGroup
	const goroutines = 50
	const iterations = 100

	for i := range goroutines {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			for j := range iterations {
				s.OnPointerMotion(float64(id*10+j), float64(id*10+j))
			}
		}(i)
	}

	wg.Wait()
}

func TestSurfaceState_ConcurrentScaleAccess(t *testing.T) {
	s := NewSurfaceState(FormatHex, false)

	var wg sync.WaitGroup
	const goroutines = 30
	const iterations = 100

	for i := range goroutines / 2 {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			for range iterations {
				s.SetScale(int32(id%3 + 1))
			}
		}(i)
	}

	for range goroutines / 2 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for range iterations {
				scale := s.Scale()
				assert.GreaterOrEqual(t, scale, int32(1))
			}
		}()
	}

	wg.Wait()
}

func TestSurfaceState_ConcurrentLogicalSize(t *testing.T) {
	s := NewSurfaceState(FormatHex, false)

	var wg sync.WaitGroup
	const goroutines = 20
	const iterations = 100

	for i := range goroutines / 2 {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			for j := range iterations {
				_ = s.OnLayerConfigure(1920+id, 1080+j)
			}
		}(i)
	}

	for range goroutines / 2 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for range iterations {
				w, h := s.LogicalSize()
				_ = w
				_ = h
			}
		}()
	}

	wg.Wait()
}

func TestSurfaceState_ConcurrentIsDone(t *testing.T) {
	s := NewSurfaceState(FormatHex, false)

	var wg sync.WaitGroup
	const goroutines = 30
	const iterations = 100

	for range goroutines / 3 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for range iterations {
				s.OnPointerButton(0x110, 1)
			}
		}()
	}

	for range goroutines / 3 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for range iterations {
				s.OnKey(1, 1)
			}
		}()
	}

	for range goroutines / 3 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for range iterations {
				picked, cancelled := s.IsDone()
				_ = picked
				_ = cancelled
			}
		}()
	}

	wg.Wait()
}

func TestSurfaceState_ConcurrentIsReady(t *testing.T) {
	s := NewSurfaceState(FormatHex, false)

	var wg sync.WaitGroup
	const goroutines = 20
	const iterations = 100

	for range goroutines {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for range iterations {
				_ = s.IsReady()
			}
		}()
	}

	wg.Wait()
}

func TestSurfaceState_ConcurrentSwapBuffers(t *testing.T) {
	s := NewSurfaceState(FormatHex, false)

	var wg sync.WaitGroup
	const goroutines = 20
	const iterations = 100

	for range goroutines {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for range iterations {
				s.SwapBuffers()
			}
		}()
	}

	wg.Wait()
}

func TestSurfaceState_ZeroScale(t *testing.T) {
	s := NewSurfaceState(FormatHex, false)
	s.SetScale(0)
	assert.Equal(t, int32(1), s.Scale())
}

func TestSurfaceState_NegativeScale(t *testing.T) {
	s := NewSurfaceState(FormatHex, false)
	s.SetScale(-5)
	assert.Equal(t, int32(1), s.Scale())
}

func TestSurfaceState_ZeroDimensionConfigure(t *testing.T) {
	s := NewSurfaceState(FormatHex, false)

	err := s.OnLayerConfigure(0, 100)
	assert.NoError(t, err)

	err = s.OnLayerConfigure(100, 0)
	assert.NoError(t, err)

	err = s.OnLayerConfigure(-1, 100)
	assert.NoError(t, err)

	w, h := s.LogicalSize()
	assert.Equal(t, 0, w)
	assert.Equal(t, 0, h)
}

func TestSurfaceState_PickColorNilBuffer(t *testing.T) {
	s := NewSurfaceState(FormatHex, false)
	color, ok := s.PickColor()
	assert.False(t, ok)
	assert.Equal(t, Color{}, color)
}

func TestSurfaceState_RedrawNilBuffer(t *testing.T) {
	s := NewSurfaceState(FormatHex, false)
	buf := s.Redraw()
	assert.Nil(t, buf)
}

func TestSurfaceState_RedrawScreenOnlyNilBuffer(t *testing.T) {
	s := NewSurfaceState(FormatHex, false)
	buf := s.RedrawScreenOnly()
	assert.Nil(t, buf)
}

func TestSurfaceState_FrontRenderBufferNil(t *testing.T) {
	s := NewSurfaceState(FormatHex, false)
	buf := s.FrontRenderBuffer()
	assert.Nil(t, buf)
}

func TestSurfaceState_ScreenBufferNil(t *testing.T) {
	s := NewSurfaceState(FormatHex, false)
	buf := s.ScreenBuffer()
	assert.Nil(t, buf)
}

func TestSurfaceState_DestroyMultipleTimes(t *testing.T) {
	s := NewSurfaceState(FormatHex, false)
	s.Destroy()
	s.Destroy()
}

func TestClamp(t *testing.T) {
	tests := []struct {
		v, lo, hi, expected int
	}{
		{5, 0, 10, 5},
		{-5, 0, 10, 0},
		{15, 0, 10, 10},
		{0, 0, 10, 0},
		{10, 0, 10, 10},
	}

	for _, tt := range tests {
		result := clamp(tt.v, tt.lo, tt.hi)
		assert.Equal(t, tt.expected, result)
	}
}

func TestClampF(t *testing.T) {
	tests := []struct {
		v, lo, hi, expected float64
	}{
		{5.0, 0.0, 10.0, 5.0},
		{-5.0, 0.0, 10.0, 0.0},
		{15.0, 0.0, 10.0, 10.0},
		{0.0, 0.0, 10.0, 0.0},
		{10.0, 0.0, 10.0, 10.0},
	}

	for _, tt := range tests {
		result := clampF(tt.v, tt.lo, tt.hi)
		assert.InDelta(t, tt.expected, result, 0.001)
	}
}

func TestAbs(t *testing.T) {
	tests := []struct {
		v, expected int
	}{
		{5, 5},
		{-5, 5},
		{0, 0},
	}

	for _, tt := range tests {
		result := abs(tt.v)
		assert.Equal(t, tt.expected, result)
	}
}

func TestBlendColors(t *testing.T) {
	bg := Color{R: 0, G: 0, B: 0, A: 255}
	fg := Color{R: 255, G: 255, B: 255, A: 255}

	result := blendColors(bg, fg, 0.0)
	assert.Equal(t, bg.R, result.R)
	assert.Equal(t, bg.G, result.G)
	assert.Equal(t, bg.B, result.B)

	result = blendColors(bg, fg, 1.0)
	assert.Equal(t, fg.R, result.R)
	assert.Equal(t, fg.G, result.G)
	assert.Equal(t, fg.B, result.B)

	result = blendColors(bg, fg, 0.5)
	assert.InDelta(t, 127, int(result.R), 1)
	assert.InDelta(t, 127, int(result.G), 1)
	assert.InDelta(t, 127, int(result.B), 1)

	result = blendColors(bg, fg, -1.0)
	assert.Equal(t, bg.R, result.R)

	result = blendColors(bg, fg, 2.0)
	assert.Equal(t, fg.R, result.R)
}
