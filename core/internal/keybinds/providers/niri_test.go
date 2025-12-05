package providers

import (
	"os"
	"path/filepath"
	"testing"
)

func TestNiriProviderName(t *testing.T) {
	provider := NewNiriProvider("")
	if provider.Name() != "niri" {
		t.Errorf("Name() = %q, want %q", provider.Name(), "niri")
	}
}

func TestNiriProviderGetCheatSheet(t *testing.T) {
	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "config.kdl")

	content := `binds {
    Mod+Q { close-window; }
    Mod+F { fullscreen-window; }
    Mod+T hotkey-overlay-title="Open Terminal" { spawn "kitty"; }
    Mod+1 { focus-workspace 1; }
    Mod+Shift+1 { move-column-to-workspace 1; }
    Print { screenshot; }
    Mod+Shift+E { quit; }
}
`
	if err := os.WriteFile(configFile, []byte(content), 0644); err != nil {
		t.Fatalf("Failed to write test config: %v", err)
	}

	provider := NewNiriProvider(tmpDir)
	cheatSheet, err := provider.GetCheatSheet()
	if err != nil {
		t.Fatalf("GetCheatSheet failed: %v", err)
	}

	if cheatSheet.Title != "Niri Keybinds" {
		t.Errorf("Title = %q, want %q", cheatSheet.Title, "Niri Keybinds")
	}

	if cheatSheet.Provider != "niri" {
		t.Errorf("Provider = %q, want %q", cheatSheet.Provider, "niri")
	}

	windowBinds := cheatSheet.Binds["Window"]
	if len(windowBinds) < 2 {
		t.Errorf("Expected at least 2 Window binds, got %d", len(windowBinds))
	}

	execBinds := cheatSheet.Binds["Execute"]
	if len(execBinds) < 1 {
		t.Errorf("Expected at least 1 Execute bind, got %d", len(execBinds))
	}

	workspaceBinds := cheatSheet.Binds["Workspace"]
	if len(workspaceBinds) < 2 {
		t.Errorf("Expected at least 2 Workspace binds, got %d", len(workspaceBinds))
	}

	screenshotBinds := cheatSheet.Binds["Screenshot"]
	if len(screenshotBinds) < 1 {
		t.Errorf("Expected at least 1 Screenshot bind, got %d", len(screenshotBinds))
	}

	systemBinds := cheatSheet.Binds["System"]
	if len(systemBinds) < 1 {
		t.Errorf("Expected at least 1 System bind, got %d", len(systemBinds))
	}
}

func TestNiriCategorizeByAction(t *testing.T) {
	provider := NewNiriProvider("")

	tests := []struct {
		action   string
		expected string
	}{
		{"focus-workspace", "Workspace"},
		{"focus-workspace-up", "Workspace"},
		{"move-column-to-workspace", "Workspace"},
		{"focus-monitor-left", "Monitor"},
		{"move-column-to-monitor-right", "Monitor"},
		{"close-window", "Window"},
		{"fullscreen-window", "Window"},
		{"maximize-column", "Window"},
		{"toggle-window-floating", "Window"},
		{"focus-column-left", "Window"},
		{"move-column-right", "Window"},
		{"spawn", "Execute"},
		{"quit", "System"},
		{"power-off-monitors", "System"},
		{"screenshot", "Screenshot"},
		{"screenshot-window", "Screenshot"},
		{"toggle-overview", "Overview"},
		{"show-hotkey-overlay", "Overview"},
		{"next-window", "Alt-Tab"},
		{"previous-window", "Alt-Tab"},
		{"unknown-action", "Other"},
	}

	for _, tt := range tests {
		t.Run(tt.action, func(t *testing.T) {
			result := provider.categorizeByAction(tt.action)
			if result != tt.expected {
				t.Errorf("categorizeByAction(%q) = %q, want %q", tt.action, result, tt.expected)
			}
		})
	}
}

func TestNiriFormatRawAction(t *testing.T) {
	provider := NewNiriProvider("")

	tests := []struct {
		action   string
		args     []string
		expected string
	}{
		{"spawn", []string{"kitty"}, "spawn kitty"},
		{"spawn", []string{"dms", "ipc", "call"}, "spawn dms ipc call"},
		{"close-window", nil, "close-window"},
		{"fullscreen-window", nil, "fullscreen-window"},
		{"focus-workspace", []string{"1"}, "focus-workspace 1"},
		{"move-column-to-workspace", []string{"5"}, "move-column-to-workspace 5"},
		{"set-column-width", []string{"+10%"}, "set-column-width +10%"},
	}

	for _, tt := range tests {
		t.Run(tt.action, func(t *testing.T) {
			result := provider.formatRawAction(tt.action, tt.args)
			if result != tt.expected {
				t.Errorf("formatRawAction(%q, %v) = %q, want %q", tt.action, tt.args, result, tt.expected)
			}
		})
	}
}

func TestNiriFormatKey(t *testing.T) {
	provider := NewNiriProvider("")

	tests := []struct {
		mods     []string
		key      string
		expected string
	}{
		{[]string{"Mod"}, "Q", "Mod+Q"},
		{[]string{"Mod", "Shift"}, "F", "Mod+Shift+F"},
		{[]string{"Ctrl", "Alt"}, "Delete", "Ctrl+Alt+Delete"},
		{nil, "Print", "Print"},
		{[]string{}, "XF86AudioMute", "XF86AudioMute"},
	}

	for _, tt := range tests {
		t.Run(tt.expected, func(t *testing.T) {
			kb := &NiriKeyBinding{
				Mods: tt.mods,
				Key:  tt.key,
			}
			result := provider.formatKey(kb)
			if result != tt.expected {
				t.Errorf("formatKey(%v) = %q, want %q", kb, result, tt.expected)
			}
		})
	}
}

func TestNiriDefaultConfigDir(t *testing.T) {
	originalXDG := os.Getenv("XDG_CONFIG_HOME")
	defer os.Setenv("XDG_CONFIG_HOME", originalXDG)

	os.Setenv("XDG_CONFIG_HOME", "/custom/config")
	dir := defaultNiriConfigDir()
	if dir != "/custom/config/niri" {
		t.Errorf("With XDG_CONFIG_HOME set, got %q, want %q", dir, "/custom/config/niri")
	}

	os.Unsetenv("XDG_CONFIG_HOME")
	dir = defaultNiriConfigDir()
	home, _ := os.UserHomeDir()
	expected := filepath.Join(home, ".config", "niri")
	if dir != expected {
		t.Errorf("Without XDG_CONFIG_HOME, got %q, want %q", dir, expected)
	}
}

func TestNiriGenerateBindsContent(t *testing.T) {
	provider := NewNiriProvider("")

	tests := []struct {
		name     string
		binds    map[string]*overrideBind
		expected string
	}{
		{
			name:     "empty binds",
			binds:    map[string]*overrideBind{},
			expected: "binds {}\n",
		},
		{
			name: "simple spawn bind",
			binds: map[string]*overrideBind{
				"Mod+T": {
					Key:         "Mod+T",
					Action:      "spawn kitty",
					Description: "Open Terminal",
				},
			},
			expected: `binds {
    Mod+T hotkey-overlay-title="Open Terminal" { spawn "kitty"; }
}
`,
		},
		{
			name: "spawn with multiple args",
			binds: map[string]*overrideBind{
				"Mod+Space": {
					Key:         "Mod+Space",
					Action:      `spawn "dms" "ipc" "call" "spotlight" "toggle"`,
					Description: "Application Launcher",
				},
			},
			expected: `binds {
    Mod+Space hotkey-overlay-title="Application Launcher" { spawn "dms" "ipc" "call" "spotlight" "toggle"; }
}
`,
		},
		{
			name: "bind with allow-when-locked",
			binds: map[string]*overrideBind{
				"XF86AudioMute": {
					Key:     "XF86AudioMute",
					Action:  `spawn "dms" "ipc" "call" "audio" "mute"`,
					Options: map[string]any{"allow-when-locked": true},
				},
			},
			expected: `binds {
    XF86AudioMute allow-when-locked=true { spawn "dms" "ipc" "call" "audio" "mute"; }
}
`,
		},
		{
			name: "simple action without args",
			binds: map[string]*overrideBind{
				"Mod+Q": {
					Key:         "Mod+Q",
					Action:      "close-window",
					Description: "Close Window",
				},
			},
			expected: `binds {
    Mod+Q hotkey-overlay-title="Close Window" { close-window; }
}
`,
		},
		{
			name: "recent-windows action",
			binds: map[string]*overrideBind{
				"Alt+Tab": {
					Key:    "Alt+Tab",
					Action: "next-window",
				},
			},
			expected: `binds {
}

recent-windows {
    binds {
        Alt+Tab { next-window; }
    }
}
`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := provider.generateBindsContent(tt.binds)
			if result != tt.expected {
				t.Errorf("generateBindsContent() =\n%q\nwant:\n%q", result, tt.expected)
			}
		})
	}
}

func TestNiriGenerateBindsContentRoundTrip(t *testing.T) {
	provider := NewNiriProvider("")

	binds := map[string]*overrideBind{
		"Mod+Space": {
			Key:         "Mod+Space",
			Action:      `spawn "dms" "ipc" "call" "spotlight" "toggle"`,
			Description: "Application Launcher",
		},
		"XF86AudioMute": {
			Key:     "XF86AudioMute",
			Action:  `spawn "dms" "ipc" "call" "audio" "mute"`,
			Options: map[string]any{"allow-when-locked": true},
		},
		"Mod+Q": {
			Key:         "Mod+Q",
			Action:      "close-window",
			Description: "Close Window",
		},
	}

	content := provider.generateBindsContent(binds)

	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "config.kdl")
	if err := os.WriteFile(configFile, []byte(content), 0644); err != nil {
		t.Fatalf("Failed to write temp file: %v", err)
	}

	result, err := ParseNiriKeys(tmpDir)
	if err != nil {
		t.Fatalf("Failed to parse generated content: %v\nContent was:\n%s", err, content)
	}

	if len(result.Section.Keybinds) != 3 {
		t.Errorf("Expected 3 keybinds after round-trip, got %d", len(result.Section.Keybinds))
	}
}

func TestNiriProviderWithRealWorldConfig(t *testing.T) {
	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "config.kdl")

	content := `binds {
    Mod+Shift+Ctrl+D { debug-toggle-damage; }
    Super+D { spawn "niri" "msg" "action" "toggle-overview"; }
    Super+Tab repeat=false { toggle-overview; }
    Mod+Shift+Slash { show-hotkey-overlay; }

    Mod+T hotkey-overlay-title="Open Terminal" { spawn "kitty"; }
    Mod+Space hotkey-overlay-title="Application Launcher" {
        spawn "dms" "ipc" "call" "spotlight" "toggle";
    }

    XF86AudioRaiseVolume allow-when-locked=true {
        spawn "dms" "ipc" "call" "audio" "increment" "3";
    }
    XF86AudioLowerVolume allow-when-locked=true {
        spawn "dms" "ipc" "call" "audio" "decrement" "3";
    }

    Mod+Q repeat=false { close-window; }
    Mod+F { maximize-column; }
    Mod+Shift+F { fullscreen-window; }

    Mod+Left  { focus-column-left; }
    Mod+Down  { focus-window-down; }
    Mod+Up    { focus-window-up; }
    Mod+Right { focus-column-right; }

    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+Shift+1 { move-column-to-workspace 1; }
    Mod+Shift+2 { move-column-to-workspace 2; }

    Print { screenshot; }
    Ctrl+Print { screenshot-screen; }
    Alt+Print { screenshot-window; }

    Mod+Shift+E { quit; }
}

recent-windows {
    binds {
        Alt+Tab { next-window scope="output"; }
        Alt+Shift+Tab { previous-window scope="output"; }
    }
}
`
	if err := os.WriteFile(configFile, []byte(content), 0644); err != nil {
		t.Fatalf("Failed to write test config: %v", err)
	}

	provider := NewNiriProvider(tmpDir)
	cheatSheet, err := provider.GetCheatSheet()
	if err != nil {
		t.Fatalf("GetCheatSheet failed: %v", err)
	}

	totalBinds := 0
	for _, binds := range cheatSheet.Binds {
		totalBinds += len(binds)
	}

	if totalBinds < 20 {
		t.Errorf("Expected at least 20 keybinds, got %d", totalBinds)
	}

	if len(cheatSheet.Binds["Alt-Tab"]) < 2 {
		t.Errorf("Expected at least 2 Alt-Tab binds, got %d", len(cheatSheet.Binds["Alt-Tab"]))
	}
}
