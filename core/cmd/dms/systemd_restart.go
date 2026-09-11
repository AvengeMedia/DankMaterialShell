package main

import (
	"fmt"
	"os/exec"
	"strings"
)

const dmsSystemdUnit = "dms.service"
const dmsSessionRestartExitCode = 75 // EX_TEMPFAIL

var runSystemctl = func(args ...string) error {
	output, err := exec.Command("systemctl", args...).CombinedOutput()
	if err == nil {
		return nil
	}
	if detail := strings.TrimSpace(string(output)); detail != "" {
		return fmt.Errorf("%s: %w", detail, err)
	}
	return err
}

func trySystemdRestart() (bool, error) {
	if err := runSystemctl("--user", "is-active", "--quiet", dmsSystemdUnit); err != nil {
		return false, nil
	}

	if err := runSystemctl("--user", "restart", dmsSystemdUnit); err != nil {
		return true, fmt.Errorf("restarting %s: %w", dmsSystemdUnit, err)
	}
	return true, nil
}
