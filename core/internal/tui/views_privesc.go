package tui

import (
	"fmt"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/privesc"
	tea "github.com/charmbracelet/bubbletea"
)

func (m Model) viewSelectPrivesc() string {
	var b strings.Builder

	b.WriteString(m.renderBanner())
	b.WriteString("\n")
	b.WriteString(m.styles.Title.Render("Privilege Escalation Tool"))
	b.WriteString("\n\n")
	b.WriteString(m.styles.Normal.Render("Multiple privilege tools are available. Choose one for installation:"))
	b.WriteString("\n\n")

	for i, t := range m.availablePrivesc {
		label := fmt.Sprintf("%s  —  %s", t.Name(), privescToolDescription(t))
		switch i {
		case m.selectedPrivesc:
			b.WriteString(m.styles.SelectedOption.Render("▶ " + label))
		default:
			b.WriteString(m.styles.Normal.Render("  " + label))
		}
		b.WriteString("\n")
	}

	b.WriteString("\n")
	b.WriteString(m.styles.Subtle.Render(fmt.Sprintf("Set %s=<tool> to skip this prompt in future runs.", privesc.EnvVar)))
	b.WriteString("\n\n")
	b.WriteString(m.styles.Subtle.Render("↑/↓: Navigate, Enter: Select, Esc: Back"))
	return b.String()
}

func (m Model) updateSelectPrivescState(msg tea.Msg) (tea.Model, tea.Cmd) {
	keyMsg, ok := msg.(tea.KeyMsg)
	if !ok {
		return m, m.listenForLogs()
	}

	switch keyMsg.String() {
	case "up":
		if m.selectedPrivesc > 0 {
			m.selectedPrivesc--
		}
	case "down":
		if m.selectedPrivesc < len(m.availablePrivesc)-1 {
			m.selectedPrivesc++
		}
	case "enter":
		chosen := m.availablePrivesc[m.selectedPrivesc]
		if err := privesc.SetTool(chosen); err != nil {
			m.err = fmt.Errorf("failed to select %s: %w", chosen.Name(), err)
			m.state = StateError
			return m, nil
		}
		return m.routeToAuthAfterPrivesc()
	case "esc":
		m.state = StateDependencyReview
		return m, nil
	}
	return m, nil
}

func privescToolDescription(t privesc.Tool) string {
	switch t {
	case privesc.ToolSudo:
		return "classic sudo (supports password prompt in this installer)"
	case privesc.ToolDoas:
		return "OpenBSD-style doas (requires persist or nopass in /etc/doas.conf)"
	case privesc.ToolRun0:
		return "systemd run0 (authenticated via polkit)"
	default:
		return string(t)
	}
}

// routeToAuthAfterPrivesc advances from the privesc-selection screen to the
// right auth flow. Sudo goes through the fingerprint/password path; doas and
// run0 skip password entry and proceed to install.
func (m Model) routeToAuthAfterPrivesc() (tea.Model, tea.Cmd) {
	tool, err := privesc.Detect()
	if err != nil {
		m.err = err
		m.state = StateError
		return m, nil
	}

	if tool == privesc.ToolSudo {
		if checkFingerprintEnabled() {
			m.state = StateAuthMethodChoice
			m.selectedConfig = 0
			return m, nil
		}
		m.state = StatePasswordPrompt
		m.passwordInput.Focus()
		return m, nil
	}

	m.sudoPassword = ""
	m.packageProgress = packageInstallProgressMsg{}
	m.state = StateInstallingPackages
	m.isLoading = true
	return m, tea.Batch(m.spinner.Tick, m.installPackages())
}

// enterAuthPhase is called when dependency review (or the Gentoo screens)
// finish. It either routes directly to the sudo/fingerprint flow or shows
// the privesc-tool selection screen when multiple tools are available and
// no $DMS_PRIVESC override is set.
func (m Model) enterAuthPhase() (tea.Model, tea.Cmd) {
	tools := privesc.AvailableTools()
	_, envSet := privesc.EnvOverride()

	if len(tools) == 0 {
		m.err = fmt.Errorf("no supported privilege tool (sudo/doas/run0) found on PATH")
		m.state = StateError
		return m, nil
	}

	if envSet || len(tools) == 1 {
		return m.routeToAuthAfterPrivesc()
	}

	m.availablePrivesc = tools
	m.selectedPrivesc = 0
	m.state = StateSelectPrivesc
	return m, nil
}
