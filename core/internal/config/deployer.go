package config

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/deps"
)

type ConfigDeployer struct {
	logChan chan<- string
}

type DeploymentResult struct {
	ConfigType string
	Path       string
	BackupPath string
	Deployed   bool
	Error      error
}

func NewConfigDeployer(logChan chan<- string) *ConfigDeployer {
	return &ConfigDeployer{
		logChan: logChan,
	}
}

func (cd *ConfigDeployer) log(message string) {
	if cd.logChan != nil {
		cd.logChan <- message
	}
}

// DeployConfigurations deploys all necessary configurations based on the chosen window manager
func (cd *ConfigDeployer) DeployConfigurations(ctx context.Context, wm deps.WindowManager) ([]DeploymentResult, error) {
	return cd.DeployConfigurationsWithTerminal(ctx, wm, deps.TerminalGhostty)
}

// DeployConfigurationsWithTerminal deploys all necessary configurations based on chosen window manager and terminal
func (cd *ConfigDeployer) DeployConfigurationsWithTerminal(ctx context.Context, wm deps.WindowManager, terminal deps.Terminal) ([]DeploymentResult, error) {
	return cd.DeployConfigurationsSelective(ctx, wm, terminal, nil, nil)
}

// DeployConfigurationsWithSystemd deploys configurations with systemd option
func (cd *ConfigDeployer) DeployConfigurationsWithSystemd(ctx context.Context, wm deps.WindowManager, terminal deps.Terminal, useSystemd bool) ([]DeploymentResult, error) {
	return cd.deployConfigurationsInternal(ctx, wm, terminal, nil, nil, nil, useSystemd)
}

func (cd *ConfigDeployer) DeployConfigurationsSelective(ctx context.Context, wm deps.WindowManager, terminal deps.Terminal, installedDeps []deps.Dependency, replaceConfigs map[string]bool) ([]DeploymentResult, error) {
	return cd.DeployConfigurationsSelectiveWithReinstalls(ctx, wm, terminal, installedDeps, replaceConfigs, nil)
}

func (cd *ConfigDeployer) DeployConfigurationsSelectiveWithReinstalls(ctx context.Context, wm deps.WindowManager, terminal deps.Terminal, installedDeps []deps.Dependency, replaceConfigs map[string]bool, reinstallItems map[string]bool) ([]DeploymentResult, error) {
	return cd.deployConfigurationsInternal(ctx, wm, terminal, installedDeps, replaceConfigs, reinstallItems, true)
}

func (cd *ConfigDeployer) deployConfigurationsInternal(ctx context.Context, wm deps.WindowManager, terminal deps.Terminal, installedDeps []deps.Dependency, replaceConfigs map[string]bool, reinstallItems map[string]bool, useSystemd bool) ([]DeploymentResult, error) {
	var results []DeploymentResult

	shouldReplaceConfig := func(configType string) bool {
		if replaceConfigs == nil {
			return true
		}
		replace, exists := replaceConfigs[configType]
		return !exists || replace
	}

	switch wm {
	case deps.WindowManagerNiri:
		if shouldReplaceConfig("Niri") {
			result, err := cd.deployNiriConfig(terminal, useSystemd)
			results = append(results, result)
			if err != nil {
				return results, fmt.Errorf("failed to deploy Niri config: %w", err)
			}
		}
	case deps.WindowManagerHyprland:
		if shouldReplaceConfig("Hyprland") {
			result, err := cd.deployHyprlandConfig(terminal, useSystemd)
			results = append(results, result)
			if err != nil {
				return results, fmt.Errorf("failed to deploy Hyprland config: %w", err)
			}
		}
	}

	switch terminal {
	case deps.TerminalGhostty:
		if shouldReplaceConfig("Ghostty") {
			ghosttyResults, err := cd.deployGhosttyConfig()
			results = append(results, ghosttyResults...)
			if err != nil {
				return results, fmt.Errorf("failed to deploy Ghostty config: %w", err)
			}
		}
	case deps.TerminalKitty:
		if shouldReplaceConfig("Kitty") {
			kittyResults, err := cd.deployKittyConfig()
			results = append(results, kittyResults...)
			if err != nil {
				return results, fmt.Errorf("failed to deploy Kitty config: %w", err)
			}
		}
	case deps.TerminalAlacritty:
		if shouldReplaceConfig("Alacritty") {
			alacrittyResults, err := cd.deployAlacrittyConfig()
			results = append(results, alacrittyResults...)
			if err != nil {
				return results, fmt.Errorf("failed to deploy Alacritty config: %w", err)
			}
		}
	}

	return results, nil
}

func (cd *ConfigDeployer) deployNiriConfig(terminal deps.Terminal, useSystemd bool) (DeploymentResult, error) {
	result := DeploymentResult{
		ConfigType: "Niri",
		Path:       filepath.Join(os.Getenv("HOME"), ".config", "niri", "config.kdl"),
	}

	configDir := filepath.Dir(result.Path)
	if err := os.MkdirAll(configDir, 0o755); err != nil {
		result.Error = fmt.Errorf("failed to create config directory: %w", err)
		return result, result.Error
	}

	dmsDir := filepath.Join(configDir, "dms")
	if err := os.MkdirAll(dmsDir, 0o755); err != nil {
		result.Error = fmt.Errorf("failed to create dms directory: %w", err)
		return result, result.Error
	}

	var existingConfig string
	if _, err := os.Stat(result.Path); err == nil {
		cd.log("Found existing Niri configuration")

		existingData, err := os.ReadFile(result.Path)
		if err != nil {
			result.Error = fmt.Errorf("failed to read existing config: %w", err)
			return result, result.Error
		}
		existingConfig = string(existingData)

		timestamp := time.Now().Format("2006-01-02_15-04-05")
		result.BackupPath = result.Path + ".backup." + timestamp
		if err := os.WriteFile(result.BackupPath, existingData, 0o644); err != nil {
			result.Error = fmt.Errorf("failed to create backup: %w", err)
			return result, result.Error
		}
		cd.log(fmt.Sprintf("Backed up existing config to %s", result.BackupPath))
	}

	var terminalCommand string
	switch terminal {
	case deps.TerminalGhostty:
		terminalCommand = "ghostty"
	case deps.TerminalKitty:
		terminalCommand = "kitty"
	case deps.TerminalAlacritty:
		terminalCommand = "alacritty"
	default:
		terminalCommand = "ghostty"
	}

	newConfig := strings.ReplaceAll(NiriConfig, "{{TERMINAL_COMMAND}}", terminalCommand)

	if !useSystemd {
		newConfig = cd.transformNiriConfigForNonSystemd(newConfig, terminalCommand)
	}

	if existingConfig != "" {
		mergedConfig, err := cd.mergeNiriOutputSections(newConfig, existingConfig, dmsDir)
		if err != nil {
			cd.log(fmt.Sprintf("Warning: Failed to merge output sections: %v", err))
		} else {
			newConfig = mergedConfig
			cd.log("Successfully merged existing output sections")
		}
	}

	if err := os.WriteFile(result.Path, []byte(newConfig), 0o644); err != nil {
		result.Error = fmt.Errorf("failed to write config: %w", err)
		return result, result.Error
	}

	if err := cd.deployNiriDmsConfigs(dmsDir, terminalCommand); err != nil {
		result.Error = fmt.Errorf("failed to deploy dms configs: %w", err)
		return result, result.Error
	}

	result.Deployed = true
	cd.log("Successfully deployed Niri configuration")
	return result, nil
}

func (cd *ConfigDeployer) deployNiriDmsConfigs(dmsDir, terminalCommand string) error {
	configs := []struct {
		name    string
		content string
	}{
		{"colors.kdl", NiriColorsConfig},
		{"layout.kdl", NiriLayoutConfig},
		{"alttab.kdl", NiriAlttabConfig},
		{"binds.kdl", strings.ReplaceAll(NiriBindsConfig, "{{TERMINAL_COMMAND}}", terminalCommand)},
		{"outputs.kdl", ""},
		{"cursor.kdl", ""},
		{"windowrules.kdl", ""},
	}

	for _, cfg := range configs {
		path := filepath.Join(dmsDir, cfg.name)
		// Skip if file already exists and is not empty to preserve user modifications
		if info, err := os.Stat(path); err == nil && info.Size() > 0 {
			cd.log(fmt.Sprintf("Skipping %s (already exists)", cfg.name))
			continue
		}
		if err := os.WriteFile(path, []byte(cfg.content), 0o644); err != nil {
			return fmt.Errorf("failed to write %s: %w", cfg.name, err)
		}
		cd.log(fmt.Sprintf("Deployed %s", cfg.name))
	}

	return nil
}

func (cd *ConfigDeployer) deployGhosttyConfig() ([]DeploymentResult, error) {
	var results []DeploymentResult

	mainResult := DeploymentResult{
		ConfigType: "Ghostty",
		Path:       filepath.Join(os.Getenv("HOME"), ".config", "ghostty", "config"),
	}

	configDir := filepath.Dir(mainResult.Path)
	if err := os.MkdirAll(configDir, 0o755); err != nil {
		mainResult.Error = fmt.Errorf("failed to create config directory: %w", err)
		return []DeploymentResult{mainResult}, mainResult.Error
	}

	if _, err := os.Stat(mainResult.Path); err == nil {
		cd.log("Found existing Ghostty configuration")

		existingData, err := os.ReadFile(mainResult.Path)
		if err != nil {
			mainResult.Error = fmt.Errorf("failed to read existing config: %w", err)
			return []DeploymentResult{mainResult}, mainResult.Error
		}

		timestamp := time.Now().Format("2006-01-02_15-04-05")
		mainResult.BackupPath = mainResult.Path + ".backup." + timestamp
		if err := os.WriteFile(mainResult.BackupPath, existingData, 0o644); err != nil {
			mainResult.Error = fmt.Errorf("failed to create backup: %w", err)
			return []DeploymentResult{mainResult}, mainResult.Error
		}
		cd.log(fmt.Sprintf("Backed up existing config to %s", mainResult.BackupPath))
	}

	if err := os.WriteFile(mainResult.Path, []byte(GhosttyConfig), 0o644); err != nil {
		mainResult.Error = fmt.Errorf("failed to write config: %w", err)
		return []DeploymentResult{mainResult}, mainResult.Error
	}

	mainResult.Deployed = true
	cd.log("Successfully deployed Ghostty configuration")
	results = append(results, mainResult)

	colorResult := DeploymentResult{
		ConfigType: "Ghostty Colors",
		Path:       filepath.Join(os.Getenv("HOME"), ".config", "ghostty", "themes", "dankcolors"),
	}

	themesDir := filepath.Dir(colorResult.Path)
	if err := os.MkdirAll(themesDir, 0o755); err != nil {
		mainResult.Error = fmt.Errorf("failed to create themes directory: %w", err)
		return []DeploymentResult{mainResult}, mainResult.Error
	}

	if err := os.WriteFile(colorResult.Path, []byte(GhosttyColorConfig), 0o644); err != nil {
		colorResult.Error = fmt.Errorf("failed to write color config: %w", err)
		return results, colorResult.Error
	}

	colorResult.Deployed = true
	cd.log("Successfully deployed Ghostty color configuration")
	results = append(results, colorResult)

	return results, nil
}

func (cd *ConfigDeployer) deployKittyConfig() ([]DeploymentResult, error) {
	var results []DeploymentResult

	mainResult := DeploymentResult{
		ConfigType: "Kitty",
		Path:       filepath.Join(os.Getenv("HOME"), ".config", "kitty", "kitty.conf"),
	}

	configDir := filepath.Dir(mainResult.Path)
	if err := os.MkdirAll(configDir, 0o755); err != nil {
		mainResult.Error = fmt.Errorf("failed to create config directory: %w", err)
		return []DeploymentResult{mainResult}, mainResult.Error
	}

	if _, err := os.Stat(mainResult.Path); err == nil {
		cd.log("Found existing Kitty configuration")

		existingData, err := os.ReadFile(mainResult.Path)
		if err != nil {
			mainResult.Error = fmt.Errorf("failed to read existing config: %w", err)
			return []DeploymentResult{mainResult}, mainResult.Error
		}

		timestamp := time.Now().Format("2006-01-02_15-04-05")
		mainResult.BackupPath = mainResult.Path + ".backup." + timestamp
		if err := os.WriteFile(mainResult.BackupPath, existingData, 0o644); err != nil {
			mainResult.Error = fmt.Errorf("failed to create backup: %w", err)
			return []DeploymentResult{mainResult}, mainResult.Error
		}
		cd.log(fmt.Sprintf("Backed up existing config to %s", mainResult.BackupPath))
	}

	if err := os.WriteFile(mainResult.Path, []byte(KittyConfig), 0o644); err != nil {
		mainResult.Error = fmt.Errorf("failed to write config: %w", err)
		return []DeploymentResult{mainResult}, mainResult.Error
	}

	mainResult.Deployed = true
	cd.log("Successfully deployed Kitty configuration")
	results = append(results, mainResult)

	themeResult := DeploymentResult{
		ConfigType: "Kitty Theme",
		Path:       filepath.Join(os.Getenv("HOME"), ".config", "kitty", "dank-theme.conf"),
	}

	if err := os.WriteFile(themeResult.Path, []byte(KittyThemeConfig), 0o644); err != nil {
		themeResult.Error = fmt.Errorf("failed to write theme config: %w", err)
		return results, themeResult.Error
	}

	themeResult.Deployed = true
	cd.log("Successfully deployed Kitty theme configuration")
	results = append(results, themeResult)

	tabsResult := DeploymentResult{
		ConfigType: "Kitty Tabs",
		Path:       filepath.Join(os.Getenv("HOME"), ".config", "kitty", "dank-tabs.conf"),
	}

	if err := os.WriteFile(tabsResult.Path, []byte(KittyTabsConfig), 0o644); err != nil {
		tabsResult.Error = fmt.Errorf("failed to write tabs config: %w", err)
		return results, tabsResult.Error
	}

	tabsResult.Deployed = true
	cd.log("Successfully deployed Kitty tabs configuration")
	results = append(results, tabsResult)

	return results, nil
}

func (cd *ConfigDeployer) deployAlacrittyConfig() ([]DeploymentResult, error) {
	var results []DeploymentResult

	mainResult := DeploymentResult{
		ConfigType: "Alacritty",
		Path:       filepath.Join(os.Getenv("HOME"), ".config", "alacritty", "alacritty.toml"),
	}

	configDir := filepath.Dir(mainResult.Path)
	if err := os.MkdirAll(configDir, 0o755); err != nil {
		mainResult.Error = fmt.Errorf("failed to create config directory: %w", err)
		return []DeploymentResult{mainResult}, mainResult.Error
	}

	if _, err := os.Stat(mainResult.Path); err == nil {
		cd.log("Found existing Alacritty configuration")

		existingData, err := os.ReadFile(mainResult.Path)
		if err != nil {
			mainResult.Error = fmt.Errorf("failed to read existing config: %w", err)
			return []DeploymentResult{mainResult}, mainResult.Error
		}

		timestamp := time.Now().Format("2006-01-02_15-04-05")
		mainResult.BackupPath = mainResult.Path + ".backup." + timestamp
		if err := os.WriteFile(mainResult.BackupPath, existingData, 0o644); err != nil {
			mainResult.Error = fmt.Errorf("failed to create backup: %w", err)
			return []DeploymentResult{mainResult}, mainResult.Error
		}
		cd.log(fmt.Sprintf("Backed up existing config to %s", mainResult.BackupPath))
	}

	if err := os.WriteFile(mainResult.Path, []byte(AlacrittyConfig), 0o644); err != nil {
		mainResult.Error = fmt.Errorf("failed to write config: %w", err)
		return []DeploymentResult{mainResult}, mainResult.Error
	}

	mainResult.Deployed = true
	cd.log("Successfully deployed Alacritty configuration")
	results = append(results, mainResult)

	themeResult := DeploymentResult{
		ConfigType: "Alacritty Theme",
		Path:       filepath.Join(os.Getenv("HOME"), ".config", "alacritty", "dank-theme.toml"),
	}

	if err := os.WriteFile(themeResult.Path, []byte(AlacrittyThemeConfig), 0o644); err != nil {
		themeResult.Error = fmt.Errorf("failed to write theme config: %w", err)
		return results, themeResult.Error
	}

	themeResult.Deployed = true
	cd.log("Successfully deployed Alacritty theme configuration")
	results = append(results, themeResult)

	return results, nil
}

func (cd *ConfigDeployer) mergeNiriOutputSections(newConfig, existingConfig, dmsDir string) (string, error) {
	outputRegex := regexp.MustCompile(`(?m)^(/-)?\s*output\s+"[^"]+"\s*\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}`)
	existingOutputs := outputRegex.FindAllString(existingConfig, -1)

	if len(existingOutputs) == 0 {
		return newConfig, nil
	}

	outputsPath := filepath.Join(dmsDir, "outputs.kdl")
	if _, err := os.Stat(outputsPath); err != nil {
		var outputsContent strings.Builder
		for _, output := range existingOutputs {
			outputsContent.WriteString(output)
			outputsContent.WriteString("\n\n")
		}
		if err := os.WriteFile(outputsPath, []byte(outputsContent.String()), 0o644); err != nil {
			cd.log(fmt.Sprintf("Warning: Failed to migrate outputs to %s: %v", outputsPath, err))
		} else {
			cd.log("Migrated output sections to dms/outputs.kdl")
		}
	}

	exampleOutputRegex := regexp.MustCompile(`(?m)^/-output "eDP-2" \{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}`)
	mergedConfig := exampleOutputRegex.ReplaceAllString(newConfig, "")

	inputEndRegex := regexp.MustCompile(`(?m)^}$`)
	inputMatches := inputEndRegex.FindAllStringIndex(newConfig, -1)

	if len(inputMatches) < 1 {
		return "", fmt.Errorf("could not find insertion point for output sections")
	}

	insertPos := inputMatches[0][1]

	var builder strings.Builder
	builder.WriteString(mergedConfig[:insertPos])
	builder.WriteString("\n// Outputs from existing configuration\n")

	for _, output := range existingOutputs {
		builder.WriteString(output)
		builder.WriteString("\n")
	}

	builder.WriteString(mergedConfig[insertPos:])

	return builder.String(), nil
}

// deployHyprlandConfig handles Hyprland configuration deployment with backup and merging
func (cd *ConfigDeployer) deployHyprlandConfig(terminal deps.Terminal, useSystemd bool) (DeploymentResult, error) {
	result := DeploymentResult{
		ConfigType: "Hyprland",
		Path:       filepath.Join(os.Getenv("HOME"), ".config", "hypr", "hyprland.conf"),
	}

	configDir := filepath.Dir(result.Path)
	if err := os.MkdirAll(configDir, 0o755); err != nil {
		result.Error = fmt.Errorf("failed to create config directory: %w", err)
		return result, result.Error
	}

	dmsDir := filepath.Join(configDir, "dms")
	if err := os.MkdirAll(dmsDir, 0o755); err != nil {
		result.Error = fmt.Errorf("failed to create dms directory: %w", err)
		return result, result.Error
	}

	var existingConfig string
	if _, err := os.Stat(result.Path); err == nil {
		cd.log("Found existing Hyprland configuration")

		existingData, err := os.ReadFile(result.Path)
		if err != nil {
			result.Error = fmt.Errorf("failed to read existing config: %w", err)
			return result, result.Error
		}
		existingConfig = string(existingData)

		timestamp := time.Now().Format("2006-01-02_15-04-05")
		result.BackupPath = result.Path + ".backup." + timestamp
		if err := os.WriteFile(result.BackupPath, existingData, 0o644); err != nil {
			result.Error = fmt.Errorf("failed to create backup: %w", err)
			return result, result.Error
		}
		cd.log(fmt.Sprintf("Backed up existing config to %s", result.BackupPath))
	}

	var terminalCommand string
	switch terminal {
	case deps.TerminalGhostty:
		terminalCommand = "ghostty"
	case deps.TerminalKitty:
		terminalCommand = "kitty"
	case deps.TerminalAlacritty:
		terminalCommand = "alacritty"
	default:
		terminalCommand = "ghostty"
	}

	newConfig := strings.ReplaceAll(HyprlandConfig, "{{TERMINAL_COMMAND}}", terminalCommand)

	if !useSystemd {
		newConfig = cd.transformHyprlandConfigForNonSystemd(newConfig, terminalCommand)
	}

	if existingConfig != "" {
		mergedConfig, err := cd.mergeHyprlandMonitorSections(newConfig, existingConfig, dmsDir)
		if err != nil {
			cd.log(fmt.Sprintf("Warning: Failed to merge monitor sections: %v", err))
		} else {
			newConfig = mergedConfig
			cd.log("Successfully merged existing monitor sections")
		}
	}

	if err := os.WriteFile(result.Path, []byte(newConfig), 0o644); err != nil {
		result.Error = fmt.Errorf("failed to write config: %w", err)
		return result, result.Error
	}

	if err := cd.deployHyprlandDmsConfigs(dmsDir, terminalCommand); err != nil {
		result.Error = fmt.Errorf("failed to deploy dms configs: %w", err)
		return result, result.Error
	}

	result.Deployed = true
	cd.log("Successfully deployed Hyprland configuration")
	return result, nil
}

func (cd *ConfigDeployer) deployHyprlandDmsConfigs(dmsDir string, terminalCommand string) error {
	configs := []struct {
		name    string
		content string
	}{
		{"colors.conf", HyprColorsConfig},
		{"layout.conf", HyprLayoutConfig},
		{"binds.conf", strings.ReplaceAll(HyprBindsConfig, "{{TERMINAL_COMMAND}}", terminalCommand)},
		{"outputs.conf", ""},
		{"cursor.conf", ""},
		{"windowrules.conf", ""},
	}

	for _, cfg := range configs {
		path := filepath.Join(dmsDir, cfg.name)
		// Skip if file already exists and is not empty to preserve user modifications
		if info, err := os.Stat(path); err == nil && info.Size() > 0 {
			cd.log(fmt.Sprintf("Skipping %s (already exists)", cfg.name))
			continue
		}
		if err := os.WriteFile(path, []byte(cfg.content), 0o644); err != nil {
			return fmt.Errorf("failed to write %s: %w", cfg.name, err)
		}
		cd.log(fmt.Sprintf("Deployed %s", cfg.name))
	}

	return nil
}

func (cd *ConfigDeployer) mergeHyprlandMonitorSections(newConfig, existingConfig, dmsDir string) (string, error) {
	monitorRegex := regexp.MustCompile(`(?m)^#?\s*monitor\s*=.*$`)
	existingMonitors := monitorRegex.FindAllString(existingConfig, -1)

	if len(existingMonitors) == 0 {
		return newConfig, nil
	}

	outputsPath := filepath.Join(dmsDir, "outputs.conf")
	if _, err := os.Stat(outputsPath); err != nil {
		var outputsContent strings.Builder
		for _, monitor := range existingMonitors {
			outputsContent.WriteString(monitor)
			outputsContent.WriteString("\n")
		}
		if err := os.WriteFile(outputsPath, []byte(outputsContent.String()), 0o644); err != nil {
			cd.log(fmt.Sprintf("Warning: Failed to migrate monitors to %s: %v", outputsPath, err))
		} else {
			cd.log("Migrated monitor sections to dms/outputs.conf")
		}
	}

	exampleMonitorRegex := regexp.MustCompile(`(?m)^# monitor = eDP-2.*$`)
	mergedConfig := exampleMonitorRegex.ReplaceAllString(newConfig, "")

	monitorHeaderRegex := regexp.MustCompile(`(?m)^# MONITOR CONFIG\n# ==================$`)
	headerMatch := monitorHeaderRegex.FindStringIndex(mergedConfig)

	if headerMatch == nil {
		return "", fmt.Errorf("could not find MONITOR CONFIG section")
	}

	insertPos := headerMatch[1] + 1

	var builder strings.Builder
	builder.WriteString(mergedConfig[:insertPos])
	builder.WriteString("# Monitors from existing configuration\n")

	for _, monitor := range existingMonitors {
		builder.WriteString(monitor)
		builder.WriteString("\n")
	}

	builder.WriteString(mergedConfig[insertPos:])

	return builder.String(), nil
}

func (cd *ConfigDeployer) transformHyprlandConfigForNonSystemd(config, terminalCommand string) string {
	lines := strings.Split(config, "\n")
	var result []string
	startupSectionFound := false

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "exec-once = dbus-update-activation-environment") {
			continue
		}
		if strings.HasPrefix(trimmed, "exec-once = systemctl --user start") {
			startupSectionFound = true
			result = append(result, "exec-once = dms run")
			result = append(result, "env = QT_QPA_PLATFORM,wayland;xcb")
			result = append(result, "env = ELECTRON_OZONE_PLATFORM_HINT,auto")
			result = append(result, "env = QT_QPA_PLATFORMTHEME,gtk3")
			result = append(result, "env = QT_QPA_PLATFORMTHEME_QT6,gtk3")
			result = append(result, fmt.Sprintf("env = TERMINAL,%s", terminalCommand))
			continue
		}
		result = append(result, line)
	}

	if !startupSectionFound {
		for i, line := range result {
			if strings.Contains(line, "STARTUP APPS") {
				insertLines := []string{
					"exec-once = dms run",
					"env = QT_QPA_PLATFORM,wayland;xcb",
					"env = ELECTRON_OZONE_PLATFORM_HINT,auto",
					"env = QT_QPA_PLATFORMTHEME,gtk3",
					"env = QT_QPA_PLATFORMTHEME_QT6,gtk3",
					fmt.Sprintf("env = TERMINAL,%s", terminalCommand),
				}
				result = append(result[:i+2], append(insertLines, result[i+2:]...)...)
				break
			}
		}
	}

	return strings.Join(result, "\n")
}

func (cd *ConfigDeployer) transformNiriConfigForNonSystemd(config, terminalCommand string) string {
	envVars := fmt.Sprintf(`environment {
  XDG_CURRENT_DESKTOP "niri"
  QT_QPA_PLATFORM "wayland;xcb"
  ELECTRON_OZONE_PLATFORM_HINT "auto"
  QT_QPA_PLATFORMTHEME "gtk3"
  QT_QPA_PLATFORMTHEME_QT6 "gtk3"
  TERMINAL "%s"
}`, terminalCommand)

	config = regexp.MustCompile(`environment \{[^}]*\}`).ReplaceAllString(config, envVars)

	spawnDms := `spawn-at-startup "dms" "run"`
	if !strings.Contains(config, spawnDms) {
		// Insert spawn-at-startup for dms after the environment block
		envBlockEnd := regexp.MustCompile(`environment \{[^}]*\}`)
		if loc := envBlockEnd.FindStringIndex(config); loc != nil {
			config = config[:loc[1]] + "\n" + spawnDms + config[loc[1]:]
		}
	}

	return config
}
