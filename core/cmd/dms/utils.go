package main

import (
	"os"
	"os/exec"
	"runtime"
	"strings"
)

func disableMemProfilingUnlessRequested() {
	if os.Getenv("DMS_PPROF") != "" {
		return
	}
	runtime.MemProfileRate = 0
}

// isReadOnlyCommand returns true if the CLI args indicate a command that is
// safe to run as root (e.g. shell completion, help).
func isReadOnlyCommand(args []string) bool {
	for _, arg := range args[1:] {
		if strings.HasPrefix(arg, "-") {
			continue
		}
		switch arg {
		case "completion", "help", "__complete", "system":
			return true
		}
		return false
	}
	return false
}

func isArchPackageInstalled(packageName string) bool {
	cmd := exec.Command("pacman", "-Q", packageName)
	err := cmd.Run()
	return err == nil
}
