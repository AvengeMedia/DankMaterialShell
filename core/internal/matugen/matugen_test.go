package matugen

import (
	"os"
	"path/filepath"
	"testing"
)

func TestAppendConfigBinaryExists(t *testing.T) {
	tempDir := t.TempDir()

	shellDir := filepath.Join(tempDir, "shell")
	configsDir := filepath.Join(shellDir, "matugen", "configs")
	if err := os.MkdirAll(configsDir, 0755); err != nil {
		t.Fatalf("failed to create configs dir: %v", err)
	}

	testConfig := "test config content"
	configPath := filepath.Join(configsDir, "test.toml")
	if err := os.WriteFile(configPath, []byte(testConfig), 0644); err != nil {
		t.Fatalf("failed to write config: %v", err)
	}

	outFile := filepath.Join(tempDir, "output.toml")
	cfgFile, err := os.Create(outFile)
	if err != nil {
		t.Fatalf("failed to create output file: %v", err)
	}
	defer cfgFile.Close()

	opts := &Options{ShellDir: shellDir}

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
	if err := os.MkdirAll(configsDir, 0755); err != nil {
		t.Fatalf("failed to create configs dir: %v", err)
	}

	testConfig := "test config content"
	configPath := filepath.Join(configsDir, "test.toml")
	if err := os.WriteFile(configPath, []byte(testConfig), 0644); err != nil {
		t.Fatalf("failed to write config: %v", err)
	}

	outFile := filepath.Join(tempDir, "output.toml")
	cfgFile, err := os.Create(outFile)
	if err != nil {
		t.Fatalf("failed to create output file: %v", err)
	}
	defer cfgFile.Close()

	opts := &Options{ShellDir: shellDir}

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
	if err := os.MkdirAll(configsDir, 0755); err != nil {
		t.Fatalf("failed to create configs dir: %v", err)
	}

	testConfig := "zen config content"
	configPath := filepath.Join(configsDir, "test.toml")
	if err := os.WriteFile(configPath, []byte(testConfig), 0644); err != nil {
		t.Fatalf("failed to write config: %v", err)
	}

	outFile := filepath.Join(tempDir, "output.toml")
	cfgFile, err := os.Create(outFile)
	if err != nil {
		t.Fatalf("failed to create output file: %v", err)
	}
	defer cfgFile.Close()

	opts := &Options{ShellDir: shellDir}

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
	if err := os.MkdirAll(configsDir, 0755); err != nil {
		t.Fatalf("failed to create configs dir: %v", err)
	}

	testConfig := "test config content"
	configPath := filepath.Join(configsDir, "test.toml")
	if err := os.WriteFile(configPath, []byte(testConfig), 0644); err != nil {
		t.Fatalf("failed to write config: %v", err)
	}

	outFile := filepath.Join(tempDir, "output.toml")
	cfgFile, err := os.Create(outFile)
	if err != nil {
		t.Fatalf("failed to create output file: %v", err)
	}
	defer cfgFile.Close()

	opts := &Options{ShellDir: shellDir}

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
	if err := os.MkdirAll(configsDir, 0755); err != nil {
		t.Fatalf("failed to create configs dir: %v", err)
	}

	testConfig := "zen config content"
	configPath := filepath.Join(configsDir, "test.toml")
	if err := os.WriteFile(configPath, []byte(testConfig), 0644); err != nil {
		t.Fatalf("failed to write config: %v", err)
	}

	outFile := filepath.Join(tempDir, "output.toml")
	cfgFile, err := os.Create(outFile)
	if err != nil {
		t.Fatalf("failed to create output file: %v", err)
	}
	defer cfgFile.Close()

	opts := &Options{ShellDir: shellDir}

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
	if err := os.MkdirAll(configsDir, 0755); err != nil {
		t.Fatalf("failed to create configs dir: %v", err)
	}

	testConfig := "test config content"
	configPath := filepath.Join(configsDir, "test.toml")
	if err := os.WriteFile(configPath, []byte(testConfig), 0644); err != nil {
		t.Fatalf("failed to write config: %v", err)
	}

	outFile := filepath.Join(tempDir, "output.toml")
	cfgFile, err := os.Create(outFile)
	if err != nil {
		t.Fatalf("failed to create output file: %v", err)
	}
	defer cfgFile.Close()

	opts := &Options{ShellDir: shellDir}

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
	if err := os.MkdirAll(configsDir, 0755); err != nil {
		t.Fatalf("failed to create configs dir: %v", err)
	}

	testConfig := "always include"
	configPath := filepath.Join(configsDir, "test.toml")
	if err := os.WriteFile(configPath, []byte(testConfig), 0644); err != nil {
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
	if err := os.MkdirAll(configsDir, 0755); err != nil {
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
