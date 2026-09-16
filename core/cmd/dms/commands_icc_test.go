package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestStageProfile(t *testing.T) {
	configDir := t.TempDir()
	srcDir := t.TempDir()
	write := func(t *testing.T, path string, content string) {
		t.Helper()
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	read := func(t *testing.T, path string) string {
		t.Helper()
		data, err := os.ReadFile(path)
		if err != nil {
			t.Fatal(err)
		}
		return string(data)
	}

	first := filepath.Join(srcDir, "dp1", "display.icc")
	second := filepath.Join(srcDir, "dp2", "display.icc")
	write(t, first, "profile for DP-1")
	write(t, second, "profile for DP-2")

	dest1, copied, err := stageProfile(configDir, first)
	if err != nil {
		t.Fatalf("stageProfile(first): %v", err)
	}
	if !copied || dest1 != filepath.Join(configDir, "display.icc") {
		t.Fatalf("first copy: got %q copied=%v", dest1, copied)
	}

	dest2, copied, err := stageProfile(configDir, second)
	if err != nil {
		t.Fatalf("stageProfile(second): %v", err)
	}
	if !copied || dest2 != filepath.Join(configDir, "display-1.icc") {
		t.Fatalf("same-named different profile must get a sibling: got %q copied=%v", dest2, copied)
	}
	if got := read(t, dest1); got != "profile for DP-1" {
		t.Fatalf("first copy was overwritten: %q", got)
	}
	if got := read(t, dest2); got != "profile for DP-2" {
		t.Fatalf("second copy has wrong content: %q", got)
	}

	again, copied, err := stageProfile(configDir, second)
	if err != nil {
		t.Fatalf("stageProfile(second again): %v", err)
	}
	if copied || again != dest2 {
		t.Fatalf("an identical copy must be reused, not rewritten: got %q copied=%v", again, copied)
	}

	inPlace, copied, err := stageProfile(configDir, dest1)
	if err != nil {
		t.Fatalf("stageProfile(in place): %v", err)
	}
	if copied || inPlace != dest1 {
		t.Fatalf("a file already in the profile directory is used as it is: got %q copied=%v", inPlace, copied)
	}

	if _, _, err := stageProfile(configDir, filepath.Join(srcDir, "missing.icc")); err == nil {
		t.Fatal("expected an error for a missing source")
	}
}
