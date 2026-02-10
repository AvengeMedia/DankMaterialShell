package utils

import (
	"fmt"
	"os/exec"
	"strings"
)

func dconfPath(schema, key string) string {
	return "/" + strings.ReplaceAll(schema, ".", "/") + "/" + key
}

// GsettingsGet reads a gsettings value, falling back to dconf read.
func GsettingsGet(schema, key string) (string, error) {
	if out, err := exec.Command("gsettings", "get", schema, key).Output(); err == nil {
		return strings.TrimSpace(string(out)), nil
	}
	out, err := exec.Command("dconf", "read", dconfPath(schema, key)).Output()
	if err != nil {
		return "", fmt.Errorf("gsettings/dconf get failed for %s %s: %w", schema, key, err)
	}
	return strings.TrimSpace(string(out)), nil
}

// GsettingsSet writes a gsettings value, falling back to dconf write.
func GsettingsSet(schema, key, value string) error {
	if err := exec.Command("gsettings", "set", schema, key, value).Run(); err == nil {
		return nil
	}
	return exec.Command("dconf", "write", dconfPath(schema, key), "'"+value+"'").Run()
}
