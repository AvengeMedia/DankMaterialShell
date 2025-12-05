package colorpicker

import (
	"encoding/json"
	"fmt"
	"math"
	"strings"
)

type Color struct {
	R, G, B, A uint8
}

type OutputFormat int

const (
	FormatHex OutputFormat = iota
	FormatRGB
	FormatHSL
	FormatHSV
	FormatCMYK
)

func ParseFormat(s string) OutputFormat {
	switch strings.ToLower(s) {
	case "rgb":
		return FormatRGB
	case "hsl":
		return FormatHSL
	case "hsv":
		return FormatHSV
	case "cmyk":
		return FormatCMYK
	default:
		return FormatHex
	}
}

func (c Color) ToHex(lowercase bool) string {
	if lowercase {
		return fmt.Sprintf("#%02x%02x%02x", c.R, c.G, c.B)
	}
	return fmt.Sprintf("#%02X%02X%02X", c.R, c.G, c.B)
}

func (c Color) ToRGB() string {
	return fmt.Sprintf("%d %d %d", c.R, c.G, c.B)
}

func (c Color) ToHSL() string {
	h, s, l := rgbToHSL(c.R, c.G, c.B)
	return fmt.Sprintf("%d %d%% %d%%", h, s, l)
}

func (c Color) ToHSV() string {
	h, s, v := rgbToHSV(c.R, c.G, c.B)
	return fmt.Sprintf("%d %d%% %d%%", h, s, v)
}

func (c Color) ToCMYK() string {
	cy, m, y, k := rgbToCMYK(c.R, c.G, c.B)
	return fmt.Sprintf("%d%% %d%% %d%% %d%%", cy, m, y, k)
}

func (c Color) Format(format OutputFormat, lowercase bool, customFmt string) string {
	if customFmt != "" {
		return c.formatCustom(format, customFmt)
	}

	switch format {
	case FormatRGB:
		return c.ToRGB()
	case FormatHSL:
		return c.ToHSL()
	case FormatHSV:
		return c.ToHSV()
	case FormatCMYK:
		return c.ToCMYK()
	default:
		return c.ToHex(lowercase)
	}
}

func (c Color) formatCustom(format OutputFormat, customFmt string) string {
	switch format {
	case FormatRGB:
		return replaceArgs(customFmt, c.R, c.G, c.B)
	case FormatHSL:
		h, s, l := rgbToHSL(c.R, c.G, c.B)
		return replaceArgs(customFmt, h, s, l)
	case FormatHSV:
		h, s, v := rgbToHSV(c.R, c.G, c.B)
		return replaceArgs(customFmt, h, s, v)
	case FormatCMYK:
		cy, m, y, k := rgbToCMYK(c.R, c.G, c.B)
		return replaceArgs4(customFmt, cy, m, y, k)
	default:
		if strings.Contains(customFmt, "{0}") {
			r := fmt.Sprintf("%02X", c.R)
			g := fmt.Sprintf("%02X", c.G)
			b := fmt.Sprintf("%02X", c.B)
			return replaceArgsStr(customFmt, r, g, b)
		}
		return c.ToHex(false)
	}
}

func replaceArgs[T any](format string, a, b, c T) string {
	result := format
	result = strings.ReplaceAll(result, "{0}", fmt.Sprintf("%v", a))
	result = strings.ReplaceAll(result, "{1}", fmt.Sprintf("%v", b))
	result = strings.ReplaceAll(result, "{2}", fmt.Sprintf("%v", c))
	return result
}

func replaceArgs4[T any](format string, a, b, c, d T) string {
	result := format
	result = strings.ReplaceAll(result, "{0}", fmt.Sprintf("%v", a))
	result = strings.ReplaceAll(result, "{1}", fmt.Sprintf("%v", b))
	result = strings.ReplaceAll(result, "{2}", fmt.Sprintf("%v", c))
	result = strings.ReplaceAll(result, "{3}", fmt.Sprintf("%v", d))
	return result
}

func replaceArgsStr(format, a, b, c string) string {
	result := format
	result = strings.ReplaceAll(result, "{0}", a)
	result = strings.ReplaceAll(result, "{1}", b)
	result = strings.ReplaceAll(result, "{2}", c)
	return result
}

func rgbToHSL(r, g, b uint8) (int, int, int) {
	rf := float64(r) / 255.0
	gf := float64(g) / 255.0
	bf := float64(b) / 255.0

	maxVal := math.Max(rf, math.Max(gf, bf))
	minVal := math.Min(rf, math.Min(gf, bf))
	l := (maxVal + minVal) / 2

	if maxVal == minVal {
		return 0, 0, int(math.Round(l * 100))
	}

	d := maxVal - minVal
	var s float64
	if l > 0.5 {
		s = d / (2 - maxVal - minVal)
	} else {
		s = d / (maxVal + minVal)
	}

	var h float64
	switch maxVal {
	case rf:
		h = (gf - bf) / d
		if gf < bf {
			h += 6
		}
	case gf:
		h = (bf-rf)/d + 2
	case bf:
		h = (rf-gf)/d + 4
	}
	h /= 6

	return int(math.Round(h * 360)), int(math.Round(s * 100)), int(math.Round(l * 100))
}

func rgbToHSV(r, g, b uint8) (int, int, int) {
	rf := float64(r) / 255.0
	gf := float64(g) / 255.0
	bf := float64(b) / 255.0

	maxVal := math.Max(rf, math.Max(gf, bf))
	minVal := math.Min(rf, math.Min(gf, bf))
	v := maxVal
	d := maxVal - minVal

	var s float64
	if maxVal != 0 {
		s = d / maxVal
	}

	if maxVal == minVal {
		return 0, int(math.Round(s * 100)), int(math.Round(v * 100))
	}

	var h float64
	switch maxVal {
	case rf:
		h = (gf - bf) / d
		if gf < bf {
			h += 6
		}
	case gf:
		h = (bf-rf)/d + 2
	case bf:
		h = (rf-gf)/d + 4
	}
	h /= 6

	return int(math.Round(h * 360)), int(math.Round(s * 100)), int(math.Round(v * 100))
}

func rgbToCMYK(r, g, b uint8) (int, int, int, int) {
	if r == 0 && g == 0 && b == 0 {
		return 0, 0, 0, 100
	}

	rf := float64(r) / 255.0
	gf := float64(g) / 255.0
	bf := float64(b) / 255.0

	k := 1 - math.Max(rf, math.Max(gf, bf))
	c := (1 - rf - k) / (1 - k)
	m := (1 - gf - k) / (1 - k)
	y := (1 - bf - k) / (1 - k)

	return int(math.Round(c * 100)), int(math.Round(m * 100)), int(math.Round(y * 100)), int(math.Round(k * 100))
}

func (c Color) Luminance() float64 {
	r := float64(c.R) / 255.0
	g := float64(c.G) / 255.0
	b := float64(c.B) / 255.0

	if r <= 0.03928 {
		r = r / 12.92
	} else {
		r = math.Pow((r+0.055)/1.055, 2.4)
	}

	if g <= 0.03928 {
		g = g / 12.92
	} else {
		g = math.Pow((g+0.055)/1.055, 2.4)
	}

	if b <= 0.03928 {
		b = b / 12.92
	} else {
		b = math.Pow((b+0.055)/1.055, 2.4)
	}

	return 0.2126*r + 0.7152*g + 0.0722*b
}

func (c Color) IsDark() bool {
	return c.Luminance() < 0.179
}

type ColorJSON struct {
	Hex string `json:"hex"`
	RGB struct {
		R int `json:"r"`
		G int `json:"g"`
		B int `json:"b"`
	} `json:"rgb"`
	HSL struct {
		H int `json:"h"`
		S int `json:"s"`
		L int `json:"l"`
	} `json:"hsl"`
	HSV struct {
		H int `json:"h"`
		S int `json:"s"`
		V int `json:"v"`
	} `json:"hsv"`
	CMYK struct {
		C int `json:"c"`
		M int `json:"m"`
		Y int `json:"y"`
		K int `json:"k"`
	} `json:"cmyk"`
}

func (c Color) ToJSON() (string, error) {
	h, s, l := rgbToHSL(c.R, c.G, c.B)
	hv, sv, v := rgbToHSV(c.R, c.G, c.B)
	cy, m, y, k := rgbToCMYK(c.R, c.G, c.B)

	data := ColorJSON{
		Hex: c.ToHex(false),
	}
	data.RGB.R = int(c.R)
	data.RGB.G = int(c.G)
	data.RGB.B = int(c.B)
	data.HSL.H = h
	data.HSL.S = s
	data.HSL.L = l
	data.HSV.H = hv
	data.HSV.S = sv
	data.HSV.V = v
	data.CMYK.C = cy
	data.CMYK.M = m
	data.CMYK.Y = y
	data.CMYK.K = k

	bytes, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}
