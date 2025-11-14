package providers

import (
	"os"
	"path/filepath"
	"testing"
)

func TestSwayAutogenerateComment(t *testing.T) {
	tests := []struct {
		command  string
		expected string
	}{
		{"exec kitty", "kitty"},
		{"exec --no-startup-id firefox", "firefox"},
		{"kill", "Close window"},
		{"exit", "Exit Sway"},
		{"reload", "Reload configuration"},
		{"fullscreen toggle", "Toggle fullscreen"},
		{"floating toggle", "Float/unfloat window"},
		{"focus mode_toggle", "Toggle focus mode"},
		{"focus parent", "Focus parent container"},
		{"focus left", "Focus left"},
		{"focus right", "Focus right"},
		{"focus up", "Focus up"},
		{"focus down", "Focus down"},
		{"focus output left", "Focus monitor"},
		{"move left", "Move window left"},
		{"move right", "Move window right"},
		{"move up", "Move window up"},
		{"move down", "Move window down"},
		{"move container to workspace number 1", "Move to workspace 1"},
		{"move container to workspace prev", "Move to previous workspace"},
		{"move container to workspace next", "Move to next workspace"},
		{"move workspace to output left", "Move workspace to monitor"},
		{"workspace number 1", "Workspace 1"},
		{"workspace prev", "Previous workspace"},
		{"workspace next", "Next workspace"},
		{"layout tabbed", "Layout tabbed"},
		{"layout stacking", "Layout stacking"},
		{"splith", "Split horizontal"},
		{"splitv", "Split vertical"},
		{"resize grow width 10 ppt", "Resize window"},
		{"move scratchpad", "Toggle scratchpad"},
	}

	for _, tt := range tests {
		t.Run(tt.command, func(t *testing.T) {
			result := swayAutogenerateComment(tt.command)
			if result != tt.expected {
				t.Errorf("swayAutogenerateComment(%q) = %q, want %q",
					tt.command, result, tt.expected)
			}
		})
	}
}

func TestSwayGetKeybindAtLine(t *testing.T) {
	tests := []struct {
		name     string
		line     string
		expected *SwayKeyBinding
	}{
		{
			name: "basic_keybind",
			line: "bindsym Mod4+q kill",
			expected: &SwayKeyBinding{
				Mods:    []string{"Mod4"},
				Key:     "q",
				Command: "kill",
				Comment: "Close window",
			},
		},
		{
			name: "keybind_with_exec",
			line: "bindsym Mod4+t exec kitty",
			expected: &SwayKeyBinding{
				Mods:    []string{"Mod4"},
				Key:     "t",
				Command: "exec kitty",
				Comment: "kitty",
			},
		},
		{
			name: "keybind_with_comment",
			line: "bindsym Mod4+Space exec dms ipc call spotlight toggle # Open launcher",
			expected: &SwayKeyBinding{
				Mods:    []string{"Mod4"},
				Key:     "Space",
				Command: "exec dms ipc call spotlight toggle",
				Comment: "Open launcher",
			},
		},
		{
			name:     "keybind_hidden",
			line:     "bindsym Mod4+h exec secret # [hidden]",
			expected: nil,
		},
		{
			name: "keybind_multiple_mods",
			line: "bindsym Mod4+Shift+e exit",
			expected: &SwayKeyBinding{
				Mods:    []string{"Mod4", "Shift"},
				Key:     "e",
				Command: "exit",
				Comment: "Exit Sway",
			},
		},
		{
			name: "keybind_no_mods",
			line: "bindsym Print exec grim screenshot.png",
			expected: &SwayKeyBinding{
				Mods:    []string{},
				Key:     "Print",
				Command: "exec grim screenshot.png",
				Comment: "grim screenshot.png",
			},
		},
		{
			name: "keybind_with_flags",
			line: "bindsym --release Mod4+x exec notify-send released",
			expected: &SwayKeyBinding{
				Mods:    []string{"Mod4"},
				Key:     "x",
				Command: "exec notify-send released",
				Comment: "notify-send released",
			},
		},
		{
			name: "keybind_focus_direction",
			line: "bindsym Mod4+Left focus left",
			expected: &SwayKeyBinding{
				Mods:    []string{"Mod4"},
				Key:     "Left",
				Command: "focus left",
				Comment: "Focus left",
			},
		},
		{
			name: "keybind_workspace",
			line: "bindsym Mod4+1 workspace number 1",
			expected: &SwayKeyBinding{
				Mods:    []string{"Mod4"},
				Key:     "1",
				Command: "workspace number 1",
				Comment: "Workspace 1",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			parser := NewSwayParser()
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
			if result.Command != tt.expected.Command {
				t.Errorf("Command = %q, want %q", result.Command, tt.expected.Command)
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

func TestSwayVariableExpansion(t *testing.T) {
	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "config")

	content := `set $mod Mod4
set $term kitty
set $menu rofi

bindsym $mod+t exec $term
bindsym $mod+d exec $menu
`

	if err := os.WriteFile(configFile, []byte(content), 0644); err != nil {
		t.Fatalf("Failed to write test config: %v", err)
	}

	section, err := ParseSwayKeys(configFile)
	if err != nil {
		t.Fatalf("ParseSwayKeys failed: %v", err)
	}

	if len(section.Keybinds) != 2 {
		t.Errorf("Expected 2 keybinds, got %d", len(section.Keybinds))
	}

	if len(section.Keybinds) > 0 {
		if section.Keybinds[0].Mods[0] != "Mod4" {
			t.Errorf("Expected Mod4, got %q", section.Keybinds[0].Mods[0])
		}
		if section.Keybinds[0].Command != "exec kitty" {
			t.Errorf("Expected 'exec kitty', got %q", section.Keybinds[0].Command)
		}
	}

	if len(section.Keybinds) > 1 {
		if section.Keybinds[1].Command != "exec rofi" {
			t.Errorf("Expected 'exec rofi', got %q", section.Keybinds[1].Command)
		}
	}
}

func TestSwayParseKeysWithSections(t *testing.T) {
	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "config")

	content := `set $mod Mod4

##! Window Management
bindsym $mod+q kill
bindsym $mod+f fullscreen toggle

###! Focus
bindsym $mod+Left focus left
bindsym $mod+Right focus right

##! Applications
bindsym $mod+t exec kitty # Terminal
`

	if err := os.WriteFile(configFile, []byte(content), 0644); err != nil {
		t.Fatalf("Failed to write test config: %v", err)
	}

	section, err := ParseSwayKeys(tmpDir)
	if err != nil {
		t.Fatalf("ParseSwayKeys failed: %v", err)
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
			focus := windowMgmt.Children[0]
			if focus.Name != "Focus" {
				t.Errorf("Focus section name = %q, want %q", focus.Name, "Focus")
			}
			if len(focus.Keybinds) != 2 {
				t.Errorf("Focus keybinds = %d, want 2", len(focus.Keybinds))
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

func TestSwayReadContentErrors(t *testing.T) {
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
			_, err := ParseSwayKeys(tt.path)
			if err == nil {
				t.Error("Expected error, got nil")
			}
		})
	}
}

func TestSwayReadContentWithTildeExpansion(t *testing.T) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		t.Skip("Cannot get home directory")
	}

	tmpSubdir := filepath.Join(homeDir, ".config", "test-sway-"+t.Name())
	if err := os.MkdirAll(tmpSubdir, 0755); err != nil {
		t.Skip("Cannot create test directory in home")
	}
	defer os.RemoveAll(tmpSubdir)

	configFile := filepath.Join(tmpSubdir, "config")
	if err := os.WriteFile(configFile, []byte("bindsym Mod4+q kill\n"), 0644); err != nil {
		t.Fatalf("Failed to write test config: %v", err)
	}

	relPath, err := filepath.Rel(homeDir, tmpSubdir)
	if err != nil {
		t.Skip("Cannot create relative path")
	}

	parser := NewSwayParser()
	tildePathMatch := "~/" + relPath
	err = parser.ReadContent(tildePathMatch)

	if err != nil {
		t.Errorf("ReadContent with tilde path failed: %v", err)
	}
}

func TestSwayEmptyAndCommentLines(t *testing.T) {
	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "config")

	content := `
# This is a comment
bindsym Mod4+q kill

# Another comment

bindsym Mod4+t exec kitty
`

	if err := os.WriteFile(configFile, []byte(content), 0644); err != nil {
		t.Fatalf("Failed to write test config: %v", err)
	}

	section, err := ParseSwayKeys(configFile)
	if err != nil {
		t.Fatalf("ParseSwayKeys failed: %v", err)
	}

	if len(section.Keybinds) != 2 {
		t.Errorf("Expected 2 keybinds (comments ignored), got %d", len(section.Keybinds))
	}
}

func TestSwayRealWorldConfig(t *testing.T) {
	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "config")

	content := `set $mod Mod4
set $term kitty

## Application Launchers
bindsym $mod+t exec $term
bindsym $mod+Space exec rofi

## Window Management
bindsym $mod+q kill
bindsym $mod+f fullscreen toggle

## Focus Navigation
bindsym $mod+Left focus left
bindsym $mod+Right focus right

## Workspace Navigation
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+Shift+1 move container to workspace number 1
`

	if err := os.WriteFile(configFile, []byte(content), 0644); err != nil {
		t.Fatalf("Failed to write test config: %v", err)
	}

	section, err := ParseSwayKeys(configFile)
	if err != nil {
		t.Fatalf("ParseSwayKeys failed: %v", err)
	}

	if len(section.Keybinds) < 9 {
		t.Errorf("Expected at least 9 keybinds, got %d", len(section.Keybinds))
	}

	foundExec := false
	foundKill := false
	foundWorkspace := false

	for _, kb := range section.Keybinds {
		if kb.Command == "exec kitty" {
			foundExec = true
		}
		if kb.Command == "kill" {
			foundKill = true
		}
		if kb.Command == "workspace number 1" {
			foundWorkspace = true
		}
	}

	if !foundExec {
		t.Error("Did not find exec kitty keybind")
	}
	if !foundKill {
		t.Error("Did not find kill keybind")
	}
	if !foundWorkspace {
		t.Error("Did not find workspace 1 keybind")
	}
}

func TestSwayIsMod(t *testing.T) {
	tests := []struct {
		input    string
		expected bool
	}{
		{"Mod4", true},
		{"Shift", true},
		{"Control", true},
		{"Alt", true},
		{"Super", true},
		{"$mod", true},
		{"Left", false},
		{"q", false},
		{"1", false},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			result := swayIsMod(tt.input)
			if result != tt.expected {
				t.Errorf("swayIsMod(%q) = %v, want %v", tt.input, result, tt.expected)
			}
		})
	}
}
