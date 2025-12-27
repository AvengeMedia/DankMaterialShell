package plugins

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/spf13/afero"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func setupTestManager(t *testing.T) (*Manager, afero.Fs, string) {
	fs := afero.NewMemMapFs()
	pluginsDir := "/test-plugins"
	manager := &Manager{
		fs:         fs,
		pluginsDir: pluginsDir,
		gitClient:  &mockGitClient{},
	}
	return manager, fs, pluginsDir
}

func TestNewManager(t *testing.T) {
	manager, err := NewManager()
	assert.NoError(t, err)
	assert.NotNil(t, manager)
	assert.NotEmpty(t, manager.pluginsDir)
}

func TestGetPluginsDir(t *testing.T) {
	t.Run("uses XDG_CONFIG_HOME when set", func(t *testing.T) {
		oldConfig := os.Getenv("XDG_CONFIG_HOME")
		defer func() {
			if oldConfig != "" {
				os.Setenv("XDG_CONFIG_HOME", oldConfig)
			} else {
				os.Unsetenv("XDG_CONFIG_HOME")
			}
		}()

		os.Setenv("XDG_CONFIG_HOME", "/tmp/test-config")
		dir := getPluginsDir()
		assert.Equal(t, "/tmp/test-config/DankMaterialShell/plugins", dir)
	})

	t.Run("falls back to home directory", func(t *testing.T) {
		oldConfig := os.Getenv("XDG_CONFIG_HOME")
		defer func() {
			if oldConfig != "" {
				os.Setenv("XDG_CONFIG_HOME", oldConfig)
			} else {
				os.Unsetenv("XDG_CONFIG_HOME")
			}
		}()

		os.Unsetenv("XDG_CONFIG_HOME")
		dir := getPluginsDir()
		assert.Contains(t, dir, ".config/DankMaterialShell/plugins")
	})
}

func TestIsInstalled(t *testing.T) {
	t.Run("returns true when plugin is installed", func(t *testing.T) {
		manager, fs, pluginsDir := setupTestManager(t)

		plugin := Plugin{ID: "test-plugin", Name: "TestPlugin"}
		pluginPath := filepath.Join(pluginsDir, plugin.ID)
		err := fs.MkdirAll(pluginPath, 0755)
		require.NoError(t, err)

		installed, err := manager.IsInstalled(plugin)
		assert.NoError(t, err)
		assert.True(t, installed)
	})

	t.Run("returns false when plugin is not installed", func(t *testing.T) {
		manager, _, _ := setupTestManager(t)

		plugin := Plugin{ID: "non-existent", Name: "NonExistent"}
		installed, err := manager.IsInstalled(plugin)
		assert.NoError(t, err)
		assert.False(t, installed)
	})
}

func TestInstall(t *testing.T) {
	t.Run("installs plugin successfully", func(t *testing.T) {
		manager, fs, pluginsDir := setupTestManager(t)

		plugin := Plugin{
			ID:   "test-plugin",
			Name: "TestPlugin",
			Repo: "https://github.com/test/plugin",
		}

		cloneCalled := false
		mockGit := &mockGitClient{
			cloneFunc: func(path string, url string) error {
				cloneCalled = true
				assert.Equal(t, filepath.Join(pluginsDir, plugin.ID), path)
				assert.Equal(t, plugin.Repo, url)
				return fs.MkdirAll(path, 0755)
			},
		}
		manager.gitClient = mockGit

		err := manager.Install(plugin)
		assert.NoError(t, err)
		assert.True(t, cloneCalled)

		exists, _ := afero.DirExists(fs, filepath.Join(pluginsDir, plugin.ID))
		assert.True(t, exists)
	})

	t.Run("returns error when plugin already installed", func(t *testing.T) {
		manager, fs, pluginsDir := setupTestManager(t)

		plugin := Plugin{ID: "test-plugin", Name: "TestPlugin"}
		pluginPath := filepath.Join(pluginsDir, plugin.ID)
		err := fs.MkdirAll(pluginPath, 0755)
		require.NoError(t, err)

		err = manager.Install(plugin)
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "already installed")
	})

	t.Run("installs monorepo plugin with symlink", func(t *testing.T) {
		t.Skip("Skipping symlink test as MemMapFs doesn't support symlinks")
	})
}

func TestManagerUpdate(t *testing.T) {
	t.Run("updates plugin successfully", func(t *testing.T) {
		manager, fs, pluginsDir := setupTestManager(t)

		plugin := Plugin{ID: "test-plugin", Name: "TestPlugin"}
		pluginPath := filepath.Join(pluginsDir, plugin.ID)
		err := fs.MkdirAll(pluginPath, 0755)
		require.NoError(t, err)

		pullCalled := false
		mockGit := &mockGitClient{
			pullFunc: func(path string) error {
				pullCalled = true
				assert.Equal(t, pluginPath, path)
				return nil
			},
		}
		manager.gitClient = mockGit

		err = manager.Update(plugin)
		assert.NoError(t, err)
		assert.True(t, pullCalled)
	})

	t.Run("returns error when plugin not installed", func(t *testing.T) {
		manager, _, _ := setupTestManager(t)

		plugin := Plugin{ID: "non-existent", Name: "NonExistent"}
		err := manager.Update(plugin)
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "not installed")
	})
}

func TestUninstall(t *testing.T) {
	t.Run("uninstalls plugin successfully", func(t *testing.T) {
		manager, fs, pluginsDir := setupTestManager(t)

		plugin := Plugin{ID: "test-plugin", Name: "TestPlugin"}
		pluginPath := filepath.Join(pluginsDir, plugin.ID)
		err := fs.MkdirAll(pluginPath, 0755)
		require.NoError(t, err)

		err = manager.Uninstall(plugin)
		assert.NoError(t, err)

		exists, _ := afero.DirExists(fs, pluginPath)
		assert.False(t, exists)
	})

	t.Run("returns error when plugin not installed", func(t *testing.T) {
		manager, _, _ := setupTestManager(t)

		plugin := Plugin{ID: "non-existent", Name: "NonExistent"}
		err := manager.Uninstall(plugin)
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "not installed")
	})
}

func TestListInstalled(t *testing.T) {
	t.Run("lists installed plugins", func(t *testing.T) {
		manager, fs, pluginsDir := setupTestManager(t)

		err := fs.MkdirAll(filepath.Join(pluginsDir, "Plugin1"), 0755)
		require.NoError(t, err)
		err = afero.WriteFile(fs, filepath.Join(pluginsDir, "Plugin1", "plugin.json"), []byte(`{"id":"Plugin1"}`), 0644)
		require.NoError(t, err)

		err = fs.MkdirAll(filepath.Join(pluginsDir, "Plugin2"), 0755)
		require.NoError(t, err)
		err = afero.WriteFile(fs, filepath.Join(pluginsDir, "Plugin2", "plugin.json"), []byte(`{"id":"Plugin2"}`), 0644)
		require.NoError(t, err)

		installed, err := manager.ListInstalled()
		assert.NoError(t, err)
		assert.Len(t, installed, 2)
		assert.Contains(t, installed, "Plugin1")
		assert.Contains(t, installed, "Plugin2")
	})

	t.Run("returns empty list when no plugins installed", func(t *testing.T) {
		manager, _, _ := setupTestManager(t)

		installed, err := manager.ListInstalled()
		assert.NoError(t, err)
		assert.Empty(t, installed)
	})

	t.Run("ignores files and .repos directory", func(t *testing.T) {
		manager, fs, pluginsDir := setupTestManager(t)

		err := fs.MkdirAll(pluginsDir, 0755)
		require.NoError(t, err)
		err = fs.MkdirAll(filepath.Join(pluginsDir, "Plugin1"), 0755)
		require.NoError(t, err)
		err = afero.WriteFile(fs, filepath.Join(pluginsDir, "Plugin1", "plugin.json"), []byte(`{"id":"Plugin1"}`), 0644)
		require.NoError(t, err)
		err = fs.MkdirAll(filepath.Join(pluginsDir, ".repos"), 0755)
		require.NoError(t, err)
		err = afero.WriteFile(fs, filepath.Join(pluginsDir, "README.md"), []byte("test"), 0644)
		require.NoError(t, err)

		installed, err := manager.ListInstalled()
		assert.NoError(t, err)
		assert.Len(t, installed, 1)
		assert.Equal(t, "Plugin1", installed[0])
	})
}

func TestManagerGetPluginsDir(t *testing.T) {
	manager, _, pluginsDir := setupTestManager(t)
	assert.Equal(t, pluginsDir, manager.GetPluginsDir())
}

func TestPluginManifestIsDashTab(t *testing.T) {
	t.Run("returns true for dashtab type", func(t *testing.T) {
		manifest := &pluginManifest{
			ID:   "test",
			Name: "Test",
			Type: "dashtab",
		}
		assert.True(t, manifest.IsDashTab())
	})

	t.Run("returns true for dankdash-tab capability", func(t *testing.T) {
		manifest := &pluginManifest{
			ID:           "test",
			Name:         "Test",
			Type:         "widget",
			Capabilities: []string{"dankbar-widget", "dankdash-tab"},
		}
		assert.True(t, manifest.IsDashTab())
	})

	t.Run("returns true when tabComponent is set", func(t *testing.T) {
		manifest := &pluginManifest{
			ID:           "test",
			Name:         "Test",
			Type:         "widget",
			TabComponent: "./MyTab.qml",
		}
		assert.True(t, manifest.IsDashTab())
	})

	t.Run("returns false for widget without tab", func(t *testing.T) {
		manifest := &pluginManifest{
			ID:        "test",
			Name:      "Test",
			Type:      "widget",
			Component: "./MyWidget.qml",
		}
		assert.False(t, manifest.IsDashTab())
	})

	t.Run("returns false for daemon type", func(t *testing.T) {
		manifest := &pluginManifest{
			ID:   "test",
			Name: "Test",
			Type: "daemon",
		}
		assert.False(t, manifest.IsDashTab())
	})
}

func TestPluginManifestGetTabName(t *testing.T) {
	t.Run("returns tabName when set", func(t *testing.T) {
		manifest := &pluginManifest{
			ID:      "test",
			Name:    "Test Plugin",
			TabName: "My Tab",
		}
		assert.Equal(t, "My Tab", manifest.GetTabName())
	})

	t.Run("falls back to name when tabName not set", func(t *testing.T) {
		manifest := &pluginManifest{
			ID:   "test",
			Name: "Test Plugin",
		}
		assert.Equal(t, "Test Plugin", manifest.GetTabName())
	})
}

func TestPluginManifestGetTabIcon(t *testing.T) {
	t.Run("returns tabIcon when set", func(t *testing.T) {
		manifest := &pluginManifest{
			ID:      "test",
			Name:    "Test",
			TabIcon: "dashboard",
		}
		assert.Equal(t, "dashboard", manifest.GetTabIcon())
	})

	t.Run("falls back to extension when tabIcon not set", func(t *testing.T) {
		manifest := &pluginManifest{
			ID:   "test",
			Name: "Test",
		}
		assert.Equal(t, "extension", manifest.GetTabIcon())
	})
}

func TestGetPluginManifestWithTabFields(t *testing.T) {
	t.Run("parses manifest with tab fields", func(t *testing.T) {
		manager, fs, pluginsDir := setupTestManager(t)

		pluginPath := filepath.Join(pluginsDir, "TabPlugin")
		err := fs.MkdirAll(pluginPath, 0755)
		require.NoError(t, err)

		manifestJSON := `{
			"id": "tabPlugin",
			"name": "Tab Plugin",
			"type": "widget",
			"component": "./Widget.qml",
			"tabComponent": "./Tab.qml",
			"tabName": "My Tab",
			"tabIcon": "star",
			"tabPosition": "start",
			"capabilities": ["dankbar-widget"]
		}`
		err = afero.WriteFile(fs, filepath.Join(pluginPath, "plugin.json"), []byte(manifestJSON), 0644)
		require.NoError(t, err)

		manifest := manager.getPluginManifest(pluginPath)
		require.NotNil(t, manifest)

		assert.Equal(t, "tabPlugin", manifest.ID)
		assert.Equal(t, "Tab Plugin", manifest.Name)
		assert.Equal(t, "widget", manifest.Type)
		assert.Equal(t, "./Widget.qml", manifest.Component)
		assert.Equal(t, "./Tab.qml", manifest.TabComponent)
		assert.Equal(t, "My Tab", manifest.TabName)
		assert.Equal(t, "star", manifest.TabIcon)
		assert.Equal(t, "start", manifest.TabPosition)
		assert.Contains(t, manifest.Capabilities, "dankbar-widget")

		assert.True(t, manifest.IsDashTab())
		assert.Equal(t, "My Tab", manifest.GetTabName())
		assert.Equal(t, "star", manifest.GetTabIcon())
	})

	t.Run("parses dashtab type manifest", func(t *testing.T) {
		manager, fs, pluginsDir := setupTestManager(t)

		pluginPath := filepath.Join(pluginsDir, "DashTabPlugin")
		err := fs.MkdirAll(pluginPath, 0755)
		require.NoError(t, err)

		manifestJSON := `{
			"id": "dashTabPlugin",
			"name": "DashTab Plugin",
			"type": "dashtab",
			"component": "./Tab.qml",
			"tabIcon": "event"
		}`
		err = afero.WriteFile(fs, filepath.Join(pluginPath, "plugin.json"), []byte(manifestJSON), 0644)
		require.NoError(t, err)

		manifest := manager.getPluginManifest(pluginPath)
		require.NotNil(t, manifest)

		assert.Equal(t, "dashTabPlugin", manifest.ID)
		assert.Equal(t, "dashtab", manifest.Type)
		assert.True(t, manifest.IsDashTab())
		assert.Equal(t, "DashTab Plugin", manifest.GetTabName())
		assert.Equal(t, "event", manifest.GetTabIcon())
	})
}
