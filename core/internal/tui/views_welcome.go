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
	b.WriteString("\n")

	theme := TerminalTheme()

	decorator := lipgloss.NewStyle().
		Foreground(lipgloss.Color(theme.Accent)).
		Render("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	titleBox := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color(theme.Primary)).
		Padding(0, 2).
		MarginBottom(1)

	titleText := lipgloss.NewStyle().
		Foreground(lipgloss.Color(theme.Primary)).
		Bold(true).
		Render("dankinstall")

	versionTag := lipgloss.NewStyle().
		Foreground(lipgloss.Color(theme.Accent)).
		Italic(true).
		Render(" // Dank Linux Installer")

	subtitle := lipgloss.NewStyle().
		Foreground(lipgloss.Color(theme.Subtle)).
		Italic(true).
		Render("Quickstart for a Dank™ Desktop")

	b.WriteString(decorator)
	b.WriteString("\n")
	b.WriteString(titleBox.Render(titleText + versionTag))
	b.WriteString("\n")
	b.WriteString(subtitle)
	b.WriteString("\n\n")

	if m.osInfo != nil {
		if distros.IsUnsupportedDistro(m.osInfo.Distribution.ID, m.osInfo.VersionID) {
			errorBox := lipgloss.NewStyle().
				Border(lipgloss.RoundedBorder()).
				BorderForeground(lipgloss.Color("#FF6B6B")).
				Padding(1, 2).
				MarginBottom(1)

			errorTitle := lipgloss.NewStyle().
				Foreground(lipgloss.Color("#FF6B6B")).
				Bold(true).
				Render("⚠ UNSUPPORTED DISTRIBUTION")

			var errorMsg string
			switch m.osInfo.Distribution.ID {
			case "ubuntu":
				errorMsg = fmt.Sprintf("Ubuntu %s is not supported.\n\nOnly Ubuntu 25.04+ is supported.\n\nPlease upgrade to Ubuntu 25.04 or later.", m.osInfo.VersionID)
			case "debian":
				errorMsg = fmt.Sprintf("Debian %s is not supported.\n\nOnly Debian 13+ (Trixie) is supported.\n\nPlease upgrade to Debian 13 or later.", m.osInfo.VersionID)
			case "nixos":
				errorMsg = "See the NixOS documentation for installation instructions: https://danklinux.com/docs/dankmaterialshell/nixos."
			default:
				errorMsg = fmt.Sprintf("%s is not supported.\nFeel free to request on https://github.com/AvengeMedia/DankMaterialShell", m.osInfo.PrettyName)
			}

			errorMsgStyled := lipgloss.NewStyle().
				Foreground(lipgloss.Color(theme.Text)).
				Render(errorMsg)

			b.WriteString(errorBox.Render(errorTitle + "\n\n" + errorMsgStyled))
			b.WriteString("\n\n")
		} else {
			// System info box
			sysBox := lipgloss.NewStyle().
				Border(lipgloss.NormalBorder()).
				BorderForeground(lipgloss.Color(theme.Subtle)).
				Padding(0, 1).
				MarginBottom(1)

			// Style the distro name with its color
			distroStyle := lipgloss.NewStyle().
				Foreground(lipgloss.Color(m.osInfo.Distribution.HexColorCode)).
				Bold(true)
			distroName := distroStyle.Render(m.osInfo.PrettyName)

			archStyle := lipgloss.NewStyle().
				Foreground(lipgloss.Color(theme.Accent))

			sysInfo := fmt.Sprintf("System: %s / %s", distroName, archStyle.Render(m.osInfo.Architecture))
			b.WriteString(sysBox.Render(sysInfo))
			b.WriteString("\n")

			// Feature list with better styling
			featTitle := lipgloss.NewStyle().
				Foreground(lipgloss.Color(theme.Primary)).
				Bold(true).
				Underline(true).
				Render("WHAT YOU GET")
			b.WriteString(featTitle + "\n\n")

			features := []string{
				"[shell]   dms (DankMaterialShell)",
				"[wm]      niri or Hyprland",
				"[term]    Ghostty, kitty, or Alacritty",
				"[style]   All the themes, automatically.",
				"[config]  DANK defaults - keybindings, rules, animations, etc.",
			}

			for i, feat := range features {
				prefix := feat[:9]
				content := feat[10:]

				prefixStyle := lipgloss.NewStyle().
					Foreground(lipgloss.Color(theme.Accent)).
					Bold(true)

				contentStyle := lipgloss.NewStyle().
					Foreground(lipgloss.Color(theme.Text))

				if i == len(features)-1 {
					contentStyle = contentStyle.Bold(true)
				}

				b.WriteString(fmt.Sprintf("  %s %s\n",
					prefixStyle.Render(prefix),
					contentStyle.Render(content)))
			}

			b.WriteString("\n")

			noteStyle := lipgloss.NewStyle().
				Foreground(lipgloss.Color(theme.Subtle)).
				Italic(true)
			note := noteStyle.Render("* Existing configs can be replaced (and backed up) or preserved")
			b.WriteString(note)
			b.WriteString("\n")

			if m.osInfo.Distribution.ID == "gentoo" {
				gentooNote := noteStyle.Render("* Will set per-package USE flags and unmask testing packages as needed")
				b.WriteString(gentooNote)
				b.WriteString("\n")
			}

			b.WriteString("\n")
		}

	} else if m.isLoading {
		spinner := m.spinner.View()
		loading := m.styles.Normal.Render("Detecting system...")
		b.WriteString(fmt.Sprintf("%s %s\n\n", spinner, loading))
	}

	// Footer with better visual separation
	footerDivider := lipgloss.NewStyle().
		Foreground(lipgloss.Color(theme.Subtle)).
		Render("───────────────────────────────────────────────────────────")
	b.WriteString(footerDivider + "\n")

	if m.osInfo != nil {
		ctrlKey := lipgloss.NewStyle().
			Foreground(lipgloss.Color(theme.Primary)).
			Bold(true).
			Render("Ctrl+C")

		if distros.IsUnsupportedDistro(m.osInfo.Distribution.ID, m.osInfo.VersionID) {
			b.WriteString(m.styles.Subtle.Render("Press ") + ctrlKey + m.styles.Subtle.Render(" to quit"))
		} else {
			enterKey := lipgloss.NewStyle().
				Foreground(lipgloss.Color(theme.Primary)).
				Bold(true).
				Render("Enter")

			b.WriteString(m.styles.Subtle.Render("Press ") + enterKey + m.styles.Subtle.Render(" to choose window manager, ") + ctrlKey + m.styles.Subtle.Render(" to quit"))
		}
	} else {
		help := m.styles.Subtle.Render("Press Enter to continue, Ctrl+C to quit")
		b.WriteString(help)
	}

	return b.String()
}

func (m Model) updateWelcomeState(msg tea.Msg) (tea.Model, tea.Cmd) {
	if completeMsg, ok := msg.(osInfoCompleteMsg); ok {
		m.isLoading = false
		if completeMsg.err != nil {
			m.err = completeMsg.err
			m.state = StateError
		} else {
			m.osInfo = completeMsg.info
		}
		return m, m.listenForLogs()
	}

	if keyMsg, ok := msg.(tea.KeyMsg); ok {
		switch keyMsg.String() {
		case "enter":
			if m.osInfo != nil && !distros.IsUnsupportedDistro(m.osInfo.Distribution.ID, m.osInfo.VersionID) {
				m.state = StateSelectWindowManager
				return m, m.listenForLogs()
			}
		}
	}
	return m, m.listenForLogs()
}
