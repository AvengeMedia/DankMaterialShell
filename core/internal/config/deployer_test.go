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

	tests := []struct {
		name            string
		newConfig       string
		existingConfig  string
		wantError       bool
		wantContains    []string
		wantNotContains []string
	}{
		{
			name: "no existing monitors",
			newConfig: `# ==================
# MONITOR CONFIG
# ==================
# monitor = eDP-2, 2560x1600@239.998993, 2560x0, 1, vrr, 1

# ==================
# ENVIRONMENT VARS
# ==================
env = XDG_CURRENT_DESKTOP,niri`,
			existingConfig: `# Some other config
input {
    kb_layout = us
}`,
			wantError:    false,
			wantContains: []string{"MONITOR CONFIG", "ENVIRONMENT VARS"},
		},
		{
			name: "merge single monitor",
			newConfig: `# ==================
# MONITOR CONFIG
# ==================
# monitor = eDP-2, 2560x1600@239.998993, 2560x0, 1, vrr, 1

# ==================
# ENVIRONMENT VARS
# ==================`,
			existingConfig: `# My config
monitor = DP-1, 1920x1080@144, 0x0, 1
input {
    kb_layout = us
}`,
			wantError: false,
			wantContains: []string{
				"MONITOR CONFIG",
				"monitor = DP-1, 1920x1080@144, 0x0, 1",
				"Monitors from existing configuration",
			},
			wantNotContains: []string{
				"monitor = eDP-2", // Example monitor should be removed
			},
		},
		{
			name: "merge multiple monitors",
			newConfig: `# ==================
# MONITOR CONFIG
# ==================
# monitor = eDP-2, 2560x1600@239.998993, 2560x0, 1, vrr, 1

# ==================
# ENVIRONMENT VARS
# ==================`,
			existingConfig: `monitor = DP-1, 1920x1080@144, 0x0, 1
# monitor = HDMI-A-1, 1920x1080@60, 1920x0, 1
monitor = eDP-1, 2560x1440@165, auto, 1.25`,
			wantError: false,
			wantContains: []string{
				"monitor = DP-1",
				"# monitor = HDMI-A-1", // Commented monitor preserved
				"monitor = eDP-1",
				"Monitors from existing configuration",
			},
			wantNotContains: []string{
				"monitor = eDP-2", // Example monitor should be removed
			},
		},
		{
			name: "preserve commented monitors",
			newConfig: `# ==================
# MONITOR CONFIG
# ==================
# monitor = eDP-2, 2560x1600@239.998993, 2560x0, 1, vrr, 1

# ==================`,
			existingConfig: `# monitor = DP-1, 1920x1080@144, 0x0, 1
# monitor = HDMI-A-1, 1920x1080@60, 1920x0, 1`,
			wantError: false,
			wantContains: []string{
				"# monitor = DP-1",
				"# monitor = HDMI-A-1",
				"Monitors from existing configuration",
			},
		},
		{
			name: "no monitor config section",
			newConfig: `# Some config without monitor section
input {
    kb_layout = us
}`,
			existingConfig: `monitor = DP-1, 1920x1080@144, 0x0, 1`,
			wantError:      true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tmpDir := t.TempDir()
			result, err := cd.mergeHyprlandMonitorSections(tt.newConfig, tt.existingConfig, tmpDir)

			if tt.wantError {
				assert.Error(t, err)
				return
			}

			require.NoError(t, err)

			for _, want := range tt.wantContains {
				assert.Contains(t, result, want, "merged config should contain: %s", want)
			}

			for _, notWant := range tt.wantNotContains {
				assert.NotContains(t, result, notWant, "merged config should NOT contain: %s", notWant)
			}
		})
	}
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
		result, err := cd.deployHyprlandConfig(deps.TerminalGhostty, true)
		require.NoError(t, err)

		assert.Equal(t, "Hyprland", result.ConfigType)
		assert.True(t, result.Deployed)
		assert.Empty(t, result.BackupPath)
		assert.FileExists(t, result.Path)

		content, err := os.ReadFile(result.Path)
		require.NoError(t, err)
		assert.Contains(t, string(content), "# MONITOR CONFIG")
		assert.Contains(t, string(content), "source = ./dms/binds.conf")
		assert.Contains(t, string(content), "exec-once = ")
	})

	t.Run("deploy hyprland config with existing monitors", func(t *testing.T) {
		existingContent := `# My existing Hyprland config
monitor = DP-1, 1920x1080@144, 0x0, 1
monitor = HDMI-A-1, 3840x2160@60, 1920x0, 1.5

general {
    gaps_in = 10
}
`
		hyprPath := filepath.Join(tempDir, ".config", "hypr", "hyprland.conf")
		err := os.MkdirAll(filepath.Dir(hyprPath), 0o755)
		require.NoError(t, err)
		err = os.WriteFile(hyprPath, []byte(existingContent), 0o644)
		require.NoError(t, err)

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

		newContent, err := os.ReadFile(result.Path)
		require.NoError(t, err)
		assert.Contains(t, string(newContent), "monitor = DP-1, 1920x1080@144")
		assert.Contains(t, string(newContent), "monitor = HDMI-A-1, 3840x2160@60")
		assert.Contains(t, string(newContent), "source = ./dms/binds.conf")
		assert.NotContains(t, string(newContent), "monitor = eDP-2")
	})
}

func TestNiriConfigStructure(t *testing.T) {
	assert.Contains(t, NiriConfig, "input {")
	assert.Contains(t, NiriConfig, "layout {")

	assert.Contains(t, NiriBindsConfig, "binds {")
	assert.Contains(t, NiriBindsConfig, `spawn "{{TERMINAL_COMMAND}}"`)
}

func TestHyprlandConfigStructure(t *testing.T) {
	assert.Contains(t, HyprlandConfig, "# MONITOR CONFIG")
	assert.Contains(t, HyprlandConfig, "# STARTUP APPS")
	assert.Contains(t, HyprlandConfig, "# INPUT CONFIG")
	assert.Contains(t, HyprlandConfig, "source = ./dms/binds.conf")
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
}
