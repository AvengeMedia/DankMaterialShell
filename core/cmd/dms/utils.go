package main

import (
	"fmt"
	"os/exec"
	"slices"
	"strings"
)

func findCommandPath(cmd string) (string, error) {
	path, err := exec.LookPath(cmd)
	if err != nil {
		return "", fmt.Errorf("command '%s' not found in PATH", cmd)
	}
	return path, nil
}

func isArchPackageInstalled(packageName string) bool {
	cmd := exec.Command("pacman", "-Q", packageName)
	err := cmd.Run()
	return err == nil
}

type systemdServiceState struct {
	Name         string
	EnabledState string
	NeedsDisable bool
	Exists       bool
}

// checkSystemdServiceEnabled returns (state, should_disable, error) for a systemd service
func checkSystemdServiceEnabled(serviceName string) (string, bool, error) {
	cmd := exec.Command("systemctl", "is-enabled", serviceName)
	output, err := cmd.Output()

	stateStr := strings.TrimSpace(string(output))

	if err != nil {
		knownStates := []string{"disabled", "masked", "masked-runtime", "not-found", "enabled", "enabled-runtime", "static", "indirect", "alias"}
		isKnownState := slices.Contains(knownStates, stateStr)

		if !isKnownState {
			return stateStr, false, fmt.Errorf("systemctl is-enabled failed: %w (output: %s)", err, stateStr)
		}
	}

	shouldDisable := false
	switch stateStr {
	case "enabled", "enabled-runtime", "static", "indirect", "alias":
		shouldDisable = true
	case "disabled", "masked", "masked-runtime", "not-found":
		shouldDisable = false
	default:
		shouldDisable = true
	}

	return stateStr, shouldDisable, nil
}

func getSystemdServiceState(serviceName string) (*systemdServiceState, error) {
	state := &systemdServiceState{
		Name:   serviceName,
		Exists: false,
	}

	enabledState, needsDisable, err := checkSystemdServiceEnabled(serviceName)
	if err != nil {
		return nil, fmt.Errorf("failed to check enabled state: %w", err)
	}

	state.EnabledState = enabledState
	state.NeedsDisable = needsDisable

	if enabledState == "not-found" {
		state.Exists = false
		return state, nil
	}

	state.Exists = true
	return state, nil
}
