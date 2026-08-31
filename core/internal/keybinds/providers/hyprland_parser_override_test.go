package providers

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// hyprlandBindIndex flattens a parsed section into "SUPER+V" -> binding.
func hyprlandBindIndex(section HyprlandSection) map[string]HyprlandKeyBinding {
	index := make(map[string]HyprlandKeyBinding)
	var walk func(HyprlandSection)
	walk = func(s HyprlandSection) {
		for _, kb := range s.Keybinds {
			parts := append(append([]string{}, kb.Mods...), kb.Key)
			index[strings.ToUpper(strings.Join(parts, "+"))] = kb
		}
		for _, child := range s.Children {
			walk(child)
		}
	}
	walk(section)
	return index
}

func writeHyprlandConfig(t *testing.T, dir string, files map[string]string) {
	t.Helper()
	for name, content := range files {
		path := filepath.Join(dir, name)
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
}

// A user module that unbinds a DMS key and binds it again is an override: in
// Hyprland the DMS bind is gone and only the new one fires, so the modal has to
// show the new one. It used to show the DMS bind instead, because the unbind was
// discarded whenever the same file rebound the key and the rebind was then
// dropped as a conflicting config bind (#3145).
func TestParserShowsUnbindRebindOverrideFromUserModule(t *testing.T) {
	tmpDir := t.TempDir()
	writeHyprlandConfig(t, tmpDir, map[string]string{
		"hyprland.lua": `
require("dms.binds")
require("mybinds")
`,
		"dms/binds.lua": `hl.bind("SUPER + V", hl.dsp.exec_cmd("dms ipc call clipboard toggle"), { description = "Clipboard history" })
hl.bind("SUPER + T", hl.dsp.exec_cmd("kitty"), { description = "Terminal" })`,
		"mybinds.lua": `hl.unbind("SUPER + V")
hl.bind("SUPER + V", hl.dsp.togglefloating(), { description = "float toggle" })`,
	})

	result, err := ParseHyprlandKeysWithDMS(tmpDir)
	if err != nil {
		t.Fatal(err)
	}

	binds := hyprlandBindIndex(*result.Section)
	got, ok := binds["SUPER+V"]
	if !ok {
		t.Fatalf("SUPER+V missing entirely, got keys: %v", bindKeys(binds))
	}
	if got.Comment != "float toggle" {
		t.Errorf("SUPER+V shows %q from %s, want the override %q",
			got.Comment, filepath.Base(got.Source), "float toggle")
	}
	if filepath.Base(got.Source) != "mybinds.lua" {
		t.Errorf("SUPER+V sourced from %s, want mybinds.lua", filepath.Base(got.Source))
	}
	if _, ok := binds["SUPER+T"]; !ok {
		t.Errorf("SUPER+T should be untouched, got keys: %v", bindKeys(binds))
	}
	// An unbind makes this an override rather than two live binds on one key.
	if result.DMSStatus.BindsAfterDMS != 0 {
		t.Errorf("BindsAfterDMS = %d, want 0 for an unbind+rebind override",
			result.DMSStatus.BindsAfterDMS)
	}
}

// Without an unbind both binds stay live in Hyprland. That is the ambiguous case
// the conflict counter is for, and it must keep behaving as before.
func TestParserStillReportsConflictWithoutUnbind(t *testing.T) {
	tmpDir := t.TempDir()
	writeHyprlandConfig(t, tmpDir, map[string]string{
		"hyprland.lua": `
require("dms.binds")
require("mybinds")
`,
		"dms/binds.lua": `hl.bind("SUPER + V", hl.dsp.exec_cmd("dms ipc call clipboard toggle"), { description = "Clipboard history" })`,
		"mybinds.lua":   `hl.bind("SUPER + V", hl.dsp.togglefloating(), { description = "float toggle" })`,
	})

	result, err := ParseHyprlandKeysWithDMS(tmpDir)
	if err != nil {
		t.Fatal(err)
	}

	binds := hyprlandBindIndex(*result.Section)
	got, ok := binds["SUPER+V"]
	if !ok {
		t.Fatalf("SUPER+V missing entirely, got keys: %v", bindKeys(binds))
	}
	if got.Comment != "Clipboard history" {
		t.Errorf("SUPER+V shows %q, want the DMS bind to be kept as before", got.Comment)
	}
	if result.DMSStatus.BindsAfterDMS != 1 {
		t.Errorf("BindsAfterDMS = %d, want 1 for a config bind without unbind",
			result.DMSStatus.BindsAfterDMS)
	}
}

// An unbind without a rebind stays a plain removal, from a user module as well
// as from dms/binds-user.lua.
func TestParserUnbindWithoutRebindStillRemoves(t *testing.T) {
	tmpDir := t.TempDir()
	writeHyprlandConfig(t, tmpDir, map[string]string{
		"hyprland.lua": `
require("dms.binds")
require("mybinds")
`,
		"dms/binds.lua": `hl.bind("SUPER + V", hl.dsp.exec_cmd("dms ipc call clipboard toggle"))
hl.bind("SUPER + T", hl.dsp.exec_cmd("kitty"))`,
		"mybinds.lua": `hl.unbind("SUPER + V")`,
	})

	result, err := ParseHyprlandKeysWithDMS(tmpDir)
	if err != nil {
		t.Fatal(err)
	}

	binds := hyprlandBindIndex(*result.Section)
	if _, ok := binds["SUPER+V"]; ok {
		t.Errorf("SUPER+V should be removed by the bare unbind, got keys: %v", bindKeys(binds))
	}
	if _, ok := binds["SUPER+T"]; !ok {
		t.Errorf("SUPER+T should remain, got keys: %v", bindKeys(binds))
	}
}

// dms/binds-user.lua is what the settings modal writes, and it writes an unbind
// followed by a bind. Recording that unbind must not delete the rebind that
// comes with it.
func TestParserKeepsBindsUserRebindAfterItsOwnUnbind(t *testing.T) {
	tmpDir := t.TempDir()
	writeHyprlandConfig(t, tmpDir, map[string]string{
		"hyprland.lua": `
require("dms.binds")
require("dms.binds-user")
`,
		"dms/binds.lua": `hl.bind("SUPER + V", hl.dsp.exec_cmd("dms ipc call clipboard toggle"), { description = "Clipboard history" })
hl.bind("SUPER + T", hl.dsp.exec_cmd("kitty"), { description = "Terminal" })`,
		"dms/binds-user.lua": `hl.unbind("SUPER + V")
hl.bind("SUPER + V", hl.dsp.togglefloating(), { description = "float toggle" })`,
	})

	result, err := ParseHyprlandKeysWithDMS(tmpDir)
	if err != nil {
		t.Fatal(err)
	}

	binds := hyprlandBindIndex(*result.Section)
	got, ok := binds["SUPER+V"]
	if !ok {
		t.Fatalf("SUPER+V missing entirely, got keys: %v", bindKeys(binds))
	}
	if got.Comment != "float toggle" {
		t.Errorf("SUPER+V shows %q from %s, want the binds-user.lua override",
			got.Comment, filepath.Base(got.Source))
	}
	if _, ok := binds["SUPER+T"]; !ok {
		t.Errorf("SUPER+T should be untouched, got keys: %v", bindKeys(binds))
	}
}

func bindKeys(binds map[string]HyprlandKeyBinding) []string {
	keys := make([]string, 0, len(binds))
	for k := range binds {
		keys = append(keys, k)
	}
	return keys
}
