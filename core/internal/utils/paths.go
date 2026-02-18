package utils

import (
	"os"
	"path/filepath"
	"strings"
)

func XDGStateHome() string {
	if dir := os.Getenv("XDG_STATE_HOME"); dir != "" {
		return dir
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".local", "state")
}

func XDGDataHome() string {
	if dir := os.Getenv("XDG_DATA_HOME"); dir != "" {
		return dir
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".local", "share")
}

func XDGCacheHome() string {
	if dir, err := os.UserCacheDir(); err == nil {
		return dir
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".cache")
}

func XDGConfigHome() string {
	if dir, err := os.UserConfigDir(); err == nil {
		return dir
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config")
}

func EmacsConfigDir() string {
	home, _ := os.UserHomeDir()

	emacsD := filepath.Join(home, ".emacs.d")
	if info, err := os.Stat(emacsD); err == nil && info.IsDir() {
		return emacsD
	}

	xdgEmacs := filepath.Join(XDGConfigHome(), "emacs")
	if info, err := os.Stat(xdgEmacs); err == nil && info.IsDir() {
		return xdgEmacs
	}

	return ""
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
