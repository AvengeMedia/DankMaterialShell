package dank16

import (
	"math"
	"testing"
)

func TestHexToRGB(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected RGB
	}{
		{
			name:     "black with hash",
			input:    "#000000",
			expected: RGB{R: 0.0, G: 0.0, B: 0.0},
		},
		{
			name:     "white with hash",
			input:    "#ffffff",
			expected: RGB{R: 1.0, G: 1.0, B: 1.0},
		},
		{
			name:     "red without hash",
			input:    "ff0000",
			expected: RGB{R: 1.0, G: 0.0, B: 0.0},
		},
		{
			name:     "purple",
			input:    "#625690",
			expected: RGB{R: 0.3843137254901961, G: 0.33725490196078434, B: 0.5647058823529412},
		},
		{
			name:     "mid gray",
			input:    "#808080",
			expected: RGB{R: 0.5019607843137255, G: 0.5019607843137255, B: 0.5019607843137255},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := HexToRGB(tt.input)
			if !floatEqual(result.R, tt.expected.R) || !floatEqual(result.G, tt.expected.G) || !floatEqual(result.B, tt.expected.B) {
				t.Errorf("HexToRGB(%s) = %v, expected %v", tt.input, result, tt.expected)
			}
		})
	}
}

func TestRGBToHex(t *testing.T) {
	tests := []struct {
		name     string
		input    RGB
		expected string
	}{
		{
			name:     "black",
			input:    RGB{R: 0.0, G: 0.0, B: 0.0},
			expected: "#000000",
		},
		{
			name:     "white",
			input:    RGB{R: 1.0, G: 1.0, B: 1.0},
			expected: "#ffffff",
		},
		{
			name:     "red",
			input:    RGB{R: 1.0, G: 0.0, B: 0.0},
			expected: "#ff0000",
		},
		{
			name:     "clamping above 1.0",
			input:    RGB{R: 1.5, G: 0.5, B: 0.5},
			expected: "#ff7f7f",
		},
		{
			name:     "clamping below 0.0",
			input:    RGB{R: -0.5, G: 0.5, B: 0.5},
			expected: "#007f7f",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := RGBToHex(tt.input)
			if result != tt.expected {
				t.Errorf("RGBToHex(%v) = %s, expected %s", tt.input, result, tt.expected)
			}
		})
	}
}

func TestRGBToHSV(t *testing.T) {
	tests := []struct {
		name     string
		input    RGB
		expected HSV
	}{
		{
			name:     "black",
			input:    RGB{R: 0.0, G: 0.0, B: 0.0},
			expected: HSV{H: 0.0, S: 0.0, V: 0.0},
		},
		{
			name:     "white",
			input:    RGB{R: 1.0, G: 1.0, B: 1.0},
			expected: HSV{H: 0.0, S: 0.0, V: 1.0},
		},
		{
			name:     "red",
			input:    RGB{R: 1.0, G: 0.0, B: 0.0},
			expected: HSV{H: 0.0, S: 1.0, V: 1.0},
		},
		{
			name:     "green",
			input:    RGB{R: 0.0, G: 1.0, B: 0.0},
			expected: HSV{H: 0.3333333333333333, S: 1.0, V: 1.0},
		},
		{
			name:     "blue",
			input:    RGB{R: 0.0, G: 0.0, B: 1.0},
			expected: HSV{H: 0.6666666666666666, S: 1.0, V: 1.0},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := RGBToHSV(tt.input)
			if !floatEqual(result.H, tt.expected.H) || !floatEqual(result.S, tt.expected.S) || !floatEqual(result.V, tt.expected.V) {
				t.Errorf("RGBToHSV(%v) = %v, expected %v", tt.input, result, tt.expected)
			}
		})
	}
}

func TestHSVToRGB(t *testing.T) {
	tests := []struct {
		name     string
		input    HSV
		expected RGB
	}{
		{
			name:     "black",
			input:    HSV{H: 0.0, S: 0.0, V: 0.0},
			expected: RGB{R: 0.0, G: 0.0, B: 0.0},
		},
		{
			name:     "white",
			input:    HSV{H: 0.0, S: 0.0, V: 1.0},
			expected: RGB{R: 1.0, G: 1.0, B: 1.0},
		},
		{
			name:     "red",
			input:    HSV{H: 0.0, S: 1.0, V: 1.0},
			expected: RGB{R: 1.0, G: 0.0, B: 0.0},
		},
		{
			name:     "green",
			input:    HSV{H: 0.3333333333333333, S: 1.0, V: 1.0},
			expected: RGB{R: 0.0, G: 1.0, B: 0.0},
		},
		{
			name:     "blue",
			input:    HSV{H: 0.6666666666666666, S: 1.0, V: 1.0},
			expected: RGB{R: 0.0, G: 0.0, B: 1.0},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := HSVToRGB(tt.input)
			if !floatEqual(result.R, tt.expected.R) || !floatEqual(result.G, tt.expected.G) || !floatEqual(result.B, tt.expected.B) {
				t.Errorf("HSVToRGB(%v) = %v, expected %v", tt.input, result, tt.expected)
			}
		})
	}
}

func TestLuminance(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected float64
	}{
		{
			name:     "black",
			input:    "#000000",
			expected: 0.0,
		},
		{
			name:     "white",
			input:    "#ffffff",
			expected: 1.0,
		},
		{
			name:     "red",
			input:    "#ff0000",
			expected: 0.2126,
		},
		{
			name:     "green",
			input:    "#00ff00",
			expected: 0.7152,
		},
		{
			name:     "blue",
			input:    "#0000ff",
			expected: 0.0722,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := Luminance(tt.input)
			if !floatEqual(result, tt.expected) {
				t.Errorf("Luminance(%s) = %f, expected %f", tt.input, result, tt.expected)
			}
		})
	}
}

func TestContrastRatio(t *testing.T) {
	tests := []struct {
		name     string
		fg       string
		bg       string
		expected float64
	}{
		{
			name:     "black on white",
			fg:       "#000000",
			bg:       "#ffffff",
			expected: 21.0,
		},
		{
			name:     "white on black",
			fg:       "#ffffff",
			bg:       "#000000",
			expected: 21.0,
		},
		{
			name:     "same color",
			fg:       "#808080",
			bg:       "#808080",
			expected: 1.0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := ContrastRatio(tt.fg, tt.bg)
			if !floatEqual(result, tt.expected) {
				t.Errorf("ContrastRatio(%s, %s) = %f, expected %f", tt.fg, tt.bg, result, tt.expected)
			}
		})
	}
}

func TestEnsureContrast(t *testing.T) {
	tests := []struct {
		name        string
		color       string
		bg          string
		minRatio    float64
		isLightMode bool
	}{
		{
			name:        "already sufficient contrast dark mode",
			color:       "#ffffff",
			bg:          "#000000",
			minRatio:    4.5,
			isLightMode: false,
		},
		{
			name:        "already sufficient contrast light mode",
			color:       "#000000",
			bg:          "#ffffff",
			minRatio:    4.5,
			isLightMode: true,
		},
		{
			name:        "needs adjustment dark mode",
			color:       "#404040",
			bg:          "#1a1a1a",
			minRatio:    4.5,
			isLightMode: false,
		},
		{
			name:        "needs adjustment light mode",
			color:       "#c0c0c0",
			bg:          "#f8f8f8",
			minRatio:    4.5,
			isLightMode: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := EnsureContrast(tt.color, tt.bg, tt.minRatio, tt.isLightMode)
			actualRatio := ContrastRatio(result, tt.bg)
			if actualRatio < tt.minRatio {
				t.Errorf("EnsureContrast(%s, %s, %f, %t) = %s with ratio %f, expected ratio >= %f",
					tt.color, tt.bg, tt.minRatio, tt.isLightMode, result, actualRatio, tt.minRatio)
			}
		})
	}
}

func TestGeneratePalette(t *testing.T) {
	tests := []struct {
		name string
		base string
		opts PaletteOptions
	}{
		{
			name: "dark theme default",
			base: "#625690",
			opts: PaletteOptions{IsLight: false},
		},
		{
			name: "light theme default",
			base: "#625690",
			opts: PaletteOptions{IsLight: true},
		},
		{
			name: "light theme with custom background",
			base: "#625690",
			opts: PaletteOptions{
				IsLight:    true,
				Background: "#fafafa",
			},
		},
		{
			name: "dark theme with custom background",
			base: "#625690",
			opts: PaletteOptions{
				IsLight:    false,
				Background: "#0a0a0a",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := GeneratePalette(tt.base, tt.opts)

			colors := []ColorInfo{
				result.Color0, result.Color1, result.Color2, result.Color3,
				result.Color4, result.Color5, result.Color6, result.Color7,
				result.Color8, result.Color9, result.Color10, result.Color11,
				result.Color12, result.Color13, result.Color14, result.Color15,
			}

			for i, color := range colors {
				if len(color.Hex) != 7 || color.Hex[0] != '#' {
					t.Errorf("Color at index %d (%s) is not a valid hex color", i, color.Hex)
				}
			}

			if tt.opts.Background != "" && result.Color0.Hex != tt.opts.Background {
				t.Errorf("Background color = %s, expected %s", result.Color0.Hex, tt.opts.Background)
			} else if !tt.opts.IsLight && tt.opts.Background == "" && result.Color0.Hex != "#1a1a1a" {
				t.Errorf("Dark mode background = %s, expected #1a1a1a", result.Color0.Hex)
			} else if tt.opts.IsLight && tt.opts.Background == "" && result.Color0.Hex != "#f8f8f8" {
				t.Errorf("Light mode background = %s, expected #f8f8f8", result.Color0.Hex)
			}

			if tt.opts.IsLight && result.Color15.Hex != "#1a1a1a" {
				t.Errorf("Light mode foreground = %s, expected #1a1a1a", result.Color15.Hex)
			} else if !tt.opts.IsLight && result.Color15.Hex != "#ffffff" {
				t.Errorf("Dark mode foreground = %s, expected #ffffff", result.Color15.Hex)
			}
		})
	}
}

func TestRoundTripConversion(t *testing.T) {
	testColors := []string{"#000000", "#ffffff", "#ff0000", "#00ff00", "#0000ff", "#625690", "#808080"}

	for _, hex := range testColors {
		t.Run(hex, func(t *testing.T) {
			rgb := HexToRGB(hex)
			result := RGBToHex(rgb)
			if result != hex {
				t.Errorf("Round trip %s -> RGB -> %s failed", hex, result)
			}
		})
	}
}

func TestRGBHSVRoundTrip(t *testing.T) {
	testCases := []RGB{
		{R: 0.0, G: 0.0, B: 0.0},
		{R: 1.0, G: 1.0, B: 1.0},
		{R: 1.0, G: 0.0, B: 0.0},
		{R: 0.0, G: 1.0, B: 0.0},
		{R: 0.0, G: 0.0, B: 1.0},
		{R: 0.5, G: 0.5, B: 0.5},
		{R: 0.3843137254901961, G: 0.33725490196078434, B: 0.5647058823529412},
	}

	for _, rgb := range testCases {
		t.Run("", func(t *testing.T) {
			hsv := RGBToHSV(rgb)
			result := HSVToRGB(hsv)
			if !floatEqual(result.R, rgb.R) || !floatEqual(result.G, rgb.G) || !floatEqual(result.B, rgb.B) {
				t.Errorf("Round trip RGB->HSV->RGB failed: %v -> %v -> %v", rgb, hsv, result)
			}
		})
	}
}

func floatEqual(a, b float64) bool {
	return math.Abs(a-b) < 1e-9
}

func TestDeltaPhiStar(t *testing.T) {
	tests := []struct {
		name             string
		fg               string
		bg               string
		negativePolarity bool
		minExpected      float64
	}{
		{
			name:             "white on black (negative polarity)",
			fg:               "#ffffff",
			bg:               "#000000",
			negativePolarity: true,
			minExpected:      100.0,
		},
		{
			name:             "black on white (positive polarity)",
			fg:               "#000000",
			bg:               "#ffffff",
			negativePolarity: false,
			minExpected:      100.0,
		},
		{
			name:             "low contrast same color",
			fg:               "#808080",
			bg:               "#808080",
			negativePolarity: false,
			minExpected:      -40.0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := DeltaPhiStar(tt.fg, tt.bg, tt.negativePolarity)
			if result < tt.minExpected {
				t.Errorf("DeltaPhiStar(%s, %s, %v) = %f, expected >= %f",
					tt.fg, tt.bg, tt.negativePolarity, result, tt.minExpected)
			}
		})
	}
}

func TestDeltaPhiStarContrast(t *testing.T) {
	tests := []struct {
		name        string
		fg          string
		bg          string
		isLightMode bool
		minExpected float64
	}{
		{
			name:        "white on black (dark mode)",
			fg:          "#ffffff",
			bg:          "#000000",
			isLightMode: false,
			minExpected: 100.0,
		},
		{
			name:        "black on white (light mode)",
			fg:          "#000000",
			bg:          "#ffffff",
			isLightMode: true,
			minExpected: 100.0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := DeltaPhiStarContrast(tt.fg, tt.bg, tt.isLightMode)
			if result < tt.minExpected {
				t.Errorf("DeltaPhiStarContrast(%s, %s, %v) = %f, expected >= %f",
					tt.fg, tt.bg, tt.isLightMode, result, tt.minExpected)
			}
		})
	}
}

func TestEnsureContrastDPS(t *testing.T) {
	tests := []struct {
		name        string
		color       string
		bg          string
		minLc       float64
		isLightMode bool
	}{
		{
			name:        "already sufficient contrast dark mode",
			color:       "#ffffff",
			bg:          "#000000",
			minLc:       60.0,
			isLightMode: false,
		},
		{
			name:        "already sufficient contrast light mode",
			color:       "#000000",
			bg:          "#ffffff",
			minLc:       60.0,
			isLightMode: true,
		},
		{
			name:        "needs adjustment dark mode",
			color:       "#404040",
			bg:          "#1a1a1a",
			minLc:       60.0,
			isLightMode: false,
		},
		{
			name:        "needs adjustment light mode",
			color:       "#c0c0c0",
			bg:          "#f8f8f8",
			minLc:       60.0,
			isLightMode: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := EnsureContrastDPS(tt.color, tt.bg, tt.minLc, tt.isLightMode)
			actualLc := DeltaPhiStarContrast(result, tt.bg, tt.isLightMode)
			if actualLc < tt.minLc {
				t.Errorf("EnsureContrastDPS(%s, %s, %f, %t) = %s with Lc %f, expected Lc >= %f",
					tt.color, tt.bg, tt.minLc, tt.isLightMode, result, actualLc, tt.minLc)
			}
		})
	}
}

func TestGeneratePaletteWithDPS(t *testing.T) {
	tests := []struct {
		name string
		base string
		opts PaletteOptions
	}{
		{
			name: "dark theme with DPS",
			base: "#625690",
			opts: PaletteOptions{IsLight: false, UseDPS: true},
		},
		{
			name: "light theme with DPS",
			base: "#625690",
			opts: PaletteOptions{IsLight: true, UseDPS: true},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := GeneratePalette(tt.base, tt.opts)

			colors := []ColorInfo{
				result.Color0, result.Color1, result.Color2, result.Color3,
				result.Color4, result.Color5, result.Color6, result.Color7,
				result.Color8, result.Color9, result.Color10, result.Color11,
				result.Color12, result.Color13, result.Color14, result.Color15,
			}

			for i, color := range colors {
				if len(color.Hex) != 7 || color.Hex[0] != '#' {
					t.Errorf("Color at index %d (%s) is not a valid hex color", i, color.Hex)
				}
			}

			bgColor := result.Color0.Hex
			for i := 1; i < 8; i++ {
				lc := DeltaPhiStarContrast(colors[i].Hex, bgColor, tt.opts.IsLight)
				minLc := 30.0
				if lc < minLc && lc > 0 {
					t.Errorf("Color %d (%s) has insufficient DPS contrast %f with background %s (expected >= %f)",
						i, colors[i].Hex, lc, bgColor, minLc)
				}
			}
		})
	}
}

func TestDeriveContainer(t *testing.T) {
	tests := []struct {
		name     string
		primary  string
		isLight  bool
		expected string
	}{
		{
			name:     "dark mode",
			primary:  "#ccbdff",
			isLight:  false,
			expected: "#4a3e76",
		},
		{
			name:     "light mode",
			primary:  "#625690",
			isLight:  true,
			expected: "#e7deff",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := DeriveContainer(tt.primary, tt.isLight)

			resultRGB := HexToRGB(result)
			expectedRGB := HexToRGB(tt.expected)

			rDiff := math.Abs(resultRGB.R - expectedRGB.R)
			gDiff := math.Abs(resultRGB.G - expectedRGB.G)
			bDiff := math.Abs(resultRGB.B - expectedRGB.B)

			tolerance := 0.02
			if rDiff > tolerance || gDiff > tolerance || bDiff > tolerance {
				t.Errorf("DeriveContainer(%s, %v) = %s, expected %s (RGB diff: R:%.4f G:%.4f B:%.4f)",
					tt.primary, tt.isLight, result, tt.expected, rDiff, gDiff, bDiff)
			}
		})
	}
}

func TestContrastAlgorithmComparison(t *testing.T) {
	base := "#625690"

	optsWCAG := PaletteOptions{IsLight: false, UseDPS: false}
	optsDPS := PaletteOptions{IsLight: false, UseDPS: true}

	paletteWCAG := GeneratePalette(base, optsWCAG)
	paletteDPS := GeneratePalette(base, optsDPS)

	wcagColors := []ColorInfo{
		paletteWCAG.Color0, paletteWCAG.Color1, paletteWCAG.Color2, paletteWCAG.Color3,
		paletteWCAG.Color4, paletteWCAG.Color5, paletteWCAG.Color6, paletteWCAG.Color7,
		paletteWCAG.Color8, paletteWCAG.Color9, paletteWCAG.Color10, paletteWCAG.Color11,
		paletteWCAG.Color12, paletteWCAG.Color13, paletteWCAG.Color14, paletteWCAG.Color15,
	}
	dpsColors := []ColorInfo{
		paletteDPS.Color0, paletteDPS.Color1, paletteDPS.Color2, paletteDPS.Color3,
		paletteDPS.Color4, paletteDPS.Color5, paletteDPS.Color6, paletteDPS.Color7,
		paletteDPS.Color8, paletteDPS.Color9, paletteDPS.Color10, paletteDPS.Color11,
		paletteDPS.Color12, paletteDPS.Color13, paletteDPS.Color14, paletteDPS.Color15,
	}

	if paletteWCAG.Color0.Hex != paletteDPS.Color0.Hex {
		t.Errorf("Background colors differ: WCAG=%s, DPS=%s", paletteWCAG.Color0.Hex, paletteDPS.Color0.Hex)
	}

	differentCount := 0
	for i := range 16 {
		if wcagColors[i].Hex != dpsColors[i].Hex {
			differentCount++
		}
	}

	t.Logf("WCAG and DPS palettes differ in %d/16 colors", differentCount)
}
