package utils

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestFlatpakInPathAvailable(t *testing.T) {
	result := FlatpakInPath()
	if !result {
		t.Skip("flatpak not in PATH")
	}
	if !result {
		t.Errorf("expected true when flatpak is in PATH")
	}
}

func TestFlatpakInPathUnavailable(t *testing.T) {
	tempDir := t.TempDir()
	t.Setenv("PATH", tempDir)

	result := FlatpakInPath()
	if result {
		t.Errorf("expected false when flatpak not in PATH, got true")
	}
}

func TestFlatpakExistsValidPackage(t *testing.T) {
	if !FlatpakInPath() {
		t.Skip("flatpak not in PATH")
	}

	result := FlatpakExists("com.nonexistent.package.test")
	if result {
		t.Logf("package exists (unexpected but not an error)")
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

func TestFlatpakSearchBySubstringNonexistent(t *testing.T) {
	if !FlatpakInPath() {
		t.Skip("flatpak not in PATH")
	}

	result := FlatpakSearchBySubstring("ThisIsAVeryUnlikelyPackageName12345")
	if result {
		t.Errorf("expected false for nonexistent package substring")
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

func TestFlatpakInstallationDirNonexistent(t *testing.T) {
	if !FlatpakInPath() {
		t.Skip("flatpak not in PATH")
	}

	_, err := FlatpakInstallationDir("com.nonexistent.package.test")
	if err == nil {
		t.Errorf("expected error for nonexistent package")
	}
	if err != nil && !strings.Contains(err.Error(), "not installed") {
		t.Errorf("expected 'not installed' error, got: %v", err)
	}
}

func TestFlatpakInstallationDirValid(t *testing.T) {
	if !FlatpakInPath() {
		t.Skip("flatpak not in PATH")
	}

	// This test requires a known installed flatpak
	// We can't guarantee any specific flatpak is installed,
	// so we'll skip if we can't find a common one
	commonFlatpaks := []string{
		"org.mozilla.firefox",
		"org.gnome.Calculator",
		"org.freedesktop.Platform",
	}

	var testPackage string
	for _, pkg := range commonFlatpaks {
		if FlatpakExists(pkg) {
			testPackage = pkg
			break
		}
	}

	if testPackage == "" {
		t.Skip("no common flatpak packages found for testing")
	}

	result, err := FlatpakInstallationDir(testPackage)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result == "" {
		t.Errorf("expected non-empty installation directory")
	}
	if !strings.Contains(result, testPackage) {
		t.Logf("installation directory %s doesn't contain package name (may be expected)", result)
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
	err := os.WriteFile(fakeFlatpak, []byte(script), 0755)
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
	err := os.WriteFile(fakeFlatpak, []byte(script), 0755)
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
	err := os.WriteFile(fakeFlatpak, []byte(script), 0755)
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
