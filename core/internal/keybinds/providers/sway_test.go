package providers

import (
	"os"
	"path/filepath"
	"testing"
)

func TestSwayProviderName(t *testing.T) {
	provider := NewSwayProvider("")
	if provider.Name() != "sway" {
		t.Errorf("Name() = %q, want %q", provider.Name(), "sway")
	}
}

func TestSwayProviderDefaultPath(t *testing.T) {
	provider := NewSwayProvider("")
	if provider.configPath != "$HOME/.config/sway" {
		t.Errorf("configPath = %q, want %q", provider.configPath, "$HOME/.config/sway")
	}
}

func TestSwayProviderCustomPath(t *testing.T) {
	customPath := "/custom/path"
	provider := NewSwayProvider(customPath)
	if provider.configPath != customPath {
		t.Errorf("configPath = %q, want %q", provider.configPath, customPath)
	}
}

func TestSwayCategorizeByCommand(t *testing.T) {
	tests := []struct {
		command  string
		expected string
	}{
		{"workspace number 1", "Workspace"},
		{"workspace prev", "Workspace"},
		{"workspace next", "Workspace"},
		{"move container to workspace number 1", "Workspace"},
		{"focus output left", "Monitor"},
		{"move workspace to output right", "Monitor"},
		{"kill", "Window"},
		{"fullscreen toggle", "Window"},
		{"floating toggle", "Window"},
		{"focus left", "Window"},
		{"focus right", "Window"},
		{"move left", "Window"},
		{"move right", "Window"},
		{"resize grow width 10px", "Window"},
		{"splith", "Window"},
		{"splitv", "Window"},
		{"layout tabbed", "Layout"},
		{"layout stacking", "Layout"},
		{"move scratchpad", "Scratchpad"},
		{"scratchpad show", "Scratchpad"},
		{"exec kitty", "Execute"},
		{"exec --no-startup-id firefox", "Execute"},
		{"exit", "System"},
		{"reload", "System"},
		{"unknown command", "Other"},
	}

	provider := NewSwayProvider("")
	for _, tt := range tests {
		t.Run(tt.command, func(t *testing.T) {
			result := provider.categorizeByCommand(tt.command)
			if result != tt.expected {
				t.Errorf("categorizeByCommand(%q) = %q, want %q", tt.command, result, tt.expected)
			}
		})
	}
}

func TestSwayFormatKey(t *testing.T) {
	tests := []struct {
		name     string
		keybind  *SwayKeyBinding
		expected string
	}{
		{
			name: "single_mod",
			keybind: &SwayKeyBinding{
				Mods: []string{"Mod4"},
				Key:  "q",
			},
			expected: "Mod4+q",
		},
		{
			name: "multiple_mods",
			keybind: &SwayKeyBinding{
				Mods: []string{"Mod4", "Shift"},
				Key:  "e",
			},
			expected: "Mod4+Shift+e",
		},
		{
			name: "no_mods",
			keybind: &SwayKeyBinding{
				Mods: []string{},
				Key:  "Print",
			},
			expected: "Print",
		},
	}

	provider := NewSwayProvider("")
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := provider.formatKey(tt.keybind)
			if result != tt.expected {
				t.Errorf("formatKey() = %q, want %q", result, tt.expected)
			}
		})
	}
}

func TestSwayConvertKeybind(t *testing.T) {
	tests := []struct {
		name     string
		keybind  *SwayKeyBinding
		wantKey  string
		wantDesc string
	}{
		{
			name: "with_comment",
			keybind: &SwayKeyBinding{
				Mods:    []string{"Mod4"},
				Key:     "t",
				Command: "exec kitty",
				Comment: "Open terminal",
			},
			wantKey:  "Mod4+t",
			wantDesc: "Open terminal",
		},
		{
			name: "without_comment",
			keybind: &SwayKeyBinding{
				Mods:    []string{"Mod4"},
				Key:     "r",
				Command: "reload",
				Comment: "",
			},
			wantKey:  "Mod4+r",
			wantDesc: "reload",
		},
	}

	provider := NewSwayProvider("")
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := provider.convertKeybind(tt.keybind, "")
			if result.Key != tt.wantKey {
				t.Errorf("convertKeybind().Key = %q, want %q", result.Key, tt.wantKey)
			}
			if result.Description != tt.wantDesc {
				t.Errorf("convertKeybind().Description = %q, want %q", result.Description, tt.wantDesc)
			}
		})
	}
}

func TestSwayGetCheatSheet(t *testing.T) {
	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "config")

	content := `set $mod Mod4
set $term kitty

# System
bindsym $mod+Shift+c reload
bindsym $mod+Shift+e exit

# Applications
bindsym $mod+t exec $term
bindsym $mod+Space exec rofi

# Window Management
bindsym $mod+q kill
bindsym $mod+f fullscreen toggle
bindsym $mod+Left focus left
bindsym $mod+Right focus right

# Workspace
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+Shift+1 move container to workspace number 1

# Layout
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
`

	if err := os.WriteFile(configFile, []byte(content), 0644); err != nil {
		t.Fatalf("Failed to write test config: %v", err)
	}

	provider := NewSwayProvider(tmpDir)
	sheet, err := provider.GetCheatSheet()
	if err != nil {
		t.Fatalf("GetCheatSheet failed: %v", err)
	}

	if sheet == nil {
		t.Fatal("Expected non-nil CheatSheet")
	}

	if sheet.Title != "Sway Keybinds" {
		t.Errorf("Title = %q, want %q", sheet.Title, "Sway Keybinds")
	}

	if sheet.Provider != "sway" {
		t.Errorf("Provider = %q, want %q", sheet.Provider, "sway")
	}

	categories := []string{"System", "Execute", "Window", "Workspace", "Layout"}
	for _, category := range categories {
		if _, exists := sheet.Binds[category]; !exists {
			t.Errorf("Expected category %q to exist", category)
		}
	}

	if len(sheet.Binds["System"]) < 2 {
		t.Error("Expected at least 2 System keybinds")
	}
	if len(sheet.Binds["Execute"]) < 2 {
		t.Error("Expected at least 2 Execute keybinds")
	}
	if len(sheet.Binds["Window"]) < 4 {
		t.Error("Expected at least 4 Window keybinds")
	}
	if len(sheet.Binds["Workspace"]) < 3 {
		t.Error("Expected at least 3 Workspace keybinds")
	}
}

func TestSwayGetCheatSheetError(t *testing.T) {
	provider := NewSwayProvider("/nonexistent/path")
	_, err := provider.GetCheatSheet()
	if err == nil {
		t.Error("Expected error for nonexistent path, got nil")
	}
}

func TestSwayIntegration(t *testing.T) {
	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "config")

	content := `set $mod Mod4

bindsym $mod+t exec kitty # Terminal
bindsym $mod+q kill
bindsym $mod+f fullscreen toggle
bindsym $mod+1 workspace number 1
`

	if err := os.WriteFile(configFile, []byte(content), 0644); err != nil {
		t.Fatalf("Failed to write test config: %v", err)
	}

	provider := NewSwayProvider(tmpDir)
	sheet, err := provider.GetCheatSheet()
	if err != nil {
		t.Fatalf("GetCheatSheet failed: %v", err)
	}

	totalBinds := 0
	for _, binds := range sheet.Binds {
		totalBinds += len(binds)
	}

	expectedBinds := 4
	if totalBinds != expectedBinds {
		t.Errorf("Expected %d total keybinds, got %d", expectedBinds, totalBinds)
	}

	foundTerminal := false
	for _, binds := range sheet.Binds {
		for _, bind := range binds {
			if bind.Description == "Terminal" && bind.Key == "Mod4+t" {
				foundTerminal = true
			}
		}
	}

	if !foundTerminal {
		t.Error("Did not find terminal keybind with correct key and description")
	}
}
