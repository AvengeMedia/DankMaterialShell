package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// LocateDMSConfig searches for DMS installation following XDG Base Directory specification
func LocateDMSConfig() (string, error) {
	var primaryPaths []string

	configHome := os.Getenv("XDG_CONFIG_HOME")
	if configHome == "" {
		if homeDir, err := os.UserHomeDir(); err == nil {
			configHome = filepath.Join(homeDir, ".config")
		}
	}

	if configHome != "" {
		primaryPaths = append(primaryPaths, filepath.Join(configHome, "quickshell", "dms"))
	}

	// System data directories
	dataDirs := os.Getenv("XDG_DATA_DIRS")
	if dataDirs == "" {
		dataDirs = "/usr/local/share:/usr/share"
	}

	for _, dir := range strings.Split(dataDirs, ":") {
		if dir != "" {
			primaryPaths = append(primaryPaths, filepath.Join(dir, "quickshell", "dms"))
		}
	}

	// System config directories (fallback)
	configDirs := os.Getenv("XDG_CONFIG_DIRS")
	if configDirs == "" {
		configDirs = "/etc/xdg"
	}

	for _, dir := range strings.Split(configDirs, ":") {
		if dir != "" {
			primaryPaths = append(primaryPaths, filepath.Join(dir, "quickshell", "dms"))
		}
	}

	// Build search paths with secondary (monorepo) paths interleaved
	var searchPaths []string
	for _, path := range primaryPaths {
		searchPaths = append(searchPaths, path)
		searchPaths = append(searchPaths, filepath.Join(path, "quickshell"))
	}

	for _, path := range searchPaths {
		shellPath := filepath.Join(path, "shell.qml")
		if info, err := os.Stat(shellPath); err == nil && !info.IsDir() {
			return path, nil
		}
	}

	return "", fmt.Errorf("could not find DMS config (shell.qml) in any valid config path")
}
