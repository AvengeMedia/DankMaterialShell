//go:build !distro_binary

package dms

import (
	"os/exec"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/deps"
	tea "github.com/charmbracelet/bubbletea"
)

type AppState int

const (
	StateMainMenu AppState = iota
	StateUpdate
	StateUpdatePassword
	StateUpdateProgress
	StateShell
	StatePluginsMenu
	StatePluginsBrowse
	StatePluginDetail
	StatePluginSearch
	StatePluginsInstalled
	StatePluginInstalledDetail
	StateGreeterMenu
	StateGreeterCompositorSelect
	StateGreeterPassword
	StateGreeterInstalling
	StateAbout
)

type Model struct {
	version      string
	detector     *Detector
	dependencies []DependencyInfo
	state        AppState
	selectedItem int
	width        int
	height       int

	// Menu items
	menuItems []MenuItem

	updateDeps        []DependencyInfo
	selectedUpdateDep int
	updateToggles     map[string]bool

	updateProgressChan chan updateProgressMsg
	updateProgress     updateProgressMsg
	updateLogs         []string
	sudoPassword       string
	passwordInput      string
	passwordError      string

	// Window manager states
	hyprlandInstalled bool
	niriInstalled     bool

	selectedGreeterItem     int
	greeterInstallChan      chan greeterProgressMsg
	greeterProgress         greeterProgressMsg
	greeterLogs             []string
	greeterPasswordInput    string
	greeterPasswordError    string
	greeterSudoPassword     string
	greeterCompositors      []string
	greeterSelectedComp     int
	greeterChosenCompositor string

	pluginsMenuItems        []MenuItem
	selectedPluginsMenuItem int
	pluginsList             []pluginInfo
	filteredPluginsList     []pluginInfo
	selectedPluginIndex     int
	pluginsLoading          bool
	pluginsError            string
	pluginSearchQuery       string
	installedPluginsList    []pluginInfo
	selectedInstalledIndex  int
	installedPluginsLoading bool
	installedPluginsError   string
	pluginInstallStatus     map[string]bool
}

type pluginInfo struct {
	ID           string
	Name         string
	Category     string
	Author       string
	Description  string
	Repo         string
	Path         string
	Capabilities []string
	Compositors  []string
	Dependencies []string
	FirstParty   bool
}

type MenuItem struct {
	Label  string
	Action AppState
}

func NewModel(version string) Model {
	detector, _ := NewDetector()
	var dependencies []DependencyInfo
	var hyprlandInstalled, niriInstalled bool
	var err error
	if detector != nil {
		dependencies = detector.GetInstalledComponents()

		// Use the proper detection method for both window managers
		hyprlandInstalled, niriInstalled, err = detector.GetWindowManagerStatus()
		if err != nil {
			// Fallback to false if detection fails
			hyprlandInstalled = false
			niriInstalled = false
		}
	}

	updateToggles := make(map[string]bool)
	for _, dep := range dependencies {
		if dep.Name == "dms (DankMaterialShell)" && dep.Status == deps.StatusNeedsUpdate {
			updateToggles[dep.Name] = true
			break
		}
	}

	m := Model{
		version:             version,
		detector:            detector,
		dependencies:        dependencies,
		state:               StateMainMenu,
		selectedItem:        0,
		updateToggles:       updateToggles,
		updateDeps:          dependencies,
		updateProgressChan:  make(chan updateProgressMsg, 100),
		hyprlandInstalled:   hyprlandInstalled,
		niriInstalled:       niriInstalled,
		greeterInstallChan:  make(chan greeterProgressMsg, 100),
		pluginInstallStatus: make(map[string]bool),
	}

	m.menuItems = m.buildMenuItems()
	return m
}

func (m *Model) buildMenuItems() []MenuItem {
	items := []MenuItem{
		{Label: "Update", Action: StateUpdate},
	}

	// Shell management
	if m.isShellRunning() {
		items = append(items, MenuItem{Label: "Terminate Shell", Action: StateShell})
	} else {
		items = append(items, MenuItem{Label: "Start Shell (Daemon)", Action: StateShell})
	}

	// Plugins management
	items = append(items, MenuItem{Label: "Plugins", Action: StatePluginsMenu})

	// Greeter management
	items = append(items, MenuItem{Label: "Greeter", Action: StateGreeterMenu})

	items = append(items, MenuItem{Label: "About", Action: StateAbout})

	return items
}

func (m *Model) buildPluginsMenuItems() []MenuItem {
	return []MenuItem{
		{Label: "Browse Plugins", Action: StatePluginsBrowse},
		{Label: "View Installed", Action: StatePluginsInstalled},
	}
}

func (m *Model) isShellRunning() bool {
	// Check for both -c and -p flag patterns since quickshell can be started either way
	// -c dms: config name mode
	// -p <path>/dms: path mode (used when installed via system packages)
	cmd := exec.Command("pgrep", "-f", "qs.*dms")
	err := cmd.Run()
	return err == nil
}

func (m Model) Init() tea.Cmd {
	return nil
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
	case shellStartedMsg:
		m.menuItems = m.buildMenuItems()
		if m.selectedItem >= len(m.menuItems) {
			m.selectedItem = len(m.menuItems) - 1
		}
		return m, nil
	case updateProgressMsg:
		m.updateProgress = msg
		if msg.logOutput != "" {
			m.updateLogs = append(m.updateLogs, msg.logOutput)
		}
		return m, m.waitForProgress()
	case updateCompleteMsg:
		m.updateProgress.complete = true
		m.updateProgress.err = msg.err
		m.dependencies = m.detector.GetInstalledComponents()
		m.updateDeps = m.dependencies
		m.menuItems = m.buildMenuItems()

		// Restart shell if update was successful and shell is running
		if msg.err == nil && m.isShellRunning() {
			restartShell()
		}
		return m, nil
	case greeterProgressMsg:
		m.greeterProgress = msg
		if msg.logOutput != "" {
			m.greeterLogs = append(m.greeterLogs, msg.logOutput)
		}
		return m, m.waitForGreeterProgress()
	case pluginsLoadedMsg:
		m.pluginsLoading = false
		if msg.err != nil {
			m.pluginsError = msg.err.Error()
		} else {
			m.pluginsList = make([]pluginInfo, len(msg.plugins))
			for i, p := range msg.plugins {
				m.pluginsList[i] = pluginInfo{
					ID:           p.ID,
					Name:         p.Name,
					Category:     p.Category,
					Author:       p.Author,
					Description:  p.Description,
					Repo:         p.Repo,
					Path:         p.Path,
					Capabilities: p.Capabilities,
					Compositors:  p.Compositors,
					Dependencies: p.Dependencies,
					FirstParty:   strings.HasPrefix(p.Repo, "https://github.com/AvengeMedia"),
				}
			}
			m.filteredPluginsList = m.pluginsList
			m.selectedPluginIndex = 0
			m.updatePluginInstallStatus()
		}
		return m, nil
	case installedPluginsLoadedMsg:
		m.installedPluginsLoading = false
		if msg.err != nil {
			m.installedPluginsError = msg.err.Error()
		} else {
			m.installedPluginsList = make([]pluginInfo, len(msg.plugins))
			for i, p := range msg.plugins {
				m.installedPluginsList[i] = pluginInfo{
					ID:           p.ID,
					Name:         p.Name,
					Category:     p.Category,
					Author:       p.Author,
					Description:  p.Description,
					Repo:         p.Repo,
					Path:         p.Path,
					Capabilities: p.Capabilities,
					Compositors:  p.Compositors,
					Dependencies: p.Dependencies,
					FirstParty:   strings.HasPrefix(p.Repo, "https://github.com/AvengeMedia"),
				}
			}
			m.selectedInstalledIndex = 0
		}
		return m, nil
	case pluginUninstalledMsg:
		if msg.err != nil {
			m.installedPluginsError = msg.err.Error()
			m.state = StatePluginInstalledDetail
		} else {
			m.state = StatePluginsInstalled
			m.installedPluginsLoading = true
			m.installedPluginsError = ""
			return m, loadInstalledPlugins
		}
		return m, nil
	case pluginInstalledMsg:
		if msg.err != nil {
			m.pluginsError = msg.err.Error()
		} else {
			m.pluginInstallStatus[msg.pluginName] = true
			m.pluginsError = ""
		}
		return m, nil
	case greeterPasswordValidMsg:
		if msg.valid {
			m.greeterSudoPassword = msg.password
			m.greeterPasswordInput = ""
			m.greeterPasswordError = ""
			m.state = StateGreeterInstalling
			m.greeterProgress = greeterProgressMsg{step: "Starting greeter installation..."}
			m.greeterLogs = []string{}
			return m, tea.Batch(m.performGreeterInstall(), m.waitForGreeterProgress())
		} else {
			m.greeterPasswordError = "Incorrect password. Please try again."
			m.greeterPasswordInput = ""
		}
		return m, nil
	case passwordValidMsg:
		if msg.valid {
			m.sudoPassword = msg.password
			m.passwordInput = ""
			m.passwordError = ""
			m.state = StateUpdateProgress
			m.updateProgress = updateProgressMsg{progress: 0.0, step: "Starting update..."}
			m.updateLogs = []string{}
			return m, tea.Batch(m.performUpdate(), m.waitForProgress())
		} else {
			m.passwordError = "Incorrect password. Please try again."
			m.passwordInput = ""
		}
		return m, nil
	case tea.KeyMsg:
		switch m.state {
		case StateMainMenu:
			return m.updateMainMenu(msg)
		case StateUpdate:
			return m.updateUpdateView(msg)
		case StateUpdatePassword:
			return m.updatePasswordView(msg)
		case StateUpdateProgress:
			return m.updateProgressView(msg)
		case StateShell:
			return m.updateShellView(msg)
		case StatePluginsMenu:
			return m.updatePluginsMenu(msg)
		case StatePluginsBrowse:
			return m.updatePluginsBrowse(msg)
		case StatePluginDetail:
			return m.updatePluginDetail(msg)
		case StatePluginSearch:
			return m.updatePluginSearch(msg)
		case StatePluginsInstalled:
			return m.updatePluginsInstalled(msg)
		case StatePluginInstalledDetail:
			return m.updatePluginInstalledDetail(msg)
		case StateGreeterMenu:
			return m.updateGreeterMenu(msg)
		case StateGreeterCompositorSelect:
			return m.updateGreeterCompositorSelect(msg)
		case StateGreeterPassword:
			return m.updateGreeterPasswordView(msg)
		case StateGreeterInstalling:
			return m.updateGreeterInstalling(msg)
		case StateAbout:
			return m.updateAboutView(msg)
		}
	}

	return m, nil
}

type updateProgressMsg struct {
	progress  float64
	step      string
	complete  bool
	err       error
	logOutput string
}

type updateCompleteMsg struct {
	err error
}

type passwordValidMsg struct {
	password string
	valid    bool
}

type greeterProgressMsg struct {
	step      string
	complete  bool
	err       error
	logOutput string
}

type greeterPasswordValidMsg struct {
	password string
	valid    bool
}

func (m Model) waitForProgress() tea.Cmd {
	return func() tea.Msg {
		return <-m.updateProgressChan
	}
}

func (m Model) waitForGreeterProgress() tea.Cmd {
	return func() tea.Msg {
		return <-m.greeterInstallChan
	}
}

func (m Model) View() string {
	switch m.state {
	case StateMainMenu:
		return m.renderMainMenu()
	case StateUpdate:
		return m.renderUpdateView()
	case StateUpdatePassword:
		return m.renderPasswordView()
	case StateUpdateProgress:
		return m.renderProgressView()
	case StateShell:
		return m.renderShellView()
	case StatePluginsMenu:
		return m.renderPluginsMenu()
	case StatePluginsBrowse:
		return m.renderPluginsBrowse()
	case StatePluginDetail:
		return m.renderPluginDetail()
	case StatePluginSearch:
		return m.renderPluginSearch()
	case StatePluginsInstalled:
		return m.renderPluginsInstalled()
	case StatePluginInstalledDetail:
		return m.renderPluginInstalledDetail()
	case StateGreeterMenu:
		return m.renderGreeterMenu()
	case StateGreeterCompositorSelect:
		return m.renderGreeterCompositorSelect()
	case StateGreeterPassword:
		return m.renderGreeterPasswordView()
	case StateGreeterInstalling:
		return m.renderGreeterInstalling()
	case StateAbout:
		return m.renderAboutView()
	default:
		return m.renderMainMenu()
	}
}
