package utils

import (
	"bytes"
	"cmp"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
)

var flatpakInstallationsDir = "/etc/flatpak/installations.d"

func FlatpakInPath() bool {
	_, err := exec.LookPath("flatpak")
	return err == nil
}

func FlatpakExists(name string) bool {
	if !FlatpakInPath() {
		return false
	}
	for _, dir := range flatpakInstallations() {
		if info, err := os.Stat(filepath.Join(dir, "app", name)); err == nil && info.IsDir() {
			return true
		}
	}
	return false
}

func flatpakInstallations() []string {
	dirs := []string{
		cmp.Or(os.Getenv("FLATPAK_USER_DIR"), filepath.Join(XDGDataHome(), "flatpak")),
		cmp.Or(os.Getenv("FLATPAK_SYSTEM_DIR"), "/var/lib/flatpak"),
	}
	entries, err := os.ReadDir(flatpakInstallationsDir)
	if err != nil {
		return dirs
	}
	for _, entry := range entries {
		if !strings.HasSuffix(entry.Name(), ".conf") {
			continue
		}
		data, err := os.ReadFile(filepath.Join(flatpakInstallationsDir, entry.Name()))
		if err != nil {
			continue
		}
		for line := range strings.Lines(string(data)) {
			if path, ok := strings.CutPrefix(strings.TrimSpace(line), "Path="); ok {
				dirs = append(dirs, strings.TrimSpace(path))
			}
		}
	}
	return dirs
}

func FlatpakSearchBySubstring(substring string) bool {
	if !FlatpakInPath() {
		return false
	}

	cmd := exec.Command("flatpak", "list", "--app")
	var stdout bytes.Buffer
	cmd.Stdout = &stdout

	if err := cmd.Run(); err != nil {
		return false
	}

	out := stdout.String()

	for line := range strings.SplitSeq(out, "\n") {
		fields := strings.Fields(line)
		if len(fields) > 1 {
			id := fields[1]
			idParts := strings.Split(id, ".")
			// We are assuming that the last part of the ID is
			// the package name we're looking for. This might
			// not always be true, some developers use arbitrary
			// suffixes.
			if len(idParts) > 0 && idParts[len(idParts)-1] == substring {
				cmd := exec.Command("flatpak", "info", id)
				err := cmd.Run()
				return err == nil
			}
		}
	}
	return false
}

func AnyFlatpakExists(flatpaks ...string) bool {
	return slices.ContainsFunc(flatpaks, FlatpakExists)
}

func FlatpakInstallationDir(name string) (string, error) {
	if !FlatpakInPath() {
		return "", errors.New("flatpak not found in PATH")
	}

	cmd := exec.Command("flatpak", "info", "--show-location", name)
	var stdout bytes.Buffer
	cmd.Stdout = &stdout

	if err := cmd.Run(); err != nil {
		return "", errors.New("flatpak not installed: " + name)
	}

	location := strings.TrimSpace(stdout.String())
	if location == "" {
		return "", errors.New("installation directory not found for: " + name)
	}

	return location, nil
}
