package tui

import (
	"context"
	"fmt"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/deps"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/distros"
	tea "github.com/charmbracelet/bubbletea"
)

type listOption struct {
	label string
	desc  string
}

func (m Model) isGentoo() bool {
	return m.osInfo != nil && m.osInfo.Distribution.ID == "gentoo"
}

type wmChoice struct {
	wm    deps.WindowManager
	label string
	desc  string
}

func (m Model) windowManagerChoices() []wmChoice {
	choices := []wmChoice{
		{deps.WindowManagerNiri, "niri", "Scrollable-tiling Wayland compositor."},
	}
	if m.osInfo == nil || m.osInfo.Distribution.ID != "debian" {
		choices = append(choices, wmChoice{deps.WindowManagerHyprland, "Hyprland", "Dynamic tiling Wayland compositor."})
	}
	return append(choices, wmChoice{deps.WindowManagerMango, "mango", "dwl-based dynamic tiling Wayland compositor."})
}

func (m Model) chosenWindowManager() deps.WindowManager {
	choices := m.windowManagerChoices()
	if m.selectedWM < 0 || m.selectedWM >= len(choices) {
		return deps.WindowManagerNiri
	}
	return choices[m.selectedWM].wm
}

type terminalChoice struct {
	terminal deps.Terminal
	label    string
	desc     string
}

func (m Model) terminalChoices() []terminalChoice {
	var choices []terminalChoice
	if !m.isGentoo() {
		choices = append(choices, terminalChoice{deps.TerminalGhostty, "ghostty", "A fast, native terminal emulator built in Zig."})
	}
	return append(choices,
		terminalChoice{deps.TerminalKitty, "kitty", "A feature-rich, customizable terminal emulator."},
		terminalChoice{deps.TerminalAlacritty, "alacritty", "A simple terminal emulator."},
	)
}

func (m Model) chosenTerminal() deps.Terminal {
	choices := m.terminalChoices()
	if m.selectedTerminal < 0 || m.selectedTerminal >= len(choices) {
		return choices[0].terminal
	}
	return choices[m.selectedTerminal].terminal
}

func (m Model) renderOptionList(b *strings.Builder, options []listOption, selected int) {
	for i, opt := range options {
		cursor, style := "  ", m.styles.Normal
		if i == selected {
			cursor, style = "▶ ", m.styles.SelectedOption
		}
		b.WriteString(style.Render(cursor + opt.label))
		b.WriteByte('\n')

		if opt.desc == "" {
			continue
		}
		b.WriteString(m.styles.Subtle.Render("  " + opt.desc))
		b.WriteByte('\n')
		if i < len(options)-1 {
			b.WriteByte('\n')
		}
	}
}

func (m Model) viewChoiceScreen(title string, options []listOption, selected int) string {
	var b strings.Builder

	b.WriteString(m.renderBanner())
	b.WriteByte('\n')
	b.WriteString(m.styles.Title.Render(title))
	b.WriteString("\n\n")

	m.renderOptionList(&b, options, selected)

	b.WriteByte('\n')
	b.WriteString(m.styles.Subtle.Render("Use ↑/↓ to navigate, Enter to select, Esc to go back"))
	return b.String()
}

func (m Model) viewSelectWindowManager() string {
	choices := m.windowManagerChoices()
	options := make([]listOption, len(choices))
	for i, c := range choices {
		options[i] = listOption{c.label, c.desc}
	}
	return m.viewChoiceScreen("Choose Window Manager", options, m.selectedWM)
}

func (m Model) viewSelectTerminal() string {
	choices := m.terminalChoices()
	options := make([]listOption, len(choices))
	for i, c := range choices {
		options[i] = listOption{c.label, c.desc}
	}
	return m.viewChoiceScreen("Choose Terminal Emulator", options, m.selectedTerminal)
}

func (m Model) updateSelectWindowManagerState(msg tea.Msg) (tea.Model, tea.Cmd) {
	keyMsg, ok := msg.(tea.KeyMsg)
	if !ok {
		return m, m.listenForLogs()
	}

	switch keyMsg.String() {
	case "up":
		m.selectedWM = moveIndex(m.selectedWM, -1, len(m.windowManagerChoices())-1)
	case "down":
		m.selectedWM = moveIndex(m.selectedWM, 1, len(m.windowManagerChoices())-1)
	case "enter":
		m.state = StateSelectTerminal
	case "esc":
		m.state = StateWelcome
	}
	return m, m.listenForLogs()
}

func (m Model) updateSelectTerminalState(msg tea.Msg) (tea.Model, tea.Cmd) {
	keyMsg, ok := msg.(tea.KeyMsg)
	if !ok {
		return m, m.listenForLogs()
	}

	switch keyMsg.String() {
	case "up":
		m.selectedTerminal = moveIndex(m.selectedTerminal, -1, len(m.terminalChoices())-1)
	case "down":
		m.selectedTerminal = moveIndex(m.selectedTerminal, 1, len(m.terminalChoices())-1)
	case "enter":
		m.state = StateDetectingDeps
		m.isLoading = true
		return m, tea.Batch(m.spinner.Tick, m.detectDependencies())
	case "esc":
		m.state = StateSelectWindowManager
	}
	return m, m.listenForLogs()
}

func (m Model) detectDependencies() tea.Cmd {
	return func() tea.Msg {
		if m.osInfo == nil {
			return depsDetectedMsg{err: fmt.Errorf("OS info not available")}
		}

		detector, err := distros.NewDependencyDetector(m.osInfo.Distribution.ID, m.logChan)
		if err != nil {
			return depsDetectedMsg{err: err}
		}

		dependencies, err := detector.DetectDependenciesWithTerminal(context.Background(), m.chosenWindowManager(), m.chosenTerminal())
		return depsDetectedMsg{deps: dependencies, err: err}
	}
}
