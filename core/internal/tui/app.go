package tui

import (
	"github.com/AvengeMedia/DankMaterialShell/core/internal/deps"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/distros"
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
)

type Model struct {
	version string
	state   ApplicationState

	osInfo       *distros.OSInfo
	dependencies []deps.Dependency
	err          error

	spinner       spinner.Model
	passwordInput textinput.Model
	width         int
	height        int
	isLoading     bool
	styles        Styles

	logMessages         []string
	logChan             chan string
	logFilePath         string
	packageProgressChan chan packageInstallProgressMsg
	packageProgress     packageInstallProgressMsg
	installationLogs    []string
	showDebugLogs       bool

	selectedWM         int
	selectedTerminal   int
	selectedDep        int
	selectedConfig     int
	reinstallItems     map[string]bool
	disabledItems      map[string]bool
	replaceConfigs     map[string]bool
	skipGentooUseFlags bool
	sudoPassword       string
	existingConfigs    []ExistingConfigInfo
	fingerprintFailed  bool
}

func NewModel(version string, logFilePath string) Model {
	s := spinner.New()
	s.Spinner = spinner.Dot

	theme := TerminalTheme()
	styles := NewStyles(theme)
	s.Style = styles.SpinnerStyle

	pi := textinput.New()
	pi.Placeholder = "Enter sudo password"
	pi.EchoMode = textinput.EchoPassword
	pi.EchoCharacter = '•'
	pi.Focus()

	logChan := make(chan string, 1000)
	packageProgressChan := make(chan packageInstallProgressMsg, 100)

	return Model{
		version:       version,
		state:         StateWelcome,
		spinner:       s,
		passwordInput: pi,
		isLoading:     true,
		styles:        styles,

		logMessages:         []string{},
		logChan:             logChan,
		logFilePath:         logFilePath,
		packageProgressChan: packageProgressChan,
		packageProgress: packageInstallProgressMsg{
			progress:   0.0,
			step:       "Initializing package installation",
			isComplete: false,
		},
		showDebugLogs:    false,
		selectedWM:       0,
		selectedTerminal: 0, // Default to Ghostty
		selectedDep:      0,
		selectedConfig:   0,
		reinstallItems:   make(map[string]bool),
		disabledItems:    make(map[string]bool),
		replaceConfigs:   make(map[string]bool),
		installationLogs: []string{},
	}
}

func (m Model) GetLogChan() <-chan string {
	return m.logChan
}

func (m Model) Init() tea.Cmd {
	return tea.Batch(
		m.spinner.Tick,
		m.listenForLogs(),
		m.detectOS(),
	)
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	if keyMsg, ok := msg.(tea.KeyMsg); ok {
		switch keyMsg.String() {
		case "ctrl+c":
			return m, tea.Quit
		case "ctrl+d":
			// Toggle debug logs view (except during password input states)
			if m.state != StatePasswordPrompt && m.state != StateFingerprintAuth {
				m.showDebugLogs = !m.showDebugLogs
				return m, nil
			}
		}
	}

	if tickMsg, ok := msg.(spinner.TickMsg); ok {
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(tickMsg)
		return m, tea.Batch(cmd, m.listenForLogs())
	}

	if sizeMsg, ok := msg.(tea.WindowSizeMsg); ok {
		m.width = sizeMsg.Width
		m.height = sizeMsg.Height
	}

	if logMsg, ok := msg.(logMsg); ok {
		m.logMessages = append(m.logMessages, logMsg.message)
		return m, m.listenForLogs()
	}

	switch m.state {
	case StateWelcome:
		return m.updateWelcomeState(msg)
	case StateSelectWindowManager:
		return m.updateSelectWindowManagerState(msg)
	case StateSelectTerminal:
		return m.updateSelectTerminalState(msg)
	case StateDetectingDeps:
		return m.updateDetectingDepsState(msg)
	case StateDependencyReview:
		return m.updateDependencyReviewState(msg)
	case StateGentooUseFlags:
		return m.updateGentooUseFlagsState(msg)
	case StateGentooGCCCheck:
		return m.updateGentooGCCCheckState(msg)
	case StateAuthMethodChoice:
		return m.updateAuthMethodChoiceState(msg)
	case StateFingerprintAuth:
		return m.updateFingerprintAuthState(msg)
	case StatePasswordPrompt:
		return m.updatePasswordPromptState(msg)
	case StateInstallingPackages:
		return m.updateInstallingPackagesState(msg)
	case StateConfigConfirmation:
		return m.updateConfigConfirmationState(msg)
	case StateDeployingConfigs:
		return m.updateDeployingConfigsState(msg)
	case StateInstallComplete:
		return m.updateInstallCompleteState(msg)
	case StateError:
		return m.updateErrorState(msg)
	default:
		return m, m.listenForLogs()
	}
}

func (m Model) View() string {
	// If debug logs are shown, show that view regardless of state
	if m.showDebugLogs {
		return m.viewDebugLogs()
	}

	switch m.state {
	case StateWelcome:
		return m.viewWelcome()
	case StateSelectWindowManager:
		return m.viewSelectWindowManager()
	case StateSelectTerminal:
		return m.viewSelectTerminal()
	case StateDetectingDeps:
		return m.viewDetectingDeps()
	case StateDependencyReview:
		return m.viewDependencyReview()
	case StateGentooUseFlags:
		return m.viewGentooUseFlags()
	case StateGentooGCCCheck:
		return m.viewGentooGCCCheck()
	case StateAuthMethodChoice:
		return m.viewAuthMethodChoice()
	case StateFingerprintAuth:
		return m.viewFingerprintAuth()
	case StatePasswordPrompt:
		return m.viewPasswordPrompt()
	case StateInstallingPackages:
		return m.viewInstallingPackages()
	case StateConfigConfirmation:
		return m.viewConfigConfirmation()
	case StateDeployingConfigs:
		return m.viewDeployingConfigs()
	case StateInstallComplete:
		return m.viewInstallComplete()
	case StateError:
		return m.viewError()
	default:
		return m.viewWelcome()
	}
}

func (m Model) listenForLogs() tea.Cmd {
	return func() tea.Msg {
		select {
		case msg, ok := <-m.logChan:
			if !ok {
				return nil
			}
			return logMsg{message: msg}
		default:
			return nil
		}
	}
}

func (m Model) detectOS() tea.Cmd {
	return func() tea.Msg {
		info, err := distros.GetOSInfo()
		osInfoMsg := &distros.OSInfo{}
		if info != nil {
			osInfoMsg.Distribution = info.Distribution
			osInfoMsg.Version = info.Version
			osInfoMsg.VersionID = info.VersionID
			osInfoMsg.PrettyName = info.PrettyName
			osInfoMsg.Architecture = info.Architecture
		}
		return osInfoCompleteMsg{info: osInfoMsg, err: err}
	}
}
