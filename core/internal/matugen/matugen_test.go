package matugen

import (
	"fmt"
	"image"
	stdcolor "image/color"
	"image/png"
	"math"
	"os"
	"path/filepath"
	"strings"
	"testing"

	mocks_utils "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/utils"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
	matcolor "github.com/Nadim147c/material/v3/color"
	"github.com/stretchr/testify/assert"
)

func TestAppendConfigBinaryExists(t *testing.T) {
	tempDir := t.TempDir()

	shellDir := filepath.Join(tempDir, "shell")
	configsDir := filepath.Join(shellDir, "matugen", "configs")
	if err := os.MkdirAll(configsDir, 0o755); err != nil {
		t.Fatalf("failed to create configs dir: %v", err)
	}

	testConfig := "test config content"
	configPath := filepath.Join(configsDir, "test.toml")
	if err := os.WriteFile(configPath, []byte(testConfig), 0o644); err != nil {
		t.Fatalf("failed to write config: %v", err)
	}

	outFile := filepath.Join(tempDir, "output.toml")
	cfgFile, err := os.Create(outFile)
	if err != nil {
		t.Fatalf("failed to create output file: %v", err)
	}
	defer cfgFile.Close()

	mockChecker := mocks_utils.NewMockAppChecker(t)
	mockChecker.EXPECT().AnyCommandExists("sh").Return(true)

	opts := &Options{ShellDir: shellDir, AppChecker: mockChecker}

	appendConfig(opts, cfgFile, []string{"sh"}, nil, nil, "test.toml")

	cfgFile.Close()
	output, err := os.ReadFile(outFile)
	if err != nil {
		t.Fatalf("failed to read output: %v", err)
	}

	if len(output) == 0 {
		t.Errorf("expected config to be written when binary exists")
	}
	if string(output) != testConfig+"\n" {
		t.Errorf("expected %q, got %q", testConfig+"\n", string(output))
	}
}

func TestAppendConfigBinaryDoesNotExist(t *testing.T) {
	tempDir := t.TempDir()

	shellDir := filepath.Join(tempDir, "shell")
	configsDir := filepath.Join(shellDir, "matugen", "configs")
	if err := os.MkdirAll(configsDir, 0o755); err != nil {
		t.Fatalf("failed to create configs dir: %v", err)
	}

	testConfig := "test config content"
	configPath := filepath.Join(configsDir, "test.toml")
	if err := os.WriteFile(configPath, []byte(testConfig), 0o644); err != nil {
		t.Fatalf("failed to write config: %v", err)
	}

	outFile := filepath.Join(tempDir, "output.toml")
	cfgFile, err := os.Create(outFile)
	if err != nil {
		t.Fatalf("failed to create output file: %v", err)
	}
	defer cfgFile.Close()

	mockChecker := mocks_utils.NewMockAppChecker(t)
	mockChecker.EXPECT().AnyCommandExists("nonexistent-binary-12345").Return(false)
	mockChecker.EXPECT().AnyFlatpakExists().Return(false)

	opts := &Options{ShellDir: shellDir, AppChecker: mockChecker}

	appendConfig(opts, cfgFile, []string{"nonexistent-binary-12345"}, []string{}, nil, "test.toml")

	cfgFile.Close()
	output, err := os.ReadFile(outFile)
	if err != nil {
		t.Fatalf("failed to read output: %v", err)
	}

	if len(output) != 0 {
		t.Errorf("expected no config when binary doesn't exist, got: %q", string(output))
	}
}

func TestAppendConfigFlatpakExists(t *testing.T) {
	tempDir := t.TempDir()

	shellDir := filepath.Join(tempDir, "shell")
	configsDir := filepath.Join(shellDir, "matugen", "configs")
	if err := os.MkdirAll(configsDir, 0o755); err != nil {
		t.Fatalf("failed to create configs dir: %v", err)
	}

	testConfig := "zen config content"
	configPath := filepath.Join(configsDir, "test.toml")
	if err := os.WriteFile(configPath, []byte(testConfig), 0o644); err != nil {
		t.Fatalf("failed to write config: %v", err)
	}

	outFile := filepath.Join(tempDir, "output.toml")
	cfgFile, err := os.Create(outFile)
	if err != nil {
		t.Fatalf("failed to create output file: %v", err)
	}
	defer cfgFile.Close()

	mockChecker := mocks_utils.NewMockAppChecker(t)
	mockChecker.EXPECT().AnyFlatpakExists("app.zen_browser.zen").Return(true)

	opts := &Options{ShellDir: shellDir, AppChecker: mockChecker}

	appendConfig(opts, cfgFile, nil, []string{"app.zen_browser.zen"}, nil, "test.toml")

	cfgFile.Close()
	output, err := os.ReadFile(outFile)
	if err != nil {
		t.Fatalf("failed to read output: %v", err)
	}

	if len(output) == 0 {
		t.Errorf("expected config to be written when flatpak exists")
	}
}

func TestAppendConfigFlatpakDoesNotExist(t *testing.T) {
	tempDir := t.TempDir()

	shellDir := filepath.Join(tempDir, "shell")
	configsDir := filepath.Join(shellDir, "matugen", "configs")
	if err := os.MkdirAll(configsDir, 0o755); err != nil {
		t.Fatalf("failed to create configs dir: %v", err)
	}

	testConfig := "test config content"
	configPath := filepath.Join(configsDir, "test.toml")
	if err := os.WriteFile(configPath, []byte(testConfig), 0o644); err != nil {
		t.Fatalf("failed to write config: %v", err)
	}

	outFile := filepath.Join(tempDir, "output.toml")
	cfgFile, err := os.Create(outFile)
	if err != nil {
		t.Fatalf("failed to create output file: %v", err)
	}
	defer cfgFile.Close()

	mockChecker := mocks_utils.NewMockAppChecker(t)
	mockChecker.EXPECT().AnyCommandExists().Return(false)
	mockChecker.EXPECT().AnyFlatpakExists("com.nonexistent.flatpak").Return(false)

	opts := &Options{ShellDir: shellDir, AppChecker: mockChecker}

	appendConfig(opts, cfgFile, []string{}, []string{"com.nonexistent.flatpak"}, nil, "test.toml")

	cfgFile.Close()
	output, err := os.ReadFile(outFile)
	if err != nil {
		t.Fatalf("failed to read output: %v", err)
	}

	if len(output) != 0 {
		t.Errorf("expected no config when flatpak doesn't exist, got: %q", string(output))
	}
}

func TestAppendConfigBothExist(t *testing.T) {
	tempDir := t.TempDir()

	shellDir := filepath.Join(tempDir, "shell")
	configsDir := filepath.Join(shellDir, "matugen", "configs")
	if err := os.MkdirAll(configsDir, 0o755); err != nil {
		t.Fatalf("failed to create configs dir: %v", err)
	}

	testConfig := "zen config content"
	configPath := filepath.Join(configsDir, "test.toml")
	if err := os.WriteFile(configPath, []byte(testConfig), 0o644); err != nil {
		t.Fatalf("failed to write config: %v", err)
	}

	outFile := filepath.Join(tempDir, "output.toml")
	cfgFile, err := os.Create(outFile)
	if err != nil {
		t.Fatalf("failed to create output file: %v", err)
	}
	defer cfgFile.Close()

	mockChecker := mocks_utils.NewMockAppChecker(t)
	mockChecker.EXPECT().AnyCommandExists("sh").Return(true)

	opts := &Options{ShellDir: shellDir, AppChecker: mockChecker}

	appendConfig(opts, cfgFile, []string{"sh"}, []string{"app.zen_browser.zen"}, nil, "test.toml")

	cfgFile.Close()
	output, err := os.ReadFile(outFile)
	if err != nil {
		t.Fatalf("failed to read output: %v", err)
	}

	if len(output) == 0 {
		t.Errorf("expected config to be written when both binary and flatpak exist")
	}
}

func TestAppendConfigNeitherExists(t *testing.T) {
	tempDir := t.TempDir()

	shellDir := filepath.Join(tempDir, "shell")
	configsDir := filepath.Join(shellDir, "matugen", "configs")
	if err := os.MkdirAll(configsDir, 0o755); err != nil {
		t.Fatalf("failed to create configs dir: %v", err)
	}

	testConfig := "test config content"
	configPath := filepath.Join(configsDir, "test.toml")
	if err := os.WriteFile(configPath, []byte(testConfig), 0o644); err != nil {
		t.Fatalf("failed to write config: %v", err)
	}

	outFile := filepath.Join(tempDir, "output.toml")
	cfgFile, err := os.Create(outFile)
	if err != nil {
		t.Fatalf("failed to create output file: %v", err)
	}
	defer cfgFile.Close()

	mockChecker := mocks_utils.NewMockAppChecker(t)
	mockChecker.EXPECT().AnyCommandExists("nonexistent-binary-12345").Return(false)
	mockChecker.EXPECT().AnyFlatpakExists("com.nonexistent.flatpak").Return(false)

	opts := &Options{ShellDir: shellDir, AppChecker: mockChecker}

	appendConfig(opts, cfgFile, []string{"nonexistent-binary-12345"}, []string{"com.nonexistent.flatpak"}, nil, "test.toml")

	cfgFile.Close()
	output, err := os.ReadFile(outFile)
	if err != nil {
		t.Fatalf("failed to read output: %v", err)
	}

	if len(output) != 0 {
		t.Errorf("expected no config when neither exists, got: %q", string(output))
	}
}

func TestAppendConfigNoChecks(t *testing.T) {
	tempDir := t.TempDir()

	shellDir := filepath.Join(tempDir, "shell")
	configsDir := filepath.Join(shellDir, "matugen", "configs")
	if err := os.MkdirAll(configsDir, 0o755); err != nil {
		t.Fatalf("failed to create configs dir: %v", err)
	}

	testConfig := "always include"
	configPath := filepath.Join(configsDir, "test.toml")
	if err := os.WriteFile(configPath, []byte(testConfig), 0o644); err != nil {
		t.Fatalf("failed to write config: %v", err)
	}

	outFile := filepath.Join(tempDir, "output.toml")
	cfgFile, err := os.Create(outFile)
	if err != nil {
		t.Fatalf("failed to create output file: %v", err)
	}
	defer cfgFile.Close()

	opts := &Options{ShellDir: shellDir}

	appendConfig(opts, cfgFile, nil, nil, nil, "test.toml")

	cfgFile.Close()
	output, err := os.ReadFile(outFile)
	if err != nil {
		t.Fatalf("failed to read output: %v", err)
	}

	if len(output) == 0 {
		t.Errorf("expected config to be written when no checks specified")
	}
}

func TestAppendConfigFileDoesNotExist(t *testing.T) {
	tempDir := t.TempDir()

	shellDir := filepath.Join(tempDir, "shell")
	configsDir := filepath.Join(shellDir, "matugen", "configs")
	if err := os.MkdirAll(configsDir, 0o755); err != nil {
		t.Fatalf("failed to create configs dir: %v", err)
	}

	outFile := filepath.Join(tempDir, "output.toml")
	cfgFile, err := os.Create(outFile)
	if err != nil {
		t.Fatalf("failed to create output file: %v", err)
	}
	defer cfgFile.Close()

	opts := &Options{ShellDir: shellDir}

	appendConfig(opts, cfgFile, nil, nil, nil, "nonexistent.toml")

	cfgFile.Close()
	output, err := os.ReadFile(outFile)
	if err != nil {
		t.Fatalf("failed to read output: %v", err)
	}

	if len(output) != 0 {
		t.Errorf("expected no config when file doesn't exist, got: %q", string(output))
	}
}

func TestSourceSelectionArgs(t *testing.T) {
	tests := []struct {
		name           string
		sourceMode     string
		supportsPrefer bool
		expected       []string
	}{
		{"darkness", "darkness", true, []string{"--prefer", "darkness"}},
		{"lightness", "lightness", true, []string{"--prefer", "lightness"}},
		{"saturation", "saturation", true, []string{"--prefer", "saturation"}},
		{"less-saturation", "less-saturation", true, []string{"--prefer", "less-saturation"}},
		{"value", "value", true, []string{"--prefer", "value"}},
		{"empty falls back to dominant", "", true, []string{"--source-color-index", "0"}},
		{"dominant falls back", "dominant", true, []string{"--source-color-index", "0"}},
		{"colorful falls back (resolved to hex before this is reached)", "colorful", true, []string{"--source-color-index", "0"}},
		{"typo falls back", "bogus", true, []string{"--source-color-index", "0"}},
		{"wrong case is not allowlisted", "DARKNESS", true, []string{"--source-color-index", "0"}},
		{"closest-to-fallback is deliberately excluded", "closest-to-fallback", true, []string{"--source-color-index", "0"}},
		{"injection-shaped value cannot escape the allowlist", "value; --exec touch /tmp/pwned", true, []string{"--source-color-index", "0"}},
		// matugen 4.0.x has --source-color-index but not --prefer, and aborts on
		// an unknown argument. Every prefer mode must degrade, not fail.
		{"4.0.x: darkness degrades", "darkness", false, []string{"--source-color-index", "0"}},
		{"4.0.x: lightness degrades", "lightness", false, []string{"--source-color-index", "0"}},
		{"4.0.x: saturation degrades", "saturation", false, []string{"--source-color-index", "0"}},
		{"4.0.x: less-saturation degrades", "less-saturation", false, []string{"--source-color-index", "0"}},
		{"4.0.x: value degrades", "value", false, []string{"--source-color-index", "0"}},
		{"4.0.x: colorful is unaffected", "colorful", false, []string{"--source-color-index", "0"}},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			result := sourceSelectionArgs(tc.sourceMode, tc.supportsPrefer)
			assert.Equal(t, tc.expected, result)
			if !tc.supportsPrefer {
				assert.NotContains(t, result, "--prefer", "matugen 4.0.x must never see --prefer")
			}
		})
	}
}

func TestBuildMatugenArgsSourceModes(t *testing.T) {
	baseArgs := []string{"-c", "/tmp/merged.toml", "-t", "scheme-tonal-spot"}
	modes := []string{"dominant", "colorful", "darkness", "lightness", "saturation", "less-saturation", "value"}

	for _, mode := range modes {
		t.Run("v4/"+mode, func(t *testing.T) {
			args := buildMatugenArgs(baseArgs, matugenFlags{isV4: true, supportsPrefer: true}, mode)
			expected := append(append([]string{}, baseArgs...), sourceSelectionArgs(mode, true)...)
			assert.Equal(t, expected, args)
		})

		t.Run("v4.0/"+mode, func(t *testing.T) {
			// matugen 4.0.x: --source-color-index exists, --prefer does not.
			args := buildMatugenArgs(baseArgs, matugenFlags{isV4: true, supportsPrefer: false}, mode)
			expected := append(append([]string{}, baseArgs...), "--source-color-index", "0")
			assert.Equal(t, expected, args)
			assert.NotContains(t, args, "--prefer")
		})

		t.Run("v3/"+mode, func(t *testing.T) {
			// matugen 3 has neither --prefer nor --source-color-index. Adding
			// either would break every user still on it, so under isV4=false
			// no source-selection args may appear for any mode.
			args := buildMatugenArgs(baseArgs, matugenFlags{isV4: false}, mode)
			assert.Equal(t, baseArgs, args)
			assert.NotContains(t, args, "--prefer")
			assert.NotContains(t, args, "--source-color-index")
		})
	}
}

func TestBuildMatugenArgsDefaultPreservesExistingBehavior(t *testing.T) {
	baseArgs := []string{"-c", "/tmp/merged.toml", "-t", "scheme-tonal-spot"}

	args := buildMatugenArgs(baseArgs, matugenFlags{isV4: true, supportsPrefer: true}, "")

	expected := append(append([]string{}, baseArgs...), "--source-color-index", "0")
	assert.Equal(t, expected, args, "empty source mode must produce byte-identical args to pre-feature behavior")
}

func TestBuildImportData(t *testing.T) {
	const dank16 = `{"color0":"#000000"}`

	assert.Equal(t, `{"dank16": {"color0":"#000000"}}`, buildImportData(dank16, ""),
		"no image must produce byte-identical import data to pre-feature behavior")
	assert.Equal(t, `{"dank16": {"color0":"#000000"}, "image": "/home/u/My Wallpaper.png"}`,
		buildImportData(dank16, "/home/u/My Wallpaper.png"))
	assert.Equal(t, `{"dank16": {"color0":"#000000"}, "image": "/home/u/a\"b\\c.png"}`,
		buildImportData(dank16, `/home/u/a"b\c.png`), "paths must be escaped, not interpolated raw")
}

// writeTestPNG encodes img as a PNG at path, failing the test on any error.
func writeTestPNG(t *testing.T, path string, img image.Image) {
	t.Helper()
	f, err := os.Create(path)
	if err != nil {
		t.Fatalf("failed to create test image: %v", err)
	}
	defer f.Close()
	if err := png.Encode(f, img); err != nil {
		t.Fatalf("failed to encode test image: %v", err)
	}
}

func TestExtractSourceColorPrefersVividOverDull(t *testing.T) {
	dir := t.TempDir()

	const w, h = 50, 50
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	dull := stdcolor.RGBA{R: 190, G: 200, B: 210, A: 255} // pale grey-blue, low chroma
	vivid := stdcolor.RGBA{R: 255, G: 140, B: 0, A: 255}  // strong warm orange

	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			img.Set(x, y, dull)
		}
	}
	// ~19% of the image, in a corner, well clear of 80/20.
	const vividSize = 22
	for y := 0; y < vividSize; y++ {
		for x := 0; x < vividSize; x++ {
			img.Set(x, y, vivid)
		}
	}

	path := filepath.Join(dir, "mixed.png")
	writeTestPNG(t, path, img)

	seed, err := ExtractSourceColor(path)
	if err != nil {
		t.Fatalf("ExtractSourceColor returned an error: %v", err)
	}

	var r, g, b uint8
	if _, err := fmt.Sscanf(seed, "#%02x%02x%02x", &r, &g, &b); err != nil {
		t.Fatalf("seed %q is not a #RRGGBB hex string: %v", seed, err)
	}
	hct := matcolor.NewARGB(255, r, g, b).ToHct()

	dullHue := matcolor.NewARGB(255, dull.R, dull.G, dull.B).ToHct().Hue

	// The failure this feature targets is landing on the large dull region.
	// Assert the hue family, not an exact value: it must be nowhere near the
	// dull blue-grey (~240) and it must sit in the warm orange/yellow band
	// the vivid region occupies (~58, with generous tolerance either side).
	assert.InDelta(t, 58.0, hct.Hue, 40.0, "expected the seed's hue to be in the vivid orange family, got hue=%.2f from %s", hct.Hue, seed)
	assert.Greater(t, hueDistance(hct.Hue, dullHue), 60.0, "seed hue %.2f should not be in the dull region's hue family (%.2f)", hct.Hue, dullHue)
}

// hueDistance is the shortest angular distance between two hues on a 360
// degree wheel.
func hueDistance(a, b float64) float64 {
	d := math.Abs(a - b)
	if d > 180 {
		d = 360 - d
	}
	return d
}

func TestExtractSourceColorDeterministic(t *testing.T) {
	dir := t.TempDir()

	const w, h = 50, 50
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			if x < 22 && y < 22 {
				img.Set(x, y, stdcolor.RGBA{R: 255, G: 140, B: 0, A: 255})
			} else {
				img.Set(x, y, stdcolor.RGBA{R: 190, G: 200, B: 210, A: 255})
			}
		}
	}
	path := filepath.Join(dir, "deterministic.png")
	writeTestPNG(t, path, img)

	first, err := ExtractSourceColor(path)
	if err != nil {
		t.Fatalf("ExtractSourceColor returned an error: %v", err)
	}

	for i := 0; i < 3; i++ {
		next, err := ExtractSourceColor(path)
		if err != nil {
			t.Fatalf("ExtractSourceColor returned an error on repeat run %d: %v", i, err)
		}
		assert.Equal(t, first, next, "the same wallpaper must yield a byte-identical seed every run")
	}
}

func TestExtractSourceColorNonexistentPath(t *testing.T) {
	path := filepath.Join(t.TempDir(), "does-not-exist.png")

	seed, err := ExtractSourceColor(path)

	assert.Error(t, err)
	assert.Empty(t, seed)
	assert.Contains(t, err.Error(), "open")
}

func TestExtractSourceColorNonImageFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "not-an-image.jpg")
	if err := os.WriteFile(path, []byte("this is plain text, not an image"), 0o644); err != nil {
		t.Fatalf("failed to write test file: %v", err)
	}

	seed, err := ExtractSourceColor(path)

	assert.Error(t, err)
	assert.Empty(t, seed)
	assert.Contains(t, err.Error(), "decode")
}

func TestExtractSourceColorFullyTransparentImage(t *testing.T) {
	dir := t.TempDir()
	// image.NewRGBA zero-values to fully transparent black.
	img := image.NewRGBA(image.Rect(0, 0, 8, 8))
	path := filepath.Join(dir, "transparent.png")
	writeTestPNG(t, path, img)

	seed, err := ExtractSourceColor(path)

	assert.Error(t, err)
	assert.Empty(t, seed)
	assert.Contains(t, err.Error(), "no opaque pixels")
}

func TestExtractSourceColorAllBlackImage(t *testing.T) {
	dir := t.TempDir()
	img := image.NewRGBA(image.Rect(0, 0, 8, 8))
	for y := 0; y < 8; y++ {
		for x := 0; x < 8; x++ {
			img.Set(x, y, stdcolor.RGBA{R: 0, G: 0, B: 0, A: 255})
		}
	}
	path := filepath.Join(dir, "black.png")
	writeTestPNG(t, path, img)

	seed, err := ExtractSourceColor(path)

	assert.Error(t, err)
	assert.Empty(t, seed)
	assert.Contains(t, err.Error(), "no usable color")
}

func TestExtractSourceColorOnePixelDoesNotPanic(t *testing.T) {
	dir := t.TempDir()
	img := image.NewRGBA(image.Rect(0, 0, 1, 1))
	img.Set(0, 0, stdcolor.RGBA{R: 255, G: 0, B: 0, A: 255})
	path := filepath.Join(dir, "one-pixel.png")
	writeTestPNG(t, path, img)

	assert.NotPanics(t, func() {
		_, _ = ExtractSourceColor(path)
	})
}

func TestSubstituteVars(t *testing.T) {
	configDir := utils.XDGConfigHome()
	dataDir := utils.XDGDataHome()
	cacheDir := utils.XDGCacheHome()

	tests := []struct {
		name     string
		input    string
		shellDir string
		expected string
	}{
		{
			name:     "substitutes SHELL_DIR",
			input:    "input_path = 'SHELL_DIR/matugen/templates/foo.conf'",
			shellDir: "/home/user/shell",
			expected: "input_path = '/home/user/shell/matugen/templates/foo.conf'",
		},
		{
			name:     "substitutes CONFIG_DIR",
			input:    "output_path = 'CONFIG_DIR/kitty/theme.conf'",
			shellDir: "/home/user/shell",
			expected: "output_path = '" + configDir + "/kitty/theme.conf'",
		},
		{
			name:     "substitutes DATA_DIR",
			input:    "output_path = 'DATA_DIR/color-schemes/theme.colors'",
			shellDir: "/home/user/shell",
			expected: "output_path = '" + dataDir + "/color-schemes/theme.colors'",
		},
		{
			name:     "substitutes CACHE_DIR",
			input:    "output_path = 'CACHE_DIR/wal/colors.json'",
			shellDir: "/home/user/shell",
			expected: "output_path = '" + cacheDir + "/wal/colors.json'",
		},
		{
			name:     "substitutes all dir types",
			input:    "'SHELL_DIR/a' 'CONFIG_DIR/b' 'DATA_DIR/c' 'CACHE_DIR/d'",
			shellDir: "/shell",
			expected: "'/shell/a' '" + configDir + "/b' '" + dataDir + "/c' '" + cacheDir + "/d'",
		},
		{
			name:     "no substitution when no placeholders",
			input:    "input_path = '/absolute/path/foo.conf'",
			shellDir: "/home/user/shell",
			expected: "input_path = '/absolute/path/foo.conf'",
		},
		{
			name:     "multiple SHELL_DIR occurrences",
			input:    "'SHELL_DIR/a' and 'SHELL_DIR/b'",
			shellDir: "/shell",
			expected: "'/shell/a' and '/shell/b'",
		},
		{
			name:     "only substitutes quoted paths",
			input:    "SHELL_DIR/unquoted and 'SHELL_DIR/quoted'",
			shellDir: "/shell",
			expected: "SHELL_DIR/unquoted and '/shell/quoted'",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			result := substituteVars(tc.input, tc.shellDir)
			assert.Equal(t, tc.expected, result)
		})
	}
}

func TestBuildMergedConfigColorsOnly(t *testing.T) {
	tempDir := t.TempDir()

	shellDir := filepath.Join(tempDir, "shell")
	configsDir := filepath.Join(shellDir, "matugen", "configs")
	if err := os.MkdirAll(configsDir, 0o755); err != nil {
		t.Fatalf("failed to create configs dir: %v", err)
	}

	baseConfig := "[config]\ncustom_keywords = []\n"
	if err := os.WriteFile(filepath.Join(configsDir, "base.toml"), []byte(baseConfig), 0o644); err != nil {
		t.Fatalf("failed to write base config: %v", err)
	}

	cfgFile, err := os.CreateTemp(tempDir, "merged-*.toml")
	if err != nil {
		t.Fatalf("failed to create temp config: %v", err)
	}
	defer os.Remove(cfgFile.Name())
	defer cfgFile.Close()

	opts := &Options{
		ShellDir:   shellDir,
		ConfigDir:  filepath.Join(tempDir, "config"),
		StateDir:   filepath.Join(tempDir, "state"),
		ColorsOnly: true,
	}

	if err := buildMergedConfig(opts, cfgFile, filepath.Join(tempDir, "templates")); err != nil {
		t.Fatalf("buildMergedConfig failed: %v", err)
	}

	if err := cfgFile.Close(); err != nil {
		t.Fatalf("failed to close merged config: %v", err)
	}

	output, err := os.ReadFile(cfgFile.Name())
	if err != nil {
		t.Fatalf("failed to read merged config: %v", err)
	}

	content := string(output)
	assert.Contains(t, content, "[templates.dank]")
	assert.Contains(t, content, "output_path = '"+opts.colorsStaging()+"'")
	assert.NotContains(t, content, "[templates.gtk]")
	assert.False(t, strings.Contains(content, "output_path = 'CONFIG_DIR/"), "colors-only config should not emit app template outputs")
}

func TestBuildMergedConfigSkipsMangowcWithoutActiveSession(t *testing.T) {
	t.Setenv("MANGO_INSTANCE_SIGNATURE", "")

	tempDir := t.TempDir()
	shellDir := filepath.Join(tempDir, "shell")
	configsDir := filepath.Join(shellDir, "matugen", "configs")
	if err := os.MkdirAll(configsDir, 0o755); err != nil {
		t.Fatalf("failed to create configs dir: %v", err)
	}

	if err := os.WriteFile(filepath.Join(configsDir, "base.toml"), []byte("[config]\n"), 0o644); err != nil {
		t.Fatalf("failed to write base config: %v", err)
	}
	mangowcConfig := "[templates.dmsmango]\ninput_path = 'in'\noutput_path = 'out'\n"
	if err := os.WriteFile(filepath.Join(configsDir, "mangowc.toml"), []byte(mangowcConfig), 0o644); err != nil {
		t.Fatalf("failed to write mangowc config: %v", err)
	}

	cfgFile, err := os.CreateTemp(tempDir, "merged-*.toml")
	if err != nil {
		t.Fatalf("failed to create temp config: %v", err)
	}
	defer os.Remove(cfgFile.Name())
	defer cfgFile.Close()

	opts := &Options{
		ShellDir:      shellDir,
		ConfigDir:     filepath.Join(tempDir, "config"),
		StateDir:      filepath.Join(tempDir, "state"),
		SkipTemplates: "gtk,niri,hyprland,qt5ct,qt6ct,firefox,pywalfox,zenbrowser,vesktop,vencord,equibop,ghostty,kitty,foot,alacritty,wezterm,nvim,dgop,kcolorscheme,vscode,emacs,zed",
	}

	if err := buildMergedConfig(opts, cfgFile, filepath.Join(tempDir, "templates")); err != nil {
		t.Fatalf("buildMergedConfig failed: %v", err)
	}
	if err := cfgFile.Close(); err != nil {
		t.Fatalf("failed to close merged config: %v", err)
	}

	output, err := os.ReadFile(cfgFile.Name())
	if err != nil {
		t.Fatalf("failed to read merged config: %v", err)
	}
	assert.NotContains(t, string(output), "[templates.dmsmango]")
}

func TestAppendConfigConfigDirExists(t *testing.T) {
	tempDir := t.TempDir()

	shellDir := filepath.Join(tempDir, "shell")
	configsDir := filepath.Join(shellDir, "matugen", "configs")
	if err := os.MkdirAll(configsDir, 0o755); err != nil {
		t.Fatalf("failed to create configs dir: %v", err)
	}

	testConfig := "vencord config content"
	if err := os.WriteFile(filepath.Join(configsDir, "vencord.toml"), []byte(testConfig), 0o644); err != nil {
		t.Fatalf("failed to write config: %v", err)
	}

	configHome := filepath.Join(tempDir, "config")
	if err := os.MkdirAll(filepath.Join(configHome, "Vencord"), 0o755); err != nil {
		t.Fatalf("failed to create Vencord config dir: %v", err)
	}
	t.Setenv("XDG_CONFIG_HOME", configHome)

	outFile := filepath.Join(tempDir, "output.toml")
	cfgFile, err := os.Create(outFile)
	if err != nil {
		t.Fatalf("failed to create output file: %v", err)
	}
	defer cfgFile.Close()

	mockChecker := mocks_utils.NewMockAppChecker(t)
	mockChecker.EXPECT().AnyCommandExists("nonexistent-binary-12345").Return(false)
	mockChecker.EXPECT().AnyFlatpakExists("com.nonexistent.flatpak").Return(false)

	opts := &Options{ShellDir: shellDir, AppChecker: mockChecker}

	appendConfig(opts, cfgFile, []string{"nonexistent-binary-12345"}, []string{"com.nonexistent.flatpak"}, []string{"Vencord"}, "vencord.toml")

	cfgFile.Close()
	output, err := os.ReadFile(outFile)
	if err != nil {
		t.Fatalf("failed to read output: %v", err)
	}

	assert.Equal(t, testConfig+"\n", string(output))
}

func TestAppendConfigConfigDirDoesNotExist(t *testing.T) {
	tempDir := t.TempDir()

	shellDir := filepath.Join(tempDir, "shell")
	configsDir := filepath.Join(shellDir, "matugen", "configs")
	if err := os.MkdirAll(configsDir, 0o755); err != nil {
		t.Fatalf("failed to create configs dir: %v", err)
	}

	if err := os.WriteFile(filepath.Join(configsDir, "vencord.toml"), []byte("vencord config content"), 0o644); err != nil {
		t.Fatalf("failed to write config: %v", err)
	}

	configHome := filepath.Join(tempDir, "config")
	if err := os.MkdirAll(configHome, 0o755); err != nil {
		t.Fatalf("failed to create config home: %v", err)
	}
	t.Setenv("XDG_CONFIG_HOME", configHome)

	outFile := filepath.Join(tempDir, "output.toml")
	cfgFile, err := os.Create(outFile)
	if err != nil {
		t.Fatalf("failed to create output file: %v", err)
	}
	defer cfgFile.Close()

	mockChecker := mocks_utils.NewMockAppChecker(t)
	mockChecker.EXPECT().AnyCommandExists("nonexistent-binary-12345").Return(false)
	mockChecker.EXPECT().AnyFlatpakExists("com.nonexistent.flatpak").Return(false)

	opts := &Options{ShellDir: shellDir, AppChecker: mockChecker}

	appendConfig(opts, cfgFile, []string{"nonexistent-binary-12345"}, []string{"com.nonexistent.flatpak"}, []string{"Vencord"}, "vencord.toml")

	cfgFile.Close()
	output, err := os.ReadFile(outFile)
	if err != nil {
		t.Fatalf("failed to read output: %v", err)
	}

	assert.Empty(t, string(output))
}
