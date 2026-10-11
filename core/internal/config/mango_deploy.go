package config

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/deps"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/mangoconf"
)

// BindsConfigType is the replaceConfigs key choosing stock DMS binds over the user's.
const BindsConfigType = "Keybinds"

// SetReplaceBinds picks the DMS stock binds over existing ones; existing binds are kept by default.
func (cd *ConfigDeployer) SetReplaceBinds(replace bool) {
	cd.replaceBinds = replace
}

// ExistingBinds returns where the user's keybinds for wm live, if any. Hyprland
// is absent on purpose: its binds.lua is DMS-owned and user binds sit in binds-user.lua.
func ExistingBinds(wm deps.WindowManager) (string, bool) {
	switch wm {
	case deps.WindowManagerNiri:
		return nonEmptyFile(filepath.Join(os.Getenv("HOME"), ".config", "niri", "dms", "binds.kdl"))
	case deps.WindowManagerMango:
		return MangoExistingBinds()
	}
	return "", false
}

func nonEmptyFile(path string) (string, bool) {
	info, err := os.Stat(path)
	if err != nil || info.Size() == 0 {
		return "", false
	}
	return path, true
}

var (
	mangoBindLine    = regexp.MustCompile(`^\s*(bind[a-z]*|mousebind|axisbind|gesturebind|switchbind|keymode|key_mode)\s*=`)
	mangoMonitorLine = regexp.MustCompile(`^\s*(monitorrule|monitor_rule)\s*=`)
	mangoWindowLine  = regexp.MustCompile(`^\s*(windowrule|window_rule|windowrule-once|window_rule_once)\s*=`)
	mangoExecOnceDMS = regexp.MustCompile(`(?m)^# Starts the shell when DMS.*\n#.*\n(exec-once|exec_once)=dms run\n`)
)

var (
	mangoDialect                = mangoconf.Detect
	mangoSessionTargetInstalled = mangoconf.SessionTargetInstalled
	mangoAddWants               = func() error {
		return exec.Command("systemctl", "--user", "add-wants", mangoconf.SessionTarget, "dms").Run()
	}
)

// MangoExistingBinds returns where the user's Mango binds live: a non-empty
// dms/binds.conf, else a config.conf with bind lines.
func MangoExistingBinds() (string, bool) {
	dir := mangoconf.Dir()
	bindsPath := filepath.Join(dir, "dms", "binds.conf")
	if info, err := os.Stat(bindsPath); err == nil && info.Size() > 0 {
		return bindsPath, true
	}
	mainPath := filepath.Join(dir, "config.conf")
	data, err := os.ReadFile(mainPath)
	if err != nil {
		return "", false
	}
	if extractMangoLines(string(data), mangoBindLine) == "" {
		return "", false
	}
	return mainPath, true
}

func extractMangoLines(text string, match *regexp.Regexp) string {
	var out []string
	for line := range strings.SplitSeq(text, "\n") {
		if match.MatchString(line) {
			out = append(out, strings.TrimSpace(line))
		}
	}
	if len(out) == 0 {
		return ""
	}
	return strings.Join(out, "\n") + "\n"
}

// mangoSystemdAutostart starts dms.service from mango-session.target and
// returns false when that is not possible, so the config keeps exec-once.
func (cd *ConfigDeployer) mangoSystemdAutostart(useSystemd bool) bool {
	link := mangoconf.WantsLink()
	if !useSystemd || !mangoSessionTargetInstalled() {
		if err := os.Remove(link); err == nil {
			cd.log("Removed dms.service from " + mangoconf.SessionTarget)
		}
		return false
	}
	if err := mangoAddWants(); err != nil {
		cd.log(fmt.Sprintf("Warning: add-wants %s dms failed (%v); starting DMS from the Mango config instead", mangoconf.SessionTarget, err))
		return false
	}
	cd.log("DMS starts as dms.service with " + mangoconf.SessionTarget)
	return true
}

func (cd *ConfigDeployer) deployMangoConfig(terminalCommand string, useSystemd bool) (DeploymentResult, error) {
	configDir := mangoconf.Dir()
	result := DeploymentResult{
		ConfigType: "Mango",
		Path:       filepath.Join(configDir, "config.conf"),
	}

	dmsDir := filepath.Join(configDir, "dms")
	if err := os.MkdirAll(dmsDir, 0o755); err != nil {
		result.Error = fmt.Errorf("failed to create dms directory: %w", err)
		return result, result.Error
	}

	timestamp := time.Now().Format("2006-01-02_15-04-05")
	var existing string
	if data, err := os.ReadFile(result.Path); err == nil {
		existing = string(data)
		cd.log("Found existing Mango configuration")
		result.BackupPath = result.Path + ".backup." + timestamp
		if err := os.WriteFile(result.BackupPath, data, 0o644); err != nil {
			result.Error = fmt.Errorf("failed to create backup: %w", err)
			return result, result.Error
		}
		cd.log(fmt.Sprintf("Backed up existing config to %s", result.BackupPath))
	}

	dialect := mangoDialect()
	newConfig := strings.ReplaceAll(MangoConfig, "{{TERMINAL_COMMAND}}", terminalCommand)
	if cd.mangoSystemdAutostart(useSystemd) {
		newConfig = mangoExecOnceDMS.ReplaceAllString(newConfig, "")
	}
	if err := os.WriteFile(result.Path, []byte(dialect.Translate(newConfig)), 0o644); err != nil {
		result.Error = fmt.Errorf("failed to write config: %w", err)
		return result, result.Error
	}

	if err := cd.deployMangoDmsConfigs(dmsDir, terminalCommand, dialect, existing, timestamp); err != nil {
		result.Error = fmt.Errorf("failed to deploy dms configs: %w", err)
		return result, result.Error
	}

	result.Deployed = true
	cd.log("Successfully deployed Mango configuration")
	return result, nil
}

// Like niri, fragments the user or the shell already filled are left alone; the
// replaced config.conf hands its binds, monitor and window rules to empty ones.
func (cd *ConfigDeployer) deployMangoDmsConfigs(dmsDir, terminalCommand string, dialect mangoconf.Dialect, oldMain, timestamp string) error {
	stockBinds := strings.ReplaceAll(MangoBindsConfig, "{{TERMINAL_COMMAND}}", terminalCommand)
	bindsPath := filepath.Join(dmsDir, "binds.conf")
	if data, err := os.ReadFile(bindsPath); err == nil && len(data) > 0 {
		backup := bindsPath + ".backup." + timestamp
		if err := os.WriteFile(backup, data, 0o644); err != nil {
			return fmt.Errorf("failed to back up binds.conf: %w", err)
		}
		cd.log(fmt.Sprintf("Backed up existing binds to %s", backup))
		if cd.replaceBinds {
			if err := os.WriteFile(bindsPath, []byte(dialect.Translate(stockBinds)), 0o644); err != nil {
				return fmt.Errorf("failed to write binds.conf: %w", err)
			}
			cd.log("Deployed DMS stock binds.conf")
		} else {
			if !mangoconf.HasUserBindsHeader(string(data)) {
				if err := os.WriteFile(bindsPath, append([]byte(mangoconf.BindsKeptHeader+"\n"), data...), 0o644); err != nil {
					return fmt.Errorf("failed to write binds.conf: %w", err)
				}
			}
			cd.log("Keeping existing binds.conf")
		}
	} else {
		binds := stockBinds
		if old := extractMangoLines(oldMain, mangoBindLine); old != "" && !cd.replaceBinds {
			binds = mangoconf.BindsMovedHeader + "\n" + old
			cd.log("Moved existing binds from config.conf to binds.conf")
		}
		if err := os.WriteFile(bindsPath, []byte(dialect.Translate(binds)), 0o644); err != nil {
			return fmt.Errorf("failed to write binds.conf: %w", err)
		}
	}

	configs := []struct {
		name    string
		content string
	}{
		{"colors.conf", MangoColorsConfig},
		{"layout.conf", MangoLayoutConfig},
		{"outputs.conf", extractMangoLines(oldMain, mangoMonitorLine)},
		{"cursor.conf", ""},
		{"input.conf", ""},
		{"windowrules.conf", extractMangoLines(oldMain, mangoWindowLine)},
	}
	for _, cfg := range configs {
		path := filepath.Join(dmsDir, cfg.name)
		if info, err := os.Stat(path); err == nil && info.Size() > 0 {
			cd.log(fmt.Sprintf("Skipping %s (already exists)", cfg.name))
			continue
		}
		if err := os.WriteFile(path, []byte(dialect.Translate(cfg.content)), 0o644); err != nil {
			return fmt.Errorf("failed to write %s: %w", cfg.name, err)
		}
		cd.log(fmt.Sprintf("Deployed %s", cfg.name))
	}
	return nil
}
