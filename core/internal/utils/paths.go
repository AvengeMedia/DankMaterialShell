package utils

import (
	"os"
	"path/filepath"
	"strings"
)

func xdgDir(envVar string, defaultPath ...string) string {
	if dir := os.Getenv(envVar); dir != "" {
		return dir
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(append([]string{home}, defaultPath...)...)
}

func XDGConfigHome() string {
	return xdgDir("XDG_CONFIG_HOME", ".config")
}

func XDGStateHome() string {
	return xdgDir("XDG_STATE_HOME", ".local", "state")
}

func XDGCacheHome() string {
	return xdgDir("XDG_CACHE_HOME", ".cache")
}

func XDGDataHome() string {
	return xdgDir("XDG_DATA_HOME", ".local", "share")
}

func ExpandPath(path string) (string, error) {
	expanded := os.ExpandEnv(path)
	expanded = filepath.Clean(expanded)

	if strings.HasPrefix(expanded, "~") {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		expanded = filepath.Join(home, expanded[1:])
	}

	return expanded, nil
}
