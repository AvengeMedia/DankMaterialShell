package distros

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/deps"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
)

func TestBaseDistribution_detectDMS_NotInstalled(t *testing.T) {
	originalHome := os.Getenv("HOME")
	defer os.Setenv("HOME", originalHome)

	tempDir := t.TempDir()
	os.Setenv("HOME", tempDir)

	logChan := make(chan string, 10)
	defer close(logChan)

	base := NewBaseDistribution(logChan)
	dep := base.detectDMS()

	if dep.Status != deps.StatusMissing {
		t.Errorf("Expected StatusMissing, got %d", dep.Status)
	}

	if dep.Name != "dms (DankMaterialShell)" {
		t.Errorf("Expected name 'dms (DankMaterialShell)', got %s", dep.Name)
	}

	if !dep.Required {
		t.Error("Expected Required to be true")
	}
}

func TestBaseDistribution_detectDMS_Installed(t *testing.T) {
	if !utils.CommandExists("git") {
		t.Skip("git not available")
	}

	tempDir := t.TempDir()
	dmsPath := filepath.Join(tempDir, ".config", "quickshell", "dms")
	os.MkdirAll(dmsPath, 0o755)

	originalHome := os.Getenv("HOME")
	defer os.Setenv("HOME", originalHome)
	os.Setenv("HOME", tempDir)

	exec.Command("git", "init", dmsPath).Run()
	exec.Command("git", "-C", dmsPath, "config", "user.email", "test@test.com").Run()
	exec.Command("git", "-C", dmsPath, "config", "user.name", "Test User").Run()
	exec.Command("git", "-C", dmsPath, "checkout", "-b", "master").Run()

	testFile := filepath.Join(dmsPath, "test.txt")
	os.WriteFile(testFile, []byte("test"), 0o644)
	exec.Command("git", "-C", dmsPath, "add", ".").Run()
	exec.Command("git", "-C", dmsPath, "commit", "-m", "initial").Run()

	logChan := make(chan string, 10)
	defer close(logChan)

	base := NewBaseDistribution(logChan)
	dep := base.detectDMS()

	if dep.Status == deps.StatusMissing {
		t.Error("Expected DMS to be detected as installed")
	}

	if dep.Name != "dms (DankMaterialShell)" {
		t.Errorf("Expected name 'dms (DankMaterialShell)', got %s", dep.Name)
	}

	if !dep.Required {
		t.Error("Expected Required to be true")
	}

	t.Logf("Status: %d, Version: %s", dep.Status, dep.Version)
}

func TestBaseDistribution_detectDMS_DirectoryWithoutGit(t *testing.T) {
	tempDir := t.TempDir()
	dmsPath := filepath.Join(tempDir, ".config", "quickshell", "dms")
	os.MkdirAll(dmsPath, 0o755)

	originalHome := os.Getenv("HOME")
	defer os.Setenv("HOME", originalHome)
	os.Setenv("HOME", tempDir)

	logChan := make(chan string, 10)
	defer close(logChan)

	base := NewBaseDistribution(logChan)
	dep := base.detectDMS()

	if dep.Status == deps.StatusMissing {
		t.Error("Expected DMS to be detected as present")
	}

	if dep.Name != "dms (DankMaterialShell)" {
		t.Errorf("Expected name 'dms (DankMaterialShell)', got %s", dep.Name)
	}

	if !dep.Required {
		t.Error("Expected Required to be true")
	}
}
