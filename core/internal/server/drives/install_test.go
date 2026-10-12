package drives

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestInstallCommand(t *testing.T) {
	cases := map[string]string{
		"ID=cachyos":                     "sudo pacman -S smartmontools",
		`ID="fedora"`:                    "sudo dnf install smartmontools",
		"NAME=Ubuntu\nID=ubuntu\n":       "sudo apt install smartmontools",
		"ID=debian":                      "sudo apt install smartmontools",
		"ID=opensuse-tumbleweed":         "sudo zypper install smartmontools",
		"ID=void":                        "sudo xbps-install smartmontools",
		"ID=gentoo":                      "sudo emerge sys-apps/smartmontools",
		"ID=nixos":                       "",
		"ID=somethingelse\nID_LIKE=arch": "",
	}
	for osRelease, want := range cases {
		root := t.TempDir()
		require.NoError(t, os.MkdirAll(filepath.Join(root, "etc"), 0o755))
		require.NoError(t, os.WriteFile(filepath.Join(root, "etc", "os-release"), []byte(osRelease), 0o644))
		assert.Equal(t, want, installCommand(root), osRelease)
	}
	assert.Equal(t, "", installCommand(t.TempDir()), "missing os-release")
}

func TestInstallCommandOstree(t *testing.T) {
	root := t.TempDir()
	require.NoError(t, os.MkdirAll(filepath.Join(root, "etc"), 0o755))
	require.NoError(t, os.MkdirAll(filepath.Join(root, "run"), 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(root, "etc", "os-release"), []byte("ID=fedora"), 0o644))
	require.NoError(t, os.WriteFile(filepath.Join(root, "run", "ostree-booted"), nil, 0o644))
	assert.Equal(t, "", installCommand(root))
}
