package dms

import (
	"fmt"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/tui"
	"github.com/charmbracelet/lipgloss"
)

func (m Model) renderMainMenu() string {
	var b strings.Builder

	b.WriteString(m.renderBanner())
	b.WriteString("\n")

	headerStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#FFFFFF")).
		Bold(true).
		MarginBottom(1)

	b.WriteString(headerStyle.Render("dms"))
	b.WriteString("\n")

	selectedStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#00D4AA")).
		Bold(true)

	normalStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#FFFFFF"))

	for i, item := range m.menuItems {
		if i == m.selectedItem {
			b.WriteString(selectedStyle.Render(fmt.Sprintf("▶ %s", item.Label)))
		} else {
			b.WriteString(normalStyle.Render(fmt.Sprintf("  %s", item.Label)))
		}
		b.WriteString("\n")
	}

	b.WriteString("\n")
	instructionStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#888888")).
		MarginTop(1)

	instructions := "↑/↓: Navigate, Enter: Select, q/Esc: Exit"
	b.WriteString(instructionStyle.Render(instructions))

	return b.String()
}

func (m Model) renderShellView() string {
	var b strings.Builder

	b.WriteString(m.renderBanner())
	b.WriteString("\n")

	headerStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#FFFFFF")).
		Bold(true).
		MarginBottom(1)

	b.WriteString(headerStyle.Render("Shell"))
	b.WriteString("\n\n")

	normalStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#FFFFFF"))

	b.WriteString(normalStyle.Render("Opening interactive shell..."))
	b.WriteString("\n")
	b.WriteString(normalStyle.Render("This will launch a shell with DMS environment loaded."))
	b.WriteString("\n\n")

	instructionStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#888888")).
		MarginTop(1)

	instructions := "Press any key to launch shell, Esc: Back"
	b.WriteString(instructionStyle.Render(instructions))

	return b.String()
}

func (m Model) renderAboutView() string {
	var b strings.Builder

	b.WriteString(m.renderBanner())
	b.WriteString("\n")

	headerStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#FFFFFF")).
		Bold(true).
		MarginBottom(1)

	b.WriteString(headerStyle.Render("About DankMaterialShell"))
	b.WriteString("\n\n")

	normalStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#FFFFFF"))

	b.WriteString(normalStyle.Render(fmt.Sprintf("DMS Management Interface %s", m.version)))
	b.WriteString("\n\n")
	b.WriteString(normalStyle.Render("DankMaterialShell is a comprehensive desktop environment"))
	b.WriteString("\n")
	b.WriteString(normalStyle.Render("built around Quickshell, providing a modern Material Design"))
	b.WriteString("\n")
	b.WriteString(normalStyle.Render("experience for Wayland compositors."))
	b.WriteString("\n\n")

	b.WriteString(normalStyle.Render("Components:"))
	b.WriteString("\n")
	if len(m.dependencies) == 0 {
		b.WriteString(normalStyle.Render("\n  Component detection not supported on this platform."))
	}
	for _, dep := range m.dependencies {
		status := "✗"
		if dep.Status == 1 {
			status = "✓"
		}
		b.WriteString(normalStyle.Render(fmt.Sprintf("  %s %s", status, dep.Name)))
		b.WriteString("\n")
	}

	b.WriteString("\n")
	instructionStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#888888")).
		MarginTop(1)

	instructions := "Esc: Back to main menu"
	b.WriteString(instructionStyle.Render(instructions))

	return b.String()
}

func (m Model) renderBanner() string {
	theme := tui.TerminalTheme()

	logo := `
██████╗  █████╗ ███╗   ██╗██╗  ██╗
██╔══██╗██╔══██╗████╗  ██║██║ ██╔╝
██║  ██║███████║██╔██╗ ██║█████╔╝
██║  ██║██╔══██║██║╚██╗██║██╔═██╗
██████╔╝██║  ██║██║ ╚████║██║  ██╗
╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝`

	titleStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color(theme.Primary)).
		Bold(true).
		MarginBottom(1)

	return titleStyle.Render(logo)
}
