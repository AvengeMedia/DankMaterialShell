package providers

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/keybinds"
)

func TestHyprlandAutogenerateComment(t *testing.T) {
	tests := []struct {
		dispatcher string
		params     string
		expected   string
	}{
		{"resizewindow", "", "Resize window"},
		{"movewindow", "", "Move window"},
		{"movewindow", "l", "move in left direction"},
		{"movewindow", "r", "move in right direction"},
		{"movewindow", "u", "move in up direction"},
		{"movewindow", "d", "move in down direction"},
		{"pin", "", "pin (show on all workspaces)"},
		{"splitratio", "0.5", "Window split ratio 0.5"},
		{"togglefloating", "", "Float/unfloat window"},
		{"resizeactive", "10 20", "Resize window by 10 20"},
		{"killactive", "", "Close window"},
		{"fullscreen", "0", "Toggle fullscreen"},
		{"fullscreen", "1", "Toggle maximization"},
		{"fullscreen", "2", "Toggle fullscreen on Hyprland's side"},
		{"fakefullscreen", "", "Toggle fake fullscreen"},
		{"workspace", "+1", "focus right"},
		{"workspace", "-1", "focus left"},
		{"workspace", "5", "focus workspace 5"},
		{"movefocus", "l", "move focus left"},
		{"movefocus", "r", "move focus right"},
		{"movefocus", "u", "move focus up"},
		{"movefocus", "d", "move focus down"},
		{"swapwindow", "l", "swap in left direction"},
		{"swapwindow", "r", "swap in right direction"},
		{"swapwindow", "u", "swap in up direction"},
		{"swapwindow", "d", "swap in down direction"},
		{"movetoworkspace", "+1", "move to right workspace (non-silent)"},
		{"movetoworkspace", "-1", "move to left workspace (non-silent)"},
		{"movetoworkspace", "3", "move to workspace 3 (non-silent)"},
		{"movetoworkspacesilent", "+1", "move to right workspace"},
		{"movetoworkspacesilent", "-1", "move to right workspace"},
		{"movetoworkspacesilent", "2", "move to workspace 2"},
		{"togglespecialworkspace", "", "toggle special"},
		{"exec", "firefox", "firefox"},
		{"unknown", "", ""},
	}

	for _, tt := range tests {
		t.Run(tt.dispatcher+"_"+tt.params, func(t *testing.T) {
			result := hyprlandAutogenerateComment(tt.dispatcher, tt.params)
			if result != tt.expected {
				t.Errorf("hyprlandAutogenerateComment(%q, %q) = %q, want %q",
					tt.dispatcher, tt.params, result, tt.expected)
			}
		})
	}
}

func TestHyprlandLuaBindRoundTripHelpers(t *testing.T) {
	tests := []struct {
		expr           string
		wantDispatcher string
		wantParams     string
	}{
		{`hl.dsp.exec_cmd([[dms ipc call brightness increment 5 ""]])`, "exec", `dms ipc call brightness increment 5 ""`},
		{`hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })`, "fullscreen", "1"},
		{`hl.dsp.focus({ workspace = "e+1" })`, "workspace", "e+1"},
		{`hl.dsp.window.move({ monitor = "l" })`, "movewindow", "mon:l"},
		{`hl.dsp.window.resize({ x = "-10%", y = 0, relative = true })`, "resizeactive", "-10% 0"},
		{`hl.dsp.layout("togglesplit")`, "layoutmsg", "togglesplit"},
		{`hl.dsp.dpms({ action = "toggle" })`, "dpms", "toggle"},
	}

	for _, tt := range tests {
		t.Run(tt.expr, func(t *testing.T) {
			gotDispatcher, gotParams := luaExprToDispatcherParams(tt.expr)
			if gotDispatcher != tt.wantDispatcher || gotParams != tt.wantParams {
				t.Fatalf("luaExprToDispatcherParams() = %q, %q; want %q, %q", gotDispatcher, gotParams, tt.wantDispatcher, tt.wantParams)
			}
		})
	}
}

func TestWriteLuaBindLineOptionsInsideCall(t *testing.T) {
	var sb strings.Builder
	writeLuaBindLine(&sb, &hyprlandOverrideBind{
		Key:         "Super+k",
		Action:      "exec kitty",
		Description: "Open terminal",
		Flags:       "led",
	})

	want := `hl.unbind("SUPER + K")
hl.bind("SUPER + K", hl.dsp.exec_cmd("kitty"), { locked = true, repeating = true, description = "Open terminal" })`
	if got := strings.TrimSpace(sb.String()); got != want {
		t.Fatalf("writeLuaBindLine() = %q, want %q", got, want)
	}
}

func TestWriteLuaBindLineMapsSpawnActionForHyprland(t *testing.T) {
	var sb strings.Builder
	writeLuaBindLine(&sb, &hyprlandOverrideBind{
		Key:         "Super+n",
		Action:      "spawn dms ipc call notepad toggle",
		Description: "Notepad: Toggle",
	})

	want := `hl.unbind("SUPER + N")
hl.bind("SUPER + N", hl.dsp.exec_cmd("dms ipc call notepad toggle")) -- Notepad: Toggle`
	if got := strings.TrimSpace(sb.String()); got != want {
		t.Fatalf("writeLuaBindLine() = %q, want %q", got, want)
	}
}

func TestHyprlandLuaBindsUserOverridesDefaults(t *testing.T) {
	tmpDir := t.TempDir()
	dmsDir := filepath.Join(tmpDir, "dms")
	if err := os.MkdirAll(dmsDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(tmpDir, "hyprland.lua"), []byte(`
require("dms.binds")
require("dms.binds-user")
`), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dmsDir, "binds.lua"), []byte(`hl.bind("SUPER + T", hl.dsp.exec_cmd("kitty"))`), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dmsDir, "binds-user.lua"), []byte(`hl.bind("SUPER + T", hl.dsp.exec_cmd("foot"), { description = "User terminal" })`), 0o644); err != nil {
		t.Fatal(err)
	}

	result, err := ParseHyprlandKeysWithDMS(tmpDir)
	if err != nil {
		t.Fatal(err)
	}

	var found []HyprlandKeyBinding
	var walk func(HyprlandSection)
	walk = func(section HyprlandSection) {
		for _, kb := range section.Keybinds {
			if strings.EqualFold(strings.Join(append(kb.Mods, kb.Key), "+"), "SUPER+T") {
				found = append(found, kb)
			}
		}
		for _, child := range section.Children {
			walk(child)
		}
	}
	walk(*result.Section)

	if len(found) != 1 {
		t.Fatalf("expected one effective SUPER+T bind, got %d: %#v", len(found), found)
	}
	if found[0].Params != "foot" || found[0].Comment != "User terminal" {
		t.Fatalf("expected user override bind, got %#v", found[0])
	}
}

func TestWriteLuaBindLineEmitsUnbindOnlyForNegativeOverride(t *testing.T) {
	var sb strings.Builder
	writeLuaBindLine(&sb, &hyprlandOverrideBind{Key: "Super+i", Unbind: true})

	want := `hl.unbind("SUPER + I")`
	if got := strings.TrimSpace(sb.String()); got != want {
		t.Fatalf("writeLuaBindLine() = %q, want %q", got, want)
	}
}

func TestReadLuaOverrideRecognizesLoneUnbindAsNegativeOverride(t *testing.T) {
	tmpDir := t.TempDir()
	overridePath := filepath.Join(tmpDir, "binds-user.lua")
	contents := `-- DMS user keybind overrides
hl.unbind("SUPER + I")
hl.unbind("SUPER + N")
hl.bind("SUPER + N", hl.dsp.exec_cmd("dms ipc call notepad toggle"))
`
	if err := os.WriteFile(overridePath, []byte(contents), 0o644); err != nil {
		t.Fatal(err)
	}

	binds, err := readLuaOrHyprlangOverride(overridePath)
	if err != nil {
		t.Fatal(err)
	}

	got, ok := binds["super+i"]
	if !ok {
		t.Fatalf("expected SUPER+I entry in override map, got: %#v", binds)
	}
	if !got.Unbind {
		t.Fatalf("expected SUPER+I to be marked Unbind, got: %#v", got)
	}
	if rebind, ok := binds["super+n"]; !ok || rebind.Unbind {
		t.Fatalf("expected SUPER+N to be a normal rebind override, got: %#v", rebind)
	}
}

func TestParserDropsDMSDefaultsSuppressedByBindsUserUnbind(t *testing.T) {
	tmpDir := t.TempDir()
	dmsDir := filepath.Join(tmpDir, "dms")
	if err := os.MkdirAll(dmsDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(tmpDir, "hyprland.lua"), []byte(`
require("dms.binds")
require("dms.binds-user")
`), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dmsDir, "binds.lua"), []byte(
		`hl.bind("SUPER + I", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + T", hl.dsp.exec_cmd("kitty"))`,
	), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dmsDir, "binds-user.lua"), []byte(`hl.unbind("SUPER + I")`), 0o644); err != nil {
		t.Fatal(err)
	}

	result, err := ParseHyprlandKeysWithDMS(tmpDir)
	if err != nil {
		t.Fatal(err)
	}

	var keys []string
	var walk func(HyprlandSection)
	walk = func(section HyprlandSection) {
		for _, kb := range section.Keybinds {
			keys = append(keys, strings.ToUpper(strings.Join(append(kb.Mods, kb.Key), "+")))
		}
		for _, child := range section.Children {
			walk(child)
		}
	}
	walk(*result.Section)

	for _, k := range keys {
		if k == "SUPER+I" {
			t.Fatalf("expected SUPER+I to be suppressed by binds-user.lua unbind, got: %v", keys)
		}
	}
	foundT := false
	for _, k := range keys {
		if k == "SUPER+T" {
			foundT = true
		}
	}
	if !foundT {
		t.Fatalf("expected SUPER+T to remain (only SUPER+I was unbound), got: %v", keys)
	}
}

func TestHyprlandRemoveBindWritesNegativeOverrideForDefault(t *testing.T) {
	tmpDir := t.TempDir()
	dmsDir := filepath.Join(tmpDir, "dms")
	if err := os.MkdirAll(dmsDir, 0o755); err != nil {
		t.Fatal(err)
	}

	provider := NewHyprlandProvider(tmpDir)
	if err := provider.RemoveBind("SUPER+I"); err != nil {
		t.Fatal(err)
	}

	data, err := os.ReadFile(filepath.Join(dmsDir, "binds-user.lua"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(data), `hl.unbind("SUPER + I")`) {
		t.Fatalf("expected negative override hl.unbind line, got:\n%s", string(data))
	}
	if strings.Contains(string(data), `hl.bind("SUPER + I"`) {
		t.Fatalf("expected NO hl.bind for SUPER+I, got:\n%s", string(data))
	}
}

func TestHyprlandRemoveBindReplacesExistingOverrideWithNegativeOverride(t *testing.T) {
	tmpDir := t.TempDir()
	dmsDir := filepath.Join(tmpDir, "dms")
	if err := os.MkdirAll(dmsDir, 0o755); err != nil {
		t.Fatal(err)
	}
	override := `hl.unbind("SUPER + N")
hl.bind("SUPER + N", hl.dsp.exec_cmd("dms ipc call notepad toggle"))
`
	if err := os.WriteFile(filepath.Join(dmsDir, "binds-user.lua"), []byte(override), 0o644); err != nil {
		t.Fatal(err)
	}

	provider := NewHyprlandProvider(tmpDir)
	if err := provider.RemoveBind("SUPER+N"); err != nil {
		t.Fatal(err)
	}

	data, err := os.ReadFile(filepath.Join(dmsDir, "binds-user.lua"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(data), `hl.unbind("SUPER + N")`) {
		t.Fatalf("expected negative override hl.unbind line, got:\n%s", string(data))
	}
	if strings.Contains(string(data), `hl.bind("SUPER + N"`) {
		t.Fatalf("expected NO hl.bind for SUPER+N after remove, got:\n%s", string(data))
	}
}

func TestHyprlandResetBindRevertsExistingOverrideToDefault(t *testing.T) {
	tmpDir := t.TempDir()
	dmsDir := filepath.Join(tmpDir, "dms")
	if err := os.MkdirAll(dmsDir, 0o755); err != nil {
		t.Fatal(err)
	}
	override := `hl.unbind("SUPER + N")
hl.bind("SUPER + N", hl.dsp.exec_cmd("dms ipc call notepad toggle"))
`
	if err := os.WriteFile(filepath.Join(dmsDir, "binds-user.lua"), []byte(override), 0o644); err != nil {
		t.Fatal(err)
	}

	provider := NewHyprlandProvider(tmpDir)
	if err := provider.ResetBind("SUPER+N"); err != nil {
		t.Fatal(err)
	}

	data, err := os.ReadFile(filepath.Join(dmsDir, "binds-user.lua"))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(data), `SUPER + N`) {
		t.Fatalf("expected SUPER+N to be fully removed (revert to default), got:\n%s", string(data))
	}
}

func TestHyprlandHasDefaultSetForOverrideOfDefaultKey(t *testing.T) {
	tmpDir := t.TempDir()
	dmsDir := filepath.Join(tmpDir, "dms")
	if err := os.MkdirAll(dmsDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(tmpDir, "hyprland.lua"), []byte(`
require("dms.binds")
require("dms.binds-user")
`), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dmsDir, "binds.lua"), []byte(
		`hl.bind("SUPER + T", hl.dsp.exec_cmd("kitty"))`,
	), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dmsDir, "binds-user.lua"), []byte(
		`hl.unbind("SUPER + T")
hl.bind("SUPER + T", hl.dsp.exec_cmd("foot"))
hl.bind("SUPER + Z", hl.dsp.exec_cmd("custom"))`,
	), 0o644); err != nil {
		t.Fatal(err)
	}

	provider := NewHyprlandProvider(tmpDir)
	sheet, err := provider.GetCheatSheet()
	if err != nil {
		t.Fatal(err)
	}

	var foundT, foundZ *keybinds.Keybind
	for _, group := range sheet.Binds {
		for i := range group {
			kb := group[i]
			keyUpper := strings.ToUpper(kb.Key)
			if keyUpper == "SUPER+T" {
				foundT = &group[i]
			}
			if keyUpper == "SUPER+Z" {
				foundZ = &group[i]
			}
		}
	}
	if foundT == nil {
		t.Fatalf("expected SUPER+T override in cheatsheet")
	}
	if !foundT.HasDefault {
		t.Fatalf("expected SUPER+T HasDefault=true (default exists in binds.lua), got %+v", foundT)
	}
	if foundZ == nil {
		t.Fatalf("expected SUPER+Z (user-only) in cheatsheet")
	}
	if foundZ.HasDefault {
		t.Fatalf("expected SUPER+Z HasDefault=false (no default), got %+v", foundZ)
	}
}

func TestHyprlandGetKeybindAtLine(t *testing.T) {
	tests := []struct {
		name     string
		line     string
		expected *HyprlandKeyBinding
	}{
		{
			name: "basic_keybind",
			line: "bind = SUPER, Q, killactive",
			expected: &HyprlandKeyBinding{
				Mods:       []string{"SUPER"},
				Key:        "Q",
				Dispatcher: "killactive",
				Params:     "",
				Comment:    "Close window",
			},
		},
		{
			name: "keybind_with_params",
			line: "bind = SUPER, left, movefocus, l",
			expected: &HyprlandKeyBinding{
				Mods:       []string{"SUPER"},
				Key:        "left",
				Dispatcher: "movefocus",
				Params:     "l",
				Comment:    "move focus left",
			},
		},
		{
			name: "keybind_with_comment",
			line: "bind = SUPER, T, exec, kitty # Open terminal",
			expected: &HyprlandKeyBinding{
				Mods:       []string{"SUPER"},
				Key:        "T",
				Dispatcher: "exec",
				Params:     "kitty",
				Comment:    "Open terminal",
			},
		},
		{
			name:     "keybind_hidden",
			line:     "bind = SUPER, H, exec, secret # [hidden]",
			expected: nil,
		},
		{
			name: "keybind_multiple_mods",
			line: "bind = SUPER+SHIFT, F, fullscreen, 0",
			expected: &HyprlandKeyBinding{
				Mods:       []string{"SUPER", "SHIFT"},
				Key:        "F",
				Dispatcher: "fullscreen",
				Params:     "0",
				Comment:    "Toggle fullscreen",
			},
		},
		{
			name: "keybind_no_mods",
			line: "bind = , Print, exec, screenshot",
			expected: &HyprlandKeyBinding{
				Mods:       []string{},
				Key:        "Print",
				Dispatcher: "exec",
				Params:     "screenshot",
				Comment:    "screenshot",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			parser := NewHyprlandParser("")
			parser.contentLines = []string{tt.line}
			result := parser.getKeybindAtLine(0)

			if tt.expected == nil {
				if result != nil {
					t.Errorf("expected nil, got %+v", result)
				}
				return
			}

			if result == nil {
				t.Errorf("expected %+v, got nil", tt.expected)
				return
			}

			if result.Key != tt.expected.Key {
				t.Errorf("Key = %q, want %q", result.Key, tt.expected.Key)
			}
			if result.Dispatcher != tt.expected.Dispatcher {
				t.Errorf("Dispatcher = %q, want %q", result.Dispatcher, tt.expected.Dispatcher)
			}
			if result.Params != tt.expected.Params {
				t.Errorf("Params = %q, want %q", result.Params, tt.expected.Params)
			}
			if result.Comment != tt.expected.Comment {
				t.Errorf("Comment = %q, want %q", result.Comment, tt.expected.Comment)
			}
			if len(result.Mods) != len(tt.expected.Mods) {
				t.Errorf("Mods length = %d, want %d", len(result.Mods), len(tt.expected.Mods))
			} else {
				for i := range result.Mods {
					if result.Mods[i] != tt.expected.Mods[i] {
						t.Errorf("Mods[%d] = %q, want %q", i, result.Mods[i], tt.expected.Mods[i])
					}
				}
			}
		})
	}
}

func TestHyprlandParseKeysWithSections(t *testing.T) {
	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "hyprland.conf")

	content := `##! Window Management
bind = SUPER, Q, killactive
bind = SUPER, F, fullscreen, 0

###! Movement
bind = SUPER, left, movefocus, l
bind = SUPER, right, movefocus, r

##! Applications
bind = SUPER, T, exec, kitty # Terminal
`

	if err := os.WriteFile(configFile, []byte(content), 0o644); err != nil {
		t.Fatalf("Failed to write test config: %v", err)
	}

	section, err := ParseHyprlandKeys(tmpDir)
	if err != nil {
		t.Fatalf("ParseHyprlandKeys failed: %v", err)
	}

	if len(section.Children) != 2 {
		t.Errorf("Expected 2 top-level sections, got %d", len(section.Children))
	}

	if len(section.Children) >= 1 {
		windowMgmt := section.Children[0]
		if windowMgmt.Name != "Window Management" {
			t.Errorf("First section name = %q, want %q", windowMgmt.Name, "Window Management")
		}
		if len(windowMgmt.Keybinds) != 2 {
			t.Errorf("Window Management keybinds = %d, want 2", len(windowMgmt.Keybinds))
		}

		if len(windowMgmt.Children) != 1 {
			t.Errorf("Window Management children = %d, want 1", len(windowMgmt.Children))
		} else {
			movement := windowMgmt.Children[0]
			if movement.Name != "Movement" {
				t.Errorf("Movement section name = %q, want %q", movement.Name, "Movement")
			}
			if len(movement.Keybinds) != 2 {
				t.Errorf("Movement keybinds = %d, want 2", len(movement.Keybinds))
			}
		}
	}

	if len(section.Children) >= 2 {
		apps := section.Children[1]
		if apps.Name != "Applications" {
			t.Errorf("Second section name = %q, want %q", apps.Name, "Applications")
		}
		if len(apps.Keybinds) != 1 {
			t.Errorf("Applications keybinds = %d, want 1", len(apps.Keybinds))
		}
		if len(apps.Keybinds) > 0 && apps.Keybinds[0].Comment != "Terminal" {
			t.Errorf("Applications keybind comment = %q, want %q", apps.Keybinds[0].Comment, "Terminal")
		}
	}
}

func TestHyprlandParseKeysWithCommentBinds(t *testing.T) {
	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "test.conf")

	content := `#/# = SUPER, A, exec, app1
bind = SUPER, B, exec, app2
#/# = SUPER, C, exec, app3 # Custom comment
`

	if err := os.WriteFile(configFile, []byte(content), 0o644); err != nil {
		t.Fatalf("Failed to write test config: %v", err)
	}

	section, err := ParseHyprlandKeys(tmpDir)
	if err != nil {
		t.Fatalf("ParseHyprlandKeys failed: %v", err)
	}

	if len(section.Keybinds) != 3 {
		t.Errorf("Expected 3 keybinds, got %d", len(section.Keybinds))
	}

	if len(section.Keybinds) > 0 && section.Keybinds[0].Key != "A" {
		t.Errorf("First keybind key = %q, want %q", section.Keybinds[0].Key, "A")
	}
	if len(section.Keybinds) > 1 && section.Keybinds[1].Key != "B" {
		t.Errorf("Second keybind key = %q, want %q", section.Keybinds[1].Key, "B")
	}
	if len(section.Keybinds) > 2 && section.Keybinds[2].Comment != "Custom comment" {
		t.Errorf("Third keybind comment = %q, want %q", section.Keybinds[2].Comment, "Custom comment")
	}
}

func TestHyprlandReadContentMultipleFiles(t *testing.T) {
	tmpDir := t.TempDir()

	file1 := filepath.Join(tmpDir, "a.conf")
	file2 := filepath.Join(tmpDir, "b.conf")

	content1 := "bind = SUPER, Q, killactive\n"
	content2 := "bind = SUPER, T, exec, kitty\n"

	if err := os.WriteFile(file1, []byte(content1), 0o644); err != nil {
		t.Fatalf("Failed to write file1: %v", err)
	}
	if err := os.WriteFile(file2, []byte(content2), 0o644); err != nil {
		t.Fatalf("Failed to write file2: %v", err)
	}

	parser := NewHyprlandParser("")
	if err := parser.ReadContent(tmpDir); err != nil {
		t.Fatalf("ReadContent failed: %v", err)
	}

	section := parser.ParseKeys()
	if len(section.Keybinds) != 2 {
		t.Errorf("Expected 2 keybinds from multiple files, got %d", len(section.Keybinds))
	}
}

func TestHyprlandReadContentErrors(t *testing.T) {
	tests := []struct {
		name string
		path string
	}{
		{
			name: "nonexistent_directory",
			path: "/nonexistent/path/that/does/not/exist",
		},
		{
			name: "empty_directory",
			path: t.TempDir(),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := ParseHyprlandKeys(tt.path)
			if err == nil {
				t.Error("Expected error, got nil")
			}
		})
	}
}

func TestHyprlandReadContentWithTildeExpansion(t *testing.T) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		t.Skip("Cannot get home directory")
	}

	tmpSubdir := filepath.Join(homeDir, ".config", "test-hypr-"+t.Name())
	if err := os.MkdirAll(tmpSubdir, 0o755); err != nil {
		t.Skip("Cannot create test directory in home")
	}
	defer os.RemoveAll(tmpSubdir)

	configFile := filepath.Join(tmpSubdir, "test.conf")
	if err := os.WriteFile(configFile, []byte("bind = SUPER, Q, killactive\n"), 0o644); err != nil {
		t.Fatalf("Failed to write test config: %v", err)
	}

	relPath, err := filepath.Rel(homeDir, tmpSubdir)
	if err != nil {
		t.Skip("Cannot create relative path")
	}

	parser := NewHyprlandParser("")
	tildePathMatch := "~/" + relPath
	err = parser.ReadContent(tildePathMatch)

	if err != nil {
		t.Errorf("ReadContent with tilde path failed: %v", err)
	}
}

func TestHyprlandKeybindWithParamsContainingCommas(t *testing.T) {
	parser := NewHyprlandParser("")
	parser.contentLines = []string{"bind = SUPER, R, exec, notify-send 'Title' 'Message, with comma'"}

	result := parser.getKeybindAtLine(0)

	if result == nil {
		t.Fatal("Expected keybind, got nil")
	}

	expected := "notify-send 'Title' 'Message, with comma'"
	if result.Params != expected {
		t.Errorf("Params = %q, want %q", result.Params, expected)
	}
}

func TestHyprlandEmptyAndCommentLines(t *testing.T) {
	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "test.conf")

	content := `
# This is a comment
bind = SUPER, Q, killactive

# Another comment

bind = SUPER, T, exec, kitty
`

	if err := os.WriteFile(configFile, []byte(content), 0o644); err != nil {
		t.Fatalf("Failed to write test config: %v", err)
	}

	section, err := ParseHyprlandKeys(tmpDir)
	if err != nil {
		t.Fatalf("ParseHyprlandKeys failed: %v", err)
	}

	if len(section.Keybinds) != 2 {
		t.Errorf("Expected 2 keybinds (comments ignored), got %d", len(section.Keybinds))
	}
}

func TestExtractBindFlags(t *testing.T) {
	tests := []struct {
		bindType string
		expected string
	}{
		{"bind", ""},
		{"binde", "e"},
		{"bindl", "l"},
		{"bindr", "r"},
		{"bindd", "d"},
		{"bindo", "o"},
		{"bindel", "el"},
		{"bindler", "ler"},
		{"bindem", "em"},
		{"  bind  ", ""},
		{"  binde  ", "e"},
		{"notbind", ""},
		{"", ""},
	}

	for _, tt := range tests {
		t.Run(tt.bindType, func(t *testing.T) {
			result := extractBindFlags(tt.bindType)
			if result != tt.expected {
				t.Errorf("extractBindFlags(%q) = %q, want %q", tt.bindType, result, tt.expected)
			}
		})
	}
}

func TestHyprlandBindFlags(t *testing.T) {
	tests := []struct {
		name          string
		line          string
		expectedFlags string
		expectedKey   string
		expectedDisp  string
		expectedDesc  string
	}{
		{
			name:          "regular bind",
			line:          "bind = SUPER, Q, killactive",
			expectedFlags: "",
			expectedKey:   "Q",
			expectedDisp:  "killactive",
			expectedDesc:  "Close window",
		},
		{
			name:          "binde (repeat on hold)",
			line:          "binde = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+",
			expectedFlags: "e",
			expectedKey:   "XF86AudioRaiseVolume",
			expectedDisp:  "exec",
			expectedDesc:  "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+",
		},
		{
			name:          "bindl (locked/inhibitor bypass)",
			line:          "bindl = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
			expectedFlags: "l",
			expectedKey:   "XF86AudioLowerVolume",
			expectedDisp:  "exec",
			expectedDesc:  "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
		},
		{
			name:          "bindr (release trigger)",
			line:          "bindr = SUPER, SUPER_L, exec, pkill wofi || wofi",
			expectedFlags: "r",
			expectedKey:   "SUPER_L",
			expectedDisp:  "exec",
			expectedDesc:  "pkill wofi || wofi",
		},
		{
			name:          "bindd (description)",
			line:          "bindd = SUPER, Q, Open my favourite terminal, exec, kitty",
			expectedFlags: "d",
			expectedKey:   "Q",
			expectedDisp:  "exec",
			expectedDesc:  "Open my favourite terminal",
		},
		{
			name:          "bindo (long press)",
			line:          "bindo = SUPER, XF86AudioNext, exec, playerctl next",
			expectedFlags: "o",
			expectedKey:   "XF86AudioNext",
			expectedDisp:  "exec",
			expectedDesc:  "playerctl next",
		},
		{
			name:          "bindel (combined flags)",
			line:          "bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+",
			expectedFlags: "el",
			expectedKey:   "XF86AudioRaiseVolume",
			expectedDisp:  "exec",
			expectedDesc:  "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			parser := NewHyprlandParser("")
			parser.contentLines = []string{tt.line}
			result := parser.getKeybindAtLine(0)

			if result == nil {
				t.Fatal("Expected keybind, got nil")
			}

			if result.Flags != tt.expectedFlags {
				t.Errorf("Flags = %q, want %q", result.Flags, tt.expectedFlags)
			}
			if result.Key != tt.expectedKey {
				t.Errorf("Key = %q, want %q", result.Key, tt.expectedKey)
			}
			if result.Dispatcher != tt.expectedDisp {
				t.Errorf("Dispatcher = %q, want %q", result.Dispatcher, tt.expectedDisp)
			}
			if result.Comment != tt.expectedDesc {
				t.Errorf("Comment = %q, want %q", result.Comment, tt.expectedDesc)
			}
		})
	}
}
