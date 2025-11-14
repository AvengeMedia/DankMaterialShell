package providers

import (
	"os"
	"path/filepath"
	"testing"
)

func TestMangoWCProviderName(t *testing.T) {
	provider := NewMangoWCProvider("")
	if provider.Name() != "mangowc" {
		t.Errorf("Name() = %q, want %q", provider.Name(), "mangowc")
	}
}

func TestMangoWCProviderDefaultPath(t *testing.T) {
	provider := NewMangoWCProvider("")
	if provider.configPath != "$HOME/.config/mango" {
		t.Errorf("configPath = %q, want %q", provider.configPath, "$HOME/.config/mango")
	}
}

func TestMangoWCProviderCustomPath(t *testing.T) {
	customPath := "/custom/path"
	provider := NewMangoWCProvider(customPath)
	if provider.configPath != customPath {
		t.Errorf("configPath = %q, want %q", provider.configPath, customPath)
	}
}

func TestMangoWCCategorizeByCommand(t *testing.T) {
	tests := []struct {
		command  string
		expected string
	}{
		{"view", "Tags"},
		{"tag", "Tags"},
		{"toggleview", "Tags"},
		{"viewtoleft", "Tags"},
		{"viewtoright", "Tags"},
		{"viewtoleft_have_client", "Tags"},
		{"tagtoleft", "Tags"},
		{"tagtoright", "Tags"},
		{"focusmon", "Monitor"},
		{"tagmon", "Monitor"},
		{"focusstack", "Window"},
		{"focusdir", "Window"},
		{"exchange_client", "Window"},
		{"killclient", "Window"},
		{"togglefloating", "Window"},
		{"togglefullscreen", "Window"},
		{"togglefakefullscreen", "Window"},
		{"togglemaximizescreen", "Window"},
		{"toggleglobal", "Window"},
		{"toggleoverlay", "Window"},
		{"minimized", "Window"},
		{"restore_minimized", "Window"},
		{"movewin", "Window"},
		{"resizewin", "Window"},
		{"toggleoverview", "Overview"},
		{"toggle_scratchpad", "Scratchpad"},
		{"setlayout", "Layout"},
		{"switch_layout", "Layout"},
		{"set_proportion", "Layout"},
		{"switch_proportion_preset", "Layout"},
		{"incgaps", "Gaps"},
		{"togglegaps", "Gaps"},
		{"spawn", "Execute"},
		{"spawn_shell", "Execute"},
		{"quit", "System"},
		{"reload_config", "System"},
		{"unknown_command", "Other"},
	}

	provider := NewMangoWCProvider("")
	for _, tt := range tests {
		t.Run(tt.command, func(t *testing.T) {
			result := provider.categorizeByCommand(tt.command)
			if result != tt.expected {
				t.Errorf("categorizeByCommand(%q) = %q, want %q", tt.command, result, tt.expected)
			}
		})
	}
}

func TestMangoWCFormatKey(t *testing.T) {
	tests := []struct {
		name     string
		keybind  *MangoWCKeyBinding
		expected string
	}{
		{
			name: "single_mod",
			keybind: &MangoWCKeyBinding{
				Mods: []string{"ALT"},
				Key:  "q",
			},
			expected: "ALT+q",
		},
		{
			name: "multiple_mods",
			keybind: &MangoWCKeyBinding{
				Mods: []string{"SUPER", "SHIFT"},
				Key:  "Up",
			},
			expected: "SUPER+SHIFT+Up",
		},
		{
			name: "no_mods",
			keybind: &MangoWCKeyBinding{
				Mods: []string{},
				Key:  "Print",
			},
			expected: "Print",
		},
	}

	provider := NewMangoWCProvider("")
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := provider.formatKey(tt.keybind)
			if result != tt.expected {
				t.Errorf("formatKey() = %q, want %q", result, tt.expected)
			}
		})
	}
}

func TestMangoWCConvertKeybind(t *testing.T) {
	tests := []struct {
		name     string
		keybind  *MangoWCKeyBinding
		wantKey  string
		wantDesc string
	}{
		{
			name: "with_comment",
			keybind: &MangoWCKeyBinding{
				Mods:    []string{"ALT"},
				Key:     "t",
				Command: "spawn",
				Params:  "kitty",
				Comment: "Open terminal",
			},
			wantKey:  "ALT+t",
			wantDesc: "Open terminal",
		},
		{
			name: "without_comment",
			keybind: &MangoWCKeyBinding{
				Mods:    []string{"SUPER"},
				Key:     "r",
				Command: "reload_config",
				Params:  "",
				Comment: "",
			},
			wantKey:  "SUPER+r",
			wantDesc: "reload_config",
		},
		{
			name: "with_params_no_comment",
			keybind: &MangoWCKeyBinding{
				Mods:    []string{"CTRL"},
				Key:     "1",
				Command: "view",
				Params:  "1,0",
				Comment: "",
			},
			wantKey:  "CTRL+1",
			wantDesc: "view 1,0",
		},
	}

	provider := NewMangoWCProvider("")
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := provider.convertKeybind(tt.keybind)
			if result.Key != tt.wantKey {
				t.Errorf("convertKeybind().Key = %q, want %q", result.Key, tt.wantKey)
			}
			if result.Description != tt.wantDesc {
				t.Errorf("convertKeybind().Description = %q, want %q", result.Description, tt.wantDesc)
			}
		})
	}
}

func TestMangoWCGetCheatSheet(t *testing.T) {
	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "config.conf")

	content := `# MangoWC Configuration
blur=0

# Key Bindings
bind=SUPER,r,reload_config
bind=Alt,t,spawn,kitty # Terminal
bind=ALT,q,killclient,

# Window management
bind=ALT,Left,focusdir,left
bind=ALT,Right,focusdir,right
bind=SUPER+SHIFT,Up,exchange_client,up

# Tags
bind=Ctrl,1,view,1,0
bind=Ctrl,2,view,2,0
bind=Alt,1,tag,1,0

# Layout
bind=SUPER,n,switch_layout

# Gaps
bind=ALT+SHIFT,X,incgaps,1
`

	if err := os.WriteFile(configFile, []byte(content), 0644); err != nil {
		t.Fatalf("Failed to write test config: %v", err)
	}

	provider := NewMangoWCProvider(tmpDir)
	sheet, err := provider.GetCheatSheet()
	if err != nil {
		t.Fatalf("GetCheatSheet failed: %v", err)
	}

	if sheet == nil {
		t.Fatal("Expected non-nil CheatSheet")
	}

	if sheet.Title != "MangoWC Keybinds" {
		t.Errorf("Title = %q, want %q", sheet.Title, "MangoWC Keybinds")
	}

	if sheet.Provider != "mangowc" {
		t.Errorf("Provider = %q, want %q", sheet.Provider, "mangowc")
	}

	categories := []string{"System", "Execute", "Window", "Tags", "Layout", "Gaps"}
	for _, category := range categories {
		if _, exists := sheet.Binds[category]; !exists {
			t.Errorf("Expected category %q to exist", category)
		}
	}

	if len(sheet.Binds["System"]) < 1 {
		t.Error("Expected at least 1 System keybind")
	}
	if len(sheet.Binds["Execute"]) < 1 {
		t.Error("Expected at least 1 Execute keybind")
	}
	if len(sheet.Binds["Window"]) < 3 {
		t.Error("Expected at least 3 Window keybinds")
	}
	if len(sheet.Binds["Tags"]) < 3 {
		t.Error("Expected at least 3 Tags keybinds")
	}
}

func TestMangoWCGetCheatSheetError(t *testing.T) {
	provider := NewMangoWCProvider("/nonexistent/path")
	_, err := provider.GetCheatSheet()
	if err == nil {
		t.Error("Expected error for nonexistent path, got nil")
	}
}

func TestMangoWCIntegration(t *testing.T) {
	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "config.conf")

	content := `bind=Alt,t,spawn,kitty # Open terminal
bind=ALT,q,killclient,
bind=SUPER,r,reload_config # Reload config
bind=ALT,Left,focusdir,left
bind=Ctrl,1,view,1,0
`

	if err := os.WriteFile(configFile, []byte(content), 0644); err != nil {
		t.Fatalf("Failed to write test config: %v", err)
	}

	provider := NewMangoWCProvider(tmpDir)
	sheet, err := provider.GetCheatSheet()
	if err != nil {
		t.Fatalf("GetCheatSheet failed: %v", err)
	}

	totalBinds := 0
	for _, binds := range sheet.Binds {
		totalBinds += len(binds)
	}

	expectedBinds := 5
	if totalBinds != expectedBinds {
		t.Errorf("Expected %d total keybinds, got %d", expectedBinds, totalBinds)
	}

	foundTerminal := false
	for _, binds := range sheet.Binds {
		for _, bind := range binds {
			if bind.Description == "Open terminal" && bind.Key == "Alt+t" {
				foundTerminal = true
			}
		}
	}

	if !foundTerminal {
		t.Error("Did not find terminal keybind with correct key and description")
	}
}
