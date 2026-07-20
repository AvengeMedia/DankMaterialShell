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
