package greeter

import (
	"path/filepath"
	"testing"
)

func TestUserGreeterCacheDir(t *testing.T) {
	t.Parallel()

	got := userGreeterCacheDir("/var/cache/dms-greeter", "alice")
	want := filepath.Join("/var/cache/dms-greeter", "users", "alice")
	if got != want {
		t.Fatalf("userGreeterCacheDir() = %q, want %q", got, want)
	}
}

func TestResolveUserProfileImageSource(t *testing.T) {
	t.Parallel()

	homeDir := t.TempDir()
	facePath := filepath.Join(homeDir, ".face")
	writeTestFile(t, facePath, "face")

	got := resolveUserProfileImageSource(homeDir)
	if got != facePath {
		t.Fatalf("resolveUserProfileImageSource() = %q, want %q", got, facePath)
	}
}

func TestIsUserOwnedGreeterCacheSlot(t *testing.T) {
	t.Parallel()

	slot := filepath.Join(GreeterCacheDir, "users", "alice", "settings.json")
	if !isUserOwnedGreeterCacheSlot(slot, "alice") {
		t.Fatalf("expected alice to own %q", slot)
	}
	if isUserOwnedGreeterCacheSlot(slot, "bob") {
		t.Fatalf("expected bob not to own alice slot")
	}
	if isUserOwnedGreeterCacheSlot(filepath.Join(GreeterCacheDir, "settings.json"), "alice") {
		t.Fatalf("expected root cache file not to be a user slot")
	}
}

func TestLocalizeSessionWallpapers(t *testing.T) {
	t.Parallel()

	homeDir := t.TempDir()
	userDir := filepath.Join(homeDir, "users", "alice")
	wallpaperPath := filepath.Join(homeDir, "wall.jpg")
	writeTestFile(t, wallpaperPath, "wallpaper")

	session := map[string]any{
		"wallpaperPath": wallpaperPath,
		"monitorWallpapers": map[string]any{
			"DP-1": wallpaperPath,
		},
	}

	if err := localizeSessionWallpapers(session, userDir, userSlotSyncOpts{}); err != nil {
		t.Fatalf("localizeSessionWallpapers returned error: %v", err)
	}

	gotPath, ok := session["wallpaperPath"].(string)
	if !ok || gotPath == "" {
		t.Fatalf("expected localized wallpaperPath, got %#v", session["wallpaperPath"])
	}
	if gotPath == wallpaperPath {
		t.Fatalf("expected copied wallpaper path, still points to source")
	}

	monitorMap, ok := session["monitorWallpapers"].(map[string]any)
	if !ok {
		t.Fatalf("expected monitorWallpapers map")
	}
	monitorPath, ok := monitorMap["DP-1"].(string)
	if !ok || monitorPath == "" || monitorPath == wallpaperPath {
		t.Fatalf("expected localized monitor wallpaper, got %#v", monitorMap["DP-1"])
	}
}
