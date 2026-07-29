package themes

import (
	"testing"

	"github.com/spf13/afero"
)

func TestLoadThemeWCAG(t *testing.T) {
	fs := afero.NewMemMapFs()
	themeDir := "/themes/example"
	wcagJSON := `{
		"level": "AA",
		"dark": {
			"level": "AAA", "minRatio": 8.5, "worstPair": ["surfaceText", "surface"],
			"body": {"level": "AAA", "minRatio": 8.5},
			"accent": {"level": "AAA", "minRatio": 9.1}
		},
		"light": {
			"level": "AA", "minRatio": 5.2,
			"body": {"level": "AAA", "minRatio": 7.4},
			"accent": {"level": "AA", "minRatio": 5.2},
			"variants": {"blue": "AA", "red": "fail"}
		}
	}`
	if err := afero.WriteFile(fs, themeDir+"/wcag.json", []byte(wcagJSON), 0o644); err != nil {
		t.Fatal(err)
	}

	wcag := loadThemeWCAG(fs, themeDir)
	if wcag == nil {
		t.Fatal("expected wcag report, got nil")
	}
	if wcag.Level != "AA" {
		t.Fatalf("expected level AA, got %s", wcag.Level)
	}
	if wcag.Dark.Level != "AAA" || wcag.Dark.MinRatio != 8.5 {
		t.Fatalf("unexpected dark mode report: %+v", wcag.Dark)
	}
	if wcag.Light.Variants["red"] != "fail" {
		t.Fatalf("unexpected light variants: %+v", wcag.Light.Variants)
	}
	if wcag.Light.Body == nil || wcag.Light.Body.Level != "AAA" {
		t.Fatalf("expected light body AAA, got %+v", wcag.Light.Body)
	}
	if wcag.Light.Accent == nil || wcag.Light.Accent.Level != "AA" {
		t.Fatalf("expected light accent AA, got %+v", wcag.Light.Accent)
	}
}

func TestLoadThemeWCAGMissingFile(t *testing.T) {
	if wcag := loadThemeWCAG(afero.NewMemMapFs(), "/themes/none"); wcag != nil {
		t.Fatalf("expected nil for missing wcag.json, got %+v", wcag)
	}
}

func TestLoadThemeWCAGInvalidJSON(t *testing.T) {
	fs := afero.NewMemMapFs()
	if err := afero.WriteFile(fs, "/themes/bad/wcag.json", []byte("{"), 0o644); err != nil {
		t.Fatal(err)
	}

	if wcag := loadThemeWCAG(fs, "/themes/bad"); wcag != nil {
		t.Fatalf("expected nil for invalid wcag.json, got %+v", wcag)
	}
}

func TestParseRegistriesFromEnv(t *testing.T) {
	t.Run("defaults to official when env unset", func(t *testing.T) {
		t.Setenv("DMS_THEME_REGISTRIES", "")
		cfgs := ParseRegistriesFromEnv()
		if len(cfgs) != 1 {
			t.Fatalf("expected 1 registry, got %d", len(cfgs))
		}
		if cfgs[0].Name != "official" {
			t.Fatalf("expected name=official, got %q", cfgs[0].Name)
		}
		if cfgs[0].URL != defaultRegistryURL {
			t.Fatalf("expected url=%s, got %q", defaultRegistryURL, cfgs[0].URL)
		}
	})

	t.Run("parses comma-separated URLs", func(t *testing.T) {
		t.Setenv("DMS_THEME_REGISTRIES", "https://a.git,https://b.git")
		cfgs := ParseRegistriesFromEnv()
		if len(cfgs) != 2 {
			t.Fatalf("expected 2 registries, got %d", len(cfgs))
		}
		if cfgs[0].URL != "https://a.git" || cfgs[1].URL != "https://b.git" {
			t.Fatalf("unexpected urls: %+v", cfgs)
		}
	})

	t.Run("falls back when all entries empty", func(t *testing.T) {
		t.Setenv("DMS_THEME_REGISTRIES", ", , ,")
		cfgs := ParseRegistriesFromEnv()
		if len(cfgs) != 1 || cfgs[0].Name != "official" {
			t.Fatalf("expected fallback to official, got %+v", cfgs)
		}
	})
}

func TestUpdateMigration(t *testing.T) {
	t.Run("migrates legacy themes cache", func(t *testing.T) {
		fs := afero.NewMemMapFs()
		base := "/test-cache"

		// Seed legacy <base>/themes/example/theme.json
		legacyDir := base + "/themes/example"
		if err := afero.NewBasePathFs(fs, base).MkdirAll(legacyDir, 0o755); err != nil {
			// BasePathFs not supported here; use direct path
			if err := fs.MkdirAll(legacyDir, 0o755); err != nil {
				t.Fatal(err)
			}
		}
		themeJSON := `{"id":"example","name":"Example","version":"1.0","author":"a","description":"d"}`
		if err := afero.WriteFile(fs, legacyDir+"/theme.json", []byte(themeJSON), 0o644); err != nil {
			t.Fatal(err)
		}

		r := &Registry{
			fs:         fs,
			cacheDir:   base,
			registries: []RegistryConfig{{Name: "official", URL: defaultRegistryURL}},
			themes:     []Theme{},
			git:        &stubGitClient{},
		}
		if err := r.Update(); err != nil {
			t.Fatalf("Update: %v", err)
		}
		if len(r.themes) != 1 {
			t.Fatalf("expected 1 theme after migration, got %d", len(r.themes))
		}
		if r.themes[0].ID != "example" {
			t.Fatalf("expected theme id=example, got %q", r.themes[0].ID)
		}
		// Legacy dir should be gone.
		if exists, _ := afero.DirExists(fs, base+"/themes"); exists {
			t.Fatal("legacy <base>/themes should be migrated/removed")
		}
		// New layout: <base>/official/themes/example/theme.json
		if exists, _ := afero.Exists(fs, base+"/official/themes/example/theme.json"); !exists {
			t.Fatal("theme should be at <base>/official/themes/example/ after migration")
		}
	})
}

type stubGitClient struct{}

func (s *stubGitClient) PlainClone(path string, url string) error { return nil }
func (s *stubGitClient) Pull(path string) error                   { return nil }
