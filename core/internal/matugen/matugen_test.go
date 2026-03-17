package matugen

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	mocks_utils "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/utils"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
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

	appendConfig(opts, cfgFile, []string{"sh"}, nil, "test.toml")

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

	appendConfig(opts, cfgFile, []string{"nonexistent-binary-12345"}, []string{}, "test.toml")

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

	appendConfig(opts, cfgFile, nil, []string{"app.zen_browser.zen"}, "test.toml")

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

	appendConfig(opts, cfgFile, []string{}, []string{"com.nonexistent.flatpak"}, "test.toml")

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

	appendConfig(opts, cfgFile, []string{"sh"}, []string{"app.zen_browser.zen"}, "test.toml")

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

	appendConfig(opts, cfgFile, []string{"nonexistent-binary-12345"}, []string{"com.nonexistent.flatpak"}, "test.toml")

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

	appendConfig(opts, cfgFile, nil, nil, "test.toml")

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

	appendConfig(opts, cfgFile, nil, nil, "nonexistent.toml")

	cfgFile.Close()
	output, err := os.ReadFile(outFile)
	if err != nil {
		t.Fatalf("failed to read output: %v", err)
	}

	if len(output) != 0 {
		t.Errorf("expected no config when file doesn't exist, got: %q", string(output))
	}
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
	assert.Contains(t, content, "output_path = '"+filepath.Join(opts.StateDir, "dms-colors.json")+"'")
	assert.NotContains(t, content, "[templates.gtk]")
	assert.False(t, strings.Contains(content, "output_path = 'CONFIG_DIR/"), "colors-only config should not emit app template outputs")
}
