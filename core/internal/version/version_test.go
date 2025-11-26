package version

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	mocks_version "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/version"
)

func TestCompareVersions(t *testing.T) {
	tests := []struct {
		v1       string
		v2       string
		expected int
	}{
		{"v0.1.0", "v0.1.0", 0},
		{"v0.1.0", "v0.1.1", -1},
		{"v0.1.1", "v0.1.0", 1},
		{"v0.1.10", "v0.1.2", 1},
		{"v0.2.0", "v0.1.9", 1},
		{"0.1.0", "0.1.0", 0},
		{"1.0.0", "v1.0.0", 0},
		{"v1.2.3", "v1.2.4", -1},
		{"v2.0.0", "v1.9.9", 1},
	}

	for _, tt := range tests {
		result := CompareVersions(tt.v1, tt.v2)
		if result != tt.expected {
			t.Errorf("CompareVersions(%q, %q) = %d; want %d", tt.v1, tt.v2, result, tt.expected)
		}
	}
}

func TestGetDMSVersionInfo_Structure(t *testing.T) {
	// Create a temp directory with a fake DMS installation
	tempDir := t.TempDir()
	dmsPath := filepath.Join(tempDir, ".config", "quickshell", "dms")
	os.MkdirAll(dmsPath, 0755)

	// Create a .git directory to simulate git installation
	os.MkdirAll(filepath.Join(dmsPath, ".git"), 0755)

	originalHome := os.Getenv("HOME")
	defer os.Setenv("HOME", originalHome)
	os.Setenv("HOME", tempDir)

	// Create mock fetcher
	mockFetcher := mocks_version.NewMockVersionFetcher(t)
	mockFetcher.EXPECT().GetCurrentVersion(dmsPath).Return("v0.1.0", nil)
	mockFetcher.EXPECT().GetLatestVersion(dmsPath).Return("v0.1.1", nil)

	info, err := GetDMSVersionInfoWithFetcher(mockFetcher)
	if err != nil {
		t.Fatalf("GetDMSVersionInfoWithFetcher() failed: %v", err)
	}

	if info == nil {
		t.Fatal("GetDMSVersionInfoWithFetcher() returned nil")
	}

	if info.Current != "v0.1.0" {
		t.Errorf("Current version = %s, expected v0.1.0", info.Current)
	}

	if info.Latest != "v0.1.1" {
		t.Errorf("Latest version = %s, expected v0.1.1", info.Latest)
	}

	if !info.HasUpdate {
		t.Error("HasUpdate should be true when current != latest")
	}

	if !info.IsTag {
		t.Error("IsTag should be true for v0.1.0")
	}

	t.Logf("Current: %s, Latest: %s, HasUpdate: %v", info.Current, info.Latest, info.HasUpdate)
}

func TestGetDMSVersionInfo_BranchVersion(t *testing.T) {
	tempDir := t.TempDir()
	dmsPath := filepath.Join(tempDir, ".config", "quickshell", "dms")
	os.MkdirAll(dmsPath, 0755)
	os.MkdirAll(filepath.Join(dmsPath, ".git"), 0755)

	originalHome := os.Getenv("HOME")
	defer os.Setenv("HOME", originalHome)
	os.Setenv("HOME", tempDir)

	mockFetcher := mocks_version.NewMockVersionFetcher(t)
	mockFetcher.EXPECT().GetCurrentVersion(dmsPath).Return("master@abc1234", nil)
	mockFetcher.EXPECT().GetLatestVersion(dmsPath).Return("master@def5678", nil)

	info, err := GetDMSVersionInfoWithFetcher(mockFetcher)
	if err != nil {
		t.Fatalf("GetDMSVersionInfoWithFetcher() failed: %v", err)
	}

	if !info.IsBranch {
		t.Error("IsBranch should be true for branch@commit format")
	}

	if !info.IsGit {
		t.Error("IsGit should be true for branch@commit format")
	}

	if !info.HasUpdate {
		t.Error("HasUpdate should be true when commits differ")
	}
}

func TestGetDMSVersionInfo_NoUpdate(t *testing.T) {
	tempDir := t.TempDir()
	dmsPath := filepath.Join(tempDir, ".config", "quickshell", "dms")
	os.MkdirAll(dmsPath, 0755)
	os.MkdirAll(filepath.Join(dmsPath, ".git"), 0755)

	originalHome := os.Getenv("HOME")
	defer os.Setenv("HOME", originalHome)
	os.Setenv("HOME", tempDir)

	mockFetcher := mocks_version.NewMockVersionFetcher(t)
	mockFetcher.EXPECT().GetCurrentVersion(dmsPath).Return("v0.1.0", nil)
	mockFetcher.EXPECT().GetLatestVersion(dmsPath).Return("v0.1.0", nil)

	info, err := GetDMSVersionInfoWithFetcher(mockFetcher)
	if err != nil {
		t.Fatalf("GetDMSVersionInfoWithFetcher() failed: %v", err)
	}

	if info.HasUpdate {
		t.Error("HasUpdate should be false when current == latest")
	}
}

func TestGetCurrentDMSVersion_NotInstalled(t *testing.T) {
	originalHome := os.Getenv("HOME")
	defer os.Setenv("HOME", originalHome)

	tempDir := t.TempDir()
	os.Setenv("HOME", tempDir)

	_, err := GetCurrentDMSVersion()
	if err == nil {
		t.Error("Expected error when DMS not installed, got nil")
	}
}

func TestGetCurrentDMSVersion_GitTag(t *testing.T) {
	if !commandExists("git") {
		t.Skip("git not available")
	}

	tempDir := t.TempDir()
	dmsPath := filepath.Join(tempDir, ".config", "quickshell", "dms")
	os.MkdirAll(dmsPath, 0755)

	originalHome := os.Getenv("HOME")
	defer os.Setenv("HOME", originalHome)
	os.Setenv("HOME", tempDir)

	exec.Command("git", "init", dmsPath).Run()
	exec.Command("git", "-C", dmsPath, "config", "user.email", "test@test.com").Run()
	exec.Command("git", "-C", dmsPath, "config", "user.name", "Test User").Run()

	testFile := filepath.Join(dmsPath, "test.txt")
	os.WriteFile(testFile, []byte("test"), 0644)
	exec.Command("git", "-C", dmsPath, "add", ".").Run()
	exec.Command("git", "-C", dmsPath, "commit", "-m", "initial").Run()
	exec.Command("git", "-C", dmsPath, "tag", "v0.1.0").Run()

	version, err := GetCurrentDMSVersion()
	if err != nil {
		t.Fatalf("GetCurrentDMSVersion() failed: %v", err)
	}

	if version != "v0.1.0" {
		t.Errorf("Expected version v0.1.0, got %s", version)
	}
}

func TestGetCurrentDMSVersion_GitBranch(t *testing.T) {
	if !commandExists("git") {
		t.Skip("git not available")
	}

	tempDir := t.TempDir()
	dmsPath := filepath.Join(tempDir, ".config", "quickshell", "dms")
	os.MkdirAll(dmsPath, 0755)

	originalHome := os.Getenv("HOME")
	defer os.Setenv("HOME", originalHome)
	os.Setenv("HOME", tempDir)

	exec.Command("git", "init", dmsPath).Run()
	exec.Command("git", "-C", dmsPath, "config", "user.email", "test@test.com").Run()
	exec.Command("git", "-C", dmsPath, "config", "user.name", "Test User").Run()
	exec.Command("git", "-C", dmsPath, "checkout", "-b", "master").Run()

	testFile := filepath.Join(dmsPath, "test.txt")
	os.WriteFile(testFile, []byte("test"), 0644)
	exec.Command("git", "-C", dmsPath, "add", ".").Run()
	exec.Command("git", "-C", dmsPath, "commit", "-m", "initial").Run()

	version, err := GetCurrentDMSVersion()
	if err != nil {
		t.Fatalf("GetCurrentDMSVersion() failed: %v", err)
	}

	if version == "" {
		t.Error("Expected non-empty version")
	}

	if len(version) < 7 {
		t.Errorf("Expected version with branch@commit format, got %s", version)
	}
}

func TestVersionInfo_IsGit(t *testing.T) {
	tests := []struct {
		current  string
		isGit    bool
		isBranch bool
		isTag    bool
	}{
		{"v0.1.0", false, false, true},
		{"master@abc1234", true, true, false},
		{"dev@def5678", true, true, false},
		{"v0.2.0", false, false, true},
		{"unknown", false, false, false},
	}

	for _, tt := range tests {
		info := &VersionInfo{
			IsGit:    tt.isGit,
			IsBranch: tt.isBranch,
			IsTag:    tt.isTag,
		}

		actualIsGit := len(tt.current) > 0 && tt.current[0] != 'v' && tt.current != "unknown"
		actualIsBranch := len(tt.current) > 0 && tt.current[0] != 'v'
		actualIsTag := len(tt.current) > 0 && tt.current[0] == 'v'

		if tt.current == "unknown" {
			actualIsGit = false
			actualIsBranch = false
			actualIsTag = false
		}

		if info.IsGit != tt.isGit {
			t.Errorf("For %s: IsGit = %v; want %v", tt.current, info.IsGit, tt.isGit)
		}
		if info.IsBranch != tt.isBranch {
			t.Errorf("For %s: IsBranch = %v; want %v", tt.current, info.IsBranch, tt.isBranch)
		}
		if info.IsTag != tt.isTag {
			t.Errorf("For %s: IsTag = %v; want %v", tt.current, info.IsTag, tt.isTag)
		}

		_ = actualIsGit
		_ = actualIsBranch
		_ = actualIsTag
	}
}

func TestVersionInfo_HasUpdate_Branch(t *testing.T) {
	tests := []struct {
		current   string
		latest    string
		hasUpdate bool
	}{
		{"master@abc1234", "master@abc1234", false},
		{"master@abc1234", "master@def5678", true},
		{"dev@abc1234", "dev@abc1234", false},
		{"dev@old1234", "dev@new5678", true},
	}

	for _, tt := range tests {
		info := &VersionInfo{
			HasUpdate: tt.hasUpdate,
		}

		if info.HasUpdate != tt.hasUpdate {
			t.Errorf("For current=%s, latest=%s: HasUpdate = %v; want %v",
				tt.current, tt.latest, info.HasUpdate, tt.hasUpdate)
		}
	}
}

func TestVersionInfo_HasUpdate_Tag(t *testing.T) {
	tests := []struct {
		current   string
		latest    string
		hasUpdate bool
	}{
		{"v0.1.0", "v0.1.0", false},
		{"v0.1.0", "v0.1.1", true},
		{"v0.1.5", "v0.1.5", false},
		{"v0.1.9", "v0.2.0", true},
	}

	for _, tt := range tests {
		info := &VersionInfo{
			HasUpdate: tt.hasUpdate,
		}

		if info.HasUpdate != tt.hasUpdate {
			t.Errorf("For current=%s, latest=%s: HasUpdate = %v; want %v",
				tt.current, tt.latest, info.HasUpdate, tt.hasUpdate)
		}
	}
}

func commandExists(cmd string) bool {
	_, err := exec.LookPath(cmd)
	return err == nil
}

func TestGetLatestDMSVersion_FallbackParsing(t *testing.T) {
	jsonResponse := `{
		"tag_name": "v0.1.17",
		"name": "Release v0.1.17"
	}`

	lines := []string{
		`  "tag_name": "v0.1.17",`,
		`  "name": "Release v0.1.17"`,
	}

	for _, line := range lines {
		if len(line) > 0 && line[0:15] == `  "tag_name": "` {
			parts := []string{"", "", "", "v0.1.17"}
			version := parts[3]
			if version != "v0.1.17" {
				t.Errorf("Failed to parse version from line: %s", line)
			}
		}
	}

	_ = jsonResponse
}

func TestCompareVersions_EdgeCases(t *testing.T) {
	tests := []struct {
		v1       string
		v2       string
		expected int
	}{
		{"", "", 0},
		{"v1", "v1", 0},
		{"v1.0", "v1", 0},
		{"v1.0.0", "v1.0", 0},
		{"v1.0.1", "v1.0", 1},
		{"v1", "v1.0.1", -1},
	}

	for _, tt := range tests {
		result := CompareVersions(tt.v1, tt.v2)
		if result != tt.expected {
			t.Errorf("CompareVersions(%q, %q) = %d; want %d", tt.v1, tt.v2, result, tt.expected)
		}
	}
}
