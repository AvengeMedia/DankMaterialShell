package headless

import (
	"strings"
	"testing"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/deps"
)

func TestParseWindowManager(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		want    deps.WindowManager
		wantErr bool
	}{
		{"niri lowercase", "niri", deps.WindowManagerNiri, false},
		{"niri mixed case", "Niri", deps.WindowManagerNiri, false},
		{"hyprland lowercase", "hyprland", deps.WindowManagerHyprland, false},
		{"hyprland mixed case", "Hyprland", deps.WindowManagerHyprland, false},
		{"invalid", "sway", 0, true},
		{"empty", "", 0, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := NewRunner(Config{Compositor: tt.input})
			got, err := r.parseWindowManager()
			if (err != nil) != tt.wantErr {
				t.Errorf("parseWindowManager() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !tt.wantErr && got != tt.want {
				t.Errorf("parseWindowManager() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestParseTerminal(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		want    deps.Terminal
		wantErr bool
	}{
		{"ghostty lowercase", "ghostty", deps.TerminalGhostty, false},
		{"ghostty mixed case", "Ghostty", deps.TerminalGhostty, false},
		{"kitty lowercase", "kitty", deps.TerminalKitty, false},
		{"alacritty lowercase", "alacritty", deps.TerminalAlacritty, false},
		{"alacritty uppercase", "ALACRITTY", deps.TerminalAlacritty, false},
		{"invalid", "wezterm", 0, true},
		{"empty", "", 0, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := NewRunner(Config{Terminal: tt.input})
			got, err := r.parseTerminal()
			if (err != nil) != tt.wantErr {
				t.Errorf("parseTerminal() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !tt.wantErr && got != tt.want {
				t.Errorf("parseTerminal() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestDepExists(t *testing.T) {
	dependencies := []deps.Dependency{
		{Name: "niri", Status: deps.StatusInstalled},
		{Name: "ghostty", Status: deps.StatusMissing},
		{Name: "dms (DankMaterialShell)", Status: deps.StatusInstalled},
		{Name: "dms-greeter", Status: deps.StatusMissing},
	}

	tests := []struct {
		name string
		dep  string
		want bool
	}{
		{"existing dep", "niri", true},
		{"existing dep with special chars", "dms (DankMaterialShell)", true},
		{"existing optional dep", "dms-greeter", true},
		{"non-existing dep", "firefox", false},
		{"empty name", "", false},
	}

	r := NewRunner(Config{})
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := r.depExists(dependencies, tt.dep); got != tt.want {
				t.Errorf("depExists(%q) = %v, want %v", tt.dep, got, tt.want)
			}
		})
	}
}

func TestNewRunner(t *testing.T) {
	cfg := Config{
		Compositor:  "niri",
		Terminal:    "ghostty",
		IncludeDeps: []string{"dms-greeter"},
		ExcludeDeps: []string{"some-pkg"},
		Yes:         true,
	}
	r := NewRunner(cfg)

	if r == nil {
		t.Fatal("NewRunner returned nil")
	}
	if r.cfg.Compositor != "niri" {
		t.Errorf("cfg.Compositor = %q, want %q", r.cfg.Compositor, "niri")
	}
	if r.cfg.Terminal != "ghostty" {
		t.Errorf("cfg.Terminal = %q, want %q", r.cfg.Terminal, "ghostty")
	}
	if !r.cfg.Yes {
		t.Error("cfg.Yes = false, want true")
	}
	if r.logChan == nil {
		t.Error("logChan is nil")
	}
}

func TestGetLogChan(t *testing.T) {
	r := NewRunner(Config{})
	ch := r.GetLogChan()
	if ch == nil {
		t.Fatal("GetLogChan returned nil")
	}

	// Verify the channel is readable by sending a message
	go func() {
		r.logChan <- "test message"
	}()
	msg := <-ch
	if msg != "test message" {
		t.Errorf("received %q, want %q", msg, "test message")
	}
}

func TestLog(t *testing.T) {
	r := NewRunner(Config{})

	// log should not block even if channel is full
	for i := 0; i < 1100; i++ {
		r.log("message")
	}
	// If we reach here without hanging, the non-blocking send works
}

func TestRunRequiresYes(t *testing.T) {
	// Verify that ErrConfirmationRequired is a distinct sentinel error
	if ErrConfirmationRequired == nil {
		t.Fatal("ErrConfirmationRequired should not be nil")
	}
	expected := "confirmation required: pass --yes to proceed"
	if ErrConfirmationRequired.Error() != expected {
		t.Errorf("ErrConfirmationRequired = %q, want %q", ErrConfirmationRequired.Error(), expected)
	}
}

func TestConfigYesStoredCorrectly(t *testing.T) {
	// Yes=false (default) should be stored
	rNo := NewRunner(Config{Compositor: "niri", Terminal: "ghostty", Yes: false})
	if rNo.cfg.Yes {
		t.Error("cfg.Yes = true, want false")
	}

	// Yes=true should be stored
	rYes := NewRunner(Config{Compositor: "niri", Terminal: "ghostty", Yes: true})
	if !rYes.cfg.Yes {
		t.Error("cfg.Yes = false, want true")
	}
}

func TestValidConfigNamesCompleteness(t *testing.T) {
	// orderedConfigNames and validConfigNames must stay in sync.
	if len(orderedConfigNames) != len(validConfigNames) {
		t.Fatalf("orderedConfigNames has %d entries but validConfigNames has %d",
			len(orderedConfigNames), len(validConfigNames))
	}

	// Every entry in orderedConfigNames must exist in validConfigNames.
	for _, name := range orderedConfigNames {
		if _, ok := validConfigNames[name]; !ok {
			t.Errorf("orderedConfigNames contains %q which is missing from validConfigNames", name)
		}
	}

	// validConfigNames must have no extra keys not in orderedConfigNames.
	ordered := make(map[string]bool, len(orderedConfigNames))
	for _, name := range orderedConfigNames {
		ordered[name] = true
	}
	for key := range validConfigNames {
		if !ordered[key] {
			t.Errorf("validConfigNames contains %q which is missing from orderedConfigNames", key)
		}
	}
}

func TestBuildReplaceConfigs(t *testing.T) {
	allDeployerKeys := []string{"Niri", "Hyprland", "Ghostty", "Kitty", "Alacritty"}

	tests := []struct {
		name           string
		replaceConfigs []string
		replaceAll     bool
		wantNil        bool     // expect nil (replace all)
		wantEnabled    []string // deployer keys that should be true
		wantErr        bool
	}{
		{
			name:        "neither flag set",
			wantNil:     false,
			wantEnabled: nil, // all should be false
		},
		{
			name:       "replace-configs-all",
			replaceAll: true,
			wantNil:    true,
		},
		{
			name:           "specific configs",
			replaceConfigs: []string{"niri", "ghostty"},
			wantNil:        false,
			wantEnabled:    []string{"Niri", "Ghostty"},
		},
		{
			name:           "both flags set",
			replaceConfigs: []string{"niri"},
			replaceAll:     true,
			wantErr:        true,
		},
		{
			name:           "invalid config name",
			replaceConfigs: []string{"foo"},
			wantErr:        true,
		},
		{
			name:           "case insensitive",
			replaceConfigs: []string{"NIRI", "Ghostty"},
			wantNil:        false,
			wantEnabled:    []string{"Niri", "Ghostty"},
		},
		{
			name:           "single config",
			replaceConfigs: []string{"kitty"},
			wantNil:        false,
			wantEnabled:    []string{"Kitty"},
		},
		{
			name:           "whitespace entry",
			replaceConfigs: []string{"  ", "niri"},
			wantNil:        false,
			wantEnabled:    []string{"Niri"},
		},
		{
			name:           "duplicate entry",
			replaceConfigs: []string{"niri", "niri"},
			wantNil:        false,
			wantEnabled:    []string{"Niri"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := NewRunner(Config{
				ReplaceConfigs:    tt.replaceConfigs,
				ReplaceConfigsAll: tt.replaceAll,
			})
			got, err := r.buildReplaceConfigs()
			if (err != nil) != tt.wantErr {
				t.Fatalf("buildReplaceConfigs() error = %v, wantErr %v", err, tt.wantErr)
			}
			if tt.wantErr {
				return
			}
			if tt.wantNil {
				if got != nil {
					t.Fatalf("buildReplaceConfigs() = %v, want nil", got)
				}
				return
			}
			if got == nil {
				t.Fatal("buildReplaceConfigs() = nil, want non-nil map")
			}

			// All known deployer keys must be present
			for _, key := range allDeployerKeys {
				if _, exists := got[key]; !exists {
					t.Errorf("missing deployer key %q in result map", key)
				}
			}

			// Build enabled set for easy lookup
			enabledSet := make(map[string]bool)
			for _, k := range tt.wantEnabled {
				enabledSet[k] = true
			}

			for _, key := range allDeployerKeys {
				want := enabledSet[key]
				if got[key] != want {
					t.Errorf("replaceConfigs[%q] = %v, want %v", key, got[key], want)
				}
			}
		})
	}
}

func TestConfigReplaceConfigsStoredCorrectly(t *testing.T) {
	r := NewRunner(Config{
		Compositor:        "niri",
		Terminal:          "ghostty",
		ReplaceConfigs:    []string{"niri", "ghostty"},
		ReplaceConfigsAll: false,
	})
	if len(r.cfg.ReplaceConfigs) != 2 {
		t.Errorf("len(ReplaceConfigs) = %d, want 2", len(r.cfg.ReplaceConfigs))
	}
	if r.cfg.ReplaceConfigsAll {
		t.Error("ReplaceConfigsAll = true, want false")
	}

	r2 := NewRunner(Config{
		Compositor:        "niri",
		Terminal:          "ghostty",
		ReplaceConfigsAll: true,
	})
	if !r2.cfg.ReplaceConfigsAll {
		t.Error("ReplaceConfigsAll = false, want true")
	}
	if len(r2.cfg.ReplaceConfigs) != 0 {
		t.Errorf("len(ReplaceConfigs) = %d, want 0", len(r2.cfg.ReplaceConfigs))
	}
}

func TestBuildDisabledItems(t *testing.T) {
	dependencies := []deps.Dependency{
		{Name: "niri", Status: deps.StatusInstalled},
		{Name: "ghostty", Status: deps.StatusMissing},
		{Name: "dms (DankMaterialShell)", Status: deps.StatusInstalled},
		{Name: "dms-greeter", Status: deps.StatusMissing},
		{Name: "waybar", Status: deps.StatusMissing},
	}

	tests := []struct {
		name         string
		includeDeps  []string
		excludeDeps  []string
		deps         []deps.Dependency // nil means use the shared fixture
		wantErr      bool
		errContains  string   // substring expected in error message
		wantDisabled []string // dep names that should be in disabledItems
		wantEnabled  []string // dep names that should NOT be in disabledItems (extra check)
	}{
		{
			name:         "no flags set, dms-greeter disabled by default",
			wantDisabled: []string{"dms-greeter"},
			wantEnabled:  []string{"niri", "ghostty", "waybar"},
		},
		{
			name:        "include dms-greeter enables it",
			includeDeps: []string{"dms-greeter"},
			wantEnabled: []string{"dms-greeter"},
		},
		{
			name:         "exclude a regular dep",
			excludeDeps:  []string{"waybar"},
			wantDisabled: []string{"dms-greeter", "waybar"},
		},
		{
			name:        "include unknown dep returns error",
			includeDeps: []string{"nonexistent"},
			wantErr:     true,
			errContains: "--include-deps",
		},
		{
			name:        "exclude unknown dep returns error",
			excludeDeps: []string{"nonexistent"},
			wantErr:     true,
			errContains: "--exclude-deps",
		},
		{
			name:        "exclude DMS itself is forbidden",
			excludeDeps: []string{"dms (DankMaterialShell)"},
			wantErr:     true,
			errContains: "cannot exclude required package",
		},
		{
			name:         "include and exclude same dep",
			includeDeps:  []string{"dms-greeter"},
			excludeDeps:  []string{"dms-greeter"},
			wantDisabled: []string{"dms-greeter"},
		},
		{
			name:        "whitespace entries are skipped",
			includeDeps: []string{"  ", "dms-greeter"},
			wantEnabled: []string{"dms-greeter"},
		},
		{
			name: "no dms-greeter in deps, nothing disabled by default",
			deps: []deps.Dependency{
				{Name: "niri", Status: deps.StatusInstalled},
			},
			wantEnabled: []string{"niri"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := NewRunner(Config{
				IncludeDeps: tt.includeDeps,
				ExcludeDeps: tt.excludeDeps,
			})
			d := tt.deps
			if d == nil {
				d = dependencies
			}
			got, err := r.buildDisabledItems(d)
			if (err != nil) != tt.wantErr {
				t.Fatalf("buildDisabledItems() error = %v, wantErr %v", err, tt.wantErr)
			}
			if tt.wantErr {
				if tt.errContains != "" && !strings.Contains(err.Error(), tt.errContains) {
					t.Errorf("error %q does not contain %q", err.Error(), tt.errContains)
				}
				return
			}
			if got == nil {
				t.Fatal("buildDisabledItems() returned nil map, want non-nil")
			}

			// Check expected disabled items
			for _, name := range tt.wantDisabled {
				if !got[name] {
					t.Errorf("expected %q to be disabled, but it is not", name)
				}
			}

			// Check expected enabled items (should not be in the map or be false)
			for _, name := range tt.wantEnabled {
				if got[name] {
					t.Errorf("expected %q to NOT be disabled, but it is", name)
				}
			}

			// If wantDisabled is empty, the map should have length 0
			if len(tt.wantDisabled) == 0 && len(got) != 0 {
				t.Errorf("expected empty disabledItems map, got %v", got)
			}
		})
	}
}
