package utils

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestFlatpakInPathUnavailable(t *testing.T) {
	tempDir := t.TempDir()
	t.Setenv("PATH", tempDir)

	result := FlatpakInPath()
	if result {
		t.Errorf("expected false when flatpak not in PATH, got true")
	}
}

func TestFlatpakExistsNoFlatpak(t *testing.T) {
	tempDir := t.TempDir()
	t.Setenv("PATH", tempDir)

	result := FlatpakExists("any.package.name")
	if result {
		t.Errorf("expected false when flatpak not in PATH, got true")
	}
}

func TestFlatpakSearchBySubstringNoFlatpak(t *testing.T) {
	tempDir := t.TempDir()
	t.Setenv("PATH", tempDir)

	result := FlatpakSearchBySubstring("test")
	if result {
		t.Errorf("expected false when flatpak not in PATH, got true")
	}
}

func TestFlatpakInstallationDirNoFlatpak(t *testing.T) {
	tempDir := t.TempDir()
	t.Setenv("PATH", tempDir)

	_, err := FlatpakInstallationDir("any.package.name")
	if err == nil {
		t.Errorf("expected error when flatpak not in PATH")
	}
	if err != nil && !strings.Contains(err.Error(), "not found in PATH") {
		t.Errorf("expected 'not found in PATH' error, got: %v", err)
	}
}

func TestFlatpakExistsCommandFailure(t *testing.T) {
	if !FlatpakInPath() {
		t.Skip("flatpak not in PATH")
	}

	// Mock a failing flatpak command through PATH interception
	tempDir := t.TempDir()
	fakeFlatpak := filepath.Join(tempDir, "flatpak")

	script := "#!/bin/sh\nexit 1\n"
	err := os.WriteFile(fakeFlatpak, []byte(script), 0o755)
	if err != nil {
		t.Fatalf("failed to create fake flatpak: %v", err)
	}

	originalPath := os.Getenv("PATH")
	t.Setenv("PATH", tempDir+":"+originalPath)

	result := FlatpakExists("test.package")
	if result {
		t.Errorf("expected false when flatpak command fails, got true")
	}
}

func TestFlatpakSearchBySubstringCommandFailure(t *testing.T) {
	if !FlatpakInPath() {
		t.Skip("flatpak not in PATH")
	}

	// Mock a failing flatpak command through PATH interception
	tempDir := t.TempDir()
	fakeFlatpak := filepath.Join(tempDir, "flatpak")

	script := "#!/bin/sh\nexit 1\n"
	err := os.WriteFile(fakeFlatpak, []byte(script), 0o755)
	if err != nil {
		t.Fatalf("failed to create fake flatpak: %v", err)
	}

	originalPath := os.Getenv("PATH")
	t.Setenv("PATH", tempDir+":"+originalPath)

	result := FlatpakSearchBySubstring("test")
	if result {
		t.Errorf("expected false when flatpak command fails, got true")
	}
}

func TestFlatpakInstallationDirCommandFailure(t *testing.T) {
	if !FlatpakInPath() {
		t.Skip("flatpak not in PATH")
	}

	// Mock a failing flatpak command through PATH interception
	tempDir := t.TempDir()
	fakeFlatpak := filepath.Join(tempDir, "flatpak")

	script := "#!/bin/sh\nexit 1\n"
	err := os.WriteFile(fakeFlatpak, []byte(script), 0o755)
	if err != nil {
		t.Fatalf("failed to create fake flatpak: %v", err)
	}

	originalPath := os.Getenv("PATH")
	t.Setenv("PATH", tempDir+":"+originalPath)

	_, err = FlatpakInstallationDir("test.package")
	if err == nil {
		t.Errorf("expected error when flatpak command fails")
	}
	if err != nil && !strings.Contains(err.Error(), "not installed") {
		t.Errorf("expected 'not installed' error, got: %v", err)
	}
}

func TestAnyFlatpakExistsSomeExist(t *testing.T) {
	tempDir := t.TempDir()
	fakeFlatpak := filepath.Join(tempDir, "flatpak")

	// Script that succeeds only for "app.exists.test"
	script := `#!/bin/sh
if [ "$1" = "info" ] && [ "$2" = "app.exists.test" ]; then
  exit 0
fi
exit 1
`
	err := os.WriteFile(fakeFlatpak, []byte(script), 0o755)
	if err != nil {
		t.Fatalf("failed to create fake flatpak: %v", err)
	}

	originalPath := os.Getenv("PATH")
	t.Setenv("PATH", tempDir+":"+originalPath)

	result := AnyFlatpakExists("com.nonexistent.flatpak", "app.exists.test", "com.another.nonexistent")
	if !result {
		t.Errorf("expected true when at least one flatpak exists")
	}
}

func TestAnyFlatpakExistsNoneExist(t *testing.T) {
	tempDir := t.TempDir()
	fakeFlatpak := filepath.Join(tempDir, "flatpak")

	script := "#!/bin/sh\nexit 1\n"
	err := os.WriteFile(fakeFlatpak, []byte(script), 0o755)
	if err != nil {
		t.Fatalf("failed to create fake flatpak: %v", err)
	}

	originalPath := os.Getenv("PATH")
	t.Setenv("PATH", tempDir+":"+originalPath)

	result := AnyFlatpakExists("com.nonexistent.flatpak1", "com.nonexistent.flatpak2")
	if result {
		t.Errorf("expected false when no flatpaks exist")
	}
}

func TestAnyFlatpakExistsNoFlatpak(t *testing.T) {
	tempDir := t.TempDir()
	t.Setenv("PATH", tempDir)

	result := AnyFlatpakExists("any.package.name", "another.package")
	if result {
		t.Errorf("expected false when flatpak not in PATH, got true")
	}
}

func TestAnyFlatpakExistsEmpty(t *testing.T) {
	result := AnyFlatpakExists()
	if result {
		t.Errorf("expected false when no flatpaks specified")
	}
}
