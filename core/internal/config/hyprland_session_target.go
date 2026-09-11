package config

import (
	"os"
	"path/filepath"
)

const hyprlandSessionTargetUnit = `[Unit]
Description=Hyprland Session Target
BindsTo=graphical-session.target
Before=graphical-session.target
Wants=graphical-session-pre.target
After=graphical-session-pre.target
`

const legacyHyprlandSessionTargetUnit = `[Unit]
Description=Hyprland Session Target
Requires=graphical-session.target
After=graphical-session.target
`

// Only a missing or dankinstall-written unit is replaced; hand-written units are left alone.
func EnsureHyprlandSessionTarget() (string, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}

	targetPath := filepath.Join(homeDir, ".config", "systemd", "user", "hyprland-session.target")
	existing, err := os.ReadFile(targetPath)
	if err == nil {
		content := string(existing)
		if content == hyprlandSessionTargetUnit {
			return targetPath, nil
		}
		if content != legacyHyprlandSessionTargetUnit {
			return targetPath, nil
		}
	}

	if err := os.MkdirAll(filepath.Dir(targetPath), 0o755); err != nil {
		return "", err
	}
	if err := os.WriteFile(targetPath, []byte(hyprlandSessionTargetUnit), 0o644); err != nil {
		return "", err
	}
	return targetPath, nil
}
