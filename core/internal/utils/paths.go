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

func XDGPicturesDir() string {
	if dir := os.Getenv("XDG_PICTURES_DIR"); dir != "" {
		if expanded, err := ExpandPath(dir); err == nil {
			return expanded
		}
	}

	data, err := os.ReadFile(filepath.Join(XDGConfigHome(), "user-dirs.dirs"))
	if err != nil {
		return ""
	}

	const prefix = "XDG_PICTURES_DIR="
	for line := range strings.SplitSeq(string(data), "\n") {
		if len(line) == 0 || line[0] == '#' {
			continue
		}
		if !strings.HasPrefix(line, prefix) {
			continue
		}
		path := strings.Trim(line[len(prefix):], "\"")
		expanded, err := ExpandPath(path)
		if err != nil {
			return ""
		}
		return expanded
	}
	return ""
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
