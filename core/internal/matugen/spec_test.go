package matugen

import (
	"encoding/json"
	"image"
	"image/png"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"testing"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
	"github.com/stretchr/testify/require"
)

func TestNormalizeHexColor(t *testing.T) {
	for _, in := range []string{"#FF3D00", "ff3d00", " #ff3d00 "} {
		got, err := NormalizeHexColor(in)
		require.NoError(t, err, in)
		require.Equal(t, "#ff3d00", got, in)
	}
	for _, in := range []string{"", "#fff", "#ff3d00aa", "red", "#gg3d00", "#ff3d00; rm -rf"} {
		_, err := NormalizeHexColor(in)
		require.Error(t, err, in)
	}
}

func TestGenerateSpecColorsRejectsSmart(t *testing.T) {
	_, err := GenerateSpecColors("#1e88e5", "scheme-smart", 0, ColorModeDark, Spec2025)
	require.Error(t, err)
	require.False(t, SpecSupportsScheme("scheme-smart"))
	require.True(t, SpecSupportsScheme("scheme-vibrant"))
}

func TestGenerateSpecColors2025IsBolderThan2021(t *testing.T) {
	colors2021 := decodeSpecColors(t, "#ff3d00", "scheme-vibrant", Spec2021)
	colors2025 := decodeSpecColors(t, "#ff3d00", "scheme-vibrant", Spec2025)
	require.Equal(t, "#ffb4a2", colors2021["primary"].Dark.Color)
	require.Equal(t, "#ff7c5b", colors2025["primary"].Dark.Color)
	require.Equal(t, colors2025["primary"].Dark.Color, colors2025["primary"].Default.Color)
	require.Equal(t, "#ff3d00", colors2025["source_color"].Dark.Color)
}

func TestGenerateSpecColorsDefaultFollowsMode(t *testing.T) {
	colors := decodeSpecColorsMode(t, "#1e88e5", "scheme-tonal-spot", Spec2021, ColorModeLight)
	require.Equal(t, colors["primary"].Light.Color, colors["primary"].Default.Color)
	require.NotEqual(t, colors["primary"].Dark.Color, colors["primary"].Default.Color)
}

func TestPreviewSchemesSmartMatchesNativeHex(t *testing.T) {
	if !SupportsSmart() {
		t.Skip("matugen 4.2+ required")
	}
	for _, seed := range []string{"#ff3d00", "#1e88e5"} {
		out, err := runMatugenDryRun(&Options{Kind: "hex", Value: seed, Mode: ColorModeDark, MatugenType: "scheme-smart"})
		require.NoError(t, err)
		expected := SchemePreview{Dark: schemeColors(out, "dark"), Light: schemeColors(out, "light")}
		require.NotEmpty(t, expected.Dark.Primary)
		for _, spec := range []string{Spec2021, Spec2025} {
			t.Run(seed+"/"+spec, func(t *testing.T) {
				previews, err := PreviewSchemes(seed, 0, "", spec)
				require.NoError(t, err)
				require.Equal(t, expected, previews["scheme-smart"])
			})
		}
	}
}

// The Go port and matugen's Rust port round differently in the last bit, and
// matugen still uses the pre-2023 on_*_container tones, so exact parity is not
// expected. The accent and surface roles the shell builds everything from must
// agree to within two channel steps or the in-process path is not the same
// palette users see today.
func TestGenerateSpecColors2021MatchesMatugen(t *testing.T) {
	if _, err := exec.LookPath("matugen"); err != nil {
		t.Skip("matugen not installed")
	}
	for _, seed := range []string{"#1e88e5", "#ff3d00", "#8bc34a"} {
		out, err := exec.Command("matugen", "color", "hex", seed, "-t", "scheme-vibrant", "-m", "dark", "--json", "hex", "--dry-run", "-q").Output()
		require.NoError(t, err)
		var matugenOut struct {
			Colors map[string]specRole `json:"colors"`
		}
		require.NoError(t, json.Unmarshal(out, &matugenOut))

		ours := decodeSpecColors(t, seed, "scheme-vibrant", Spec2021)
		for name := range matugenOut.Colors {
			require.Contains(t, ours, name, "role %s missing from generator", name)
		}
		for _, name := range []string{"primary", "primary_container", "secondary", "tertiary", "surface", "surface_container", "on_surface"} {
			theirs, mine := matugenOut.Colors[name], ours[name]
			require.LessOrEqual(t, maxChannelDelta(t, theirs.Dark.Color, mine.Dark.Color), 2, "%s %s dark %s vs %s", seed, name, theirs.Dark.Color, mine.Dark.Color)
			require.LessOrEqual(t, maxChannelDelta(t, theirs.Light.Color, mine.Light.Color), 2, "%s %s light %s vs %s", seed, name, theirs.Light.Color, mine.Light.Color)
		}
	}
}

func maxChannelDelta(t *testing.T, a, b string) int {
	t.Helper()
	require.Len(t, a, 7)
	require.Len(t, b, 7)
	delta := 0
	for i := 1; i < 7; i += 2 {
		x, err := strconv.ParseInt(a[i:i+2], 16, 0)
		require.NoError(t, err)
		y, err := strconv.ParseInt(b[i:i+2], 16, 0)
		require.NoError(t, err)
		if d := int(x - y); d > delta {
			delta = d
		} else if -d > delta {
			delta = -d
		}
	}
	return delta
}

type specShade struct {
	Color string `json:"color"`
}

type specRole struct {
	Dark    specShade `json:"dark"`
	Light   specShade `json:"light"`
	Default specShade `json:"default"`
}

func decodeSpecColors(t *testing.T, seed, scheme, version string) map[string]specRole {
	return decodeSpecColorsMode(t, seed, scheme, version, ColorModeDark)
}

func decodeSpecColorsMode(t *testing.T, seed, scheme, version string, mode ColorMode) map[string]specRole {
	t.Helper()
	raw, err := GenerateSpecColors(seed, scheme, 0, mode, version)
	require.NoError(t, err)
	var roles map[string]specRole
	require.NoError(t, json.Unmarshal([]byte(raw), &roles))
	return roles
}

// Runs the real matugen against the repo's dank.json template, colors only,
// into a temp state dir: the shell must read back the seed and the 2025 primary
// from dms-colors.json.
func TestBuildOnceSeedColorAndSpec2025(t *testing.T) {
	if _, err := exec.LookPath("matugen"); err != nil {
		t.Skip("matugen not installed")
	}
	shellDir, err := filepath.Abs(filepath.Join("..", "..", "..", "quickshell"))
	require.NoError(t, err)
	if _, err := os.Stat(filepath.Join(shellDir, "matugen", "templates", "dank.json")); err != nil {
		t.Skip("quickshell dir not available")
	}
	wallpaper := filepath.Join(t.TempDir(), "wall.png")
	img := image.NewRGBA(image.Rect(0, 0, 8, 8))
	for i := range img.Pix {
		img.Pix[i] = 0x40
	}
	f, err := os.Create(wallpaper)
	require.NoError(t, err)
	require.NoError(t, png.Encode(f, img))
	require.NoError(t, f.Close())

	opts := &Options{
		StateDir:    t.TempDir(),
		ShellDir:    shellDir,
		ConfigDir:   t.TempDir(),
		Kind:        "image",
		Value:       wallpaper,
		Mode:        ColorModeDark,
		MatugenType: "scheme-vibrant",
		SeedColor:   "#FF3D00",
		Spec:        Spec2025,
		ColorsOnly:  true,
		AppChecker:  utils.DefaultAppChecker{},
	}
	changed, err := buildOnce(opts)
	require.NoError(t, err)
	require.True(t, changed)

	raw, err := os.ReadFile(opts.ColorsOutput())
	require.NoError(t, err)
	var out struct {
		Colors struct {
			Dark map[string]string `json:"dark"`
		} `json:"colors"`
	}
	require.NoError(t, json.Unmarshal(raw, &out))
	require.Equal(t, "#ff3d00", out.Colors.Dark["source_color"])
	require.Equal(t, "#ff7c5b", out.Colors.Dark["primary"])
}
