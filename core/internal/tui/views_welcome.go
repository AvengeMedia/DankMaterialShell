package tui

import (
	"fmt"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/distros"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

func (m Model) viewWelcome() string {
	var b strings.Builder

	b.WriteString(m.renderBanner())
	b.WriteByte('\n')
	b.WriteString(m.styles.Accent.Render(strings.Repeat("━", 58)))
	b.WriteByte('\n')
	b.WriteString(m.styles.TitleBox.Render(
		m.styles.Highlight.Render("dankinstall") + m.styles.AccentItalic.Render(" // Dank Linux Installer")))
	b.WriteByte('\n')
	b.WriteString(m.styles.SubtleItalic.Render("Quickstart for a Dank Desktop"))
	b.WriteString("\n\n")

	switch {
	case m.osInfo == nil && m.isLoading:
		fmt.Fprintf(&b, "%s %s\n\n", m.spinner.View(), m.styles.Normal.Render("Detecting system..."))
	case m.osInfo != nil && distros.IsUnsupportedDistro(m.osInfo.Distribution.ID, m.osInfo.VersionID):
		m.writeUnsupportedDistro(&b)
	case m.osInfo != nil:
		m.writeSystemSummary(&b)
	}

	b.WriteString(m.styles.Subtle.Render(strings.Repeat("─", 59)))
	b.WriteByte('\n')
	m.writeWelcomeFooter(&b)

	return b.String()
}

func (m Model) writeUnsupportedDistro(b *strings.Builder) {
	title := m.styles.Error.Bold(true).Render("⚠ UNSUPPORTED DISTRIBUTION")
	msg := m.styles.Normal.Render(unsupportedDistroMessage(m.osInfo))
	b.WriteString(m.styles.ErrorBox.Render(title + "\n\n" + msg))
	b.WriteString("\n\n")
}

func unsupportedDistroMessage(info *distros.OSInfo) string {
	switch info.Distribution.ID {
	case "ubuntu":
		return fmt.Sprintf("Ubuntu %s is not supported.\n\nOnly Ubuntu 25.04+ is supported.\n\nPlease upgrade to Ubuntu 25.04 or later.", info.VersionID)
	case "debian":
		return fmt.Sprintf("Debian %s is not supported.\n\nOnly Debian 13+ (Trixie) is supported.\n\nPlease upgrade to Debian 13 or later.", info.VersionID)
	case "nixos":
		return "See the NixOS documentation for installation instructions: https://danklinux.com/docs/dankmaterialshell/nixos."
	default:
		return fmt.Sprintf("%s is not supported.\nFeel free to request on https://github.com/AvengeMedia/DankMaterialShell", info.PrettyName)
	}
}

func (m Model) writeSystemSummary(b *strings.Builder) {
	distroName := lipgloss.NewStyle().
		Foreground(lipgloss.Color(m.osInfo.Distribution.HexColorCode)).
		Bold(true).
		Render(m.osInfo.PrettyName)
	arch := m.styles.Accent.Render(m.osInfo.Architecture)
	b.WriteString(m.styles.InfoBox.Render(fmt.Sprintf("System: %s / %s", distroName, arch)))
	b.WriteByte('\n')

	b.WriteString(m.styles.Highlight.Underline(true).Render("WHAT YOU GET"))
	b.WriteString("\n\n")

	features := []struct {
		tag  string
		desc string
	}{
		{"[shell]", "dms (DankMaterialShell)"},
		{"[wm]", "niri or Hyprland"},
		{"[term]", "Ghostty, kitty, or Alacritty"},
		{"[style]", "All the themes, automatically."},
		{"[config]", "DANK defaults - keybindings, rules, animations, etc."},
	}

	tagStyle := m.styles.Accent.Bold(true)
	for i, feat := range features {
		descStyle := m.styles.Normal
		if i == len(features)-1 {
			descStyle = descStyle.Bold(true)
		}
		fmt.Fprintf(b, "  %s %s\n", tagStyle.Render(fmt.Sprintf("%-9s", feat.tag)), descStyle.Render(feat.desc))
	}
	b.WriteByte('\n')

	b.WriteString(m.styles.SubtleItalic.Render("* Existing configs can be replaced (and backed up) or preserved"))
	b.WriteByte('\n')
	if m.isGentoo() {
		b.WriteString(m.styles.SubtleItalic.Render("* Will set per-package USE flags and unmask testing packages as needed"))
		b.WriteByte('\n')
	}
	b.WriteByte('\n')
}

func (m Model) writeWelcomeFooter(b *strings.Builder) {
	if m.osInfo == nil {
		b.WriteString(m.styles.Subtle.Render("Press Enter to continue, Ctrl+C to quit"))
		return
	}

	ctrlKey := m.styles.Highlight.Render("Ctrl+C")
	if distros.IsUnsupportedDistro(m.osInfo.Distribution.ID, m.osInfo.VersionID) {
		b.WriteString(m.styles.Subtle.Render("Press ") + ctrlKey + m.styles.Subtle.Render(" to quit"))
		return
	}

	enterKey := m.styles.Highlight.Render("Enter")
	b.WriteString(m.styles.Subtle.Render("Press ") + enterKey +
		m.styles.Subtle.Render(" to choose window manager, ") + ctrlKey + m.styles.Subtle.Render(" to quit"))
}

func (m Model) updateWelcomeState(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case osInfoCompleteMsg:
		m.isLoading = false
		if msg.err != nil {
			m.err = msg.err
			m.state = StateError
			return m, m.listenForLogs()
		}
		m.osInfo = msg.info

	case tea.KeyMsg:
		if msg.String() != "enter" {
			break
		}
		if m.osInfo == nil || distros.IsUnsupportedDistro(m.osInfo.Distribution.ID, m.osInfo.VersionID) {
			break
		}
		m.state = StateSelectWindowManager
	}
	return m, m.listenForLogs()
}
