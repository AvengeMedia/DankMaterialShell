package tui

import (
	"context"
	"fmt"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/deps"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/distros"
	tea "github.com/charmbracelet/bubbletea"
)

// windowManagerOptions returns the WM enums in selection-list order (debian omits
// Hyprland). selectedWM indexes into this, so all index->WM conversions use it.
func (m Model) windowManagerOptions() []deps.WindowManager {
	opts := []deps.WindowManager{deps.WindowManagerNiri}
	if m.osInfo == nil || m.osInfo.Distribution.ID != "debian" {
		opts = append(opts, deps.WindowManagerHyprland)
	}
	opts = append(opts, deps.WindowManagerMango)
	return opts
}

// selectedWindowManager maps the current selectedWM index to its WM enum.
func (m Model) selectedWindowManager() deps.WindowManager {
	opts := m.windowManagerOptions()
	if m.selectedWM >= 0 && m.selectedWM < len(opts) {
		return opts[m.selectedWM]
	}
	return deps.WindowManagerNiri
}

func (m Model) viewSelectWindowManager() string {
	var b strings.Builder

	b.WriteString(m.renderBanner())
	b.WriteString("\n")

	title := m.styles.Title.Render("Choose Window Manager")
	b.WriteString(title)
	b.WriteString("\n\n")

	options := []struct {
		name        string
		description string
	}{
		{"niri", "Scrollable-tiling Wayland compositor."},
	}

	if m.osInfo == nil || m.osInfo.Distribution.ID != "debian" {
		options = append(options, struct {
			name        string
			description string
		}{"Hyprland", "Dynamic tiling Wayland compositor."})
	}

	options = append(options, struct {
		name        string
		description string
	}{"mango", "dwl-based dynamic tiling Wayland compositor."})

	for i, option := range options {
		if i == m.selectedWM {
			selected := m.styles.SelectedOption.Render("▶ " + option.name)
			b.WriteString(selected)
			b.WriteString("\n")
			desc := m.styles.Subtle.Render("  " + option.description)
			b.WriteString(desc)
		} else {
			normal := m.styles.Normal.Render("  " + option.name)
			b.WriteString(normal)
			b.WriteString("\n")
			desc := m.styles.Subtle.Render("  " + option.description)
			b.WriteString(desc)
		}
		b.WriteString("\n")
		if i < len(options)-1 {
			b.WriteString("\n")
		}
	}

	b.WriteString("\n")
	help := m.styles.Subtle.Render("Use ↑/↓ to navigate, Enter to select, Esc to go back")
	b.WriteString(help)

	return b.String()
}

func (m Model) viewSelectTerminal() string {
	var b strings.Builder

	b.WriteString(m.renderBanner())
	b.WriteString("\n")

	title := m.styles.Title.Render("Choose Terminal Emulator")
	b.WriteString(title)
	b.WriteString("\n\n")

	var options []struct {
		name        string
		description string
	}

	if m.osInfo != nil && m.osInfo.Distribution.ID == "gentoo" {
		options = []struct {
			name        string
			description string
		}{
			{"kitty", "A feature-rich, customizable terminal emulator."},
			{"alacritty", "A simple terminal emulator."},
		}
	} else {
		options = []struct {
			name        string
			description string
		}{
			{"ghostty", "A fast, native terminal emulator built in Zig."},
			{"kitty", "A feature-rich, customizable terminal emulator."},
			{"alacritty", "A simple terminal emulator."},
		}
	}

	for i, option := range options {
		if i == m.selectedTerminal {
			selected := m.styles.SelectedOption.Render("▶ " + option.name)
			b.WriteString(selected)
			b.WriteString("\n")
			desc := m.styles.Subtle.Render("  " + option.description)
			b.WriteString(desc)
		} else {
			normal := m.styles.Normal.Render("  " + option.name)
			b.WriteString(normal)
			b.WriteString("\n")
			desc := m.styles.Subtle.Render("  " + option.description)
			b.WriteString(desc)
		}
		b.WriteString("\n")
		if i < len(options)-1 {
			b.WriteString("\n")
		}
	}

	b.WriteString("\n")
	help := m.styles.Subtle.Render("Use ↑/↓ to navigate, Enter to select, Esc to go back")
	b.WriteString(help)

	return b.String()
}

func (m Model) updateSelectTerminalState(msg tea.Msg) (tea.Model, tea.Cmd) {
	if keyMsg, ok := msg.(tea.KeyMsg); ok {
		maxTerminalIndex := 2
		if m.osInfo != nil && m.osInfo.Distribution.ID == "gentoo" {
			maxTerminalIndex = 1
		}

		switch keyMsg.String() {
		case "up":
			if m.selectedTerminal > 0 {
				m.selectedTerminal--
			}
		case "down":
			if m.selectedTerminal < maxTerminalIndex {
				m.selectedTerminal++
			}
		case "enter":
			m.state = StateDetectingDeps
			m.isLoading = true
			return m, tea.Batch(m.spinner.Tick, m.detectDependencies())
		case "esc":
			m.state = StateSelectWindowManager
			return m, m.listenForLogs()
		}
	}
	return m, m.listenForLogs()
}

func (m Model) updateSelectWindowManagerState(msg tea.Msg) (tea.Model, tea.Cmd) {
	if keyMsg, ok := msg.(tea.KeyMsg); ok {
		maxWMIndex := len(m.windowManagerOptions()) - 1

		switch keyMsg.String() {
		case "up":
			if m.selectedWM > 0 {
				m.selectedWM--
			}
		case "down":
			if m.selectedWM < maxWMIndex {
				m.selectedWM++
			}
		case "enter":
			m.state = StateSelectTerminal
			return m, m.listenForLogs()
		case "esc":
			// Go back to welcome screen
			m.state = StateWelcome
			return m, m.listenForLogs()
		}
	}
	return m, m.listenForLogs()
}

func (m Model) detectDependencies() tea.Cmd {
	return func() tea.Msg {
		if m.osInfo == nil {
			return depsDetectedMsg{deps: nil, err: fmt.Errorf("OS info not available")}
		}

		detector, err := distros.NewDependencyDetector(m.osInfo.Distribution.ID, m.logChan)
		if err != nil {
			return depsDetectedMsg{deps: nil, err: err}
		}

		// Convert TUI selection to deps enum
		wm := m.selectedWindowManager()

		var terminal deps.Terminal
		if m.osInfo != nil && m.osInfo.Distribution.ID == "gentoo" {
			switch m.selectedTerminal {
			case 0:
				terminal = deps.TerminalKitty
			case 1:
				terminal = deps.TerminalAlacritty
			default:
				terminal = deps.TerminalKitty
			}
		} else {
			switch m.selectedTerminal {
			case 0:
				terminal = deps.TerminalGhostty
			case 1:
				terminal = deps.TerminalKitty
			default:
				terminal = deps.TerminalAlacritty
			}
		}

		dependencies, err := detector.DetectDependenciesWithTerminal(context.Background(), wm, terminal)
		return depsDetectedMsg{deps: dependencies, err: err}
	}
}
