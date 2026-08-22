package plugins

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/registries"
	"github.com/go-git/go-git/v6"
	"github.com/go-git/go-git/v6/plumbing/object"
	"github.com/spf13/afero"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const testRegistryURL = "https://example.com/test-registry.git"

type mockGitClient struct {
	cloneFunc      func(path string, url string) error
	pullFunc       func(path string) error
	originFunc     func(path string) (string, error)
	hasUpdatesFunc func(path string) (bool, string, string, error)
	revisionFunc   func(path string) (string, error)
	checkoutFunc   func(path string, revision string) error
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

func (m *mockGitClient) OriginURL(path string) (string, error) {
	if m.originFunc != nil {
		return m.originFunc(path)
	}
	return "https://github.com/test/plugin.git", nil
}

func (m *mockGitClient) HasUpdates(path string) (bool, string, string, error) {
	if m.hasUpdatesFunc != nil {
		return m.hasUpdatesFunc(path)
	}
	return false, "", "", nil
}

func (m *mockGitClient) CurrentRevision(path string) (string, error) {
	if m.revisionFunc != nil {
		return m.revisionFunc(path)
	}
	return "0123456789abcdef0123456789abcdef01234567", nil
}

func (m *mockGitClient) CheckoutRevision(path string, revision string) error {
	if m.checkoutFunc != nil {
		return m.checkoutFunc(path, revision)
	}
	return nil
}

func TestNewRegistry(t *testing.T) {
	registry, err := NewRegistry()
	assert.NoError(t, err)
	assert.NotNil(t, registry)
	assert.NotEmpty(t, registry.cacheDir)
	require.NotEmpty(t, registry.registries)
	assert.Equal(t, registries.OfficialName, registry.registries[0].Name)
}

func TestGetCacheDir(t *testing.T) {
	cacheDir := getCacheDir()
	assert.Contains(t, cacheDir, "/tmp/dankdots-plugin-registry")
}

func TestRealGitClientRevisionCheckout(t *testing.T) {
	t.Setenv("GIT_CONFIG_GLOBAL", "")
	t.Setenv("GIT_CONFIG_SYSTEM", "")

	repoPath := t.TempDir()
	repo, err := git.PlainInit(repoPath, false)
	require.NoError(t, err)
	worktree, err := repo.Worktree()
	require.NoError(t, err)
	filePath := filepath.Join(repoPath, "value.txt")
	signature := &object.Signature{Name: "DMS Test", Email: "test@example.com", When: time.Unix(1, 0)}

	require.NoError(t, os.WriteFile(filePath, []byte("one"), 0o644))
	_, err = worktree.Add("value.txt")
	require.NoError(t, err)
	first, err := worktree.Commit("first", &git.CommitOptions{Author: signature})
	require.NoError(t, err)

	require.NoError(t, os.WriteFile(filePath, []byte("two"), 0o644))
	_, err = worktree.Add("value.txt")
	require.NoError(t, err)
	second, err := worktree.Commit("second", &git.CommitOptions{Author: signature})
	require.NoError(t, err)

	client := &realGitClient{}
	revision, err := client.CurrentRevision(repoPath)
	require.NoError(t, err)
	assert.Equal(t, second.String(), revision)
	require.NoError(t, client.CheckoutRevision(repoPath, first.String()))

	revision, err = client.CurrentRevision(repoPath)
	require.NoError(t, err)
	assert.Equal(t, first.String(), revision)
	data, err := os.ReadFile(filePath)
	require.NoError(t, err)
	assert.Equal(t, "one", string(data))
}

func setupTestRegistry(t *testing.T) (*Registry, afero.Fs, string) {
	t.Helper()
	fs := afero.NewMemMapFs()
	tmpDir := "/test-cache"
	registry := &Registry{
		fs:         fs,
		cacheDir:   tmpDir,
		registries: []registries.Source{{Name: "test", URL: testRegistryURL}},
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

	t.Run("missing plugins directory is a themes-only registry", func(t *testing.T) {
		registry, _, _ := setupTestRegistry(t)

		plugins, err := registry.loadPluginsFrom(registry.cacheDir)
		assert.NoError(t, err)
		assert.Empty(t, plugins)
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

		registry.git = &mockGitClient{
			cloneFunc: func(path string, url string) error {
				createTestPlugin(t, fs, path, "plugin.json", plugin)
				return nil
			},
		}

		plugins, err := registry.List()
		assert.NoError(t, err)
		assert.Len(t, plugins, 1)
		assert.Equal(t, "NewPlugin", plugins[0].Name)
	})

	t.Run("partial registry failure still returns loaded plugins", func(t *testing.T) {
		registry, fs, _ := setupTestRegistry(t)

		registry.registries = []registries.Source{
			{Name: "test", URL: testRegistryURL},
			{Name: "broken", URL: "https://example.com/broken.git"},
		}
		registry.git = &mockGitClient{
			cloneFunc: func(path string, url string) error {
				if url != testRegistryURL {
					return errors.New("clone failed")
				}
				createTestPlugin(t, fs, path, "x.json", Plugin{ID: "x", Name: "X"})
				return nil
			},
		}

		plugins, err := registry.List()
		assert.NoError(t, err)
		assert.Len(t, plugins, 1)
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
		registry.git = &mockGitClient{
			cloneFunc: func(path string, url string) error {
				cloneCalled = true
				assert.Equal(t, testRegistryURL, url)
				assert.Equal(t, filepath.Join(tmpDir, "test"), path)
				createTestPlugin(t, fs, path, "plugin.json", plugin)
				return nil
			},
		}

		err := registry.Update()
		assert.NoError(t, err)
		assert.True(t, cloneCalled)
		assert.Len(t, registry.plugins, 1)
		assert.Equal(t, "RepoPlugin", registry.plugins[0].Name)
	})

	t.Run("pulls when cache exists with matching origin", func(t *testing.T) {
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

		subdir := filepath.Join(tmpDir, "test")
		require.NoError(t, fs.MkdirAll(subdir, 0o755))

		pullCalled := false
		registry.git = &mockGitClient{
			originFunc: func(path string) (string, error) {
				return testRegistryURL, nil
			},
			pullFunc: func(path string) error {
				pullCalled = true
				assert.Equal(t, subdir, path)
				createTestPlugin(t, fs, path, "plugin.json", plugin)
				return nil
			},
		}

		err := registry.Update()
		assert.NoError(t, err)
		assert.True(t, pullCalled)
		assert.Len(t, registry.plugins, 1)
		assert.Equal(t, "UpdatedPlugin", registry.plugins[0].Name)
	})

	t.Run("re-clones when cached origin does not match configured URL", func(t *testing.T) {
		registry, fs, tmpDir := setupTestRegistry(t)

		subdir := filepath.Join(tmpDir, "test")
		require.NoError(t, fs.MkdirAll(subdir, 0o755))
		require.NoError(t, afero.WriteFile(fs, filepath.Join(subdir, "stale"), []byte("x"), 0o644))

		pullCalled := false
		cloneCalled := false
		registry.git = &mockGitClient{
			originFunc: func(path string) (string, error) {
				return "https://example.com/old-origin.git", nil
			},
			pullFunc: func(path string) error {
				pullCalled = true
				return nil
			},
			cloneFunc: func(path string, url string) error {
				cloneCalled = true
				assert.Equal(t, testRegistryURL, url)
				createTestPlugin(t, fs, path, "x.json", Plugin{ID: "x", Name: "X"})
				return nil
			},
		}

		err := registry.Update()
		assert.NoError(t, err)
		assert.False(t, pullCalled, "stale origin must not be pulled")
		assert.True(t, cloneCalled)
		exists, _ := afero.Exists(fs, filepath.Join(subdir, "stale"))
		assert.False(t, exists, "stale cache contents removed before re-clone")
	})

	t.Run("re-clones when pull fails", func(t *testing.T) {
		registry, fs, tmpDir := setupTestRegistry(t)

		subdir := filepath.Join(tmpDir, "test")
		require.NoError(t, fs.MkdirAll(subdir, 0o755))

		cloneCalled := false
		registry.git = &mockGitClient{
			originFunc: func(path string) (string, error) {
				return testRegistryURL, nil
			},
			pullFunc: func(path string) error {
				return errors.New("shallow clone corruption")
			},
			cloneFunc: func(path string, url string) error {
				cloneCalled = true
				createTestPlugin(t, fs, path, "x.json", Plugin{ID: "x", Name: "X"})
				return nil
			},
		}

		err := registry.Update()
		assert.NoError(t, err)
		assert.True(t, cloneCalled)
	})

	t.Run("aggregates from multiple registries", func(t *testing.T) {
		registry, fs, _ := setupTestRegistry(t)

		pluginA := Plugin{ID: "a", Name: "PluginA", Compositors: []string{"niri"}, Distro: []string{"any"}}
		pluginB := Plugin{ID: "b", Name: "PluginB", Compositors: []string{"niri"}, Distro: []string{"any"}}

		registry.registries = []registries.Source{
			{Name: "official", URL: testRegistryURL},
			{Name: "louzt", URL: "https://example.com/louzt.git"},
		}

		registry.git = &mockGitClient{
			cloneFunc: func(path string, url string) error {
				switch filepath.Base(path) {
				case "official":
					createTestPlugin(t, fs, path, "x.json", pluginA)
				case "louzt":
					createTestPlugin(t, fs, path, "x.json", pluginB)
				}
				return nil
			},
		}

		err := registry.Update()
		assert.NoError(t, err)
		assert.Len(t, registry.plugins, 2)
		assert.Equal(t, "a", registry.plugins[0].ID)
		assert.Equal(t, "b", registry.plugins[1].ID)
	})

	t.Run("dedupes by ID with declaration order priority", func(t *testing.T) {
		registry, fs, _ := setupTestRegistry(t)

		pluginOfficial := Plugin{ID: "weather", Name: "OfficialWeather", Compositors: []string{"niri"}, Distro: []string{"any"}}
		pluginLouzt := Plugin{ID: "weather", Name: "LouztWeather", Compositors: []string{"niri"}, Distro: []string{"any"}}

		registry.registries = []registries.Source{
			{Name: "official", URL: testRegistryURL},
			{Name: "louzt", URL: "https://example.com/louzt.git"},
		}

		registry.git = &mockGitClient{
			cloneFunc: func(path string, url string) error {
				switch filepath.Base(path) {
				case "official":
					createTestPlugin(t, fs, path, "x.json", pluginOfficial)
				case "louzt":
					createTestPlugin(t, fs, path, "x.json", pluginLouzt)
				}
				return nil
			},
		}

		err := registry.Update()
		assert.NoError(t, err)
		assert.Len(t, registry.plugins, 1)
		assert.Equal(t, "OfficialWeather", registry.plugins[0].Name)
	})

	t.Run("continues past failing registry and reports it", func(t *testing.T) {
		registry, fs, _ := setupTestRegistry(t)

		registry.registries = []registries.Source{
			{Name: "broken", URL: "https://example.com/broken.git"},
			{Name: "test", URL: testRegistryURL},
		}
		registry.git = &mockGitClient{
			cloneFunc: func(path string, url string) error {
				if url != testRegistryURL {
					return errors.New("network unreachable")
				}
				createTestPlugin(t, fs, path, "x.json", Plugin{ID: "x", Name: "X"})
				return nil
			},
		}

		err := registry.Update()
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "registry broken")
		assert.Len(t, registry.plugins, 1, "healthy registry still loads")
	})

	t.Run("removes legacy single-clone cache at base", func(t *testing.T) {
		registry, fs, tmpDir := setupTestRegistry(t)

		require.NoError(t, fs.MkdirAll(filepath.Join(tmpDir, ".git"), 0o755))
		createTestPlugin(t, fs, tmpDir, "legacy.json", Plugin{ID: "legacy", Name: "Legacy"})

		registry.git = &mockGitClient{
			cloneFunc: func(path string, url string) error {
				createTestPlugin(t, fs, path, "x.json", Plugin{ID: "x", Name: "X"})
				return nil
			},
		}

		err := registry.Update()
		assert.NoError(t, err)
		exists, _ := afero.DirExists(fs, filepath.Join(tmpDir, ".git"))
		assert.False(t, exists, "legacy clone removed")
		assert.Len(t, registry.plugins, 1)
		assert.Equal(t, "x", registry.plugins[0].ID)
	})
}
