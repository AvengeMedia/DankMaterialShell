package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestCheckBundledGoogleSans(t *testing.T) {
	shellPath := t.TempDir()
	fontPath := filepath.Join(shellPath, "DankCommon", "assets", "fonts", "google-sans-flex", "GoogleSansFlex.ttf")
	missing := checkConfiguredFont("UI font", "Google Sans Flex", shellPath, "", false, "")
	if missing.status != statusWarn {
		t.Fatalf("missing bundled font status = %v, want %v", missing.status, statusWarn)
	}
	if err := os.MkdirAll(filepath.Dir(fontPath), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(fontPath, []byte("font"), 0o644); err != nil {
		t.Fatal(err)
	}
	for _, family := range []string{"Google Sans Flex", " google sans flex "} {
		result := checkConfiguredFont("UI font", family, shellPath, "", false, "")
		if result.status != statusOK {
			t.Fatalf("bundled font %q status = %v, want %v", family, result.status, statusOK)
		}
	}
}

func TestBundledDisplayFontsSkipFontconfig(t *testing.T) {
	for _, family := range []string{"DM Serif Display", "Notable"} {
		if !isBundledDefaultFont(family) {
			t.Fatalf("%q not recognized as bundled", family)
		}
	}
}
