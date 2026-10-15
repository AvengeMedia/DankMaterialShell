package distros

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/deps"
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
}

func TestParseHyprlandVersion(t *testing.T) {
	tests := []struct{ name, out, want string }{
		{
			name: "0.56 main build reports the tag, not the first line",
			out: "Hyprland 0.56.0 built from branch main at commit 5a78b5e927345860a27e2893bf894f97ee620c48 clean (unknown).\n" +
				"Date: Tue Oct 06 01:20:44 2026\n" +
				"Tag: 0.56.2, commits: 7899\n" +
				"\nLibraries:\nHyprgraphics: built against 0.5.1, system has unknown\n",
			want: "0.56.2",
		},
		{
			name: "v-prefixed tag",
			out:  "Hyprland, built from branch  at commit 918d8340afd652b011b937d29d5eea0be08467f5  (version: bump to v0.41.2).\nTag: v0.41.2, commits: 4880\n",
			want: "0.41.2",
		},
		{
			name: "no tag line falls back to the first version",
			out:  "Hyprland v0.41.2 built from branch main\n",
			want: "0.41.2",
		},
	}
	for _, tt := range tests {
		if got := ParseHyprlandVersion(tt.out); got != tt.want {
			t.Errorf("%s: got %q, want %q", tt.name, got, tt.want)
		}
	}
}
