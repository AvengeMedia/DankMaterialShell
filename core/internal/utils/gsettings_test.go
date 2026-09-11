package utils

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type fakeTool struct {
	name   string
	stdout string
	exit   int
}

func fakeTools(t *testing.T, tools ...fakeTool) string {
	t.Helper()
	binDir := t.TempDir()
	logPath := filepath.Join(binDir, "calls.log")
	for _, tool := range tools {
		script := fmt.Sprintf("#!/bin/sh\necho \"%s $*\" >> %q\nprintf '%%s' %q\nexit %d\n", tool.name, logPath, tool.stdout, tool.exit)
		require.NoError(t, os.WriteFile(filepath.Join(binDir, tool.name), []byte(script), 0o755))
	}
	t.Setenv("PATH", binDir)
	return logPath
}

func toolCalls(t *testing.T, logPath string) string {
	t.Helper()
	data, err := os.ReadFile(logPath)
	if os.IsNotExist(err) {
		return ""
	}
	require.NoError(t, err)
	return string(data)
}

func TestGsettingsSetWritesDconf(t *testing.T) {
	t.Setenv("GSETTINGS_BACKEND", "")
	logPath := fakeTools(t,
		fakeTool{name: "dconf"},
		fakeTool{name: "gsettings"},
	)

	require.NoError(t, GsettingsSet("org.gnome.desktop.interface", "gtk-theme", "adw-gtk3"))

	calls := toolCalls(t, logPath)
	assert.Contains(t, calls, "dconf write /org/gnome/desktop/interface/gtk-theme 'adw-gtk3'")
	assert.NotContains(t, calls, "gsettings")
}

func TestGsettingsSetFallsBackWhenDconfFails(t *testing.T) {
	t.Setenv("GSETTINGS_BACKEND", "")
	logPath := fakeTools(t,
		fakeTool{name: "dconf", exit: 1},
		fakeTool{name: "gsettings"},
	)

	require.NoError(t, GsettingsSet("org.gnome.desktop.interface", "gtk-theme", "adw-gtk3"))

	assert.Contains(t, toolCalls(t, logPath), "gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3")
}

func TestGsettingsSetHonorsBackendOverride(t *testing.T) {
	t.Setenv("GSETTINGS_BACKEND", "keyfile")
	logPath := fakeTools(t,
		fakeTool{name: "dconf"},
		fakeTool{name: "gsettings"},
	)

	require.NoError(t, GsettingsSet("org.gnome.desktop.interface", "gtk-theme", "adw-gtk3"))

	calls := toolCalls(t, logPath)
	assert.Contains(t, calls, "gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3")
	assert.NotContains(t, calls, "dconf write")
}

func TestGsettingsGetReadsDconf(t *testing.T) {
	t.Setenv("GSETTINGS_BACKEND", "")
	fakeTools(t,
		fakeTool{name: "dconf", stdout: "'adw-gtk3-dark'"},
		fakeTool{name: "gsettings", stdout: "'Adwaita'"},
	)

	value, err := GsettingsGet("org.gnome.desktop.interface", "gtk-theme")

	require.NoError(t, err)
	assert.Equal(t, "'adw-gtk3-dark'", value)
}

func TestGsettingsGetFallsBackWhenDconfUnset(t *testing.T) {
	t.Setenv("GSETTINGS_BACKEND", "")
	fakeTools(t,
		fakeTool{name: "dconf"},
		fakeTool{name: "gsettings", stdout: "'Adwaita'"},
	)

	value, err := GsettingsGet("org.gnome.desktop.interface", "gtk-theme")

	require.NoError(t, err)
	assert.Equal(t, "'Adwaita'", value)
}

func TestGsettingsGetFailsWhenNoToolWorks(t *testing.T) {
	t.Setenv("GSETTINGS_BACKEND", "")
	fakeTools(t,
		fakeTool{name: "dconf", exit: 1},
		fakeTool{name: "gsettings", exit: 1},
	)

	_, err := GsettingsGet("org.gnome.desktop.interface", "gtk-theme")

	require.ErrorContains(t, err, "gtk-theme")
}
