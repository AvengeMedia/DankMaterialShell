package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"slices"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/config"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/distros"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/brightness"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/network"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/tui"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/version"
	"github.com/charmbracelet/lipgloss"
	"github.com/spf13/cobra"
)

type status string

const (
	statusOK    status = "ok"
	statusWarn  status = "warn"
	statusError status = "error"
	statusInfo  status = "info"
)

func (s status) IconStyle(styles tui.Styles) (string, lipgloss.Style) {
	switch s {
	case statusOK:
		return "●", styles.Success
	case statusWarn:
		return "●", styles.Warning
	case statusError:
		return "●", styles.Error
	default:
		return "○", styles.Subtle
	}
}

type DoctorStatus struct {
	Errors   []checkResult
	Warnings []checkResult
	OK       []checkResult
	Info     []checkResult
}

func (ds *DoctorStatus) Add(r checkResult) {
	switch r.status {
	case statusError:
		ds.Errors = append(ds.Errors, r)
	case statusWarn:
		ds.Warnings = append(ds.Warnings, r)
	case statusOK:
		ds.OK = append(ds.OK, r)
	case statusInfo:
		ds.Info = append(ds.Info, r)
	}
}

func (ds *DoctorStatus) HasIssues() bool {
	return len(ds.Errors) > 0 || len(ds.Warnings) > 0
}

func (ds *DoctorStatus) ErrorCount() int {
	return len(ds.Errors)
}

func (ds *DoctorStatus) WarningCount() int {
	return len(ds.Warnings)
}

func (ds *DoctorStatus) OKCount() int {
	return len(ds.OK)
}

var (
	quickshellVersionRegex = regexp.MustCompile(`quickshell (\d+\.\d+\.\d+)`)
	hyprlandVersionRegex   = regexp.MustCompile(`v?(\d+\.\d+\.\d+)`)
	niriVersionRegex       = regexp.MustCompile(`niri (\d+\.\d+)`)
	swayVersionRegex       = regexp.MustCompile(`sway version (\d+\.\d+)`)
	riverVersionRegex      = regexp.MustCompile(`river (\d+\.\d+)`)
	wayfireVersionRegex    = regexp.MustCompile(`wayfire (\d+\.\d+)`)
)

var doctorCmd = &cobra.Command{
	Use:   "doctor",
	Short: "Diagnose DMS installation and dependencies",
	Long:  "Check system health, verify dependencies, and diagnose configuration issues for DMS",
	Run:   runDoctor,
}

var (
	doctorVerbose bool
	doctorJSON    bool
)

func init() {
	doctorCmd.Flags().BoolVarP(&doctorVerbose, "verbose", "v", false, "Show detailed output including paths and versions")
	doctorCmd.Flags().BoolVarP(&doctorJSON, "json", "j", false, "Output results in JSON format")
}

type category int

const (
	catSystem category = iota
	catVersions
	catInstallation
	catCompositor
	catQuickshellFeatures
	catOptionalFeatures
	catConfigFiles
	catServices
	catEnvironment
)

func (c category) String() string {
	switch c {
	case catSystem:
		return "System"
	case catVersions:
		return "Versions"
	case catInstallation:
		return "Installation"
	case catCompositor:
		return "Compositor"
	case catQuickshellFeatures:
		return "Quickshell Features"
	case catOptionalFeatures:
		return "Optional Features"
	case catConfigFiles:
		return "Config Files"
	case catServices:
		return "Services"
	case catEnvironment:
		return "Environment"
	default:
		return "Unknown"
	}
}

const (
	checkNameMaxLength = 21
)

type checkResult struct {
	category category
	name     string
	status   status
	message  string
	details  string
}

type checkResultJSON struct {
	Category string `json:"category"`
	Name     string `json:"name"`
	Status   string `json:"status"`
	Message  string `json:"message"`
	Details  string `json:"details,omitempty"`
}

type doctorOutputJSON struct {
	Summary struct {
		Errors   int `json:"errors"`
		Warnings int `json:"warnings"`
		OK       int `json:"ok"`
		Info     int `json:"info"`
	} `json:"summary"`
	Results []checkResultJSON `json:"results"`
}

func (r checkResult) toJSON() checkResultJSON {
	return checkResultJSON{
		Category: r.category.String(),
		Name:     r.name,
		Status:   string(r.status),
		Message:  r.message,
		Details:  r.details,
	}
}

func runDoctor(cmd *cobra.Command, args []string) {
	if !doctorJSON {
		printDoctorHeader()
	}

	qsFeatures, qsMissingFeatures := checkQuickshellFeatures()

	results := slices.Concat(
		checkSystemInfo(),
		checkVersions(qsMissingFeatures),
		checkDMSInstallation(),
		checkWindowManagers(),
		qsFeatures,
		checkOptionalDependencies(),
		checkConfigurationFiles(),
		checkSystemdServices(),
		checkEnvironmentVars(),
	)

	if doctorJSON {
		printResultsJSON(results)
	} else {
		printResults(results)
		printSummary(results, qsMissingFeatures)
	}
}

func printDoctorHeader() {
	theme := tui.TerminalTheme()
	styles := tui.NewStyles(theme)

	fmt.Println(getThemedASCII())
	fmt.Println(styles.Title.Render("System Health Check"))
	fmt.Println(styles.Subtle.Render("──────────────────────────────────────"))
	fmt.Println()
}

func checkSystemInfo() []checkResult {
	var results []checkResult

	osInfo, err := distros.GetOSInfo()
	if err != nil {
		status, message, details := statusWarn, fmt.Sprintf("Unknown (%v)", err), ""

		if strings.Contains(err.Error(), "Unsupported distribution") {
			osRelease := readOSRelease()
			if osRelease["ID"] == "nixos" {
				status = statusOK
				message = osRelease["PRETTY_NAME"]
				if message == "" {
					message = fmt.Sprintf("NixOS %s", osRelease["VERSION_ID"])
				}
				details = "Supported for runtime (install via NixOS module or Flake)"
			} else if osRelease["PRETTY_NAME"] != "" {
				message = fmt.Sprintf("%s (not supported by dms setup)", osRelease["PRETTY_NAME"])
				details = "DMS may work but automatic installation is not available"
			}
		}

		results = append(results, checkResult{catSystem, "Operating System", status, message, details})
	} else {
		status := statusOK
		message := osInfo.PrettyName
		if message == "" {
			message = fmt.Sprintf("%s %s", osInfo.Distribution.ID, osInfo.VersionID)
		}
		if distros.IsUnsupportedDistro(osInfo.Distribution.ID, osInfo.VersionID) {
			status = statusWarn
			message += " (version may not be fully supported)"
		}
		results = append(results, checkResult{
			catSystem, "Operating System", status, message,
			fmt.Sprintf("ID: %s, Version: %s, Arch: %s", osInfo.Distribution.ID, osInfo.VersionID, osInfo.Architecture),
		})
	}

	arch := runtime.GOARCH
	archStatus := statusOK
	if arch != "amd64" && arch != "arm64" {
		archStatus = statusError
	}
	results = append(results, checkResult{catSystem, "Architecture", archStatus, arch, ""})

	waylandDisplay := os.Getenv("WAYLAND_DISPLAY")
	xdgSessionType := os.Getenv("XDG_SESSION_TYPE")

	switch {
	case waylandDisplay != "" || xdgSessionType == "wayland":
		results = append(results, checkResult{
			catSystem, "Display Server", statusOK, "Wayland",
			fmt.Sprintf("WAYLAND_DISPLAY=%s", waylandDisplay),
		})
	case xdgSessionType == "x11":
		results = append(results, checkResult{catSystem, "Display Server", statusError, "X11 (DMS requires Wayland)", ""})
	default:
		results = append(results, checkResult{
			catSystem, "Display Server", statusWarn, "Unknown (ensure you're running Wayland)",
			fmt.Sprintf("XDG_SESSION_TYPE=%s", xdgSessionType),
		})
	}

	return results
}

func checkEnvironmentVars() []checkResult {
	var results []checkResult
	results = append(results, checkEnvVar("QT_QPA_PLATFORMTHEME")...)
	results = append(results, checkEnvVar("QS_ICON_THEME")...)
	return results
}

func checkEnvVar(name string) []checkResult {
	value := os.Getenv(name)
	if value != "" {
		return []checkResult{{catEnvironment, name, statusInfo, value, ""}}
	} else if doctorVerbose {
		return []checkResult{{catEnvironment, name, statusInfo, "Not set", ""}}
	}
	return nil
}

func readOSRelease() map[string]string {
	result := make(map[string]string)
	data, err := os.ReadFile("/etc/os-release")
	if err != nil {
		return result
	}
	for line := range strings.SplitSeq(string(data), "\n") {
		if parts := strings.SplitN(line, "=", 2); len(parts) == 2 {
			result[parts[0]] = strings.Trim(parts[1], "\"")
		}
	}
	return result
}

func checkVersions(qsMissingFeatures bool) []checkResult {
	dmsCliPath, _ := os.Executable()
	dmsCliDetails := ""
	if doctorVerbose {
		dmsCliDetails = dmsCliPath
	}

	results := []checkResult{
		{catVersions, "DMS CLI", statusOK, formatVersion(Version), dmsCliDetails},
	}

	qsVersion, qsStatus, qsPath := getQuickshellVersionInfo(qsMissingFeatures)
	qsDetails := ""
	if doctorVerbose && qsPath != "" {
		qsDetails = qsPath
	}
	results = append(results, checkResult{catVersions, "Quickshell", qsStatus, qsVersion, qsDetails})

	dmsVersion, dmsPath := getDMSShellVersion()
	if dmsVersion != "" {
		results = append(results, checkResult{catVersions, "DMS Shell", statusOK, dmsVersion, dmsPath})
	} else {
		results = append(results, checkResult{catVersions, "DMS Shell", statusError, "Not installed or not detected", "Run 'dms setup' to install"})
	}

	return results
}

func getDMSShellVersion() (version, path string) {
	if err := findConfig(nil, nil); err == nil && configPath != "" {
		versionFile := filepath.Join(configPath, "VERSION")
		if data, err := os.ReadFile(versionFile); err == nil {
			return strings.TrimSpace(string(data)), configPath
		}
		return "installed", configPath
	}

	if dmsPath, err := config.LocateDMSConfig(); err == nil {
		versionFile := filepath.Join(dmsPath, "VERSION")
		if data, err := os.ReadFile(versionFile); err == nil {
			return strings.TrimSpace(string(data)), dmsPath
		}
		return "installed", dmsPath
	}

	return "", ""
}

func getQuickshellVersionInfo(missingFeatures bool) (string, status, string) {
	if !utils.CommandExists("qs") {
		return "Not installed", statusError, ""
	}

	qsPath, _ := exec.LookPath("qs")

	output, err := exec.Command("qs", "--version").Output()
	if err != nil {
		return "Installed (version check failed)", statusWarn, qsPath
	}

	fullVersion := strings.TrimSpace(string(output))
	if matches := quickshellVersionRegex.FindStringSubmatch(fullVersion); len(matches) >= 2 {
		if version.CompareVersions(matches[1], "0.2.0") < 0 {
			return fmt.Sprintf("%s (needs >= 0.2.0)", fullVersion), statusError, qsPath
		}
		if missingFeatures {
			return fullVersion, statusWarn, qsPath
		}
		return fullVersion, statusOK, qsPath
	}

	return fullVersion, statusWarn, qsPath
}

func checkDMSInstallation() []checkResult {
	var results []checkResult

	dmsPath := ""
	if err := findConfig(nil, nil); err == nil && configPath != "" {
		dmsPath = configPath
	} else if path, err := config.LocateDMSConfig(); err == nil {
		dmsPath = path
	}

	if dmsPath == "" {
		return []checkResult{{catInstallation, "DMS Configuration", statusError, "Not found", "shell.qml not found in any config path"}}
	}

	results = append(results, checkResult{catInstallation, "DMS Configuration", statusOK, "Found", dmsPath})

	shellQml := filepath.Join(dmsPath, "shell.qml")
	if _, err := os.Stat(shellQml); err != nil {
		results = append(results, checkResult{catInstallation, "shell.qml", statusError, "Missing", shellQml})
	} else {
		results = append(results, checkResult{catInstallation, "shell.qml", statusOK, "Present", shellQml})
	}

	if doctorVerbose {
		installType := "Unknown"
		switch {
		case strings.Contains(dmsPath, "/nix/store"):
			installType = "Nix store"
		case strings.Contains(dmsPath, ".local/share") || strings.Contains(dmsPath, "/usr/share"):
			installType = "System package"
		case strings.Contains(dmsPath, ".config"):
			installType = "User config"
		}
		results = append(results, checkResult{catInstallation, "Install Type", statusInfo, installType, dmsPath})
	}

	return results
}

func checkWindowManagers() []checkResult {
	compositors := []struct {
		name, versionCmd, versionArg string
		versionRegex                 *regexp.Regexp
		commands                     []string
	}{
		{"Hyprland", "hyprctl", "version", hyprlandVersionRegex, []string{"hyprland", "Hyprland"}},
		{"niri", "niri", "--version", niriVersionRegex, []string{"niri"}},
		{"Sway", "sway", "--version", swayVersionRegex, []string{"sway"}},
		{"River", "river", "-version", riverVersionRegex, []string{"river"}},
		{"Wayfire", "wayfire", "--version", wayfireVersionRegex, []string{"wayfire"}},
	}

	var results []checkResult
	foundAny := false

	for _, c := range compositors {
		if slices.ContainsFunc(c.commands, utils.CommandExists) {
			foundAny = true
			var compositorPath string
			for _, cmd := range c.commands {
				if path, err := exec.LookPath(cmd); err == nil {
					compositorPath = path
					break
				}
			}
			details := ""
			if doctorVerbose && compositorPath != "" {
				details = compositorPath
			}
			results = append(results, checkResult{
				catCompositor, c.name, statusOK,
				getVersionFromCommand(c.versionCmd, c.versionArg, c.versionRegex), details,
			})
		}
	}

	if !foundAny {
		results = append(results, checkResult{
			catCompositor, "Compositor", statusError,
			"No supported Wayland compositor found",
			"Install Hyprland, niri, Sway, River, or Wayfire",
		})
	}

	if wm := detectRunningWM(); wm != "" {
		results = append(results, checkResult{catCompositor, "Active", statusInfo, wm, ""})
	}

	return results
}

func getVersionFromCommand(cmd, arg string, regex *regexp.Regexp) string {
	output, err := exec.Command(cmd, arg).Output()
	if err != nil {
		return "installed"
	}

	outStr := string(output)
	if matches := regex.FindStringSubmatch(outStr); len(matches) > 1 {
		ver := matches[1]
		if strings.Contains(outStr, "git") || strings.Contains(outStr, "dirty") {
			return ver + " (git)"
		}
		return ver
	}
	return strings.TrimSpace(outStr)
}

func detectRunningWM() string {
	switch {
	case os.Getenv("HYPRLAND_INSTANCE_SIGNATURE") != "":
		return "Hyprland"
	case os.Getenv("NIRI_SOCKET") != "":
		return "niri"
	case os.Getenv("XDG_CURRENT_DESKTOP") != "":
		return os.Getenv("XDG_CURRENT_DESKTOP")
	}
	return ""
}

func checkQuickshellFeatures() ([]checkResult, bool) {
	if !utils.CommandExists("qs") {
		return nil, false
	}

	tmpDir := os.TempDir()
	testScript := filepath.Join(tmpDir, "qs-feature-test.qml")
	defer os.Remove(testScript)

	qmlContent := `
import QtQuick
import Quickshell

ShellRoot {
	id: root

	property bool polkitAvailable: false
	property bool idleMonitorAvailable: false
	property bool idleInhibitorAvailable: false
	property bool shortcutInhibitorAvailable: false

	Timer {
		interval: 50
		running: true
		repeat: false
		onTriggered: {
			try {
				var polkitTest = Qt.createQmlObject(
					'import Quickshell.Services.Polkit; import QtQuick; Item {}',
					root
				)
				root.polkitAvailable = true
				polkitTest.destroy()
			} catch (e) {}

			try {
				var testItem = Qt.createQmlObject(
					'import Quickshell.Wayland; import QtQuick; QtObject { ' +
					'readonly property bool hasIdleMonitor: typeof IdleMonitor !== "undefined"; ' +
					'readonly property bool hasIdleInhibitor: typeof IdleInhibitor !== "undefined"; ' +
					'readonly property bool hasShortcutInhibitor: typeof ShortcutInhibitor !== "undefined" ' +
					'}',
					root
				)
				root.idleMonitorAvailable = testItem.hasIdleMonitor
				root.idleInhibitorAvailable = testItem.hasIdleInhibitor
				root.shortcutInhibitorAvailable = testItem.hasShortcutInhibitor
				testItem.destroy()
			} catch (e) {}

			console.warn(root.polkitAvailable ? "FEATURE:Polkit:OK" : "FEATURE:Polkit:UNAVAILABLE")
			console.warn(root.idleMonitorAvailable ? "FEATURE:IdleMonitor:OK" : "FEATURE:IdleMonitor:UNAVAILABLE")
			console.warn(root.idleInhibitorAvailable ? "FEATURE:IdleInhibitor:OK" : "FEATURE:IdleInhibitor:UNAVAILABLE")
			console.warn(root.shortcutInhibitorAvailable ? "FEATURE:ShortcutInhibitor:OK" : "FEATURE:ShortcutInhibitor:UNAVAILABLE")

			Quickshell.execDetached(["kill", "-TERM", String(Quickshell.processId)])
		}
	}
}
`

	if err := os.WriteFile(testScript, []byte(qmlContent), 0644); err != nil {
		return nil, false
	}

	cmd := exec.Command("qs", "-p", testScript)
	cmd.Env = append(os.Environ(), "NO_COLOR=1")
	output, _ := cmd.CombinedOutput()
	outputStr := string(output)

	features := []struct{ name, desc string }{
		{"Polkit", "Authentication prompts"},
		{"IdleMonitor", "Idle detection"},
		{"IdleInhibitor", "Prevent idle/sleep"},
		{"ShortcutInhibitor", "Allow shortcut management (niri)"},
	}

	var results []checkResult
	missingFeatures := false

	for _, f := range features {
		available := strings.Contains(outputStr, fmt.Sprintf("FEATURE:%s:OK", f.name))
		status, message := statusOK, "Available"
		if !available {
			status, message = statusInfo, "Not available"
			missingFeatures = true
		}
		results = append(results, checkResult{catQuickshellFeatures, f.name, status, message, f.desc})
	}

	return results, missingFeatures
}

func checkI2CAvailability() checkResult {
	ddc, err := brightness.NewDDCBackend()
	if err != nil {
		return checkResult{catOptionalFeatures, "I2C/DDC", statusInfo, "Not available", "External monitor brightness control"}
	}
	defer ddc.Close()

	devices, err := ddc.GetDevices()
	if err != nil || len(devices) == 0 {
		return checkResult{catOptionalFeatures, "I2C/DDC", statusInfo, "No monitors detected", "External monitor brightness control"}
	}

	return checkResult{catOptionalFeatures, "I2C/DDC", statusOK, fmt.Sprintf("%d monitor(s) detected", len(devices)), "External monitor brightness control"}
}

func detectNetworkBackend() string {
	result, err := network.DetectNetworkStack()
	if err != nil {
		return ""
	}

	switch result.Backend {
	case network.BackendNetworkManager:
		return "NetworkManager"
	case network.BackendIwd:
		return "iwd"
	case network.BackendNetworkd:
		if result.HasIwd {
			return "iwd + systemd-networkd"
		}
		return "systemd-networkd"
	case network.BackendConnMan:
		return "ConnMan"
	default:
		return ""
	}
}

func checkOptionalDependencies() []checkResult {
	var results []checkResult

	if utils.IsServiceActive("accounts-daemon", false) {
		results = append(results, checkResult{catOptionalFeatures, "accountsservice", statusOK, "Running", "User accounts"})
	} else {
		results = append(results, checkResult{catOptionalFeatures, "accountsservice", statusWarn, "Not running", "User accounts"})
	}

	if utils.IsServiceActive("power-profiles-daemon", false) {
		results = append(results, checkResult{catOptionalFeatures, "power-profiles-daemon", statusOK, "Running", "Power profile management"})
	} else {
		results = append(results, checkResult{catOptionalFeatures, "power-profiles-daemon", statusInfo, "Not running", "Power profile management"})
	}

	i2cStatus := checkI2CAvailability()
	results = append(results, i2cStatus)

	terminals := []string{"ghostty", "kitty", "alacritty", "foot", "wezterm"}
	if idx := slices.IndexFunc(terminals, utils.CommandExists); idx >= 0 {
		results = append(results, checkResult{catOptionalFeatures, "Terminal", statusOK, terminals[idx], ""})
	} else {
		results = append(results, checkResult{catOptionalFeatures, "Terminal", statusWarn, "None found", "Install ghostty, kitty, or alacritty"})
	}

	deps := []struct {
		name, cmd, altCmd, desc string
		important               bool
	}{
		{"matugen", "matugen", "", "Dynamic theming", true},
		{"dgop", "dgop", "", "System monitoring", true},
		{"cava", "cava", "", "Audio waveform", false},
		{"khal", "khal", "", "Calendar events", false},
		{"Network", "nmcli", "iwctl", "Network management", false},
		{"danksearch", "dsearch", "", "File search", false},
		{"loginctl", "loginctl", "", "Session management", false},
		{"fprintd", "fprintd-list", "", "Fingerprint auth", false},
	}

	for _, d := range deps {
		found, foundCmd := utils.CommandExists(d.cmd), d.cmd
		if !found && d.altCmd != "" {
			if utils.CommandExists(d.altCmd) {
				found, foundCmd = true, d.altCmd
			}
		}

		if found {
			message := "Installed"
			details := d.desc
			if d.name == "Network" {
				result, err := network.DetectNetworkStack()
				if err == nil && result.Backend != network.BackendNone {
					message = detectNetworkBackend() + " (active)"
					if doctorVerbose {
						details = result.ChosenReason
					}
				} else {
					switch foundCmd {
					case "nmcli":
						message = "NetworkManager (installed)"
					case "iwctl":
						message = "iwd (installed)"
					}
				}
			}
			results = append(results, checkResult{catOptionalFeatures, d.name, statusOK, message, details})
		} else if d.important {
			results = append(results, checkResult{catOptionalFeatures, d.name, statusWarn, "Missing", d.desc})
		} else {
			results = append(results, checkResult{catOptionalFeatures, d.name, statusInfo, "Not installed", d.desc})
		}
	}

	return results
}

func checkConfigurationFiles() []checkResult {
	configDir, _ := os.UserConfigDir()
	cacheDir, _ := os.UserCacheDir()
	dmsDir := "DankMaterialShell"

	configFiles := []struct{ name, path string }{
		{"settings.json", filepath.Join(configDir, dmsDir, "settings.json")},
		{"clsettings.json", filepath.Join(configDir, dmsDir, "clsettings.json")},
		{"plugin_settings.json", filepath.Join(configDir, dmsDir, "plugin_settings.json")},
		{"session.json", filepath.Join(utils.XDGStateHome(), dmsDir, "session.json")},
		{"dms-colors.json", filepath.Join(cacheDir, dmsDir, "dms-colors.json")},
	}

	var results []checkResult
	for _, cf := range configFiles {
		info, err := os.Stat(cf.path)
		if err == nil {
			status := statusOK
			message := "Present"

			if info.Mode().Perm()&0200 == 0 {
				status = statusWarn
				message += " (read-only)"
			}

			results = append(results, checkResult{catConfigFiles, cf.name, status, message, cf.path})
		} else {
			results = append(results, checkResult{catConfigFiles, cf.name, statusInfo, "Not yet created", cf.path})
		}
	}
	return results
}

func checkSystemdServices() []checkResult {
	if !utils.CommandExists("systemctl") {
		return nil
	}

	var results []checkResult

	dmsState := getServiceState("dms", true)
	if !dmsState.exists {
		results = append(results, checkResult{catServices, "dms.service", statusInfo, "Not installed", "Optional user service"})
	} else {
		status, message := statusOK, dmsState.enabled
		if dmsState.active != "" {
			message = fmt.Sprintf("%s, %s", dmsState.enabled, dmsState.active)
		}
		if dmsState.enabled == "disabled" {
			status, message = statusWarn, "Disabled"
		} else if dmsState.active == "failed" || dmsState.active == "inactive" {
			status = statusError
		}
		results = append(results, checkResult{catServices, "dms.service", status, message, ""})
	}

	greetdState := getServiceState("greetd", false)
	if greetdState.exists {
		status := statusOK
		if greetdState.enabled == "disabled" {
			status = statusInfo
		}
		results = append(results, checkResult{catServices, "greetd", status, greetdState.enabled, ""})
	} else if doctorVerbose {
		results = append(results, checkResult{catServices, "greetd", statusInfo, "Not installed", "Optional greeter service"})
	}

	return results
}

type serviceState struct {
	exists  bool
	enabled string
	active  string
}

func getServiceState(name string, userService bool) serviceState {
	args := []string{"is-enabled", name}
	if userService {
		args = []string{"--user", "is-enabled", name}
	}

	output, _ := exec.Command("systemctl", args...).Output()
	enabled := strings.TrimSpace(string(output))

	if enabled == "" || enabled == "not-found" {
		return serviceState{}
	}

	state := serviceState{exists: true, enabled: enabled}

	if userService {
		output, _ = exec.Command("systemctl", "--user", "is-active", name).Output()
		if active := strings.TrimSpace(string(output)); active != "" && active != "unknown" {
			state.active = active
		}
	}

	return state
}

func printResults(results []checkResult) {
	theme := tui.TerminalTheme()
	styles := tui.NewStyles(theme)

	currentCategory := category(-1)
	for _, r := range results {
		if r.category != currentCategory {
			if currentCategory != -1 {
				fmt.Println()
			}
			fmt.Printf("  %s\n", styles.Bold.Render(r.category.String()))
			currentCategory = r.category
		}
		printResultLine(r, styles)
	}
}

func printResultsJSON(results []checkResult) {
	var ds DoctorStatus
	for _, r := range results {
		ds.Add(r)
	}

	output := doctorOutputJSON{}
	output.Summary.Errors = ds.ErrorCount()
	output.Summary.Warnings = ds.WarningCount()
	output.Summary.OK = ds.OKCount()
	output.Summary.Info = len(ds.Info)

	output.Results = make([]checkResultJSON, 0, len(results))
	for _, r := range results {
		output.Results = append(output.Results, r.toJSON())
	}

	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(output); err != nil {
		fmt.Fprintf(os.Stderr, "Error encoding JSON: %v\n", err)
		os.Exit(1)
	}
}

func printResultLine(r checkResult, styles tui.Styles) {
	icon, style := r.status.IconStyle(styles)

	name := r.name
	nameLen := len(name)

	if nameLen > checkNameMaxLength {
		name = name[:checkNameMaxLength-1] + "…"
		nameLen = checkNameMaxLength
	}
	dots := strings.Repeat("·", checkNameMaxLength-nameLen)

	fmt.Printf("    %s %s %s %s\n", style.Render(icon), name, styles.Subtle.Render(dots), r.message)

	if doctorVerbose && r.details != "" {
		fmt.Printf("      %s\n", styles.Subtle.Render("└─ "+r.details))
	}
}

func printSummary(results []checkResult, qsMissingFeatures bool) {
	theme := tui.TerminalTheme()
	styles := tui.NewStyles(theme)

	var ds DoctorStatus
	for _, r := range results {
		ds.Add(r)
	}

	fmt.Println()
	fmt.Printf("  %s\n", styles.Subtle.Render("──────────────────────────────────────"))

	if !ds.HasIssues() {
		fmt.Printf("  %s\n", styles.Success.Render("✓ All checks passed!"))
	} else {
		var parts []string

		if ds.ErrorCount() > 0 {
			parts = append(parts, styles.Error.Render(fmt.Sprintf("%d error(s)", ds.ErrorCount())))
		}
		if ds.WarningCount() > 0 {
			parts = append(parts, styles.Warning.Render(fmt.Sprintf("%d warning(s)", ds.WarningCount())))
		}
		parts = append(parts, styles.Success.Render(fmt.Sprintf("%d ok", ds.OKCount())))
		fmt.Printf("  %s\n", strings.Join(parts, ", "))

		if qsMissingFeatures {
			fmt.Println()
			fmt.Printf("  %s\n", styles.Subtle.Render("→ Consider using quickshell-git for full feature support"))
		}
	}
	fmt.Println()
}
