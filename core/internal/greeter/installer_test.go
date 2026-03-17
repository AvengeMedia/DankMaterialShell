package greeter

import (
	"os"
	"path/filepath"
	"testing"
)

func writeTestJSON(t *testing.T, path string, content string) {
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
			writeTestJSON(t, filepath.Join(homeDir, ".config", "DankMaterialShell", "settings.json"), tt.settingsJSON)
			writeTestJSON(t, filepath.Join(homeDir, ".local", "state", "DankMaterialShell", "session.json"), tt.sessionJSON)

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
