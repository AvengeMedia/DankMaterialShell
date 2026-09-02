package wayland

import (
	"math"
	"testing"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
)

func TestGenerateGammaRamp(t *testing.T) {
	tests := []struct {
		name  string
		size  uint32
		temp  int
		gamma float64
	}{
		{"small_warm", 16, 6500, 1.0},
		{"small_cool", 16, 4000, 1.0},
		{"large_warm", 256, 6500, 1.0},
		{"large_cool", 256, 4000, 1.0},
		{"custom_gamma", 64, 5500, 1.2},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ramp := GenerateGammaRamp(tt.size, tt.temp, tt.gamma, 1.0)

			if len(ramp.Red) != int(tt.size) {
				t.Errorf("expected %d red values, got %d", tt.size, len(ramp.Red))
			}
			if len(ramp.Green) != int(tt.size) {
				t.Errorf("expected %d green values, got %d", tt.size, len(ramp.Green))
			}
			if len(ramp.Blue) != int(tt.size) {
				t.Errorf("expected %d blue values, got %d", tt.size, len(ramp.Blue))
			}

			if ramp.Red[0] != 0 || ramp.Green[0] != 0 || ramp.Blue[0] != 0 {
				t.Errorf("first values should be 0, got R:%d G:%d B:%d",
					ramp.Red[0], ramp.Green[0], ramp.Blue[0])
			}

			lastIdx := tt.size - 1
			if ramp.Red[lastIdx] == 0 || ramp.Green[lastIdx] == 0 || ramp.Blue[lastIdx] == 0 {
				t.Errorf("last values should be non-zero, got R:%d G:%d B:%d",
					ramp.Red[lastIdx], ramp.Green[lastIdx], ramp.Blue[lastIdx])
			}

			for i := uint32(1); i < tt.size; i++ {
				if ramp.Red[i] < ramp.Red[i-1] {
					t.Errorf("red ramp not monotonic at index %d", i)
				}
			}
		})
	}
}

func TestCalcWhitepoint(t *testing.T) {
	tests := []struct {
		name string
		temp int
	}{
		{"very_warm", 6500},
		{"neutral", 5500},
		{"cool", 4000},
		{"very_cool", 3000},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			wp := calcWhitepoint(tt.temp)

			if wp.r < 0 || wp.r > 1 {
				t.Errorf("red out of range: %f", wp.r)
			}
			if wp.g < 0 || wp.g > 1 {
				t.Errorf("green out of range: %f", wp.g)
			}
			if wp.b < 0 || wp.b > 1 {
				t.Errorf("blue out of range: %f", wp.b)
			}
		})
	}
}

func TestWhitepointProgression(t *testing.T) {
	temps := []int{3000, 4000, 5000, 6000, 6500}

	var prevBlue float64
	for i, temp := range temps {
		wp := calcWhitepoint(temp)
		if i > 0 && wp.b < prevBlue {
			t.Errorf("blue should increase with temperature, %d->%d: %f->%f",
				temps[i-1], temp, prevBlue, wp.b)
		}
		prevBlue = wp.b
	}
}

func TestClamp(t *testing.T) {
	tests := []struct {
		val      float64
		min      float64
		max      float64
		expected float64
	}{
		{5, 0, 10, 5},
		{-5, 0, 10, 0},
		{15, 0, 10, 10},
		{0, 0, 10, 0},
		{10, 0, 10, 10},
	}

	for _, tt := range tests {
		result := utils.Clamp(tt.val, tt.min, tt.max)
		if result != tt.expected {
			t.Errorf("clamp(%f, %f, %f) = %f, want %f",
				tt.val, tt.min, tt.max, result, tt.expected)
		}
	}
}

func TestGenerateGammaRamp_NeutralContrastMatchesLegacy(t *testing.T) {
	legacy := GenerateGammaRamp(256, 4000, 1.2, 1.0)
	for i := range legacy.Red {
		want := uint16(clamp01(math.Pow(float64(i)/255.0*calcWhitepoint(4000).r, 1.0/1.2)) * 65535.0)
		if legacy.Red[i] != want {
			t.Fatalf("index %d: got %d want %d", i, legacy.Red[i], want)
		}
	}
}

func TestGenerateGammaRamp_ContrastPivotsAtMidGray(t *testing.T) {
	const size = 257
	mid := size / 2

	for _, contrast := range []float64{0.5, 1.0, 2.0} {
		ramp := GenerateGammaRamp(size, 6500, 1.0, contrast)
		if ramp.Red[mid] != 32767 {
			t.Errorf("contrast %.1f: mid-gray moved to %d", contrast, ramp.Red[mid])
		}
		for i := 1; i < size; i++ {
			if ramp.Red[i] < ramp.Red[i-1] {
				t.Fatalf("contrast %.1f: not monotonic at %d", contrast, i)
			}
		}
	}

	high := GenerateGammaRamp(size, 6500, 1.0, 2.0)
	if high.Red[size/4] != 0 || high.Red[size*3/4] != 65535 {
		t.Errorf("contrast 2.0 should clip quarter points, got %d and %d", high.Red[size/4], high.Red[size*3/4])
	}

	low := GenerateGammaRamp(size, 6500, 1.0, 0.5)
	if low.Red[0] != 16383 || low.Red[size-1] != 49151 {
		t.Errorf("contrast 0.5 should compress endpoints to quarter points, got %d and %d", low.Red[0], low.Red[size-1])
	}
}
