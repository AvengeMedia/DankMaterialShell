package greeter

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeTestFile(t *testing.T, path string, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("failed to create parent dir for %s: %v", path, err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("failed to write %s: %v", path, err)
	}
}

func TestResolveGreeterThemeSyncState(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name                    string
		settingsJSON            string
		sessionJSON             string
		wantSourcePath          string
		wantResolvedWallpaper   string
		wantDynamicOverrideUsed bool
	}{
		{
			name: "dynamic theme with greeter wallpaper override uses generated greeter colors",
			settingsJSON: `{
  "currentThemeName": "dynamic",
  "greeterWallpaperPath": "Pictures/blue.jpg",
  "matugenScheme": "scheme-tonal-spot",
  "iconTheme": "Papirus"
}`,
			sessionJSON:             `{"isLightMode":true}`,
			wantSourcePath:          filepath.Join(".cache", "DankMaterialShell", "greeter-colors", "dms-colors.json"),
			wantResolvedWallpaper:   filepath.Join("Pictures", "blue.jpg"),
			wantDynamicOverrideUsed: true,
		},
		{
			name: "dynamic theme without override uses desktop colors",
			settingsJSON: `{
  "currentThemeName": "dynamic",
  "greeterWallpaperPath": ""
}`,
			sessionJSON:             `{"isLightMode":false}`,
			wantSourcePath:          filepath.Join(".cache", "DankMaterialShell", "dms-colors.json"),
			wantResolvedWallpaper:   "",
			wantDynamicOverrideUsed: false,
		},
		{
			name: "non-dynamic theme keeps desktop colors even with override wallpaper",
			settingsJSON: `{
  "currentThemeName": "purple",
  "greeterWallpaperPath": "/tmp/blue.jpg"
}`,
			sessionJSON:             `{"isLightMode":false}`,
			wantSourcePath:          filepath.Join(".cache", "DankMaterialShell", "dms-colors.json"),
			wantResolvedWallpaper:   "/tmp/blue.jpg",
			wantDynamicOverrideUsed: false,
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			homeDir := t.TempDir()
			writeTestFile(t, filepath.Join(homeDir, ".config", "DankMaterialShell", "settings.json"), tt.settingsJSON)
			writeTestFile(t, filepath.Join(homeDir, ".local", "state", "DankMaterialShell", "session.json"), tt.sessionJSON)

			state, err := resolveGreeterThemeSyncState(homeDir)
			if err != nil {
				t.Fatalf("resolveGreeterThemeSyncState returned error: %v", err)
			}

			if got := state.effectiveColorsSource(homeDir); got != filepath.Join(homeDir, tt.wantSourcePath) {
				t.Fatalf("effectiveColorsSource = %q, want %q", got, filepath.Join(homeDir, tt.wantSourcePath))
			}

			wantResolvedWallpaper := tt.wantResolvedWallpaper
			if wantResolvedWallpaper != "" && !filepath.IsAbs(wantResolvedWallpaper) {
				wantResolvedWallpaper = filepath.Join(homeDir, wantResolvedWallpaper)
			}
			if state.ResolvedGreeterWallpaperPath != wantResolvedWallpaper {
				t.Fatalf("ResolvedGreeterWallpaperPath = %q, want %q", state.ResolvedGreeterWallpaperPath, wantResolvedWallpaper)
			}

			if state.UsesDynamicWallpaperOverride != tt.wantDynamicOverrideUsed {
				t.Fatalf("UsesDynamicWallpaperOverride = %v, want %v", state.UsesDynamicWallpaperOverride, tt.wantDynamicOverrideUsed)
			}
		})
	}
}

func TestUpsertInitialSession(t *testing.T) {
	t.Parallel()

	baseConfig := `[terminal]
vt = 1

[default_session]
user = "greeter"
command = "/usr/bin/dms-greeter --command niri"
`

	t.Run("inserts initial session", func(t *testing.T) {
		t.Parallel()
		got := upsertInitialSession(baseConfig, "alice", "niri", true)
		if !strings.Contains(got, "[initial_session]") {
			t.Fatalf("expected [initial_session] section, got:\n%s", got)
		}
		if !strings.Contains(got, `user = "alice"`) {
			t.Fatalf("expected alice user in initial session, got:\n%s", got)
		}
		if !strings.Contains(got, `env XDG_SESSION_TYPE=wayland sh -c 'exec niri'`) {
			t.Fatalf("expected wrapped session command, got:\n%s", got)
		}
	})

	t.Run("updates existing initial session", func(t *testing.T) {
		t.Parallel()
		existing := baseConfig + `
[initial_session]
user = "bob"
command = "old-command"
`
		got := upsertInitialSession(existing, "alice", "Hyprland", true)
		if strings.Contains(got, `user = "bob"`) {
			t.Fatalf("expected bob to be replaced, got:\n%s", got)
		}
		if !strings.Contains(got, `exec Hyprland`) {
			t.Fatalf("expected Hyprland command, got:\n%s", got)
		}
	})

	t.Run("removes initial session when disabled", func(t *testing.T) {
		t.Parallel()
		existing := baseConfig + `
[initial_session]
user = "alice"
command = "niri"
`
		got := upsertInitialSession(existing, "", "", false)
		if strings.Contains(got, "[initial_session]") {
			t.Fatalf("expected initial session removed, got:\n%s", got)
		}
		if !strings.Contains(got, "[default_session]") {
			t.Fatalf("expected default session preserved, got:\n%s", got)
		}
	})
}

func TestStripDesktopExecCodes(t *testing.T) {
	t.Parallel()

	got := stripDesktopExecCodes("niri --session %f")
	want := "niri --session"
	if got != want {
		t.Fatalf("stripDesktopExecCodes = %q, want %q", got, want)
	}
}

func TestResolveGreeterAutoLoginState(t *testing.T) {
	t.Parallel()

	cacheDir := t.TempDir()
	homeDir := t.TempDir()

	writeTestFile(t, filepath.Join(cacheDir, "settings.json"), `{
  "greeterAutoLogin": true,
  "greeterRememberLastUser": true,
  "greeterRememberLastSession": true
}`)
	writeTestFile(t, filepath.Join(cacheDir, ".local/state/memory.json"), `{
  "lastSuccessfulUser": "alice",
  "lastSessionExec": "niri"
}`)

	enabled, loginUser, sessionExec, err := resolveGreeterAutoLoginState(cacheDir, homeDir)
	if err != nil {
		t.Fatalf("resolveGreeterAutoLoginState returned error: %v", err)
	}
	if !enabled || loginUser != "alice" || sessionExec != "niri" {
		t.Fatalf("got enabled=%v user=%q exec=%q", enabled, loginUser, sessionExec)
	}
}

func TestResolveGreeterAutoLoginStateIgnoresMemoryFlag(t *testing.T) {
	t.Parallel()

	cacheDir := t.TempDir()
	homeDir := t.TempDir()

	writeTestFile(t, filepath.Join(cacheDir, "settings.json"), `{
  "greeterAutoLogin": false,
  "greeterRememberLastUser": true,
  "greeterRememberLastSession": true
}`)
	writeTestFile(t, filepath.Join(cacheDir, ".local/state/memory.json"), `{
  "autoLoginEnabled": true,
  "lastSuccessfulUser": "alice",
  "lastSessionExec": "niri"
}`)

	enabled, loginUser, sessionExec, err := resolveGreeterAutoLoginState(cacheDir, homeDir)
	if err != nil {
		t.Fatalf("resolveGreeterAutoLoginState returned error: %v", err)
	}
	if enabled || loginUser != "" || sessionExec != "" {
		t.Fatalf("expected disabled with empty user/exec, got enabled=%v user=%q exec=%q", enabled, loginUser, sessionExec)
	}
}

func TestClearGreeterAutoLoginMemory(t *testing.T) {
	t.Parallel()

	memoryPath := filepath.Join(t.TempDir(), "memory.json")
	writeTestFile(t, memoryPath, `{
  "autoLoginEnabled": true,
  "lastSuccessfulUser": "alice"
}`)

	if err := clearGreeterAutoLoginMemory(memoryPath, ""); err != nil {
		t.Fatalf("clearGreeterAutoLoginMemory returned error: %v", err)
	}

	data, err := os.ReadFile(memoryPath)
	if err != nil {
		t.Fatalf("failed to read memory file: %v", err)
	}
	if strings.Contains(string(data), "autoLoginEnabled") {
		t.Fatalf("expected autoLoginEnabled removed, got: %s", string(data))
	}
	if !strings.Contains(string(data), "lastSuccessfulUser") {
		t.Fatalf("expected other memory fields preserved, got: %s", string(data))
	}
}
