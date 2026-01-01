package utils

import (
	"bytes"
	"errors"
	"os/exec"
	"strings"
)

func FlatpakInPath() bool {
	_, err := exec.LookPath("flatpak")
	return err == nil
}

func FlatpakExists(name string) bool {
	if !FlatpakInPath() {
		return false
	}

	cmd := exec.Command("flatpak", "info", name)
	err := cmd.Run()
	return err == nil
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
