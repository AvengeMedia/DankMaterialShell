package config

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/deps"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestCleanupStrayHyprlandConfFile(t *testing.T) {
	if os.Getenv("HYPRLAND_INSTANCE_SIGNATURE") == "" {
		t.Setenv("HYPRLAND_INSTANCE_SIGNATURE", "test-signature")
	}

	t.Run("leaves conf alone when no hyprland.lua present", func(t *testing.T) {
		td := t.TempDir()
		t.Setenv("HOME", td)
		configDir := filepath.Join(td, ".config", "hypr")
		dmsDir := filepath.Join(configDir, "dms")
		require.NoError(t, os.MkdirAll(dmsDir, 0o755))
		confPath := filepath.Join(configDir, "hyprland.conf")
		dmsConfPath := filepath.Join(dmsDir, "colors.conf")
		require.NoError(t, os.WriteFile(confPath, []byte("# legacy user config\n"), 0o644))
		require.NoError(t, os.WriteFile(dmsConfPath, []byte("$primary = rgba(d0bcffFF)\n"), 0o644))

		CleanupStrayHyprlandConfFile(nil)

		assert.FileExists(t, confPath, "must not touch hyprland.conf when user has not migrated")
		assert.FileExists(t, dmsConfPath, "must not touch dms/*.conf when user has not migrated")
		assert.NoDirExists(t, filepath.Join(configDir, hyprlandBackupDirName))
	})

	t.Run("moves stray conf into backup when hyprland.lua exists", func(t *testing.T) {
		td := t.TempDir()
		t.Setenv("HOME", td)
		configDir := filepath.Join(td, ".config", "hypr")
		dmsDir := filepath.Join(configDir, "dms")
		require.NoError(t, os.MkdirAll(dmsDir, 0o755))
		luaPath := filepath.Join(configDir, "hyprland.lua")
		require.NoError(t, os.WriteFile(luaPath, []byte("-- dms managed\n"), 0o644))
		confPath := filepath.Join(configDir, "hyprland.conf")
		dmsConfPath := filepath.Join(dmsDir, "colors.conf")
		require.NoError(t, os.WriteFile(confPath, []byte("# autogen\n"), 0o644))
		require.NoError(t, os.WriteFile(dmsConfPath, []byte("$primary = rgba(d0bcffFF)\n"), 0o644))

		CleanupStrayHyprlandConfFile(nil)

		assert.NoFileExists(t, confPath)
		assert.NoFileExists(t, dmsConfPath)
		assert.FileExists(t, luaPath)
		entries, err := os.ReadDir(filepath.Join(configDir, hyprlandBackupDirName))
		require.NoError(t, err)
		require.Len(t, entries, 1)
		assert.FileExists(t, filepath.Join(configDir, hyprlandBackupDirName, entries[0].Name(), "hyprland.conf"))
		assert.FileExists(t, filepath.Join(configDir, hyprlandBackupDirName, entries[0].Name(), "dms", "colors.conf"))
	})
}

func TestMergeNiriOutputSections(t *testing.T) {
	cd := &ConfigDeployer{}

	tests := []struct {
		name           string
		newConfig      string
		existingConfig string
		wantError      bool
		wantContains   []string
	}{
		{
			name: "no existing outputs",
			newConfig: `input {
    keyboard {
        xkb {
        }
    }
}
layout {
    gaps 5
}`,
			existingConfig: `input {
    keyboard {
        xkb {
        }
    }
}
layout {
    gaps 10
}`,
			wantError:    false,
			wantContains: []string{"gaps 5"}, // Should keep new config
		},
		{
			name: "merge single output",
			newConfig: `input {
    keyboard {
        xkb {
        }
    }
}
/-output "eDP-2" {
    mode "2560x1600@239.998993"
    position x=2560 y=0
}
layout {
    gaps 5
}`,
			existingConfig: `input {
    keyboard {
        xkb {
        }
    }
}
output "eDP-1" {
    mode "1920x1080@60.000000"
    position x=0 y=0
    scale 1.0
}
layout {
    gaps 10
}`,
			wantError: false,
			wantContains: []string{
				"gaps 5",                              // New config preserved
				`output "eDP-1"`,                      // Existing output merged
				"1920x1080@60.000000",                 // Existing output details
				"Outputs from existing configuration", // Comment added
			},
		},
		{
			name: "merge multiple outputs",
			newConfig: `input {
    keyboard {
        xkb {
        }
    }
}
/-output "eDP-2" {
    mode "2560x1600@239.998993"
    position x=2560 y=0
}
layout {
    gaps 5
}`,
			existingConfig: `input {
    keyboard {
        xkb {
        }
    }
}
output "eDP-1" {
    mode "1920x1080@60.000000"
    position x=0 y=0
    scale 1.0
}
/-output "HDMI-1" {
    mode "1920x1080@60.000000"
    position x=1920 y=0
}
layout {
    gaps 10
}`,
			wantError: false,
			wantContains: []string{
				"gaps 5",              // New config preserved
				`output "eDP-1"`,      // First existing output
				`/-output "HDMI-1"`,   // Second existing output (commented)
				"1920x1080@60.000000", // Output details
			},
		},
		{
			name: "merge commented outputs",
			newConfig: `input {
    keyboard {
        xkb {
        }
    }
}
/-output "eDP-2" {
    mode "2560x1600@239.998993"
    position x=2560 y=0
}
layout {
    gaps 5
}`,
			existingConfig: `input {
    keyboard {
        xkb {
        }
    }
}
/-output "eDP-1" {
    mode "1920x1080@60.000000"
    position x=0 y=0
    scale 1.0
}
layout {
    gaps 10
}`,
			wantError: false,
			wantContains: []string{
				"gaps 5",              // New config preserved
				`/-output "eDP-1"`,    // Commented output preserved
				"1920x1080@60.000000", // Output details
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tmpDir := t.TempDir()
			result, err := cd.mergeNiriOutputSections(tt.newConfig, tt.existingConfig, tmpDir)

			if tt.wantError {
				assert.Error(t, err)
				return
			}

			require.NoError(t, err)

			for _, want := range tt.wantContains {
				assert.Contains(t, result, want, "merged config should contain: %s", want)
			}

			assert.NotContains(t, result, `/-output "eDP-2"`, "example output should be removed")
		})
	}
}

func TestConfigDeploymentFlow(t *testing.T) {
	tempDir, err := os.MkdirTemp("", "dankinstall-test")
	require.NoError(t, err)
	defer os.RemoveAll(tempDir)

	originalHome := os.Getenv("HOME")
	os.Setenv("HOME", tempDir)
	defer os.Setenv("HOME", originalHome)

	logChan := make(chan string, 100)
	cd := NewConfigDeployer(logChan)

	t.Run("deploy ghostty config to empty directory", func(t *testing.T) {
		results, err := cd.deployGhosttyConfig()
		require.NoError(t, err)
		require.Len(t, results, 2)

		mainResult := results[0]
		assert.Equal(t, "Ghostty", mainResult.ConfigType)
		assert.True(t, mainResult.Deployed)
		assert.Empty(t, mainResult.BackupPath)
		assert.FileExists(t, mainResult.Path)

		content, err := os.ReadFile(mainResult.Path)
		require.NoError(t, err)
		assert.Contains(t, string(content), "window-decoration = false")

		colorResult := results[1]
		assert.Equal(t, "Ghostty Colors", colorResult.ConfigType)
		assert.True(t, colorResult.Deployed)
		assert.FileExists(t, colorResult.Path)

		colorContent, err := os.ReadFile(colorResult.Path)
		require.NoError(t, err)
		assert.Contains(t, string(colorContent), "background = #101418")
	})

	t.Run("deploy ghostty config with existing file", func(t *testing.T) {
		existingContent := "# Old config\nfont-size = 14\n"
		ghosttyPath := getGhosttyPath()
		err := os.MkdirAll(filepath.Dir(ghosttyPath), 0o755)
		require.NoError(t, err)
		err = os.WriteFile(ghosttyPath, []byte(existingContent), 0o644)
		require.NoError(t, err)

		results, err := cd.deployGhosttyConfig()
		require.NoError(t, err)
		require.Len(t, results, 2)

		mainResult := results[0]
		assert.Equal(t, "Ghostty", mainResult.ConfigType)
		assert.True(t, mainResult.Deployed)
		assert.NotEmpty(t, mainResult.BackupPath)
		assert.FileExists(t, mainResult.Path)
		assert.FileExists(t, mainResult.BackupPath)

		backupContent, err := os.ReadFile(mainResult.BackupPath)
		require.NoError(t, err)
		assert.Equal(t, existingContent, string(backupContent))

		newContent, err := os.ReadFile(mainResult.Path)
		require.NoError(t, err)
		assert.NotContains(t, string(newContent), "# Old config")

		colorResult := results[1]
		assert.Equal(t, "Ghostty Colors", colorResult.ConfigType)
		assert.True(t, colorResult.Deployed)
		assert.FileExists(t, colorResult.Path)
	})
}

func getGhosttyPath() string {
	return filepath.Join(os.Getenv("HOME"), ".config", "ghostty", "config")
}

func TestMergeHyprlandMonitorSections(t *testing.T) {
	cd := &ConfigDeployer{}

	t.Run("no monitors in existing", func(t *testing.T) {
		tmp := t.TempDir()
		out, err := cd.mergeHyprlandMonitorSections(`hl.config({})`, `input { kb_layout = us }`, tmp)
		require.NoError(t, err)
		assert.Equal(t, `hl.config({})`, out)
		_, e := os.Stat(filepath.Join(tmp, "outputs.lua"))
		assert.True(t, os.IsNotExist(e))
	})

	t.Run("writes outputs lua from hyprlang monitors", func(t *testing.T) {
		tmp := t.TempDir()
		existing := `monitor = DP-1, 1920x1080@144, 0x0, 1
# monitor = HDMI-A-1, 1920x1080@60, 1920x0, 1
monitor = eDP-1, 2560x1440@165, auto, 1.25`
		out, err := cd.mergeHyprlandMonitorSections(`return`, existing, tmp)
		require.NoError(t, err)
		assert.Equal(t, `return`, out)
		b, err := os.ReadFile(filepath.Join(tmp, "outputs.lua"))
		require.NoError(t, err)
		s := string(b)
		assert.Contains(t, s, "hl.monitor")
		assert.Contains(t, s, "DP-1")
		assert.Contains(t, s, "HDMI-A-1")
		assert.Contains(t, s, "eDP-1")
		assert.Contains(t, s, "preferred") // fallback rule at end
	})

	t.Run("skips when outputs lua already exists", func(t *testing.T) {
		tmp := t.TempDir()
		path := filepath.Join(tmp, "outputs.lua")
		require.NoError(t, os.WriteFile(path, []byte("-- keep\n"), 0o644))
		_, err := cd.mergeHyprlandMonitorSections(`x`, `monitor = DP-1, 1920x1080@144, 0x0, 1`, tmp)
		require.NoError(t, err)
		b, err := os.ReadFile(path)
		require.NoError(t, err)
		assert.Equal(t, "-- keep\n", string(b))
	})
}

func TestHyprlangMonitorLineToLuaPreservesOptions(t *testing.T) {
	got, err := hyprlangMonitorLineToLua(`monitor = DP-1, 1920x1080@144, 0x0, 1, transform, 1, vrr, 2, bitdepth, 10, cm, hdr, sdrbrightness, 1.2, sdrsaturation, 0.98`)
	require.NoError(t, err)

	assert.Contains(t, got, `output = "DP-1"`)
	assert.Contains(t, got, `transform = 1`)
	assert.Contains(t, got, `vrr = 2`)
	assert.Contains(t, got, `bitdepth = 10`)
	assert.Contains(t, got, `cm = "hdr"`)
	assert.Contains(t, got, `sdrbrightness = 1.2`)
	assert.Contains(t, got, `sdrsaturation = 0.98`)
}

func TestHyprlandConfigDeployment(t *testing.T) {
	tempDir, err := os.MkdirTemp("", "dankinstall-hyprland-test")
	require.NoError(t, err)
	defer os.RemoveAll(tempDir)

	originalHome := os.Getenv("HOME")
	os.Setenv("HOME", tempDir)
	defer os.Setenv("HOME", originalHome)

	logChan := make(chan string, 100)
	cd := NewConfigDeployer(logChan)

	t.Run("deploy hyprland config to empty directory", func(t *testing.T) {
		td, err := os.MkdirTemp("", "dankinstall-hyprland-empty")
		require.NoError(t, err)
		defer os.RemoveAll(td)
		os.Setenv("HOME", td)
		result, err := cd.deployHyprlandConfig(deps.TerminalGhostty, true)
		require.NoError(t, err)

		assert.Equal(t, "Hyprland", result.ConfigType)
		assert.True(t, result.Deployed)
		assert.Empty(t, result.BackupPath)
		assert.FileExists(t, result.Path)

		content, err := os.ReadFile(result.Path)
		require.NoError(t, err)
		assert.Contains(t, string(content), `require("dms.binds")`)
		assert.Contains(t, string(content), "DMS_STARTUP_BEGIN")
		assert.Contains(t, string(content), "hl.config(")
	})

	t.Run("deploy hyprland config with existing monitors", func(t *testing.T) {
		td, err := os.MkdirTemp("", "dankinstall-hyprland-merge")
		require.NoError(t, err)
		defer os.RemoveAll(td)
		os.Setenv("HOME", td)
		existingContent := `# My existing Hyprland config
monitor = DP-1, 1920x1080@144, 0x0, 1
monitor = HDMI-A-1, 3840x2160@60, 1920x0, 1.5

general {
    gaps_in = 10
}
`
		hyprPath := filepath.Join(td, ".config", "hypr", "hyprland.conf")
		err = os.MkdirAll(filepath.Dir(hyprPath), 0o755)
		require.NoError(t, err)
		err = os.WriteFile(hyprPath, []byte(existingContent), 0o644)
		require.NoError(t, err)
		dmsDir := filepath.Join(td, ".config", "hypr", "dms")
		require.NoError(t, os.MkdirAll(dmsDir, 0o755))
		require.NoError(t, os.WriteFile(filepath.Join(dmsDir, "binds.conf"), []byte("bind = SUPER, T, exec, foot\n"), 0o644))
		require.NoError(t, os.WriteFile(filepath.Join(dmsDir, "colors.conf"), []byte("$primary = rgba(d0bcffFF)\n"), 0o644))
		require.NoError(t, os.WriteFile(filepath.Join(dmsDir, "cursor.conf"), []byte("env = XCURSOR_SIZE,24\n"), 0o644))
		require.NoError(t, os.WriteFile(filepath.Join(filepath.Dir(hyprPath), "hyprland.conf.backup.old"), []byte("old backup\n"), 0o644))
		require.NoError(t, os.WriteFile(filepath.Join(dmsDir, "binds.conf.backup.old"), []byte("old dms backup\n"), 0o644))

		result, err := cd.deployHyprlandConfig(deps.TerminalKitty, true)
		require.NoError(t, err)

		assert.Equal(t, "Hyprland", result.ConfigType)
		assert.True(t, result.Deployed)
		assert.NotEmpty(t, result.BackupPath)
		assert.FileExists(t, result.Path)
		assert.FileExists(t, result.BackupPath)

		backupContent, err := os.ReadFile(result.BackupPath)
		require.NoError(t, err)
		assert.Equal(t, existingContent, string(backupContent))
		assert.Contains(t, result.BackupPath, hyprlandBackupDirName)
		assert.NoFileExists(t, hyprPath)
		assert.FileExists(t, filepath.Join(filepath.Dir(result.BackupPath), "dms", "binds.conf"))
		assert.FileExists(t, filepath.Join(filepath.Dir(result.BackupPath), "dms", "colors.conf"))
		assert.FileExists(t, filepath.Join(filepath.Dir(result.BackupPath), "dms", "cursor.conf"))
		assert.FileExists(t, filepath.Join(filepath.Dir(result.BackupPath), "hyprland.conf.backup.old"))
		assert.FileExists(t, filepath.Join(filepath.Dir(result.BackupPath), "dms", "binds.conf.backup.old"))
		assert.NoFileExists(t, filepath.Join(dmsDir, "binds.conf"))
		assert.NoFileExists(t, filepath.Join(dmsDir, "colors.conf"))
		assert.NoFileExists(t, filepath.Join(dmsDir, "cursor.conf"))
		assert.NoFileExists(t, filepath.Join(filepath.Dir(hyprPath), "hyprland.conf.backup.old"))
		assert.NoFileExists(t, filepath.Join(dmsDir, "binds.conf.backup.old"))

		newContent, err := os.ReadFile(result.Path)
		require.NoError(t, err)
		assert.Contains(t, string(newContent), `require("dms.binds")`)

		outputsPath := filepath.Join(td, ".config", "hypr", "dms", "outputs.lua")
		outBytes, err := os.ReadFile(outputsPath)
		require.NoError(t, err)
		outs := string(outBytes)
		assert.Contains(t, outs, `hl.monitor`)
		assert.Contains(t, outs, "DP-1")
		assert.Contains(t, outs, "HDMI-A-1")
	})

	t.Run("deploy hyprland config removes root legacy symlink when lua exists", func(t *testing.T) {
		td, err := os.MkdirTemp("", "dankinstall-hyprland-lua-conf-symlink")
		require.NoError(t, err)
		defer os.RemoveAll(td)
		os.Setenv("HOME", td)

		configDir := filepath.Join(td, ".config", "hypr")
		require.NoError(t, os.MkdirAll(configDir, 0o755))
		luaPath := filepath.Join(configDir, "hyprland.lua")
		confPath := filepath.Join(configDir, "hyprland.conf")
		require.NoError(t, os.WriteFile(luaPath, []byte(`require("dms.binds")`+"\n"), 0o644))
		require.NoError(t, os.Symlink(filepath.Join(configDir, "missing-legacy.conf"), confPath))

		result, err := cd.deployHyprlandConfig(deps.TerminalKitty, true)
		require.NoError(t, err)

		assert.Equal(t, luaPath, result.Path)
		_, err = os.Lstat(confPath)
		assert.True(t, os.IsNotExist(err), "root hyprland.conf symlink should be moved out of the live config directory")
		_, err = os.Lstat(filepath.Join(filepath.Dir(result.BackupPath), "hyprland.conf"))
		assert.NoError(t, err)
	})

	t.Run("deploy hyprland config refreshes managed binds but preserves user binds", func(t *testing.T) {
		td, err := os.MkdirTemp("", "dankinstall-hyprland-refresh-binds")
		require.NoError(t, err)
		defer os.RemoveAll(td)
		os.Setenv("HOME", td)

		dmsDir := filepath.Join(td, ".config", "hypr", "dms")
		require.NoError(t, os.MkdirAll(dmsDir, 0o755))
		require.NoError(t, os.WriteFile(filepath.Join(dmsDir, "binds.lua"), []byte("-- stale managed binds\n"), 0o644))
		userBinds := "-- custom user binds\n"
		require.NoError(t, os.WriteFile(filepath.Join(dmsDir, "binds-user.lua"), []byte(userBinds), 0o644))

		_, err = cd.deployHyprlandConfig(deps.TerminalKitty, true)
		require.NoError(t, err)

		managed, err := os.ReadFile(filepath.Join(dmsDir, "binds.lua"))
		require.NoError(t, err)
		assert.Contains(t, string(managed), `hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))`)
		assert.Contains(t, string(managed), `hl.bind("SUPER + minus", hl.dsp.window.resize({ x = -100, y = 0, relative = true }), { repeating = true })`)

		user, err := os.ReadFile(filepath.Join(dmsDir, "binds-user.lua"))
		require.NoError(t, err)
		assert.Equal(t, userBinds, string(user))
	})
}

func TestNiriConfigStructure(t *testing.T) {
	assert.Contains(t, NiriConfig, "input {")
	assert.Contains(t, NiriConfig, "layout {")

	assert.Contains(t, NiriBindsConfig, "binds {")
	assert.Contains(t, NiriBindsConfig, `spawn "{{TERMINAL_COMMAND}}"`)
}

func TestHyprlandConfigStructure(t *testing.T) {
	assert.Contains(t, HyprlandLuaConfig, `require("dms.binds")`)
	assert.Contains(t, HyprlandLuaConfig, "DMS_STARTUP_BEGIN")
	assert.Contains(t, HyprlandLuaConfig, "hl.config(")
	assert.Contains(t, HyprlandLuaConfig, "input =")
}

func TestMangoConfigStructure(t *testing.T) {
	assert.Contains(t, MangoConfig, "exec-once=dms run")
	assert.NotContains(t, MangoConfig, "exec_once=dms run")
	assert.Contains(t, MangoConfig, "source=./dms/binds.conf")
	assert.Contains(t, MangoBindsConfig, "bind=SUPER,H,focusdir,left")
	assert.Contains(t, MangoBindsConfig, "bind=SUPER,J,focusdir,down")
	assert.Contains(t, MangoBindsConfig, "bind=SUPER,K,focusdir,up")
	assert.Contains(t, MangoBindsConfig, "bind=SUPER,L,focusdir,right")
	assert.Contains(t, MangoBindsConfig, "gesturebind=none,right,3,viewtoleft_have_client")
	assert.Contains(t, MangoBindsConfig, "gesturebind=none,left,3,viewtoright_have_client")
}

func TestGhosttyConfigStructure(t *testing.T) {
	assert.Contains(t, GhosttyConfig, "window-decoration = false")
	assert.Contains(t, GhosttyConfig, "background-opacity = 1.0")
	assert.Contains(t, GhosttyConfig, "theme = dankcolors")
}

func TestGhosttyColorConfigStructure(t *testing.T) {
	assert.Contains(t, GhosttyColorConfig, "background = #101418")
	assert.Contains(t, GhosttyColorConfig, "foreground = #e0e2e8")
	assert.Contains(t, GhosttyColorConfig, "cursor-color = #9dcbfb")
	assert.Contains(t, GhosttyColorConfig, "palette = 0=#101418")
	assert.Contains(t, GhosttyColorConfig, "palette = 15=#ffffff")
}

func TestKittyConfigStructure(t *testing.T) {
	assert.Contains(t, KittyConfig, "font_size 12.0")
	assert.Contains(t, KittyConfig, "window_padding_width 12")
	assert.Contains(t, KittyConfig, "background_opacity 1.0")
	assert.Contains(t, KittyConfig, "include dank-tabs.conf")
	assert.Contains(t, KittyConfig, "include dank-theme.conf")
}

func TestKittyThemeConfigStructure(t *testing.T) {
	assert.Contains(t, KittyThemeConfig, "foreground            #e0e2e8")
	assert.Contains(t, KittyThemeConfig, "background            #101418")
	assert.Contains(t, KittyThemeConfig, "cursor #e0e2e8")
	assert.Contains(t, KittyThemeConfig, "color0   #101418")
	assert.Contains(t, KittyThemeConfig, "color15   #ffffff")
}

func TestKittyTabsConfigStructure(t *testing.T) {
	assert.Contains(t, KittyTabsConfig, "tab_bar_style           powerline")
	assert.Contains(t, KittyTabsConfig, "tab_powerline_style     slanted")
	assert.Contains(t, KittyTabsConfig, "active_tab_background           #124a73")
	assert.Contains(t, KittyTabsConfig, "inactive_tab_background         #101418")
}

func TestAlacrittyConfigStructure(t *testing.T) {
	assert.Contains(t, AlacrittyConfig, "[general]")
	assert.Contains(t, AlacrittyConfig, "~/.config/alacritty/dank-theme.toml")
	assert.Contains(t, AlacrittyConfig, "[window]")
	assert.Contains(t, AlacrittyConfig, "decorations = \"None\"")
	assert.Contains(t, AlacrittyConfig, "padding = { x = 12, y = 12 }")
	assert.Contains(t, AlacrittyConfig, "[cursor]")
	assert.Contains(t, AlacrittyConfig, "[keyboard]")
}

func TestAlacrittyThemeConfigStructure(t *testing.T) {
	assert.Contains(t, AlacrittyThemeConfig, "[colors.primary]")
	assert.Contains(t, AlacrittyThemeConfig, "background = '#101418'")
	assert.Contains(t, AlacrittyThemeConfig, "foreground = '#e0e2e8'")
	assert.Contains(t, AlacrittyThemeConfig, "[colors.cursor]")
	assert.Contains(t, AlacrittyThemeConfig, "cursor = '#9dcbfb'")
	assert.Contains(t, AlacrittyThemeConfig, "[colors.normal]")
	assert.Contains(t, AlacrittyThemeConfig, "[colors.bright]")
}

func TestKittyConfigDeployment(t *testing.T) {
	tempDir, err := os.MkdirTemp("", "dankinstall-kitty-test")
	require.NoError(t, err)
	defer os.RemoveAll(tempDir)

	originalHome := os.Getenv("HOME")
	os.Setenv("HOME", tempDir)
	defer os.Setenv("HOME", originalHome)

	logChan := make(chan string, 100)
	cd := NewConfigDeployer(logChan)

	t.Run("deploy kitty config to empty directory", func(t *testing.T) {
		results, err := cd.deployKittyConfig()
		require.NoError(t, err)
		require.Len(t, results, 3)

		mainResult := results[0]
		assert.Equal(t, "Kitty", mainResult.ConfigType)
		assert.True(t, mainResult.Deployed)
		assert.FileExists(t, mainResult.Path)

		content, err := os.ReadFile(mainResult.Path)
		require.NoError(t, err)
		assert.Contains(t, string(content), "include dank-theme.conf")

		themeResult := results[1]
		assert.Equal(t, "Kitty Theme", themeResult.ConfigType)
		assert.True(t, themeResult.Deployed)
		assert.FileExists(t, themeResult.Path)

		tabsResult := results[2]
		assert.Equal(t, "Kitty Tabs", tabsResult.ConfigType)
		assert.True(t, tabsResult.Deployed)
		assert.FileExists(t, tabsResult.Path)
	})
}

func TestAlacrittyConfigDeployment(t *testing.T) {
	tempDir, err := os.MkdirTemp("", "dankinstall-alacritty-test")
	require.NoError(t, err)
	defer os.RemoveAll(tempDir)

	originalHome := os.Getenv("HOME")
	os.Setenv("HOME", tempDir)
	defer os.Setenv("HOME", originalHome)

	logChan := make(chan string, 100)
	cd := NewConfigDeployer(logChan)

	t.Run("deploy alacritty config to empty directory", func(t *testing.T) {
		results, err := cd.deployAlacrittyConfig()
		require.NoError(t, err)
		require.Len(t, results, 2)

		mainResult := results[0]
		assert.Equal(t, "Alacritty", mainResult.ConfigType)
		assert.True(t, mainResult.Deployed)
		assert.FileExists(t, mainResult.Path)

		content, err := os.ReadFile(mainResult.Path)
		require.NoError(t, err)
		assert.Contains(t, string(content), "~/.config/alacritty/dank-theme.toml")
		assert.Contains(t, string(content), "[window]")

		themeResult := results[1]
		assert.Equal(t, "Alacritty Theme", themeResult.ConfigType)
		assert.True(t, themeResult.Deployed)
		assert.FileExists(t, themeResult.Path)

		themeContent, err := os.ReadFile(themeResult.Path)
		require.NoError(t, err)
		assert.Contains(t, string(themeContent), "[colors.primary]")
		assert.Contains(t, string(themeContent), "background = '#101418'")
	})

	t.Run("deploy alacritty config with existing file", func(t *testing.T) {
		existingContent := "# Old alacritty config\n[window]\nopacity = 0.9\n"
		alacrittyPath := filepath.Join(tempDir, ".config", "alacritty", "alacritty.toml")
		err := os.MkdirAll(filepath.Dir(alacrittyPath), 0o755)
		require.NoError(t, err)
		err = os.WriteFile(alacrittyPath, []byte(existingContent), 0o644)
		require.NoError(t, err)

		results, err := cd.deployAlacrittyConfig()
		require.NoError(t, err)
		require.Len(t, results, 2)

		mainResult := results[0]
		assert.True(t, mainResult.Deployed)
		assert.NotEmpty(t, mainResult.BackupPath)
		assert.FileExists(t, mainResult.BackupPath)

		backupContent, err := os.ReadFile(mainResult.BackupPath)
		require.NoError(t, err)
		assert.Equal(t, existingContent, string(backupContent))

		newContent, err := os.ReadFile(mainResult.Path)
		require.NoError(t, err)
		assert.NotContains(t, string(newContent), "# Old alacritty config")
		assert.Contains(t, string(newContent), "decorations = \"None\"")
	})
}

func TestShouldReplaceConfigDeployIfMissing(t *testing.T) {
	allFalse := map[string]bool{
		"Niri":      false,
		"Hyprland":  false,
		"Ghostty":   false,
		"Kitty":     false,
		"Alacritty": false,
	}

	t.Run("replaceConfigs nil deploys config", func(t *testing.T) {
		tempDir, err := os.MkdirTemp("", "dankinstall-replace-nil-test")
		require.NoError(t, err)
		defer os.RemoveAll(tempDir)

		originalHome := os.Getenv("HOME")
		os.Setenv("HOME", tempDir)
		defer os.Setenv("HOME", originalHome)

		logChan := make(chan string, 100)
		cd := NewConfigDeployer(logChan)

		results, err := cd.DeployConfigurationsSelectiveWithReinstalls(
			context.Background(),
			deps.WindowManagerNiri,
			deps.TerminalGhostty,
			nil, // installedDeps
			nil, // replaceConfigs
			nil, // reinstallItems
		)
		require.NoError(t, err)

		// With replaceConfigs=nil, all configs should be deployed
		hasDeployed := false
		for _, r := range results {
			if r.Deployed {
				hasDeployed = true
				break
			}
		}
		assert.True(t, hasDeployed, "expected at least one config to be deployed when replaceConfigs is nil")
	})

	t.Run("replaceConfigs all false and config missing deploys config", func(t *testing.T) {
		tempDir, err := os.MkdirTemp("", "dankinstall-replace-missing-test")
		require.NoError(t, err)
		defer os.RemoveAll(tempDir)

		originalHome := os.Getenv("HOME")
		os.Setenv("HOME", tempDir)
		defer os.Setenv("HOME", originalHome)

		logChan := make(chan string, 100)
		cd := NewConfigDeployer(logChan)

		results, err := cd.DeployConfigurationsSelectiveWithReinstalls(
			context.Background(),
			deps.WindowManagerNiri,
			deps.TerminalGhostty,
			nil,      // installedDeps
			allFalse, // replaceConfigs — all false
			nil,      // reinstallItems
		)
		require.NoError(t, err)

		// Config files don't exist on disk, so they should still be deployed
		hasDeployed := false
		for _, r := range results {
			if r.Deployed {
				hasDeployed = true
				break
			}
		}
		assert.True(t, hasDeployed, "expected configs to be deployed when files are missing, even with replaceConfigs all false")
	})

	t.Run("replaceConfigs false and config exists skips config", func(t *testing.T) {
		tempDir, err := os.MkdirTemp("", "dankinstall-replace-exists-test")
		require.NoError(t, err)
		defer os.RemoveAll(tempDir)

		originalHome := os.Getenv("HOME")
		os.Setenv("HOME", tempDir)
		defer os.Setenv("HOME", originalHome)

		// Create the Ghostty primary config file so shouldReplaceConfig returns false
		ghosttyPath := filepath.Join(tempDir, ".config", "ghostty", "config")
		err = os.MkdirAll(filepath.Dir(ghosttyPath), 0o755)
		require.NoError(t, err)
		err = os.WriteFile(ghosttyPath, []byte("# existing ghostty config\n"), 0o644)
		require.NoError(t, err)

		// Also create the Niri primary config file
		niriPath := filepath.Join(tempDir, ".config", "niri", "config.kdl")
		err = os.MkdirAll(filepath.Dir(niriPath), 0o755)
		require.NoError(t, err)
		err = os.WriteFile(niriPath, []byte("// existing niri config\n"), 0o644)
		require.NoError(t, err)

		logChan := make(chan string, 100)
		cd := NewConfigDeployer(logChan)

		results, err := cd.DeployConfigurationsSelectiveWithReinstalls(
			context.Background(),
			deps.WindowManagerNiri,
			deps.TerminalGhostty,
			nil,      // installedDeps
			allFalse, // replaceConfigs — all false
			nil,      // reinstallItems
		)
		require.NoError(t, err)

		// Both Niri and Ghostty config files exist, so with all false they should be skipped
		for _, r := range results {
			assert.Fail(t, "expected no configs to be deployed", "got deployed config: %s", r.ConfigType)
		}
	})

	t.Run("replaceConfigs true and config exists deploys config", func(t *testing.T) {
		tempDir, err := os.MkdirTemp("", "dankinstall-replace-true-test")
		require.NoError(t, err)
		defer os.RemoveAll(tempDir)

		originalHome := os.Getenv("HOME")
		os.Setenv("HOME", tempDir)
		defer os.Setenv("HOME", originalHome)

		// Create the Ghostty primary config file
		ghosttyPath := filepath.Join(tempDir, ".config", "ghostty", "config")
		err = os.MkdirAll(filepath.Dir(ghosttyPath), 0o755)
		require.NoError(t, err)
		err = os.WriteFile(ghosttyPath, []byte("# existing ghostty config\n"), 0o644)
		require.NoError(t, err)

		logChan := make(chan string, 100)
		cd := NewConfigDeployer(logChan)

		replaceConfigs := map[string]bool{
			"Niri":      false,
			"Hyprland":  false,
			"Ghostty":   true, // explicitly true
			"Kitty":     false,
			"Alacritty": false,
		}

		results, err := cd.DeployConfigurationsSelectiveWithReinstalls(
			context.Background(),
			deps.WindowManagerNiri,
			deps.TerminalGhostty,
			nil,            // installedDeps
			replaceConfigs, // Ghostty=true, rest=false
			nil,            // reinstallItems
		)
		require.NoError(t, err)

		// Ghostty should be deployed because replaceConfigs["Ghostty"]=true
		foundGhostty := false
		for _, r := range results {
			if r.ConfigType == "Ghostty" && r.Deployed {
				foundGhostty = true
			}
		}
		assert.True(t, foundGhostty, "expected Ghostty config to be deployed when replaceConfigs is true")
	})

	t.Run("hyprland legacy config exists skips when replace false", func(t *testing.T) {
		tempDir, err := os.MkdirTemp("", "dankinstall-hyprland-legacy-skip-test")
		require.NoError(t, err)
		defer os.RemoveAll(tempDir)

		originalHome := os.Getenv("HOME")
		os.Setenv("HOME", tempDir)
		defer os.Setenv("HOME", originalHome)

		hyprConf := filepath.Join(tempDir, ".config", "hypr", "hyprland.conf")
		require.NoError(t, os.MkdirAll(filepath.Dir(hyprConf), 0o755))
		require.NoError(t, os.WriteFile(hyprConf, []byte("monitor = , preferred, auto, 1\n"), 0o644))

		logChan := make(chan string, 100)
		cd := NewConfigDeployer(logChan)
		results, err := cd.deployConfigurationsInternal(
			context.Background(),
			deps.WindowManagerHyprland,
			deps.TerminalGhostty,
			nil,
			allFalse,
			nil,
			true,
		)
		require.NoError(t, err)

		for _, r := range results {
			if r.ConfigType == "Hyprland" && r.Deployed {
				t.Fatalf("expected Hyprland deployment to be skipped when legacy config exists and replace=false")
			}
		}
	})
}
