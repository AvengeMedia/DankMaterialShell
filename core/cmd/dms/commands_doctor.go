package main

import (
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
	"github.com/AvengeMedia/DankMaterialShell/core/internal/tui"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/version"
	"github.com/spf13/cobra"
)

var doctorCmd = &cobra.Command{
	Use:   "doctor",
	Short: "Diagnose DMS installation and dependencies",
	Long:  "Check system health, verify dependencies, and diagnose configuration issues for DMS",
	Run:   runDoctor,
}

var doctorVerbose bool

func init() {
	doctorCmd.Flags().BoolVarP(&doctorVerbose, "verbose", "v", false, "Show detailed output including paths and versions")
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
)

var categoryNames = []string{
	"System", "Versions", "Installation", "Compositor",
	"Quickshell Features", "Optional Features", "Config Files", "Services",
}

type checkResult struct {
	category category
	name     string
	status   string
	message  string
	details  string
}

func runDoctor(cmd *cobra.Command, args []string) {
	printDoctorHeader()

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
	)

	printResults(results)
	printSummary(results, qsMissingFeatures)
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
	results := []checkResult{}

	osInfo, err := distros.GetOSInfo()
	if err != nil {
		status, message, details := "warn", fmt.Sprintf("Unknown (%v)", err), ""

		if strings.Contains(err.Error(), "Unsupported distribution") {
			osRelease := readOSRelease()
			if osRelease["ID"] == "nixos" {
				status = "ok"
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
		status := "ok"
		message := osInfo.PrettyName
		if message == "" {
			message = fmt.Sprintf("%s %s", osInfo.Distribution.ID, osInfo.VersionID)
		}
		if distros.IsUnsupportedDistro(osInfo.Distribution.ID, osInfo.VersionID) {
			status = "warn"
			message += " (version may not be fully supported)"
		}
		results = append(results, checkResult{
			catSystem, "Operating System", status, message,
			fmt.Sprintf("ID: %s, Version: %s, Arch: %s", osInfo.Distribution.ID, osInfo.VersionID, osInfo.Architecture),
		})
	}

	arch := runtime.GOARCH
	archStatus := "ok"
	if arch != "amd64" && arch != "arm64" {
		archStatus = "error"
	}
	results = append(results, checkResult{catSystem, "Architecture", archStatus, arch, ""})

	waylandDisplay := os.Getenv("WAYLAND_DISPLAY")
	xdgSessionType := os.Getenv("XDG_SESSION_TYPE")

	switch {
	case waylandDisplay != "" || xdgSessionType == "wayland":
		results = append(results, checkResult{
			catSystem, "Display Server", "ok", "Wayland",
			fmt.Sprintf("WAYLAND_DISPLAY=%s", waylandDisplay),
		})
	case xdgSessionType == "x11":
		results = append(results, checkResult{catSystem, "Display Server", "error", "X11 (DMS requires Wayland)", ""})
	default:
		results = append(results, checkResult{
			catSystem, "Display Server", "warn", "Unknown (ensure you're running Wayland)",
			fmt.Sprintf("XDG_SESSION_TYPE=%s", xdgSessionType),
		})
	}

	return results
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
		{catVersions, "DMS CLI", "ok", formatVersion(Version), dmsCliDetails},
	}

	qsVersion, qsStatus, qsPath := getQuickshellVersionInfo(qsMissingFeatures)
	qsDetails := ""
	if doctorVerbose && qsPath != "" {
		qsDetails = qsPath
	}
	results = append(results, checkResult{catVersions, "Quickshell", qsStatus, qsVersion, qsDetails})

	dmsVersion, dmsPath := getDMSShellVersion()
	if dmsVersion != "" {
		results = append(results, checkResult{catVersions, "DMS Shell", "ok", dmsVersion, dmsPath})
	} else {
		results = append(results, checkResult{catVersions, "DMS Shell", "error", "Not installed or not detected", "Run 'dms setup' to install"})
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

func getQuickshellVersionInfo(missingFeatures bool) (string, string, string) {
	if !utils.CommandExists("qs") {
		return "Not installed", "error", ""
	}

	qsPath, _ := exec.LookPath("qs")

	output, err := exec.Command("qs", "--version").Output()
	if err != nil {
		return "Installed (version check failed)", "warn", qsPath
	}

	fullVersion := strings.TrimSpace(string(output))
	if matches := regexp.MustCompile(`quickshell (\d+\.\d+\.\d+)`).FindStringSubmatch(fullVersion); len(matches) >= 2 {
		if version.CompareVersions(matches[1], "0.2.0") < 0 {
			return fmt.Sprintf("%s (needs >= 0.2.0)", fullVersion), "error", qsPath
		}
		if missingFeatures {
			return fullVersion, "warn", qsPath
		}
		return fullVersion, "ok", qsPath
	}

	return fullVersion, "warn", qsPath
}

func checkDMSInstallation() []checkResult {
	results := []checkResult{}

	dmsPath := ""
	if err := findConfig(nil, nil); err == nil && configPath != "" {
		dmsPath = configPath
	} else if path, err := config.LocateDMSConfig(); err == nil {
		dmsPath = path
	}

	if dmsPath == "" {
		return []checkResult{{catInstallation, "DMS Configuration", "error", "Not found", "shell.qml not found in any config path"}}
	}

	results = append(results, checkResult{catInstallation, "DMS Configuration", "ok", "Found", dmsPath})

	shellQml := filepath.Join(dmsPath, "shell.qml")
	if _, err := os.Stat(shellQml); err != nil {
		results = append(results, checkResult{catInstallation, "shell.qml", "error", "Missing", shellQml})
	} else {
		results = append(results, checkResult{catInstallation, "shell.qml", "ok", "Present", shellQml})
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
		results = append(results, checkResult{catInstallation, "Install Type", "info", installType, dmsPath})
	}

	return results
}

func checkWindowManagers() []checkResult {
	compositors := []struct {
		name, versionCmd, versionArg, versionRe string
		commands                                []string
	}{
		{"Hyprland", "hyprctl", "version", `v?(\d+\.\d+\.\d+)`, []string{"hyprland", "Hyprland"}},
		{"niri", "niri", "--version", `niri (\d+\.\d+)`, []string{"niri"}},
		{"Sway", "sway", "--version", `sway version (\d+\.\d+)`, []string{"sway"}},
		{"River", "river", "-version", `river (\d+\.\d+)`, []string{"river"}},
		{"Wayfire", "wayfire", "--version", `wayfire (\d+\.\d+)`, []string{"wayfire"}},
	}

	results := []checkResult{}
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
				catCompositor, c.name, "ok",
				getVersionFromCommand(c.versionCmd, c.versionArg, c.versionRe), details,
			})
		}
	}

	if !foundAny {
		results = append(results, checkResult{
			catCompositor, "Compositor", "error",
			"No supported Wayland compositor found",
			"Install Hyprland, niri, Sway, River, or Wayfire",
		})
	}

	if wm := detectRunningWM(); wm != "" {
		results = append(results, checkResult{catCompositor, "Active", "info", wm, ""})
	}

	return results
}

func getVersionFromCommand(cmd, arg, regex string) string {
	output, err := exec.Command(cmd, arg).Output()
	if err != nil {
		return "installed"
	}

	outStr := string(output)
	if matches := regexp.MustCompile(regex).FindStringSubmatch(outStr); len(matches) > 1 {
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

	results := []checkResult{}
	missingFeatures := false

	for _, f := range features {
		available := strings.Contains(outputStr, fmt.Sprintf("FEATURE:%s:OK", f.name))
		status, message := "ok", "Available"
		if !available {
			status, message = "info", "Not available"
			missingFeatures = true
		}
		results = append(results, checkResult{catQuickshellFeatures, f.name, status, message, f.desc})
	}

	return results, missingFeatures
}

func checkOptionalDependencies() []checkResult {
	results := []checkResult{}

	if utils.IsServiceActive("accounts-daemon", false) {
		results = append(results, checkResult{catOptionalFeatures, "accountsservice", "ok", "Running", "User accounts"})
	} else {
		results = append(results, checkResult{catOptionalFeatures, "accountsservice", "warn", "Not running", "User accounts"})
	}

	terminals := []string{"ghostty", "kitty", "alacritty", "foot", "wezterm"}
	terminalFound := ""
	for _, term := range terminals {
		if utils.CommandExists(term) {
			terminalFound = term
			break
		}
	}
	if terminalFound != "" {
		results = append(results, checkResult{catOptionalFeatures, "Terminal", "ok", terminalFound, ""})
	} else {
		results = append(results, checkResult{catOptionalFeatures, "Terminal", "warn", "None found", "Install ghostty, kitty, or alacritty"})
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
			switch foundCmd {
			case "nmcli":
				message = "NetworkManager"
			case "iwctl":
				message = "iwd"
			}
			results = append(results, checkResult{catOptionalFeatures, d.name, "ok", message, d.desc})
		} else if d.important {
			results = append(results, checkResult{catOptionalFeatures, d.name, "warn", "Missing", d.desc})
		} else {
			results = append(results, checkResult{catOptionalFeatures, d.name, "info", "Not installed", d.desc})
		}
	}

	return results
}

func checkConfigurationFiles() []checkResult {
	configFiles := []struct{ name, path string }{
		{"Settings", filepath.Join(utils.XDGConfigHome(), "DankMaterialShell", "settings.json")},
		{"Session", filepath.Join(utils.XDGStateHome(), "DankMaterialShell", "session.json")},
		{"Colors", filepath.Join(utils.XDGCacheHome(), "DankMaterialShell", "dms-colors.json")},
	}

	results := []checkResult{}
	for _, cf := range configFiles {
		if _, err := os.Stat(cf.path); err == nil {
			results = append(results, checkResult{catConfigFiles, cf.name, "ok", "Present", cf.path})
		} else {
			results = append(results, checkResult{catConfigFiles, cf.name, "info", "Not yet created", cf.path})
		}
	}
	return results
}

func checkSystemdServices() []checkResult {
	if !utils.CommandExists("systemctl") {
		return nil
	}

	results := []checkResult{}

	dmsState := getServiceState("dms", true)
	if !dmsState.exists {
		results = append(results, checkResult{catServices, "dms.service", "info", "Not installed", "Optional user service"})
	} else {
		status, message := "ok", dmsState.enabled
		if dmsState.active != "" {
			message = fmt.Sprintf("%s, %s", dmsState.enabled, dmsState.active)
		}
		if dmsState.enabled == "disabled" {
			status, message = "warn", "Disabled"
		}
		results = append(results, checkResult{catServices, "dms.service", status, message, ""})
	}

	greetdState := getServiceState("greetd", false)
	if greetdState.exists {
		status := "ok"
		if greetdState.enabled == "disabled" {
			status = "info"
		}
		results = append(results, checkResult{catServices, "greetd", status, greetdState.enabled, ""})
	} else if doctorVerbose {
		results = append(results, checkResult{catServices, "greetd", "info", "Not installed", "Optional greeter service"})
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
			fmt.Printf("  %s\n", styles.Bold.Render(categoryNames[r.category]))
			currentCategory = r.category
		}
		printResultLine(r, styles)
	}
}

func printResultLine(r checkResult, styles tui.Styles) {
	icon, style := "○", styles.Subtle
	switch r.status {
	case "ok":
		icon, style = "●", styles.Success
	case "warn":
		icon, style = "●", styles.Warning
	case "error":
		icon, style = "●", styles.Error
	}

	name := r.name
	if len(name) > 18 {
		name = name[:17] + "…"
	}
	dots := strings.Repeat("·", 19-len(name))

	fmt.Printf("    %s %s %s %s\n", style.Render(icon), name, styles.Subtle.Render(dots), r.message)

	if doctorVerbose && r.details != "" {
		fmt.Printf("      %s\n", styles.Subtle.Render("└─ "+r.details))
	}
}

func printSummary(results []checkResult, qsMissingFeatures bool) {
	theme := tui.TerminalTheme()
	styles := tui.NewStyles(theme)

	errors, warnings, ok := 0, 0, 0
	for _, r := range results {
		switch r.status {
		case "error":
			errors++
		case "warn":
			warnings++
		case "ok":
			ok++
		}
	}

	fmt.Println()
	fmt.Printf("  %s\n", styles.Subtle.Render("──────────────────────────────────────"))

	if errors == 0 && warnings == 0 {
		fmt.Printf("  %s\n", styles.Success.Render("✓ All checks passed!"))
	} else {
		parts := []string{}
		if errors > 0 {
			parts = append(parts, styles.Error.Render(fmt.Sprintf("%d error(s)", errors)))
		}
		if warnings > 0 {
			parts = append(parts, styles.Warning.Render(fmt.Sprintf("%d warning(s)", warnings)))
		}
		parts = append(parts, styles.Success.Render(fmt.Sprintf("%d ok", ok)))
		fmt.Printf("  %s\n", strings.Join(parts, ", "))

		if qsMissingFeatures {
			fmt.Println()
			fmt.Printf("  %s\n", styles.Subtle.Render("→ Consider using quickshell-git for full feature support"))
		}
	}
	fmt.Println()
}
