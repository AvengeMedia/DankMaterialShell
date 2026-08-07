package themes

import (
	"os"
	"testing"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/registries"
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

type stubGitClient struct {
	cloneFunc func(path string, url string) error
}

func (s *stubGitClient) PlainClone(path string, url string) error {
	if s.cloneFunc != nil {
		return s.cloneFunc(path, url)
	}
	return nil
}
func (s *stubGitClient) Pull(path string) error                { return nil }
func (s *stubGitClient) OriginURL(path string) (string, error) { return "", os.ErrNotExist }

func writeTestTheme(t *testing.T, fs afero.Fs, registryDir, themeID, name string) {
	dir := registryDir + "/themes/" + themeID
	if err := fs.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	themeJSON := `{"id":"` + themeID + `","name":"` + name + `","version":"1.0","author":"a","description":"d"}`
	if err := afero.WriteFile(fs, dir+"/theme.json", []byte(themeJSON), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestUpdateMultiRegistry(t *testing.T) {
	fs := afero.NewMemMapFs()
	base := "/test-cache"
	r := &Registry{
		fs:       fs,
		cacheDir: base,
		registries: []registries.Source{
			{Name: "official", URL: "https://example.com/official.git"},
			{Name: "extra", URL: "https://example.com/extra.git"},
		},
		themes: []Theme{},
	}
	r.git = &stubGitClient{
		cloneFunc: func(path string, url string) error {
			switch path {
			case base + "/official":
				writeTestTheme(t, fs, path, "shared", "OfficialShared")
				writeTestTheme(t, fs, path, "one", "One")
			case base + "/extra":
				writeTestTheme(t, fs, path, "shared", "ExtraShared")
				writeTestTheme(t, fs, path, "two", "Two")
			}
			return nil
		},
	}

	if err := r.Update(); err != nil {
		t.Fatalf("Update: %v", err)
	}
	if len(r.themes) != 3 {
		t.Fatalf("expected 3 themes after dedupe, got %d", len(r.themes))
	}
	for _, theme := range r.themes {
		if theme.ID == "shared" && theme.Name != "OfficialShared" {
			t.Fatalf("first registry should win for duplicate ID, got %q", theme.Name)
		}
	}

	if dir := r.GetThemeDir("two"); dir != base+"/extra/themes/two" {
		t.Fatalf("expected theme dir under extra registry, got %q", dir)
	}
	if path := r.GetThemeSourcePath("one"); path != base+"/official/themes/one/theme.json" {
		t.Fatalf("expected theme source under official registry, got %q", path)
	}
}
