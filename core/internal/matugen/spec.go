package matugen

import (
	"encoding/json"
	"fmt"
	"regexp"
	"strings"

	"github.com/Nadim147c/material/v3/color"
	"github.com/Nadim147c/material/v3/dynamic"
)

// Palette spec versions. Spec2021 is matugen's own output and the historical
// default. Spec2025 is the Material 3 Expressive color spec, which matugen 4.x
// cannot produce: the palette is generated in-process and handed to matugen
// through --import-json-string, the same override path stock themes use.
const (
	Spec2021 = "2021"
	Spec2025 = "2025"
)

var hexColorPattern = regexp.MustCompile(`^#?[0-9a-fA-F]{6}$`)

// NormalizeHexColor returns "#rrggbb" or an error. matugen and the shell both
// compare generated colors as strings, so casing must not vary between runs.
func NormalizeHexColor(value string) (string, error) {
	value = strings.TrimSpace(value)
	if !hexColorPattern.MatchString(value) {
		return "", fmt.Errorf("invalid hex color %q", value)
	}
	return "#" + strings.ToLower(strings.TrimPrefix(value, "#")), nil
}

var schemeVariants = map[string]dynamic.Variant{
	"scheme-tonal-spot":  dynamic.VariantTonalSpot,
	"scheme-vibrant":     dynamic.VariantVibrant,
	"scheme-content":     dynamic.VariantContent,
	"scheme-expressive":  dynamic.VariantExpressive,
	"scheme-fidelity":    dynamic.VariantFidelity,
	"scheme-fruit-salad": dynamic.VariantFruitSalad,
	"scheme-monochrome":  dynamic.VariantMonochrome,
	"scheme-neutral":     dynamic.VariantNeutral,
	"scheme-rainbow":     dynamic.VariantRainbow,
}

// SpecSupportsScheme reports whether the in-process generator can build the
// scheme. scheme-smart is chosen by matugen at run time and is not exposed in
// its output, so it stays on matugen's native palette.
func SpecSupportsScheme(schemeType string) bool {
	_, ok := schemeVariants[schemeType]
	return ok
}

// GenerateSpecColors builds the full Material color map for a seed under the
// given spec version and returns it in matugen's {"role": {"dark","light",
// "default": {"color"}}} shape. defaultMode picks which side "default" mirrors.
func GenerateSpecColors(seedHex, schemeType string, contrast float64, defaultMode ColorMode, version string) (string, error) {
	variant, ok := schemeVariants[schemeType]
	if !ok {
		return "", fmt.Errorf("scheme %q is not supported by the in-process generator", schemeType)
	}
	seed, err := NormalizeHexColor(seedHex)
	if err != nil {
		return "", err
	}
	specVersion := dynamic.Version2021
	if version == Spec2025 {
		specVersion = dynamic.Version2025
		// The 2025 spec has no reduced-contrast schemes.
		contrast = max(contrast, 0)
	}

	seedArgb, err := color.ARGBFromHex(seed)
	if err != nil {
		return "", err
	}
	// Colors.Map() in material/v3 v3.1.1 is backed by a field nothing fills,
	// so the roles are read off the scheme directly.
	generate := func(dark bool) map[string]string {
		scheme := dynamic.NewDynamicScheme(seedArgb.ToHct(), variant, contrast, dark, dynamic.PlatformPhone, specVersion)
		roles := scheme.ToColorMap()
		out := make(map[string]string, len(roles)+1)
		for name, role := range roles {
			if role == nil {
				continue
			}
			out[name] = strings.ToLower(role.GetArgb(scheme).HexRGB())
		}
		out["source_color"] = seed
		return out
	}

	dark := generate(true)
	light := generate(false)

	type shade struct {
		Color string `json:"color"`
	}
	type role struct {
		Dark    shade `json:"dark"`
		Light   shade `json:"light"`
		Default shade `json:"default"`
	}
	roles := make(map[string]role, len(dark))
	for name, darkHex := range dark {
		lightHex, ok := light[name]
		if !ok {
			continue
		}
		def := darkHex
		if defaultMode == ColorModeLight {
			def = lightHex
		}
		roles[name] = role{Dark: shade{darkHex}, Light: shade{lightHex}, Default: shade{def}}
	}

	data, err := json.Marshal(roles)
	if err != nil {
		return "", err
	}
	return string(data), nil
}
