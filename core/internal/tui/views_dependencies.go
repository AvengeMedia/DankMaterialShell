package tui

import (
	"context"
	"fmt"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/deps"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/distros"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/greeter"
	tea "github.com/charmbracelet/bubbletea"
)

func (m Model) viewDetectingDeps() string {
	var b strings.Builder

	b.WriteString(m.renderBanner())
	b.WriteString("\n")

	title := m.styles.Title.Render("Detecting Dependencies")
	b.WriteString(title)
	b.WriteString("\n\n")

	spinner := m.spinner.View()
	status := m.styles.Normal.Render("Scanning system for existing packages and configurations...")
	b.WriteString(fmt.Sprintf("%s %s", spinner, status))

	return b.String()
}

func (m Model) viewDependencyReview() string {
	var b strings.Builder

	b.WriteString(m.renderBanner())
	b.WriteString("\n")

	title := m.styles.Title.Render("Dependency Review")
	b.WriteString(title)
	b.WriteString("\n\n")

	if len(m.dependencies) > 0 {
		for i, dep := range m.dependencies {
			var status string
			var reinstallMarker string
			var variantMarker string

			isDMS := dep.Name == "dms (DankMaterialShell)"

			if dep.CanToggle && dep.Variant == deps.VariantGit {
				variantMarker = "[git] "
			}

			if m.disabledItems[dep.Name] {
				reinstallMarker = "✗ "
				status = m.styles.Subtle.Render("Will skip")
			} else if m.reinstallItems[dep.Name] {
				reinstallMarker = "🔄 "
				status = m.styles.Warning.Render("Will upgrade")
			} else if isDMS {
				reinstallMarker = "⚡ "
				switch dep.Status {
				case deps.StatusInstalled:
					status = m.styles.Success.Render("✓ Required (installed)")
				case deps.StatusMissing:
					status = m.styles.Warning.Render("○ Required (will install)")
				case deps.StatusNeedsUpdate:
					status = m.styles.Warning.Render("△ Required (needs update)")
				case deps.StatusNeedsReinstall:
					status = m.styles.Error.Render("! Required (needs reinstall)")
				}
			} else {
				switch dep.Status {
				case deps.StatusInstalled:
					status = m.styles.Subtle.Render("✓ Already installed")
				case deps.StatusMissing:
					status = m.styles.Warning.Render("○ Will install")
				case deps.StatusNeedsUpdate:
					status = m.styles.Warning.Render("△ Will install")
				case deps.StatusNeedsReinstall:
					status = m.styles.Error.Render("! Will install")
				}
			}

			note := ""
			if dep.Name == "dms-greeter" {
				note = m.styles.Subtle.Render(" (selection replaces your current display manager)")
			}

			var line string
			if i == m.selectedDep {
				line = fmt.Sprintf("▶ %s%s%-25s %s", reinstallMarker, variantMarker, dep.Name, status)
				if dep.Version != "" {
					line += fmt.Sprintf(" (%s)", dep.Version)
				}
				line = m.styles.SelectedOption.Render(line) + note
			} else {
				line = fmt.Sprintf("  %s%s%-25s %s", reinstallMarker, variantMarker, dep.Name, status)
				if dep.Version != "" {
					line += fmt.Sprintf(" (%s)", dep.Version)
				}
				line = m.styles.Normal.Render(line) + note
			}

			b.WriteString(line)
			b.WriteString("\n")
		}
	}

	b.WriteString("\n")
	help := m.styles.Subtle.Render("↑/↓: Navigate, Space: Toggle, G: Toggle stable/git, Enter: Continue")
	b.WriteString(help)

	return b.String()
}

func (m Model) updateDetectingDepsState(msg tea.Msg) (tea.Model, tea.Cmd) {
	if depsMsg, ok := msg.(depsDetectedMsg); ok {
		m.isLoading = false
		if depsMsg.err != nil {
			m.err = depsMsg.err
			m.state = StateError
		} else {
			m.dependencies = depsMsg.deps
			// dms-greeter is opt-in skipped by default
			for _, dep := range depsMsg.deps {
				if dep.Name == "dms-greeter" {
					m.disabledItems["dms-greeter"] = true
					break
				}
			}
			m.state = StateDependencyReview
		}
		return m, m.listenForLogs()
	}
	return m, m.listenForLogs()
}

func (m Model) updateDependencyReviewState(msg tea.Msg) (tea.Model, tea.Cmd) {
	if keyMsg, ok := msg.(tea.KeyMsg); ok {
		switch keyMsg.String() {
		case "up":
			if m.selectedDep > 0 {
				m.selectedDep--
			}
		case "down":
			if m.selectedDep < len(m.dependencies)-1 {
				m.selectedDep++
			}
		case " ":
			if len(m.dependencies) > 0 {
				depName := m.dependencies[m.selectedDep].Name
				isDMS := depName == "dms (DankMaterialShell)"

				if !isDMS {
					isInstalled := m.dependencies[m.selectedDep].Status == deps.StatusInstalled ||
						m.dependencies[m.selectedDep].Status == deps.StatusNeedsReinstall

					if isInstalled {
						m.reinstallItems[depName] = !m.reinstallItems[depName]
						m.disabledItems[depName] = false
					} else {
						m.disabledItems[depName] = !m.disabledItems[depName]
						m.reinstallItems[depName] = false
					}
				}
			}
		case "g", "G":
			if len(m.dependencies) > 0 && m.dependencies[m.selectedDep].CanToggle {
				if m.dependencies[m.selectedDep].Variant == deps.VariantStable {
					m.dependencies[m.selectedDep].Variant = deps.VariantGit
				} else {
					m.dependencies[m.selectedDep].Variant = deps.VariantStable
				}
			}
		case "enter":
			// Check if on Gentoo - show USE flags screen
			if m.osInfo != nil {
				if config, exists := distros.Registry[m.osInfo.Distribution.ID]; exists && config.Family == distros.FamilyGentoo {
					m.state = StateGentooUseFlags
					return m, nil
				}
			}
			// Check if fingerprint is enabled
			if checkFingerprintEnabled() {
				m.state = StateAuthMethodChoice
				m.selectedConfig = 0 // Default to fingerprint
				return m, nil
			} else {
				m.state = StatePasswordPrompt
				m.passwordInput.Focus()
				return m, nil
			}
		case "esc":
			m.state = StateSelectWindowManager
			return m, nil
		}
	}
	return m, m.listenForLogs()
}

func (m Model) installPackages() tea.Cmd {
	return func() tea.Msg {
		if m.osInfo == nil {
			return packageInstallProgressMsg{
				progress:   0.0,
				step:       "Error: OS info not available",
				isComplete: true,
			}
		}

		installer, err := distros.NewPackageInstaller(m.osInfo.Distribution.ID, m.logChan)
		if err != nil {
			return packageInstallProgressMsg{
				progress:   0.0,
				step:       fmt.Sprintf("Error: %s", err.Error()),
				isComplete: true,
			}
		}

		// Convert TUI selection to deps enum
		var wm deps.WindowManager
		if m.selectedWM == 0 {
			wm = deps.WindowManagerNiri
		} else {
			wm = deps.WindowManagerHyprland
		}

		installerProgressChan := make(chan distros.InstallProgressMsg, 100)

		go func() {
			defer close(installerProgressChan)
			err := installer.InstallPackages(context.Background(), m.dependencies, wm, m.sudoPassword, m.reinstallItems, m.disabledItems, m.skipGentooUseFlags, installerProgressChan)
			if err != nil {
				installerProgressChan <- distros.InstallProgressMsg{
					Progress:   0.0,
					Step:       fmt.Sprintf("Installation error: %s", err.Error()),
					IsComplete: true,
					Error:      err,
				}
			}
		}()

		// Convert installer messages to TUI messages
		go func() {
			for msg := range installerProgressChan {
				// Run optional greeter setup
				if msg.Phase == distros.PhaseComplete && msg.IsComplete && msg.Error == nil {
					greeterSelected := false
					for _, dep := range m.dependencies {
						if dep.Name == "dms-greeter" && !m.disabledItems["dms-greeter"] {
							greeterSelected = true
							break
						}
					}
					if greeterSelected {
						compositorName := "niri"
						if m.selectedWM == 1 {
							compositorName = "Hyprland"
						}
						m.packageProgressChan <- packageInstallProgressMsg{
							progress:  0.92,
							step:      "Configuring DMS greeter...",
							logOutput: "Starting automated greeter setup...",
						}
						greeterLogFunc := func(line string) {
							m.packageProgressChan <- packageInstallProgressMsg{
								progress:  0.94,
								step:      "Configuring DMS greeter...",
								logOutput: line,
							}
						}
						if err := greeter.AutoSetupGreeter(compositorName, m.sudoPassword, greeterLogFunc); err != nil {
							m.packageProgressChan <- packageInstallProgressMsg{
								progress:  0.96,
								step:      "Greeter setup warning",
								logOutput: fmt.Sprintf("⚠ Greeter auto-setup warning (non-fatal): %v", err),
							}
						}
					}
				}
				tuiMsg := packageInstallProgressMsg{
					progress:    msg.Progress,
					step:        msg.Step,
					isComplete:  msg.IsComplete,
					needsSudo:   msg.NeedsSudo,
					commandInfo: msg.CommandInfo,
					logOutput:   msg.LogOutput,
					error:       msg.Error,
				}
				if msg.IsComplete {
					m.logChan <- fmt.Sprintf("[DEBUG] Sending completion signal: step=%s, progress=%.2f", msg.Step, msg.Progress)
				}
				m.packageProgressChan <- tuiMsg
			}
			m.logChan <- "[DEBUG] Installer channel closed"
		}()

		return packageInstallProgressMsg{
			progress:   0.05,
			step:       "Starting installation...",
			isComplete: false,
		}
	}
}
