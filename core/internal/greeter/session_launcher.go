package greeter

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"syscall"
)

func sessionDesktopIDFromPath(path string) string {
	id := strings.TrimSpace(path)
	if id == "" {
		return ""
	}
	if strings.ContainsAny(id, "/\\") {
		id = filepath.Base(id)
	}
	if id == "" {
		return ""
	}
	if !strings.HasSuffix(id, ".desktop") {
		id += ".desktop"
	}
	return id
}

func sessionDesktopIDFromMemory(mem greeterAutoLoginMemory) string {
	if id := sessionDesktopIDFromPath(mem.LastSessionDesktopID); id != "" {
		return id
	}
	return sessionDesktopIDFromPath(mem.LastSessionID)
}

func sessionDesktopDirs() []string {
	seen := make(map[string]bool)
	dirs := make([]string, 0, 8)

	addBase := func(base string) {
		base = strings.TrimSpace(base)
		if base == "" {
			return
		}
		for _, sub := range []string{"wayland-sessions", "xsessions"} {
			dir := filepath.Join(base, sub)
			if seen[dir] {
				continue
			}
			seen[dir] = true
			dirs = append(dirs, dir)
		}
	}

	if dataHome := os.Getenv("XDG_DATA_HOME"); dataHome != "" {
		addBase(dataHome)
	} else if home, err := os.UserHomeDir(); err == nil && home != "" {
		addBase(filepath.Join(home, ".local", "share"))
	}

	if dataDirs := os.Getenv("XDG_DATA_DIRS"); dataDirs != "" {
		for _, dir := range strings.Split(dataDirs, ":") {
			addBase(dir)
		}
	} else {
		addBase("/usr/local/share")
		addBase("/usr/share")
	}

	return dirs
}

func ResolveSessionExec(sessionID string) (string, error) {
	return resolveSessionExecInDirs(sessionID, sessionDesktopDirs())
}

func resolveSessionExecInDirs(sessionID string, dirs []string) (string, error) {
	id := sessionDesktopIDFromPath(sessionID)
	if id == "" {
		return "", fmt.Errorf("session id is empty")
	}

	for _, dir := range dirs {
		path := filepath.Join(dir, id)
		execLine, err := execFromDesktopFile(path)
		if err == nil {
			return execLine, nil
		}
		if !os.IsNotExist(err) {
			return "", err
		}
	}

	return "", fmt.Errorf("session desktop file %q was not found", id)
}

func LaunchSessionByID(sessionID string) error {
	execLine, err := ResolveSessionExec(sessionID)
	if err != nil {
		return err
	}
	execLine = strings.TrimSpace(stripDesktopExecCodes(execLine))
	if execLine == "" {
		return fmt.Errorf("session %q has an empty Exec command", sessionID)
	}

	env := append(os.Environ(), "XDG_SESSION_TYPE=wayland")
	return syscall.Exec("/bin/sh", []string{"sh", "-c", "exec " + execLine}, env)
}

func LaunchSessionFromMemory(cacheDir, homeDir string) error {
	enabled, _, sessionID, err := resolveGreeterAutoLoginState(cacheDir, homeDir)
	if err != nil {
		return err
	}
	if !enabled {
		return fmt.Errorf("greeter auto-login is disabled")
	}
	if sessionID == "" {
		return fmt.Errorf("greeter auto-login has no remembered session")
	}
	return LaunchSessionByID(sessionID)
}
