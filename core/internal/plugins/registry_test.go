package plugins

import (
	"encoding/json"
	"path/filepath"
	"testing"

	"github.com/spf13/afero"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type mockGitClient struct {
	cloneFunc      func(path string, url string) error
	pullFunc       func(path string) error
	hasUpdatesFunc func(path string) (bool, string, string, error)
}

func (m *mockGitClient) PlainClone(path string, url string) error {
	if m.cloneFunc != nil {
		return m.cloneFunc(path, url)
	}
	return nil
}

func (m *mockGitClient) Pull(path string) error {
	if m.pullFunc != nil {
		return m.pullFunc(path)
	}
	return nil
}

func (m *mockGitClient) HasUpdates(path string) (bool, string, string, error) {
	if m.hasUpdatesFunc != nil {
		return m.hasUpdatesFunc(path)
	}
	return false, "", "", nil
}

func TestNewRegistry(t *testing.T) {
	registry, err := NewRegistry()
	assert.NoError(t, err)
	assert.NotNil(t, registry)
	assert.NotEmpty(t, registry.cacheDir)
}

func TestGetCacheDir(t *testing.T) {
	cacheDir := getCacheDir()
	assert.Contains(t, cacheDir, "/tmp/dankdots-plugin-registry")
}

func setupTestRegistry(t *testing.T) (*Registry, afero.Fs, string) {
	fs := afero.NewMemMapFs()
	tmpDir := "/test-cache"
	registry := &Registry{
		fs:         fs,
		cacheDir:   tmpDir,
		registries: []RegistryConfig{{Name: "test", URL: defaultRegistryURL}},
		plugins:    []Plugin{},
		git:        &mockGitClient{},
	}
	return registry, fs, tmpDir
}

func createTestPlugin(t *testing.T, fs afero.Fs, dir string, filename string, plugin Plugin) {
	pluginsDir := filepath.Join(dir, "plugins")
	err := fs.MkdirAll(pluginsDir, 0o755)
	require.NoError(t, err)

	data, err := json.Marshal(plugin)
	require.NoError(t, err)

	err = afero.WriteFile(fs, filepath.Join(pluginsDir, filename), data, 0o644)
	require.NoError(t, err)
}

func TestLoadPlugins(t *testing.T) {
	t.Run("loads valid plugin files", func(t *testing.T) {
		registry, fs, tmpDir := setupTestRegistry(t)

		plugin1 := Plugin{
			Name:         "TestPlugin1",
			Capabilities: []string{"dankbar-widget"},
			Category:     "monitoring",
			Repo:         "https://github.com/test/plugin1",
			Author:       "Test Author",
			Description:  "Test plugin 1",
			Compositors:  []string{"niri"},
			Distro:       []string{"any"},
		}

		plugin2 := Plugin{
			Name:         "TestPlugin2",
			Capabilities: []string{"system-tray"},
			Category:     "utilities",
			Repo:         "https://github.com/test/plugin2",
			Author:       "Another Author",
			Description:  "Test plugin 2",
			Dependencies: []string{"dep1", "dep2"},
			Compositors:  []string{"hyprland", "niri"},
			Distro:       []string{"arch"},
			Screenshot:   "https://example.com/screenshot.png",
		}

		createTestPlugin(t, fs, tmpDir, "plugin1.json", plugin1)
		createTestPlugin(t, fs, tmpDir, "plugin2.json", plugin2)

		plugins, err := registry.loadPluginsFrom(tmpDir)
		assert.NoError(t, err)
		assert.Len(t, plugins, 2)

		assert.Equal(t, "TestPlugin1", plugins[0].Name)
		assert.Equal(t, "TestPlugin2", plugins[1].Name)
		assert.Equal(t, []string{"dankbar-widget"}, plugins[0].Capabilities)
		assert.Equal(t, []string{"dep1", "dep2"}, plugins[1].Dependencies)
	})

	t.Run("skips non-json files", func(t *testing.T) {
		registry, fs, tmpDir := setupTestRegistry(t)

		pluginsDir := filepath.Join(tmpDir, "plugins")
		err := fs.MkdirAll(pluginsDir, 0o755)
		require.NoError(t, err)

		err = afero.WriteFile(fs, filepath.Join(pluginsDir, "README.md"), []byte("# Test"), 0o644)
		require.NoError(t, err)

		plugin := Plugin{
			Name:         "ValidPlugin",
			Capabilities: []string{"test"},
			Category:     "test",
			Repo:         "https://github.com/test/test",
			Author:       "Test",
			Description:  "Test",
			Compositors:  []string{"niri"},
			Distro:       []string{"any"},
		}
		createTestPlugin(t, fs, tmpDir, "valid.json", plugin)

		plugins, err := registry.loadPluginsFrom(tmpDir)
		assert.NoError(t, err)
		assert.Len(t, plugins, 1)
		assert.Equal(t, "ValidPlugin", plugins[0].Name)
	})

	t.Run("skips directories", func(t *testing.T) {
		registry, fs, tmpDir := setupTestRegistry(t)

		pluginsDir := filepath.Join(tmpDir, "plugins")
		err := fs.MkdirAll(filepath.Join(pluginsDir, "subdir"), 0o755)
		require.NoError(t, err)

		plugin := Plugin{
			Name:         "ValidPlugin",
			Capabilities: []string{"test"},
			Category:     "test",
			Repo:         "https://github.com/test/test",
			Author:       "Test",
			Description:  "Test",
			Compositors:  []string{"niri"},
			Distro:       []string{"any"},
		}
		createTestPlugin(t, fs, tmpDir, "valid.json", plugin)

		plugins, err := registry.loadPluginsFrom(tmpDir)
		assert.NoError(t, err)
		assert.Len(t, plugins, 1)
	})

	t.Run("skips invalid json files", func(t *testing.T) {
		registry, fs, tmpDir := setupTestRegistry(t)

		pluginsDir := filepath.Join(tmpDir, "plugins")
		err := fs.MkdirAll(pluginsDir, 0o755)
		require.NoError(t, err)

		err = afero.WriteFile(fs, filepath.Join(pluginsDir, "invalid.json"), []byte("{invalid json}"), 0o644)
		require.NoError(t, err)

		plugin := Plugin{
			Name:         "ValidPlugin",
			Capabilities: []string{"test"},
			Category:     "test",
			Repo:         "https://github.com/test/test",
			Author:       "Test",
			Description:  "Test",
			Compositors:  []string{"niri"},
			Distro:       []string{"any"},
		}
		createTestPlugin(t, fs, tmpDir, "valid.json", plugin)

		plugins, err := registry.loadPluginsFrom(tmpDir)
		assert.NoError(t, err)
		assert.Len(t, plugins, 1)
		assert.Equal(t, "ValidPlugin", plugins[0].Name)
	})

	t.Run("returns error when plugins directory missing", func(t *testing.T) {
		registry, _, _ := setupTestRegistry(t)

		_, err := registry.loadPluginsFrom(registry.cacheDir)
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "failed to read plugins directory")
	})
}

func TestList(t *testing.T) {
	t.Run("returns cached plugins if available", func(t *testing.T) {
		registry, _, _ := setupTestRegistry(t)

		plugin := Plugin{
			Name:         "CachedPlugin",
			Capabilities: []string{"test"},
			Category:     "test",
			Repo:         "https://github.com/test/test",
			Author:       "Test",
			Description:  "Test",
			Compositors:  []string{"niri"},
			Distro:       []string{"any"},
		}

		registry.plugins = []Plugin{plugin}

		plugins, err := registry.List()
		assert.NoError(t, err)
		assert.Len(t, plugins, 1)
		assert.Equal(t, "CachedPlugin", plugins[0].Name)
	})

	t.Run("updates and loads plugins when cache is empty", func(t *testing.T) {
		registry, fs, _ := setupTestRegistry(t)

		plugin := Plugin{
			Name:         "NewPlugin",
			Capabilities: []string{"test"},
			Category:     "test",
			Repo:         "https://github.com/test/test",
			Author:       "Test",
			Description:  "Test",
			Compositors:  []string{"niri"},
			Distro:       []string{"any"},
		}

		mockGit := &mockGitClient{
			cloneFunc: func(path string, url string) error {
				createTestPlugin(t, fs, path, "plugin.json", plugin)
				return nil
			},
		}
		registry.git = mockGit

		plugins, err := registry.List()
		assert.NoError(t, err)
		assert.Len(t, plugins, 1)
		assert.Equal(t, "NewPlugin", plugins[0].Name)
	})
}

func TestUpdate(t *testing.T) {
	t.Run("clones repository when cache doesn't exist", func(t *testing.T) {
		registry, fs, tmpDir := setupTestRegistry(t)

		plugin := Plugin{
			Name:         "RepoPlugin",
			Capabilities: []string{"test"},
			Category:     "test",
			Repo:         "https://github.com/test/test",
			Author:       "Test",
			Description:  "Test",
			Compositors:  []string{"niri"},
			Distro:       []string{"any"},
		}

		cloneCalled := false
		mockGit := &mockGitClient{
			cloneFunc: func(path string, url string) error {
				cloneCalled = true
				assert.Equal(t, defaultRegistryURL, url)
				assert.Equal(t, filepath.Join(tmpDir, "test"), path)
				createTestPlugin(t, fs, path, "plugin.json", plugin)
				return nil
			},
		}
		registry.git = mockGit

		err := registry.Update()
		assert.NoError(t, err)
		assert.True(t, cloneCalled)
		assert.Len(t, registry.plugins, 1)
		assert.Equal(t, "RepoPlugin", registry.plugins[0].Name)
	})

	t.Run("pulls updates when cache exists", func(t *testing.T) {
		registry, fs, tmpDir := setupTestRegistry(t)

		plugin := Plugin{
			Name:         "UpdatedPlugin",
			Capabilities: []string{"test"},
			Category:     "test",
			Repo:         "https://github.com/test/test",
			Author:       "Test",
			Description:  "Test",
			Compositors:  []string{"niri"},
			Distro:       []string{"any"},
		}

		// pre-create per-registry subdir so Pull path is taken
		subdir := filepath.Join(tmpDir, "test")
		err := fs.MkdirAll(subdir, 0o755)
		require.NoError(t, err)

		pullCalled := false
		mockGit := &mockGitClient{
			pullFunc: func(path string) error {
				pullCalled = true
				assert.Equal(t, subdir, path)
				createTestPlugin(t, fs, path, "plugin.json", plugin)
				return nil
			},
		}
		registry.git = mockGit

		err = registry.Update()
		assert.NoError(t, err)
		assert.True(t, pullCalled)
		assert.Len(t, registry.plugins, 1)
		assert.Equal(t, "UpdatedPlugin", registry.plugins[0].Name)
	})

	t.Run("aggregates from multiple registries", func(t *testing.T) {
		registry, fs, _ := setupTestRegistry(t)

		pluginA := Plugin{ID: "a", Name: "PluginA", Compositors: []string{"niri"}, Distro: []string{"any"}}
		pluginB := Plugin{ID: "b", Name: "PluginB", Compositors: []string{"niri"}, Distro: []string{"any"}}

		registry.registries = []RegistryConfig{
			{Name: "official", URL: defaultRegistryURL},
			{Name: "louzt", URL: "https://example.com/louzt.git"},
		}

		mockGit := &mockGitClient{
			cloneFunc: func(path string, url string) error {
				var p Plugin
				switch {
				case filepath.Base(path) == "official":
					p = pluginA
				case filepath.Base(path) == "louzt":
					p = pluginB
				}
				createTestPlugin(t, fs, path, "x.json", p)
				return nil
			},
		}
		registry.git = mockGit

		err := registry.Update()
		assert.NoError(t, err)
		assert.Len(t, registry.plugins, 2)
		ids := []string{registry.plugins[0].ID, registry.plugins[1].ID}
		assert.Contains(t, ids, "a")
		assert.Contains(t, ids, "b")
	})
}

func TestParseRegistriesFromEnv(t *testing.T) {
	t.Run("defaults to official when env unset", func(t *testing.T) {
		t.Setenv("DMS_PLUGIN_REGISTRIES", "")
		cfgs := ParseRegistriesFromEnv()
		assert.Len(t, cfgs, 1)
		assert.Equal(t, "official", cfgs[0].Name)
		assert.Equal(t, defaultRegistryURL, cfgs[0].URL)
	})

	t.Run("defaults to official when env is whitespace", func(t *testing.T) {
		t.Setenv("DMS_PLUGIN_REGISTRIES", "   ")
		cfgs := ParseRegistriesFromEnv()
		assert.Len(t, cfgs, 1)
		assert.Equal(t, "official", cfgs[0].Name)
	})

	t.Run("parses comma-separated URLs", func(t *testing.T) {
		t.Setenv("DMS_PLUGIN_REGISTRIES", "https://a.git,https://b.git")
		cfgs := ParseRegistriesFromEnv()
		assert.Len(t, cfgs, 2)
		assert.Equal(t, "r0", cfgs[0].Name)
		assert.Equal(t, "https://a.git", cfgs[0].URL)
		assert.Equal(t, "r1", cfgs[1].Name)
		assert.Equal(t, "https://b.git", cfgs[1].URL)
	})

	t.Run("trims whitespace around URLs", func(t *testing.T) {
		t.Setenv("DMS_PLUGIN_REGISTRIES", " https://a.git , https://b.git ")
		cfgs := ParseRegistriesFromEnv()
		assert.Len(t, cfgs, 2)
		assert.Equal(t, "https://a.git", cfgs[0].URL)
		assert.Equal(t, "https://b.git", cfgs[1].URL)
	})

	t.Run("skips empty entries", func(t *testing.T) {
		t.Setenv("DMS_PLUGIN_REGISTRIES", ",https://a.git,,https://b.git,")
		cfgs := ParseRegistriesFromEnv()
		assert.Len(t, cfgs, 2)
	})

	t.Run("falls back to official when all entries empty", func(t *testing.T) {
		t.Setenv("DMS_PLUGIN_REGISTRIES", ", , ,")
		cfgs := ParseRegistriesFromEnv()
		assert.Len(t, cfgs, 1)
		assert.Equal(t, "official", cfgs[0].Name)
	})
}
