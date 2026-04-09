package headless

import (
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
