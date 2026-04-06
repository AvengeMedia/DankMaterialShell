package tui

import (
	"fmt"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/deps"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/distros"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// wrapText wraps text to the specified width
func wrapText(text string, width int) string {
	if len(text) <= width {
		return text
	}

	var result strings.Builder
	words := strings.Fields(text)
	currentLine := ""

	for _, word := range words {
		if len(currentLine) == 0 {
			currentLine = word
		} else if len(currentLine)+1+len(word) <= width {
			currentLine += " " + word
		} else {
			result.WriteString(currentLine)
			result.WriteString("\n")
			currentLine = word
		}
	}

	if len(currentLine) > 0 {
		result.WriteString(currentLine)
	}

	return result.String()
}

func (m Model) viewInstallingPackages() string {
	var b strings.Builder

	b.WriteString(m.renderBanner())
	b.WriteString("\n")

	title := m.styles.Title.Render("Installing Packages")
	b.WriteString(title)
	b.WriteString("\n\n")

	if !m.packageProgress.isComplete {
		spinner := m.spinner.View()
		status := m.styles.Normal.Render(m.packageProgress.step)
		fmt.Fprintf(&b, "%s %s", spinner, status)
		b.WriteString("\n\n")

		// Show progress bar
		progressBar := fmt.Sprintf("[%s%s] %.0f%%",
			strings.Repeat("█", int(m.packageProgress.progress*30)),
			strings.Repeat("░", 30-int(m.packageProgress.progress*30)),
			m.packageProgress.progress*100)
		b.WriteString(m.styles.Normal.Render(progressBar))
		b.WriteString("\n")

		// Show command info if available
		if m.packageProgress.commandInfo != "" {
			cmdInfo := m.styles.Subtle.Render("$ " + m.packageProgress.commandInfo)
			b.WriteString(cmdInfo)
			b.WriteString("\n")
		}

		// Show live log output
		if len(m.installationLogs) > 0 {
			b.WriteString("\n")
			logHeader := m.styles.Subtle.Render("Live Output:")
			b.WriteString(logHeader)
			b.WriteString("\n")

			// Show last few lines of accumulated logs
			maxLines := 8
			startIdx := 0
			if len(m.installationLogs) > maxLines {
				startIdx = len(m.installationLogs) - maxLines
			}

			for i := startIdx; i < len(m.installationLogs); i++ {
				if m.installationLogs[i] != "" {
					logLine := m.styles.Subtle.Render("  " + m.installationLogs[i])
					b.WriteString(logLine)
					b.WriteString("\n")
				}
			}
		}

		// Show error if any
		if m.packageProgress.error != nil {
			b.WriteString("\n")
			wrappedErrorMsg := wrapText("Error: "+m.packageProgress.error.Error(), 80)
			errorMsg := m.styles.Error.Render(wrappedErrorMsg)
			b.WriteString(errorMsg)
		}

		// Show sudo prompt if needed
		if m.packageProgress.needsSudo {
			sudoWarning := m.styles.Warning.Render("⚠ Using provided sudo password")
			b.WriteString(sudoWarning)
		}
	} else {
		if m.packageProgress.error != nil {
			wrappedFailedMsg := wrapText("✗ Installation failed: "+m.packageProgress.error.Error(), 80)
			errorMsg := m.styles.Error.Render(wrappedFailedMsg)
			b.WriteString(errorMsg)
		} else {
			success := m.styles.Success.Render("✓ Installation complete!")
			b.WriteString(success)
		}
	}

	return b.String()
}

func dmsPackageName(distroID string, dependencies []deps.Dependency) string {
	config, ok := distros.Registry[distroID]
	if !ok {
		return "dms"
	}

	var isGit bool
	for _, dep := range dependencies {
		if dep.Name == "dms (DankMaterialShell)" {
			isGit = dep.Variant == deps.VariantGit
			break
		}
	}

	switch config.Family {
	case distros.FamilyArch:
		if isGit {
			return "dms-shell-git"
		}
		return "dms-shell"
	case distros.FamilyFedora, distros.FamilyUbuntu, distros.FamilyDebian, distros.FamilySUSE:
		if isGit {
			return "dms-git"
		}
		return "dms"
	default:
		return "dms"
	}
}

func uninstallCommand(distroID string, dependencies []deps.Dependency) string {
	config, ok := distros.Registry[distroID]
	if !ok {
		return ""
	}
	if config.Family == distros.FamilyGentoo {
		return "rm -rf ~/.config/quickshell/dms && sudo rm /usr/local/bin/dms"
	}
	pkg := dmsPackageName(distroID, dependencies)
	switch config.Family {
	case distros.FamilyArch:
		return "sudo pacman -Rs " + pkg
	case distros.FamilyFedora:
		return "sudo dnf remove " + pkg
	case distros.FamilyUbuntu, distros.FamilyDebian:
		return "sudo apt remove " + pkg
	case distros.FamilySUSE:
		return "sudo zypper remove " + pkg
	default:
		return ""
	}
}

func (m Model) viewInstallComplete() string {
	var b strings.Builder

	b.WriteString(m.renderBanner())
	b.WriteString("\n")

	title := m.styles.Success.Render("Setup Complete!")
	b.WriteString(title)
	b.WriteString("\n\n")

	success := m.styles.Success.Render("✓ All packages installed and configurations deployed.")
	b.WriteString(success)
	b.WriteString("\n\n")

	accomplishments := []string{
		"• Window manager and dependencies installed",
		"• Terminal and development tools configured",
		"• Configuration files deployed with backups",
		"• System optimized for DankMaterialShell",
	}

	for _, item := range accomplishments {
		b.WriteString(m.styles.Subtle.Render(item))
		b.WriteString("\n")
	}

	b.WriteString("\n")
	info := m.styles.Normal.Render("Your system is ready! Log out and log back in to start using\nyour new desktop environment.\nIf you do not have a greeter, login with \"niri-session\" or \"Hyprland\"")
	b.WriteString(info)
	b.WriteString("\n\n")

	theme := TerminalTheme()
	cmdStyle := lipgloss.NewStyle().Foreground(lipgloss.Color(theme.Accent))
	labelStyle := lipgloss.NewStyle().Foreground(lipgloss.Color(theme.Subtle))

	b.WriteString(labelStyle.Render("Troubleshooting:") + "\n")
	b.WriteString(labelStyle.Render("  Disable autostart: ") + cmdStyle.Render("systemctl --user disable dms") + "\n")
	b.WriteString(labelStyle.Render("  View logs:         ") + cmdStyle.Render("journalctl --user -u dms") + "\n")

	if m.osInfo != nil {
		if cmd := uninstallCommand(m.osInfo.Distribution.ID, m.dependencies); cmd != "" {
			b.WriteString(labelStyle.Render("  Uninstall:         ") + cmdStyle.Render(cmd) + "\n")
		}
	}

	b.WriteString("\n")
	b.WriteString(m.styles.Normal.Render("Press Enter to exit."))

	if m.logFilePath != "" {
		b.WriteString("\n\n")
		logInfo := m.styles.Subtle.Render(fmt.Sprintf("Full logs: %s", m.logFilePath))
		b.WriteString(logInfo)
	}

	return b.String()
}

func (m Model) viewError() string {
	var b strings.Builder

	b.WriteString(m.renderBanner())
	b.WriteString("\n")

	title := m.styles.Error.Render("Installation Failed")
	b.WriteString(title)
	b.WriteString("\n\n")

	if m.err != nil {
		wrappedError := wrapText("✗ "+m.err.Error(), 80)
		error := m.styles.Error.Render(wrappedError)
		b.WriteString(error)
		b.WriteString("\n\n")
	}

	// Show package progress error if available
	if m.packageProgress.error != nil {
		wrappedPackageError := wrapText("Package Installation Error: "+m.packageProgress.error.Error(), 80)
		packageError := m.styles.Error.Render(wrappedPackageError)
		b.WriteString(packageError)
		b.WriteString("\n\n")
	}

	// Show persistent installation logs
	if len(m.installationLogs) > 0 {
		logHeader := m.styles.Warning.Render("Installation Logs (last 15 lines):")
		b.WriteString(logHeader)
		b.WriteString("\n")

		maxLines := 15
		startIdx := 0
		if len(m.installationLogs) > maxLines {
			startIdx = len(m.installationLogs) - maxLines
		}

		for i := startIdx; i < len(m.installationLogs); i++ {
			if m.installationLogs[i] != "" {
				logLine := m.styles.Subtle.Render("  " + m.installationLogs[i])
				b.WriteString(logLine)
				b.WriteString("\n")
			}
		}
		b.WriteString("\n")
	}

	hint := m.styles.Subtle.Render("Press Ctrl+D for full debug logs")
	b.WriteString(hint)
	b.WriteString("\n")

	if m.logFilePath != "" {
		b.WriteString("\n")
		logInfo := m.styles.Warning.Render(fmt.Sprintf("Full logs: %s", m.logFilePath))
		b.WriteString(logInfo)
		b.WriteString("\n")
	}

	help := m.styles.Subtle.Render("Press Enter to exit")
	b.WriteString(help)

	return b.String()
}

func (m Model) updateInstallingPackagesState(msg tea.Msg) (tea.Model, tea.Cmd) {
	if progressMsg, ok := msg.(packageInstallProgressMsg); ok {
		m.packageProgress = progressMsg

		// Accumulate log output
		if progressMsg.logOutput != "" {
			m.installationLogs = append(m.installationLogs, progressMsg.logOutput)
			// Keep only last 50 lines to preserve more context for debugging
			if len(m.installationLogs) > 50 {
				m.installationLogs = m.installationLogs[len(m.installationLogs)-50:]
			}
		}

		if progressMsg.isComplete {
			if progressMsg.error != nil {
				m.state = StateError
				m.isLoading = false
			} else {
				m.installationLogs = []string{}
				m.state = StateConfigConfirmation
				m.isLoading = true
				return m, tea.Batch(m.spinner.Tick, m.checkExistingConfigurations())
			}
		}
		return m, m.listenForPackageProgress()
	}
	return m, m.listenForLogs()
}

func (m Model) updateInstallCompleteState(msg tea.Msg) (tea.Model, tea.Cmd) {
	if keyMsg, ok := msg.(tea.KeyMsg); ok {
		switch keyMsg.String() {
		case "enter":
			return m, tea.Quit
		}
	}
	return m, m.listenForLogs()
}

func (m Model) updateErrorState(msg tea.Msg) (tea.Model, tea.Cmd) {
	if keyMsg, ok := msg.(tea.KeyMsg); ok {
		switch keyMsg.String() {
		case "enter":
			return m, tea.Quit
		}
	}
	return m, m.listenForLogs()
}

func (m Model) listenForPackageProgress() tea.Cmd {
	return func() tea.Msg {
		msg, ok := <-m.packageProgressChan
		if !ok {
			return packageProgressCompletedMsg{}
		}
		// Always return the message, completion will be handled in updateInstallingPackagesState
		return msg
	}
}

func (m Model) viewDebugLogs() string {
	var b strings.Builder

	theme := TerminalTheme()

	titleStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color(theme.Primary)).
		Bold(true)

	b.WriteString(titleStyle.Render("Debug Logs"))
	b.WriteString("\n\n")

	// Combine both logMessages and installationLogs
	allLogs := append([]string{}, m.logMessages...)
	allLogs = append(allLogs, m.installationLogs...)

	if len(allLogs) == 0 {
		b.WriteString("No logs available\n")
	} else {
		// Calculate available height (reserve space for header and footer)
		maxHeight := m.height - 6
		if maxHeight < 10 {
			maxHeight = 10
		}

		// Show the most recent logs
		startIdx := 0
		if len(allLogs) > maxHeight {
			startIdx = len(allLogs) - maxHeight
		}

		for i := startIdx; i < len(allLogs); i++ {
			if allLogs[i] != "" {
				fmt.Fprintf(&b, "%d: %s\n", i, allLogs[i])
			}
		}

		if startIdx > 0 {
			subtleStyle := lipgloss.NewStyle().Foreground(lipgloss.Color(theme.Subtle))
			b.WriteString(subtleStyle.Render(fmt.Sprintf("... (%d older log entries hidden)\n", startIdx)))
		}
	}

	b.WriteString("\n")
	statusStyle := lipgloss.NewStyle().Foreground(lipgloss.Color(theme.Accent))
	b.WriteString(statusStyle.Render("Press Ctrl+D to return, Ctrl+C to quit"))

	return b.String()
}
