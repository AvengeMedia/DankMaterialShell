package dank16

import (
	"fmt"
	"math"

	"github.com/lucasb-eyer/go-colorful"
)

type RGB struct {
	R, G, B float64
}

type HSV struct {
	H, S, V float64
}

type ColorInfo struct {
	Hex         string `json:"hex"`
	HexStripped string `json:"hex_stripped"`
	R           int    `json:"r"`
	G           int    `json:"g"`
	B           int    `json:"b"`
}

type VariantColorValue struct {
	Hex         string `json:"hex"`
	HexStripped string `json:"hex_stripped"`
}

type VariantColorInfo struct {
	Dark    VariantColorValue `json:"dark"`
	Light   VariantColorValue `json:"light"`
	Default VariantColorValue `json:"default"`
}

type Palette struct {
	Color0  ColorInfo `json:"color0"`
	Color1  ColorInfo `json:"color1"`
	Color2  ColorInfo `json:"color2"`
	Color3  ColorInfo `json:"color3"`
	Color4  ColorInfo `json:"color4"`
	Color5  ColorInfo `json:"color5"`
	Color6  ColorInfo `json:"color6"`
	Color7  ColorInfo `json:"color7"`
	Color8  ColorInfo `json:"color8"`
	Color9  ColorInfo `json:"color9"`
	Color10 ColorInfo `json:"color10"`
	Color11 ColorInfo `json:"color11"`
	Color12 ColorInfo `json:"color12"`
	Color13 ColorInfo `json:"color13"`
	Color14 ColorInfo `json:"color14"`
	Color15 ColorInfo `json:"color15"`
}

type VariantPalette struct {
	Color0  VariantColorInfo `json:"color0"`
	Color1  VariantColorInfo `json:"color1"`
	Color2  VariantColorInfo `json:"color2"`
	Color3  VariantColorInfo `json:"color3"`
	Color4  VariantColorInfo `json:"color4"`
	Color5  VariantColorInfo `json:"color5"`
	Color6  VariantColorInfo `json:"color6"`
	Color7  VariantColorInfo `json:"color7"`
	Color8  VariantColorInfo `json:"color8"`
	Color9  VariantColorInfo `json:"color9"`
	Color10 VariantColorInfo `json:"color10"`
	Color11 VariantColorInfo `json:"color11"`
	Color12 VariantColorInfo `json:"color12"`
	Color13 VariantColorInfo `json:"color13"`
	Color14 VariantColorInfo `json:"color14"`
	Color15 VariantColorInfo `json:"color15"`
}

func NewColorInfo(hex string) ColorInfo {
	rgb := HexToRGB(hex)
	stripped := hex
	if len(hex) > 0 && hex[0] == '#' {
		stripped = hex[1:]
	}
	return ColorInfo{
		Hex:         hex,
		HexStripped: stripped,
		R:           int(math.Round(rgb.R * 255)),
		G:           int(math.Round(rgb.G * 255)),
		B:           int(math.Round(rgb.B * 255)),
	}
}

func HexToRGB(hex string) RGB {
	if hex[0] == '#' {
		hex = hex[1:]
	}
	var r, g, b uint8
	fmt.Sscanf(hex, "%02x%02x%02x", &r, &g, &b)
	return RGB{
		R: float64(r) / 255.0,
		G: float64(g) / 255.0,
		B: float64(b) / 255.0,
	}
}

func RGBToHex(rgb RGB) string {
	r := math.Max(0, math.Min(1, rgb.R))
	g := math.Max(0, math.Min(1, rgb.G))
	b := math.Max(0, math.Min(1, rgb.B))
	return fmt.Sprintf("#%02x%02x%02x", int(r*255), int(g*255), int(b*255))
}

func RGBToHSV(rgb RGB) HSV {
	max := math.Max(math.Max(rgb.R, rgb.G), rgb.B)
	min := math.Min(math.Min(rgb.R, rgb.G), rgb.B)
	delta := max - min

	var h float64
	switch {
	case delta == 0:
		h = 0
	case max == rgb.R:
		h = math.Mod((rgb.G-rgb.B)/delta, 6.0) / 6.0
	case max == rgb.G:
		h = ((rgb.B-rgb.R)/delta + 2.0) / 6.0
	default:
		h = ((rgb.R-rgb.G)/delta + 4.0) / 6.0
	}

	if h < 0 {
		h += 1.0
	}

	var s float64
	if max == 0 {
		s = 0
	} else {
		s = delta / max
	}

	return HSV{H: h, S: s, V: max}
}

func HSVToRGB(hsv HSV) RGB {
	h := hsv.H * 6.0
	c := hsv.V * hsv.S
	x := c * (1.0 - math.Abs(math.Mod(h, 2.0)-1.0))
	m := hsv.V - c

	var r, g, b float64
	switch int(h) {
	case 0:
		r, g, b = c, x, 0
	case 1:
		r, g, b = x, c, 0
	case 2:
		r, g, b = 0, c, x
	case 3:
		r, g, b = 0, x, c
	case 4:
		r, g, b = x, 0, c
	case 5:
		r, g, b = c, 0, x
	default:
		r, g, b = c, 0, x
	}

	return RGB{R: r + m, G: g + m, B: b + m}
}

func sRGBToLinear(c float64) float64 {
	if c <= 0.04045 {
		return c / 12.92
	}
	return math.Pow((c+0.055)/1.055, 2.4)
}

func Luminance(hex string) float64 {
	rgb := HexToRGB(hex)
	return 0.2126*sRGBToLinear(rgb.R) + 0.7152*sRGBToLinear(rgb.G) + 0.0722*sRGBToLinear(rgb.B)
}

func ContrastRatio(hexFg, hexBg string) float64 {
	lumFg := Luminance(hexFg)
	lumBg := Luminance(hexBg)
	lighter := math.Max(lumFg, lumBg)
	darker := math.Min(lumFg, lumBg)
	return (lighter + 0.05) / (darker + 0.05)
}

func getLstar(hex string) float64 {
	rgb := HexToRGB(hex)
	col := colorful.Color{R: rgb.R, G: rgb.G, B: rgb.B}
	L, _, _ := col.Lab()
	return L * 100.0 // go-colorful uses 0-1, we need 0-100 for DPS
}

// Lab to hex, clamping if needed
func labToHex(L, a, b float64) string {
	c := colorful.Lab(L/100.0, a, b) // back to 0-1 for go-colorful
	r, g, b2 := c.Clamped().RGB255()
	return fmt.Sprintf("#%02x%02x%02x", r, g, b2)
}

// Adjust brightness while keeping the same hue
func retoneToL(hex string, Ltarget float64) string {
	rgb := HexToRGB(hex)
	col := colorful.Color{R: rgb.R, G: rgb.G, B: rgb.B}
	L, a, b := col.Lab()
	L100 := L * 100.0

	scale := 1.0
	if L100 != 0 {
		scale = Ltarget / L100
	}

	a2, b2 := a*scale, b*scale

	// Don't let it get too saturated
	maxChroma := 0.4
	if math.Hypot(a2, b2) > maxChroma {
		k := maxChroma / math.Hypot(a2, b2)
		a2 *= k
		b2 *= k
	}

	return labToHex(Ltarget, a2, b2)
}

func DeltaPhiStar(hexFg, hexBg string, negativePolarity bool) float64 {
	Lf := getLstar(hexFg)
	Lb := getLstar(hexBg)

	phi := 1.618
	inv := 0.618
	lc := math.Pow(math.Abs(math.Pow(Lb, phi)-math.Pow(Lf, phi)), inv)*1.414 - 40

	if negativePolarity {
		lc += 5
	}

	return lc
}

func DeltaPhiStarContrast(hexFg, hexBg string, isLightMode bool) float64 {
	negativePolarity := !isLightMode
	return DeltaPhiStar(hexFg, hexBg, negativePolarity)
}

func EnsureContrast(hexColor, hexBg string, minRatio float64, isLightMode bool) string {
	currentRatio := ContrastRatio(hexColor, hexBg)
	if currentRatio >= minRatio {
		return hexColor
	}

	rgb := HexToRGB(hexColor)
	hsv := RGBToHSV(rgb)

	for step := 1; step < 30; step++ {
		delta := float64(step) * 0.02

		if isLightMode {
			newV := math.Max(0, hsv.V-delta)
			candidate := RGBToHex(HSVToRGB(HSV{H: hsv.H, S: hsv.S, V: newV}))
			if ContrastRatio(candidate, hexBg) >= minRatio {
				return candidate
			}

			newV = math.Min(1, hsv.V+delta)
			candidate = RGBToHex(HSVToRGB(HSV{H: hsv.H, S: hsv.S, V: newV}))
			if ContrastRatio(candidate, hexBg) >= minRatio {
				return candidate
			}
		} else {
			newV := math.Min(1, hsv.V+delta)
			candidate := RGBToHex(HSVToRGB(HSV{H: hsv.H, S: hsv.S, V: newV}))
			if ContrastRatio(candidate, hexBg) >= minRatio {
				return candidate
			}

			newV = math.Max(0, hsv.V-delta)
			candidate = RGBToHex(HSVToRGB(HSV{H: hsv.H, S: hsv.S, V: newV}))
			if ContrastRatio(candidate, hexBg) >= minRatio {
				return candidate
			}
		}
	}

	return hexColor
}

func EnsureContrastDPS(hexColor, hexBg string, minLc float64, isLightMode bool) string {
	currentLc := DeltaPhiStarContrast(hexColor, hexBg, isLightMode)
	if currentLc >= minLc {
		return hexColor
	}

	rgb := HexToRGB(hexColor)
	hsv := RGBToHSV(rgb)

	for step := 1; step < 50; step++ {
		delta := float64(step) * 0.015

		if isLightMode {
			newV := math.Max(0, hsv.V-delta)
			candidate := RGBToHex(HSVToRGB(HSV{H: hsv.H, S: hsv.S, V: newV}))
			if DeltaPhiStarContrast(candidate, hexBg, isLightMode) >= minLc {
				return candidate
			}

			newV = math.Min(1, hsv.V+delta)
			candidate = RGBToHex(HSVToRGB(HSV{H: hsv.H, S: hsv.S, V: newV}))
			if DeltaPhiStarContrast(candidate, hexBg, isLightMode) >= minLc {
				return candidate
			}
		} else {
			newV := math.Min(1, hsv.V+delta)
			candidate := RGBToHex(HSVToRGB(HSV{H: hsv.H, S: hsv.S, V: newV}))
			if DeltaPhiStarContrast(candidate, hexBg, isLightMode) >= minLc {
				return candidate
			}

			newV = math.Max(0, hsv.V-delta)
			candidate = RGBToHex(HSVToRGB(HSV{H: hsv.H, S: hsv.S, V: newV}))
			if DeltaPhiStarContrast(candidate, hexBg, isLightMode) >= minLc {
				return candidate
			}
		}
	}

	return hexColor
}

// Nudge L* until contrast is good enough. Keeps hue intact unlike HSV fiddling.
func EnsureContrastDPSLstar(hexColor, hexBg string, minLc float64, isLightMode bool) string {
	current := DeltaPhiStarContrast(hexColor, hexBg, isLightMode)
	if current >= minLc {
		return hexColor
	}

	fg := HexToRGB(hexColor)
	cf := colorful.Color{R: fg.R, G: fg.G, B: fg.B}
	Lf, af, bf := cf.Lab()

	dir := 1.0
	if isLightMode {
		dir = -1.0 // light mode = darker text
	}

	step := 0.5
	for range 120 {
		Lf = math.Max(0, math.Min(100, Lf+dir*step))
		cand := labToHex(Lf, af, bf)
		if DeltaPhiStarContrast(cand, hexBg, isLightMode) >= minLc {
			return cand
		}
	}

	return hexColor
}

type PaletteOptions struct {
	IsLight    bool
	Background string
	UseDPS     bool
}

func ensureContrastAuto(hexColor, hexBg string, target float64, opts PaletteOptions) string {
	if opts.UseDPS {
		return EnsureContrastDPSLstar(hexColor, hexBg, target, opts.IsLight)
	}
	return EnsureContrast(hexColor, hexBg, target, opts.IsLight)
}

func DeriveContainer(primary string, isLight bool) string {
	rgb := HexToRGB(primary)
	hsv := RGBToHSV(rgb)

	if isLight {
		containerV := math.Min(hsv.V*1.77, 1.0)
		containerS := hsv.S * 0.32
		return RGBToHex(HSVToRGB(HSV{H: hsv.H, S: containerS, V: containerV}))
	}
	containerV := hsv.V * 0.463
	containerS := math.Min(hsv.S*1.834, 1.0)
	return RGBToHex(HSVToRGB(HSV{H: hsv.H, S: containerS, V: containerV}))
}

func GeneratePalette(primaryColor string, opts PaletteOptions) Palette {
	baseColor := DeriveContainer(primaryColor, opts.IsLight)

	rgb := HexToRGB(baseColor)
	hsv := RGBToHSV(rgb)

	var palette Palette

	var normalTextTarget, secondaryTarget float64
	if opts.UseDPS {
		normalTextTarget = 40.0
		secondaryTarget = 35.0
	} else {
		normalTextTarget = 4.5
		secondaryTarget = 3.0
	}

	var bgColor string
	if opts.Background != "" {
		bgColor = opts.Background
	} else if opts.IsLight {
		bgColor = "#f8f8f8"
	} else {
		bgColor = "#1a1a1a"
	}
	palette.Color0 = NewColorInfo(bgColor)

	hueShift := (hsv.H - 0.6) * 0.12
	satBoost := 1.15

	redH := math.Mod(0.0+hueShift+1.0, 1.0)
	var redColor string
	if opts.IsLight {
		redColor = RGBToHex(HSVToRGB(HSV{H: redH, S: math.Min(0.80*satBoost, 1.0), V: 0.55}))
		palette.Color1 = NewColorInfo(ensureContrastAuto(redColor, bgColor, normalTextTarget, opts))
	} else {
		redColor = RGBToHex(HSVToRGB(HSV{H: redH, S: math.Min(0.65*satBoost, 1.0), V: 0.80}))
		palette.Color1 = NewColorInfo(ensureContrastAuto(redColor, bgColor, normalTextTarget, opts))
	}

	greenH := math.Mod(0.33+hueShift+1.0, 1.0)
	var greenColor string
	if opts.IsLight {
		greenColor = RGBToHex(HSVToRGB(HSV{H: greenH, S: math.Min(math.Max(hsv.S*0.9, 0.80)*satBoost, 1.0), V: 0.45}))
		palette.Color2 = NewColorInfo(ensureContrastAuto(greenColor, bgColor, normalTextTarget, opts))
	} else {
		greenColor = RGBToHex(HSVToRGB(HSV{H: greenH, S: math.Min(0.42*satBoost, 1.0), V: 0.84}))
		palette.Color2 = NewColorInfo(ensureContrastAuto(greenColor, bgColor, normalTextTarget, opts))
	}

	yellowH := math.Mod(0.15+hueShift+1.0, 1.0)
	var yellowColor string
	if opts.IsLight {
		yellowColor = RGBToHex(HSVToRGB(HSV{H: yellowH, S: math.Min(0.75*satBoost, 1.0), V: 0.50}))
		palette.Color3 = NewColorInfo(ensureContrastAuto(yellowColor, bgColor, normalTextTarget, opts))
	} else {
		yellowColor = RGBToHex(HSVToRGB(HSV{H: yellowH, S: math.Min(0.38*satBoost, 1.0), V: 0.86}))
		palette.Color3 = NewColorInfo(ensureContrastAuto(yellowColor, bgColor, normalTextTarget, opts))
	}

	var blueColor string
	if opts.IsLight {
		blueColor = RGBToHex(HSVToRGB(HSV{H: hsv.H, S: math.Max(hsv.S*0.9, 0.7), V: hsv.V * 1.1}))
		palette.Color4 = NewColorInfo(ensureContrastAuto(blueColor, bgColor, normalTextTarget, opts))
	} else {
		blueColor = RGBToHex(HSVToRGB(HSV{H: hsv.H, S: math.Max(hsv.S*0.8, 0.6), V: math.Min(hsv.V*1.6, 1.0)}))
		palette.Color4 = NewColorInfo(ensureContrastAuto(blueColor, bgColor, normalTextTarget, opts))
	}

	magH := hsv.H - 0.03
	if magH < 0 {
		magH += 1.0
	}
	var magColor string
	hr := HexToRGB(primaryColor)
	hh := RGBToHSV(hr)
	if opts.IsLight {
		magColor = RGBToHex(HSVToRGB(HSV{H: hh.H, S: math.Max(hh.S*0.9, 0.7), V: hh.V * 0.85}))
		palette.Color5 = NewColorInfo(ensureContrastAuto(magColor, bgColor, normalTextTarget, opts))
	} else {
		magColor = RGBToHex(HSVToRGB(HSV{H: hh.H, S: hh.S * 0.8, V: hh.V * 0.75}))
		palette.Color5 = NewColorInfo(ensureContrastAuto(magColor, bgColor, normalTextTarget, opts))
	}

	cyanH := hsv.H + 0.08
	if cyanH > 1.0 {
		cyanH -= 1.0
	}
	palette.Color6 = NewColorInfo(ensureContrastAuto(primaryColor, bgColor, normalTextTarget, opts))

	if opts.IsLight {
		palette.Color7 = NewColorInfo("#1a1a1a")
		palette.Color8 = NewColorInfo("#2e2e2e")
	} else {
		palette.Color7 = NewColorInfo("#abb2bf")
		palette.Color8 = NewColorInfo("#5c6370")
	}

	if opts.IsLight {
		brightRed := RGBToHex(HSVToRGB(HSV{H: redH, S: math.Min(0.70*satBoost, 1.0), V: 0.65}))
		palette.Color9 = NewColorInfo(ensureContrastAuto(brightRed, bgColor, secondaryTarget, opts))
		brightGreen := RGBToHex(HSVToRGB(HSV{H: greenH, S: math.Min(math.Max(hsv.S*0.85, 0.75)*satBoost, 1.0), V: 0.55}))
		palette.Color10 = NewColorInfo(ensureContrastAuto(brightGreen, bgColor, secondaryTarget, opts))
		brightYellow := RGBToHex(HSVToRGB(HSV{H: yellowH, S: math.Min(0.68*satBoost, 1.0), V: 0.60}))
		palette.Color11 = NewColorInfo(ensureContrastAuto(brightYellow, bgColor, secondaryTarget, opts))
		hr := HexToRGB(primaryColor)
		hh := RGBToHSV(hr)
		brightBlue := RGBToHex(HSVToRGB(HSV{H: hh.H, S: math.Min(hh.S*1.1, 1.0), V: math.Min(hh.V*1.2, 1.0)}))
		palette.Color12 = NewColorInfo(ensureContrastAuto(brightBlue, bgColor, secondaryTarget, opts))
		brightMag := RGBToHex(HSVToRGB(HSV{H: magH, S: math.Max(hsv.S*0.9, 0.75), V: math.Min(hsv.V*1.25, 1.0)}))
		palette.Color13 = NewColorInfo(ensureContrastAuto(brightMag, bgColor, secondaryTarget, opts))
		brightCyan := RGBToHex(HSVToRGB(HSV{H: cyanH, S: math.Max(hsv.S*0.75, 0.65), V: math.Min(hsv.V*1.25, 1.0)}))
		palette.Color14 = NewColorInfo(ensureContrastAuto(brightCyan, bgColor, secondaryTarget, opts))
	} else {
		brightRed := RGBToHex(HSVToRGB(HSV{H: redH, S: math.Min(0.50*satBoost, 1.0), V: 0.88}))
		palette.Color9 = NewColorInfo(ensureContrastAuto(brightRed, bgColor, secondaryTarget, opts))
		brightGreen := RGBToHex(HSVToRGB(HSV{H: greenH, S: math.Min(0.35*satBoost, 1.0), V: 0.88}))
		palette.Color10 = NewColorInfo(ensureContrastAuto(brightGreen, bgColor, secondaryTarget, opts))
		brightYellow := RGBToHex(HSVToRGB(HSV{H: yellowH, S: math.Min(0.30*satBoost, 1.0), V: 0.91}))
		palette.Color11 = NewColorInfo(ensureContrastAuto(brightYellow, bgColor, secondaryTarget, opts))
		brightBlue := retoneToL(primaryColor, 85.0)
		palette.Color12 = NewColorInfo(brightBlue)
		brightMag := RGBToHex(HSVToRGB(HSV{H: magH, S: math.Max(hsv.S*0.7, 0.6), V: math.Min(hsv.V*1.3, 0.9)}))
		palette.Color13 = NewColorInfo(ensureContrastAuto(brightMag, bgColor, secondaryTarget, opts))
		brightCyanH := hsv.H + 0.02
		if brightCyanH > 1.0 {
			brightCyanH -= 1.0
		}
		brightCyan := RGBToHex(HSVToRGB(HSV{H: brightCyanH, S: math.Max(hsv.S*0.6, 0.5), V: math.Min(hsv.V*1.2, 0.85)}))
		palette.Color14 = NewColorInfo(ensureContrastAuto(brightCyan, bgColor, secondaryTarget, opts))
	}

	if opts.IsLight {
		palette.Color15 = NewColorInfo("#1a1a1a")
	} else {
		palette.Color15 = NewColorInfo("#ffffff")
	}

	return palette
}

type VariantOptions struct {
	PrimaryDark  string
	PrimaryLight string
	Background   string
	UseDPS       bool
	IsLightMode  bool
}

func mergeColorInfo(dark, light ColorInfo, isLightMode bool) VariantColorInfo {
	darkVal := VariantColorValue{Hex: dark.Hex, HexStripped: dark.HexStripped}
	lightVal := VariantColorValue{Hex: light.Hex, HexStripped: light.HexStripped}

	defaultVal := darkVal
	if isLightMode {
		defaultVal = lightVal
	}

	return VariantColorInfo{
		Dark:    darkVal,
		Light:   lightVal,
		Default: defaultVal,
	}
}

func GenerateVariantPalette(opts VariantOptions) VariantPalette {
	darkOpts := PaletteOptions{IsLight: false, Background: opts.Background, UseDPS: opts.UseDPS}
	lightOpts := PaletteOptions{IsLight: true, Background: opts.Background, UseDPS: opts.UseDPS}

	dark := GeneratePalette(opts.PrimaryDark, darkOpts)
	light := GeneratePalette(opts.PrimaryLight, lightOpts)

	return VariantPalette{
		Color0:  mergeColorInfo(dark.Color0, light.Color0, opts.IsLightMode),
		Color1:  mergeColorInfo(dark.Color1, light.Color1, opts.IsLightMode),
		Color2:  mergeColorInfo(dark.Color2, light.Color2, opts.IsLightMode),
		Color3:  mergeColorInfo(dark.Color3, light.Color3, opts.IsLightMode),
		Color4:  mergeColorInfo(dark.Color4, light.Color4, opts.IsLightMode),
		Color5:  mergeColorInfo(dark.Color5, light.Color5, opts.IsLightMode),
		Color6:  mergeColorInfo(dark.Color6, light.Color6, opts.IsLightMode),
		Color7:  mergeColorInfo(dark.Color7, light.Color7, opts.IsLightMode),
		Color8:  mergeColorInfo(dark.Color8, light.Color8, opts.IsLightMode),
		Color9:  mergeColorInfo(dark.Color9, light.Color9, opts.IsLightMode),
		Color10: mergeColorInfo(dark.Color10, light.Color10, opts.IsLightMode),
		Color11: mergeColorInfo(dark.Color11, light.Color11, opts.IsLightMode),
		Color12: mergeColorInfo(dark.Color12, light.Color12, opts.IsLightMode),
		Color13: mergeColorInfo(dark.Color13, light.Color13, opts.IsLightMode),
		Color14: mergeColorInfo(dark.Color14, light.Color14, opts.IsLightMode),
		Color15: mergeColorInfo(dark.Color15, light.Color15, opts.IsLightMode),
	}
}
