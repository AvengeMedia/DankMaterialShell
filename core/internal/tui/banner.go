package tui

func (m Model) renderBanner() string {
	logo := `
██████╗ ███╗   ███╗███████╗
██╔══██╗████╗ ████║██╔════╝
██║  ██║██╔████╔██║███████╗
██║  ██║██║╚██╔╝██║╚════██║
██████╔╝██║ ╚═╝ ██║███████║
╚═════╝ ╚═╝     ╚═╝╚══════╝`

	return m.styles.Banner.Render(logo)
}
