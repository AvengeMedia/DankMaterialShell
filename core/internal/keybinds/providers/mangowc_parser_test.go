package providers

import (
	"os"
	"path/filepath"
	"testing"
)

func TestMangoWCParseAxisBindToScrollKey(t *testing.T) {
	tmpDir := t.TempDir()
	cfg := filepath.Join(tmpDir, "config.conf")
	content := "axisbind=SUPER,UP,spawn,dms ipc call test\n"
	if err := os.WriteFile(cfg, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	binds, err := ParseMangoWCKeys(cfg)
	if err != nil {
		t.Fatalf("ParseMangoWCKeys failed: %v", err)
	}
	if len(binds) != 1 {
		t.Fatalf("expected 1 bind, got %d", len(binds))
	}
	if binds[0].Key != "WheelScrollUp" {
		t.Fatalf("expected axis direction parsed as WheelScrollUp, got %q", binds[0].Key)
	}
	if len(binds[0].Mods) != 1 || binds[0].Mods[0] != "SUPER" {
		t.Fatalf("expected SUPER mod, got %v", binds[0].Mods)
	}
}

func TestMangoWCAutogenerateComment(t *testing.T) {
	tests := []struct {
		command  string
		params   string
		expected string
	}{
		{"spawn", "kitty", "kitty"},
		{"killclient", "", "Close window"},
		{"focusstack", "next", "Focus next window"},
		{"focusstack", "prev", "Focus previous window"},
		{"focusdir", "left", "Focus left"},
		{"exchange_client", "left", "Swap window left"},
		{"move_client", "left", "Move window left"},
		{"scroller_stack", "up", "Stack window up"},
		{"togglejump", "", "Jump to window"},
		{"setlayout", "tile", "Set layout tile"},
		{"view", "1,0", "View tag 1"},
		{"tag", "2,0", "Move to tag 2"},
		{"toggleview", "3,0", "Toggle tag 3"},
		{"viewtoleft_have_client", "", "View left tag"},
		{"focusmon", "left", "Focus monitor left"},
		{"incgaps", "1", "Increase gaps"},
		{"incgaps", "-1", "Decrease gaps"},
		{"movewin", "+0,-50", "Move window by +0,-50"},
		{"unknown", "", ""},
	}

	for _, tt := range tests {
		t.Run(tt.command+"_"+tt.params, func(t *testing.T) {
			result := mangowcAutogenerateComment(tt.command, tt.params)
			if result != tt.expected {
				t.Errorf("mangowcAutogenerateComment(%q, %q) = %q, want %q",
					tt.command, tt.params, result, tt.expected)
			}
		})
	}
}

func TestMangoWCGetKeybindAtLine(t *testing.T) {
	tests := []struct {
		name             string
		line             string
		precedingComment string
		expected         *MangoWCKeyBinding
	}{
		{
			name: "basic_keybind",
			line: "bind=ALT,q,killclient,",
			expected: &MangoWCKeyBinding{
				Mods:    []string{"ALT"},
				Key:     "q",
				Command: "killclient",
				Params:  "",
				Comment: "Close window",
			},
		},
		{
			name: "keybind_with_params",
			line: "bind=ALT,Left,focusdir,left",
			expected: &MangoWCKeyBinding{
				Mods:    []string{"ALT"},
				Key:     "Left",
				Command: "focusdir",
				Params:  "left",
				Comment: "Focus left",
			},
		},
		{
			name: "keybind_with_comment",
			line: "bind=Alt,t,spawn,kitty # Open terminal",
			expected: &MangoWCKeyBinding{
				Mods:    []string{"Alt"},
				Key:     "t",
				Command: "spawn",
				Params:  "kitty",
				Comment: "Open terminal",
			},
		},
		{
			name:     "keybind_hidden",
			line:     "bind=SUPER,h,spawn,secret # [hidden]",
			expected: nil,
		},
		{
			name: "keybind_multiple_mods",
			line: "bind=SUPER+SHIFT,Up,exchange_client,up",
			expected: &MangoWCKeyBinding{
				Mods:    []string{"SUPER", "SHIFT"},
				Key:     "Up",
				Command: "exchange_client",
				Params:  "up",
				Comment: "Swap window up",
			},
		},
		{
			name: "keybind_no_mods",
			line: "bind=NONE,Print,spawn,screenshot",
			expected: &MangoWCKeyBinding{
				Mods:    []string{},
				Key:     "Print",
				Command: "spawn",
				Params:  "screenshot",
				Comment: "screenshot",
			},
		},
		{
			name: "keybind_multiple_params",
			line: "bind=Ctrl,1,view,1,0",
			expected: &MangoWCKeyBinding{
				Mods:    []string{"Ctrl"},
				Key:     "1",
				Command: "view",
				Params:  "1,0",
				Comment: "View tag 1",
			},
		},
		{
			name: "bindl_flag",
			line: "bindl=SUPER+ALT,l,spawn,dms ipc call lock lock",
			expected: &MangoWCKeyBinding{
				Mods:    []string{"SUPER", "ALT"},
				Key:     "l",
				Command: "spawn",
				Params:  "dms ipc call lock lock",
				Comment: "dms ipc call lock lock",
			},
		},
		{
			name:             "preceding_comment",
			line:             "bind=SUPER+SHIFT,S,spawn,dms screenshot",
			precedingComment: "Screenshot: Interactive",
			expected: &MangoWCKeyBinding{
				Mods:    []string{"SUPER", "SHIFT"},
				Key:     "S",
				Command: "spawn",
				Params:  "dms screenshot",
				Comment: "Screenshot: Interactive",
			},
		},
		{
			name:             "section_header_not_description",
			line:             "bind=none,XF86AudioRaiseVolume,spawn,dms ipc call audio increment 3",
			precedingComment: "=== Audio Controls ===",
			expected: &MangoWCKeyBinding{
				Mods:    []string{},
				Key:     "XF86AudioRaiseVolume",
				Command: "spawn",
				Params:  "dms ipc call audio increment 3",
				Comment: "dms ipc call audio increment 3",
			},
		},
		{
			name: "keybind_with_spaces",
			line: "bind = SUPER, r, reload_config",
			expected: &MangoWCKeyBinding{
				Mods:    []string{"SUPER"},
				Key:     "r",
				Command: "reload_config",
				Params:  "",
				Comment: "Reload configuration",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			parser := NewMangoWCParser("")
			parser.contentLines = []string{tt.line}
			result := parser.getKeybindAtLine(0, tt.precedingComment)

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
			if result.Command != tt.expected.Command {
				t.Errorf("Command = %q, want %q", result.Command, tt.expected.Command)
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

func TestMangoWCParseKeys(t *testing.T) {
	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "config.conf")

	content := `# MangoWC Configuration
blur=0
border_radius=12

# Key Bindings
bind=SUPER,r,reload_config
bind=Alt,t,spawn,kitty # Terminal
bind=ALT,q,killclient,
bind=ALT,Left,focusdir,left

# Hidden binding
bind=SUPER,h,spawn,secret # [hidden]

# Multiple modifiers
bind=SUPER+SHIFT,Up,exchange_client,up

# Workspace bindings
bind=Ctrl,1,view,1,0
bind=Ctrl,2,view,2,0
`

	if err := os.WriteFile(configFile, []byte(content), 0o644); err != nil {
		t.Fatalf("Failed to write test config: %v", err)
	}

	keybinds, err := ParseMangoWCKeys(configFile)
	if err != nil {
		t.Fatalf("ParseMangoWCKeys failed: %v", err)
	}

	expectedCount := 7
	if len(keybinds) != expectedCount {
		t.Errorf("Expected %d keybinds, got %d", expectedCount, len(keybinds))
	}

	if len(keybinds) > 0 && keybinds[0].Command != "reload_config" {
		t.Errorf("First keybind command = %q, want %q", keybinds[0].Command, "reload_config")
	}

	foundHidden := false
	for _, kb := range keybinds {
		if kb.Command == "spawn" && kb.Params == "secret" {
			foundHidden = true
		}
	}
	if foundHidden {
		t.Error("Hidden keybind should not be included in results")
	}
}

func TestMangoWCReadContentMultipleFiles(t *testing.T) {
	tmpDir := t.TempDir()

	file1 := filepath.Join(tmpDir, "a.conf")
	file2 := filepath.Join(tmpDir, "b.conf")

	content1 := "bind=ALT,q,killclient,\n"
	content2 := "bind=Alt,t,spawn,kitty\n"

	if err := os.WriteFile(file1, []byte(content1), 0o644); err != nil {
		t.Fatalf("Failed to write file1: %v", err)
	}
	if err := os.WriteFile(file2, []byte(content2), 0o644); err != nil {
		t.Fatalf("Failed to write file2: %v", err)
	}

	parser := NewMangoWCParser("")
	if err := parser.ReadContent(tmpDir); err != nil {
		t.Fatalf("ReadContent failed: %v", err)
	}

	keybinds := parser.ParseKeys()
	if len(keybinds) != 2 {
		t.Errorf("Expected 2 keybinds from multiple files, got %d", len(keybinds))
	}
}

func TestMangoWCReadContentErrors(t *testing.T) {
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
			_, err := ParseMangoWCKeys(tt.path)
			if err == nil {
				t.Error("Expected error, got nil")
			}
		})
	}
}

func TestMangoWCInvalidBindLines(t *testing.T) {
	tests := []struct {
		name string
		line string
	}{
		{
			name: "missing_parts",
			line: "bind=SUPER,q",
		},
		{
			name: "not_bind",
			line: "blur=0",
		},
		{
			name: "empty_line",
			line: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			parser := NewMangoWCParser("")
			parser.contentLines = []string{tt.line}
			result := parser.getKeybindAtLine(0, "")

			if result != nil {
				t.Errorf("expected nil for invalid line, got %+v", result)
			}
		})
	}
}
