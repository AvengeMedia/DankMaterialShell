package config

import (
	"os"
	"path/filepath"
	"testing"
)

func targetPathFor(t *testing.T, home string) string {
	t.Helper()
	return filepath.Join(home, ".config", "systemd", "user", "hyprland-session.target")
}

func TestEnsureHyprlandSessionTargetWritesMissing(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)

	path, err := EnsureHyprlandSessionTarget()
	if err != nil {
		t.Fatal(err)
	}
	if path != targetPathFor(t, home) {
		t.Fatalf("unexpected path %s", path)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != hyprlandSessionTargetUnit {
		t.Fatalf("unexpected content:\n%s", data)
	}
}

func TestEnsureHyprlandSessionTargetUpgradesLegacy(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	path := targetPathFor(t, home)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(legacyHyprlandSessionTargetUnit), 0o644); err != nil {
		t.Fatal(err)
	}

	if _, err := EnsureHyprlandSessionTarget(); err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(path)
	if string(data) != hyprlandSessionTargetUnit {
		t.Fatalf("legacy unit not upgraded:\n%s", data)
	}
}

func TestEnsureHyprlandSessionTargetKeepsCustom(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	path := targetPathFor(t, home)
	custom := "[Unit]\nDescription=mine\n"
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(custom), 0o644); err != nil {
		t.Fatal(err)
	}

	if _, err := EnsureHyprlandSessionTarget(); err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(path)
	if string(data) != custom {
		t.Fatalf("custom unit was overwritten:\n%s", data)
	}
}
