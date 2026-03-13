package tui

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

func (m Model) viewAuthMethodChoice() string {
	var b strings.Builder

	b.WriteString(m.renderBanner())
	b.WriteString("\n")

	title := m.styles.Title.Render("Authentication Method")
	b.WriteString(title)
	b.WriteString("\n\n")

	message := "Fingerprint authentication is available.\nHow would you like to authenticate?"
	b.WriteString(m.styles.Normal.Render(message))
	b.WriteString("\n\n")

	// Option 0: Fingerprint
	if m.selectedConfig == 0 {
		option := m.styles.SelectedOption.Render("▶ Use Fingerprint")
		b.WriteString(option)
	} else {
		option := m.styles.Normal.Render("  Use Fingerprint")
		b.WriteString(option)
	}
	b.WriteString("\n")

	// Option 1: Password
	if m.selectedConfig == 1 {
		option := m.styles.SelectedOption.Render("▶ Use Password")
		b.WriteString(option)
	} else {
		option := m.styles.Normal.Render("  Use Password")
		b.WriteString(option)
	}
	b.WriteString("\n\n")

	help := m.styles.Subtle.Render("↑/↓: Navigate, Enter: Select, Esc: Back")
	b.WriteString(help)

	return b.String()
}

func (m Model) viewFingerprintAuth() string {
	var b strings.Builder

	b.WriteString(m.renderBanner())
	b.WriteString("\n")

	title := m.styles.Title.Render("Fingerprint Authentication")
	b.WriteString(title)
	b.WriteString("\n\n")

	if m.fingerprintFailed {
		errorMsg := m.styles.Error.Render("✗ Fingerprint authentication failed")
		b.WriteString(errorMsg)
		b.WriteString("\n")
		retryMsg := m.styles.Subtle.Render("Returning to authentication menu...")
		b.WriteString(retryMsg)
	} else {
		message := "Please place your finger on the fingerprint reader."
		b.WriteString(m.styles.Normal.Render(message))
		b.WriteString("\n\n")

		spinner := m.spinner.View()
		status := m.styles.Normal.Render("Waiting for fingerprint...")
		fmt.Fprintf(&b, "%s %s", spinner, status)
	}

	return b.String()
}

func (m Model) viewPasswordPrompt() string {
	var b strings.Builder

	b.WriteString(m.renderBanner())
	b.WriteString("\n")

	title := m.styles.Title.Render("Password Authentication")
	b.WriteString(title)
	b.WriteString("\n\n")

	message := "Installation requires sudo privileges.\nPlease enter your password to continue:"
	b.WriteString(m.styles.Normal.Render(message))
	b.WriteString("\n\n")

	// Password input
	b.WriteString(m.passwordInput.View())
	b.WriteString("\n")

	// Show validation status
	if m.packageProgress.step == "Validating sudo password..." {
		spinner := m.spinner.View()
		status := m.styles.Normal.Render(m.packageProgress.step)
		b.WriteString(spinner + " " + status)
		b.WriteString("\n")
	} else if m.packageProgress.error != nil {
		errorMsg := m.styles.Error.Render("✗ " + m.packageProgress.error.Error() + ". Please try again.")
		b.WriteString(errorMsg)
		b.WriteString("\n")
	} else if m.packageProgress.step == "Password validation failed" {
		errorMsg := m.styles.Error.Render("✗ Incorrect password. Please try again.")
		b.WriteString(errorMsg)
		b.WriteString("\n")
	}

	b.WriteString("\n")
	help := m.styles.Subtle.Render("Enter: Continue, Esc: Back, Ctrl+C: Cancel")
	b.WriteString(help)

	return b.String()
}

func (m Model) updateAuthMethodChoiceState(msg tea.Msg) (tea.Model, tea.Cmd) {
	m.fingerprintFailed = false

	if keyMsg, ok := msg.(tea.KeyMsg); ok {
		switch keyMsg.String() {
		case "up":
			if m.selectedConfig > 0 {
				m.selectedConfig--
			}
		case "down":
			if m.selectedConfig < 1 {
				m.selectedConfig++
			}
		case "enter":
			if m.selectedConfig == 0 {
				m.state = StateFingerprintAuth
				m.isLoading = true
				return m, tea.Batch(m.spinner.Tick, m.tryFingerprint())
			} else {
				m.state = StatePasswordPrompt
				m.passwordInput.Focus()
				return m, nil
			}
		case "esc":
			m.state = StateDependencyReview
			return m, nil
		}
	}
	return m, nil
}

func (m Model) updateFingerprintAuthState(msg tea.Msg) (tea.Model, tea.Cmd) {
	if validMsg, ok := msg.(passwordValidMsg); ok {
		if validMsg.valid {
			m.sudoPassword = ""
			m.packageProgress = packageInstallProgressMsg{}
			m.state = StateInstallingPackages
			m.isLoading = true
			return m, tea.Batch(m.spinner.Tick, m.installPackages())
		} else {
			m.fingerprintFailed = true
			return m, m.delayThenReturn()
		}
	}

	if _, ok := msg.(delayCompleteMsg); ok {
		m.fingerprintFailed = false
		m.selectedConfig = 0
		m.state = StateAuthMethodChoice
		return m, nil
	}

	return m, m.listenForLogs()
}

func (m Model) updatePasswordPromptState(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd

	if validMsg, ok := msg.(passwordValidMsg); ok {
		if validMsg.valid {
			// Password is valid, proceed with installation
			m.sudoPassword = validMsg.password
			m.passwordInput.SetValue("") // Clear password input
			// Clear any error state
			m.packageProgress = packageInstallProgressMsg{}
			m.state = StateInstallingPackages
			m.isLoading = true
			return m, tea.Batch(m.spinner.Tick, m.installPackages())
		} else {
			// Password is invalid, show error and stay on password prompt
			m.packageProgress = packageInstallProgressMsg{
				progress:  0.0,
				step:      "Password validation failed",
				error:     fmt.Errorf("incorrect password"),
				logOutput: "Authentication failed",
			}
			m.passwordInput.SetValue("")
			m.passwordInput.Focus()
			return m, nil
		}
	}

	if keyMsg, ok := msg.(tea.KeyMsg); ok {
		switch keyMsg.String() {
		case "enter":
			// Don't allow multiple validation attempts while one is in progress
			if m.packageProgress.step == "Validating sudo password..." {
				return m, nil
			}

			// Validate password first
			password := m.passwordInput.Value()
			if password == "" {
				return m, nil // Don't proceed with empty password
			}

			// Clear any previous error and show validation in progress
			m.packageProgress = packageInstallProgressMsg{
				progress:   0.01,
				step:       "Validating sudo password...",
				isComplete: false,
				logOutput:  "Testing password with sudo -v",
			}
			return m, m.validatePassword(password)
		case "esc":
			// Go back to dependency review
			m.passwordInput.SetValue("")
			m.packageProgress = packageInstallProgressMsg{} // Clear any validation state
			m.state = StateDependencyReview
			return m, nil
		}
	}

	m.passwordInput, cmd = m.passwordInput.Update(msg)
	return m, cmd
}

func checkFingerprintEnabled() bool {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	// Check if pam_fprintd.so is in PAM config
	cmd := exec.CommandContext(ctx, "grep", "-q", "pam_fprintd.so", "/etc/pam.d/system-auth")
	if err := cmd.Run(); err != nil {
		return false
	}

	// Check if fprintd-list exists and user has enrolled fingerprints
	user := os.Getenv("USER")
	if user == "" {
		return false
	}

	listCmd := exec.CommandContext(ctx, "fprintd-list", user)
	output, err := listCmd.CombinedOutput()
	if err != nil {
		return false
	}

	// If output contains "finger:" or similar, fingerprints are enrolled
	return strings.Contains(string(output), "finger")
}

func (m Model) delayThenReturn() tea.Cmd {
	return func() tea.Msg {
		time.Sleep(2 * time.Second)
		return delayCompleteMsg{}
	}
}

func (m Model) tryFingerprint() tea.Cmd {
	return func() tea.Msg {
		clearCmd := exec.Command("sudo", "-k")
		clearCmd.Run()

		tmpDir := os.TempDir()
		askpassScript := filepath.Join(tmpDir, fmt.Sprintf("danklinux-fp-%d.sh", time.Now().UnixNano()))

		scriptContent := "#!/bin/sh\nexit 1\n"
		if err := os.WriteFile(askpassScript, []byte(scriptContent), 0o700); err != nil {
			return passwordValidMsg{password: "", valid: false}
		}
		defer os.Remove(askpassScript)

		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()

		cmd := exec.CommandContext(ctx, "sudo", "-A", "-v")
		cmd.Env = append(os.Environ(), fmt.Sprintf("SUDO_ASKPASS=%s", askpassScript))

		err := cmd.Run()

		if err != nil {
			return passwordValidMsg{password: "", valid: false}
		}

		return passwordValidMsg{password: "", valid: true}
	}
}

func (m Model) validatePassword(password string) tea.Cmd {
	return func() tea.Msg {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		cmd := exec.CommandContext(ctx, "sudo", "-S", "-v")

		stdin, err := cmd.StdinPipe()
		if err != nil {
			return passwordValidMsg{password: "", valid: false}
		}

		if err := cmd.Start(); err != nil {
			return passwordValidMsg{password: "", valid: false}
		}

		_, err = fmt.Fprintf(stdin, "%s\n", password)
		stdin.Close()
		if err != nil {
			return passwordValidMsg{password: "", valid: false}
		}

		err = cmd.Wait()

		if err != nil {
			if ctx.Err() == context.DeadlineExceeded {
				return passwordValidMsg{password: "", valid: false}
			}
			return passwordValidMsg{password: "", valid: false}
		}

		return passwordValidMsg{password: password, valid: true}
	}
}
