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
	"github.com/AvengeMedia/DankMaterialShell/core/internal/version"
)

const hyprlandBackupDirName = ".dms-backups"

type ConfigDeployer struct {
	logChan         chan<- string
	replaceBinds    bool
	hyprlandVersion string
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

// SetHyprlandVersion gates the Lua deploy; empty means unknown (e.g. no session on a TTY) and deploys anyway.
func (cd *ConfigDeployer) SetHyprlandVersion(ver string) {
	cd.hyprlandVersion = ver
}

func hyprlandLuaUnsupported(ver string) error {
	if ver == "" || version.CompareVersions(ver, "0.55.0") >= 0 {
		return nil
	}
	return fmt.Errorf("hyprland.lua is not loaded by Hyprland %s; DMS needs 0.55 or newer", ver)
}

func (cd *ConfigDeployer) DeployConfigurationsSelectiveWithReinstalls(ctx context.Context, wm deps.WindowManager, terminal deps.Terminal, installedDeps []deps.Dependency, replaceConfigs map[string]bool, reinstallItems map[string]bool) ([]DeploymentResult, error) {
	return cd.deployConfigurationsInternal(ctx, wm, terminal, installedDeps, replaceConfigs, reinstallItems, true)
}

func (cd *ConfigDeployer) DeployConfigurationsSelectiveWithReinstallsAndSystemd(ctx context.Context, wm deps.WindowManager, terminal deps.Terminal, installedDeps []deps.Dependency, replaceConfigs map[string]bool, reinstallItems map[string]bool, useSystemd bool) ([]DeploymentResult, error) {
	return cd.deployConfigurationsInternal(ctx, wm, terminal, installedDeps, replaceConfigs, reinstallItems, useSystemd)
}

func (cd *ConfigDeployer) deployConfigurationsInternal(_ context.Context, wm deps.WindowManager, terminal deps.Terminal, installedDeps []deps.Dependency, replaceConfigs map[string]bool, _ map[string]bool, useSystemd bool) ([]DeploymentResult, error) {
	var results []DeploymentResult

	// Primary config file paths used to detect fresh installs.
	configPrimaryPaths := map[string][]string{
		"Niri": {
			filepath.Join(os.Getenv("HOME"), ".config", "niri", "config.kdl"),
		},
		"Hyprland": {
			filepath.Join(os.Getenv("HOME"), ".config", "hypr", "hyprland.lua"),
			// A conf-only install still counts: deploying moves it into backups.
			filepath.Join(os.Getenv("HOME"), ".config", "hypr", "hyprland.conf"),
		},
		"Mango": {
			filepath.Join(os.Getenv("HOME"), ".config", "mango", "config.conf"),
			filepath.Join(os.Getenv("HOME"), ".config", "mango", "mango.conf"),
		},
		"Ghostty": {
			filepath.Join(os.Getenv("HOME"), ".config", "ghostty", "config"),
		},
		"Kitty": {
			filepath.Join(os.Getenv("HOME"), ".config", "kitty", "kitty.conf"),
		},
		"Alacritty": {
			filepath.Join(os.Getenv("HOME"), ".config", "alacritty", "alacritty.toml"),
		},
	}

	shouldReplaceConfig := func(configType string) bool {
		if replaceConfigs == nil {
			return true
		}
		replace, exists := replaceConfigs[configType]
		if !exists || replace {
			return true
		}
		// Config is explicitly set to "don't replace" — but still deploy
		// if the config file doesn't exist yet (fresh install scenario).
		if primaryPaths, ok := configPrimaryPaths[configType]; ok {
			exists := false
			for _, primaryPath := range primaryPaths {
				if _, err := os.Stat(primaryPath); err == nil {
					exists = true
					break
				}
			}
			if !exists {
				return true
			}
		}
		return false
	}

	terminalCommand := terminal.Command()
	if replaceConfigs != nil {
		cd.replaceBinds = replaceConfigs[BindsConfigType]
	}
	switch wm {
	case deps.WindowManagerNiri:
		if shouldReplaceConfig("Niri") {
			result, err := cd.deployNiriConfig(terminalCommand, useSystemd)
			results = append(results, result)
			if err != nil {
				return results, fmt.Errorf("failed to deploy Niri config: %w", err)
			}
		} else if cd.replaceBinds {
			bindsPath := filepath.Join(os.Getenv("HOME"), ".config", "niri", "dms", "binds.kdl")
			if err := os.MkdirAll(filepath.Dir(bindsPath), 0o755); err != nil {
				return results, fmt.Errorf("failed to create niri binds directory: %w", err)
			}
			stockBinds := strings.ReplaceAll(NiriBindsConfig, "{{TERMINAL_COMMAND}}", terminalCommand)
			err := cd.deployBindsFile(bindsPath, stockBinds)
			results = append(results, DeploymentResult{
				ConfigType: BindsConfigType,
				Path:       bindsPath,
				Deployed:   err == nil,
				Error:      err,
			})
			if err != nil {
				return results, fmt.Errorf("failed to deploy Niri keybinds: %w", err)
			}
		}
	case deps.WindowManagerHyprland:
		for _, dep := range installedDeps {
			if dep.Name == "hyprland" && cd.hyprlandVersion == "" {
				cd.hyprlandVersion = dep.Version
			}
		}
		if shouldReplaceConfig("Hyprland") {
			result, err := cd.deployHyprlandConfig(terminalCommand, useSystemd)
			results = append(results, result)
			if err != nil {
				return results, fmt.Errorf("failed to deploy Hyprland config: %w", err)
			}
		}
	case deps.WindowManagerMango:
		if shouldReplaceConfig("Mango") {
			result, err := cd.deployMangoConfig(terminalCommand, useSystemd)
			results = append(results, result)
			if err != nil {
				return results, fmt.Errorf("failed to deploy Mango config: %w", err)
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

func (cd *ConfigDeployer) DeployCompositor(wm deps.WindowManager, terminalCommand string, useSystemd bool) (DeploymentResult, error) {
	switch wm {
	case deps.WindowManagerNiri:
		return cd.deployNiriConfig(terminalCommand, useSystemd)
	case deps.WindowManagerHyprland:
		return cd.deployHyprlandConfig(terminalCommand, useSystemd)
	case deps.WindowManagerMango:
		return cd.deployMangoConfig(terminalCommand, useSystemd)
	default:
		return DeploymentResult{}, fmt.Errorf("unsupported window manager")
	}
}

func (cd *ConfigDeployer) DeployTerminal(terminal deps.Terminal) ([]DeploymentResult, error) {
	switch terminal {
	case deps.TerminalGhostty:
		return cd.deployGhosttyConfig()
	case deps.TerminalKitty:
		return cd.deployKittyConfig()
	case deps.TerminalAlacritty:
		return cd.deployAlacrittyConfig()
	default:
		return nil, fmt.Errorf("unsupported terminal")
	}
}

func (cd *ConfigDeployer) deployNiriConfig(terminalCommand string, useSystemd bool) (DeploymentResult, error) {
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

// deployBindsFile writes stock binds when the file is missing or empty. An
// existing file is always backed up, then kept unless replaceBinds is set.
func (cd *ConfigDeployer) deployBindsFile(path, stock string) error {
	name := filepath.Base(path)
	data, err := os.ReadFile(path)
	if err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("failed to read %s: %w", name, err)
	}
	if err != nil || len(data) == 0 {
		if err := os.WriteFile(path, []byte(stock), 0o644); err != nil {
			return fmt.Errorf("failed to write %s: %w", name, err)
		}
		cd.log("Deployed " + name)
		return nil
	}
	backup := path + ".backup." + time.Now().Format("2006-01-02_15-04-05")
	if err := os.WriteFile(backup, data, 0o644); err != nil {
		return fmt.Errorf("failed to back up %s: %w", name, err)
	}
	cd.log(fmt.Sprintf("Backed up existing binds to %s", backup))
	if !cd.replaceBinds {
		cd.log("Keeping existing " + name)
		return nil
	}
	if err := os.WriteFile(path, []byte(stock), 0o644); err != nil {
		return fmt.Errorf("failed to write %s: %w", name, err)
	}
	cd.log("Deployed DMS stock " + name)
	return nil
}

func (cd *ConfigDeployer) deployNiriDmsConfigs(dmsDir, terminalCommand string) error {
	stockBinds := strings.ReplaceAll(NiriBindsConfig, "{{TERMINAL_COMMAND}}", terminalCommand)
	if err := cd.deployBindsFile(filepath.Join(dmsDir, "binds.kdl"), stockBinds); err != nil {
		return err
	}
	configs := []struct {
		name    string
		content string
	}{
		{"colors.kdl", NiriColorsConfig},
		{"layout.kdl", NiriLayoutConfig},
		{"alttab.kdl", NiriAlttabConfig},
		{"input.kdl", NiriInputConfig},
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
	var existingOutputs []string
	for _, output := range outputRegex.FindAllString(existingConfig, -1) {
		if strings.Contains(NiriConfig, output) {
			continue
		}
		existingOutputs = append(existingOutputs, output)
	}

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
func (cd *ConfigDeployer) deployHyprlandConfig(terminalCommand string, useSystemd bool) (DeploymentResult, error) {
	result := DeploymentResult{
		ConfigType: "Hyprland",
		Path:       filepath.Join(os.Getenv("HOME"), ".config", "hypr", "hyprland.lua"),
	}
	if err := hyprlandLuaUnsupported(cd.hyprlandVersion); err != nil {
		result.Error = err
		return result, err
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

	timestamp := time.Now().Format("2006-01-02_15-04-05")
	backupDir := filepath.Join(configDir, hyprlandBackupDirName, timestamp)
	var existingConfig string
	existingData, existingPath, err := readExistingHyprlandConfig(configDir)
	if err != nil {
		result.Error = err
		return result, result.Error
	}
	if existingData != "" {
		existingConfig = existingData
		cd.log(fmt.Sprintf("Found existing Hyprland configuration at %s", existingPath))
	}
	// A legacy hyprland.conf is only backed up once hyprland.lua is in place; Hyprland
	// watches the live config and regenerates a stub one if it disappears first.
	if existingData != "" && !strings.EqualFold(filepath.Ext(existingPath), ".conf") {
		result.BackupPath, err = backupHyprlandConfigFile(filepath.Join(backupDir, filepath.Base(existingPath)), []byte(existingData))
		if err != nil {
			result.Error = fmt.Errorf("failed to create backup: %w", err)
			return result, result.Error
		}
		cd.log(fmt.Sprintf("Backed up existing config to %s", result.BackupPath))
	}

	newConfig := strings.ReplaceAll(HyprlandLuaConfig, "{{TERMINAL_COMMAND}}", terminalCommand)

	if !useSystemd {
		newConfig = transformHyprlandLuaForNonSystemd(newConfig, terminalCommand)
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

	if useSystemd {
		if targetPath, err := EnsureHyprlandSessionTarget(); err != nil {
			cd.log(fmt.Sprintf("Warning: failed to write hyprland-session.target: %v", err))
		} else {
			cd.log(fmt.Sprintf("Ensured hyprland session target at %s", targetPath))
		}
	}

	movedLegacy, mainConfBackup, err := backupLegacyHyprlandConfFiles(configDir, dmsDir, backupDir)
	if err != nil {
		result.Error = fmt.Errorf("failed to back up legacy hyprlang configs: %w", err)
		return result, result.Error
	}
	if mainConfBackup != "" && result.BackupPath == "" {
		result.BackupPath = mainConfBackup
		cd.log(fmt.Sprintf("Backed up existing config to %s", mainConfBackup))
	}
	if movedLegacy > 0 {
		if result.BackupPath == "" {
			result.BackupPath = backupDir
		}
		cd.log(fmt.Sprintf("Moved %d legacy hyprlang config(s) to %s", movedLegacy, backupDir))
	}

	if err := cd.deployHyprlandDmsConfigs(dmsDir, terminalCommand); err != nil {
		result.Error = fmt.Errorf("failed to deploy dms configs: %w", err)
		return result, result.Error
	}

	CleanupStrayHyprlandConfFile(func(format string, v ...any) {
		cd.log(fmt.Sprintf(format, v...))
	})

	result.Deployed = true
	cd.log("Successfully deployed Hyprland configuration")
	return result, nil
}

func uniqueBackupPath(dst string) string {
	if _, err := os.Lstat(dst); err != nil {
		return dst
	}
	for i := 1; i < 1000; i++ {
		candidate := fmt.Sprintf("%s.%d", dst, i)
		if _, err := os.Lstat(candidate); err != nil {
			return candidate
		}
	}
	return fmt.Sprintf("%s.%d", dst, time.Now().UnixNano())
}

func backupHyprlandConfigFile(dst string, data []byte) (string, error) {
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return "", err
	}
	dst = uniqueBackupPath(dst)
	if err := os.WriteFile(dst, data, 0o644); err != nil {
		return "", err
	}
	return dst, nil
}

func backupLegacyHyprlandConfFiles(configDir, dmsDir, backupDir string) (int, string, error) {
	mainConf := filepath.Join(configDir, "hyprland.conf")
	legacyPaths := []string{mainConf}
	dmsConfPaths, err := filepath.Glob(filepath.Join(dmsDir, "*.conf"))
	if err != nil {
		return 0, "", err
	}
	legacyPaths = append(legacyPaths, dmsConfPaths...)
	backupPaths, err := adjacentHyprlandBackupFiles(configDir, dmsDir)
	if err != nil {
		return 0, "", err
	}
	legacyPaths = append(legacyPaths, backupPaths...)

	moved := 0
	mainConfBackup := ""
	for _, src := range legacyPaths {
		info, err := os.Lstat(src)
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			return moved, mainConfBackup, err
		}
		if info.IsDir() {
			continue
		}

		rel, err := filepath.Rel(configDir, src)
		if err != nil {
			rel = filepath.Base(src)
		}
		dst, err := moveHyprlandConfigFile(src, filepath.Join(backupDir, rel))
		if err != nil {
			return moved, mainConfBackup, err
		}
		if src == mainConf {
			mainConfBackup = dst
		}
		moved++
	}

	return moved, mainConfBackup, nil
}

func moveHyprlandConfigFile(src, dst string) (string, error) {
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return "", err
	}
	dst = uniqueBackupPath(dst)
	if err := os.Rename(src, dst); err != nil {
		return "", err
	}
	return dst, nil
}

func adjacentHyprlandBackupFiles(configDir, dmsDir string) ([]string, error) {
	var paths []string
	patterns := []string{
		filepath.Join(configDir, "hyprland.conf.backup.*"),
		filepath.Join(configDir, "hyprland.lua.backup.*"),
		filepath.Join(dmsDir, "*.conf.backup.*"),
		filepath.Join(dmsDir, "*.lua.backup.*"),
	}
	for _, pattern := range patterns {
		matches, err := filepath.Glob(pattern)
		if err != nil {
			return nil, err
		}
		paths = append(paths, matches...)
	}
	return paths, nil
}

func (cd *ConfigDeployer) deployHyprlandDmsConfigs(dmsDir string, terminalCommand string) error {
	configs := []struct {
		name      string
		content   string
		overwrite bool
	}{
		{name: "colors.lua", content: DMSColorsLuaConfig},
		{name: "layout.lua", content: DMSLayoutLuaConfig},
		{name: "binds.lua", content: strings.ReplaceAll(DMSBindsLuaConfig, "{{TERMINAL_COMMAND}}", terminalCommand), overwrite: true},
		{name: "binds-user.lua", content: DMSBindsUserLuaConfig},
		{name: "outputs.lua", content: DMSOutputsLuaConfig},
		{name: "cursor.lua", content: DMSCursorLuaConfig},
		{name: "input.lua", content: DMSInputLuaConfig},
		{name: "windowrules.lua", content: DMSWindowRulesLuaConfig},
	}

	for _, cfg := range configs {
		path := filepath.Join(dmsDir, cfg.name)
		existed := false
		if info, err := os.Stat(path); err == nil && info.Size() > 0 {
			existed = true
		}
		if existed && !cfg.overwrite {
			cd.log(fmt.Sprintf("Skipping %s (already exists)", cfg.name))
			continue
		}
		if err := os.WriteFile(path, []byte(cfg.content), 0o644); err != nil {
			return fmt.Errorf("failed to write %s: %w", cfg.name, err)
		}
		if existed {
			cd.log(fmt.Sprintf("Updated %s", cfg.name))
			continue
		}
		cd.log(fmt.Sprintf("Deployed %s", cfg.name))
	}

	return nil
}

func (cd *ConfigDeployer) mergeHyprlandMonitorSections(newConfig, existingConfig, dmsDir string) (string, error) {
	_ = newConfig
	lines := extractHyprlangMonitorLines(existingConfig)
	if len(lines) == 0 {
		return newConfig, nil
	}

	outputsPath := filepath.Join(dmsDir, "outputs.lua")
	if info, err := os.Stat(outputsPath); err == nil && info.Size() > 0 {
		cd.log("Skipping monitor migration: dms/outputs.lua already exists")
		return newConfig, nil
	}

	var b strings.Builder
	b.WriteString("-- Migrated from existing hyprlang monitor lines\n\n")
	ok := 0
	for _, line := range lines {
		lua, err := hyprlangMonitorLineToLua(line)
		if err != nil {
			cd.log(fmt.Sprintf("Warning: could not migrate monitor line %q: %v", line, err))
			continue
		}
		b.WriteString(lua)
		b.WriteByte('\n')
		ok++
	}
	if ok == 0 {
		return newConfig, nil
	}
	b.WriteByte('\n')
	b.WriteString("-- Default fallback\n")
	b.WriteString("hl.monitor({ output = \"\", mode = \"preferred\", position = \"auto\", scale = \"auto\" })\n")
	if err := os.WriteFile(outputsPath, []byte(b.String()), 0o644); err != nil {
		return newConfig, err
	}
	cd.log("Migrated monitor sections to dms/outputs.lua")
	return newConfig, nil
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
