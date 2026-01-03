package utils

import (
	"os/exec"
	"strings"
)

func CommandExists(cmd string) bool {
	_, err := exec.LookPath(cmd)
	return err == nil
}

func AnyCommandExists(cmds ...string) bool {
	for _, cmd := range cmds {
		if CommandExists(cmd) {
			return true
		}
	}
	return false
}

func IsServiceActive(name string, userService bool) bool {
	if !CommandExists("systemctl") {
		return false
	}

	args := []string{"is-active", name}
	if userService {
		args = []string{"--user", "is-active", name}
	}
	output, _ := exec.Command("systemctl", args...).Output()
	return strings.EqualFold(strings.TrimSpace(string(output)), "active")
}
