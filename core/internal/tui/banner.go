package tui

import "github.com/charmbracelet/lipgloss"

func (m Model) renderBanner() string {
	logo := `
██████╗  █████╗ ███╗   ██╗██╗  ██╗
██╔══██╗██╔══██╗████╗  ██║██║ ██╔╝
██║  ██║███████║██╔██╗ ██║█████╔╝
██║  ██║██╔══██║██║╚██╗██║██╔═██╗
██████╔╝██║  ██║██║ ╚████║██║  ██╗
╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝ `

	theme := TerminalTheme()
	style := lipgloss.NewStyle().
		Foreground(lipgloss.Color(theme.Primary)).
		Bold(true).
		MarginBottom(1)

	return style.Render(logo)
}
