package utils

import "os/exec"

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
