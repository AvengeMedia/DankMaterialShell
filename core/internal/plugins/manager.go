package plugins

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/afero"
)

type Manager struct {
	fs         afero.Fs
	pluginsDir string
	gitClient  GitClient
}

func NewManager() (*Manager, error) {
	return NewManagerWithFs(afero.NewOsFs())
}

func NewManagerWithFs(fs afero.Fs) (*Manager, error) {
	pluginsDir := getPluginsDir()
	return &Manager{
		fs:         fs,
		pluginsDir: pluginsDir,
		gitClient:  &realGitClient{},
	}, nil
}

func getPluginsDir() string {
	configHome := os.Getenv("XDG_CONFIG_HOME")
	if configHome == "" {
		homeDir, err := os.UserHomeDir()
		if err != nil {
			return filepath.Join(os.TempDir(), "DankMaterialShell", "plugins")
		}
		configHome = filepath.Join(homeDir, ".config")
	}
	return filepath.Join(configHome, "DankMaterialShell", "plugins")
}

func (m *Manager) IsInstalled(plugin Plugin) (bool, error) {
	pluginPath := filepath.Join(m.pluginsDir, plugin.ID)
	exists, err := afero.DirExists(m.fs, pluginPath)
	if err != nil {
		return false, err
	}
	if exists {
		return true, nil
	}

	systemPluginPath := filepath.Join("/etc/xdg/quickshell/dms-plugins", plugin.ID)
	systemExists, err := afero.DirExists(m.fs, systemPluginPath)
	if err != nil {
		return false, err
	}
	return systemExists, nil
}

func (m *Manager) Install(plugin Plugin) error {
	pluginPath := filepath.Join(m.pluginsDir, plugin.ID)

	exists, err := afero.DirExists(m.fs, pluginPath)
	if err != nil {
		return fmt.Errorf("failed to check if plugin exists: %w", err)
	}

	if exists {
		return fmt.Errorf("plugin already installed: %s", plugin.Name)
	}

	if err := m.fs.MkdirAll(m.pluginsDir, 0755); err != nil {
		return fmt.Errorf("failed to create plugins directory: %w", err)
	}

	reposDir := filepath.Join(m.pluginsDir, ".repos")
	if err := m.fs.MkdirAll(reposDir, 0755); err != nil {
		return fmt.Errorf("failed to create repos directory: %w", err)
	}

	if plugin.Path != "" {
		repoName := m.getRepoName(plugin.Repo)
		repoPath := filepath.Join(reposDir, repoName)

		repoExists, err := afero.DirExists(m.fs, repoPath)
		if err != nil {
			return fmt.Errorf("failed to check if repo exists: %w", err)
		}

		if !repoExists {
			if err := m.gitClient.PlainClone(repoPath, plugin.Repo); err != nil {
				m.fs.RemoveAll(repoPath) //nolint:errcheck
				return fmt.Errorf("failed to clone repository: %w", err)
			}
		} else {
			// Pull latest changes if repo already exists
			if err := m.gitClient.Pull(repoPath); err != nil {
				// If pull fails (e.g., corrupted shallow clone), delete and re-clone
				if err := m.fs.RemoveAll(repoPath); err != nil {
					return fmt.Errorf("failed to remove corrupted repository: %w", err)
				}

				if err := m.gitClient.PlainClone(repoPath, plugin.Repo); err != nil {
					return fmt.Errorf("failed to re-clone repository: %w", err)
				}
			}
		}

		sourcePath := filepath.Join(repoPath, plugin.Path)
		sourceExists, err := afero.DirExists(m.fs, sourcePath)
		if err != nil {
			return fmt.Errorf("failed to check plugin path: %w", err)
		}
		if !sourceExists {
			return fmt.Errorf("plugin path does not exist in repository: %s", plugin.Path)
		}

		if err := m.createSymlink(sourcePath, pluginPath); err != nil {
			return fmt.Errorf("failed to create symlink: %w", err)
		}

		metaPath := pluginPath + ".meta"
		metaContent := fmt.Sprintf("repo=%s\npath=%s\nrepodir=%s", plugin.Repo, plugin.Path, repoName)
		if err := afero.WriteFile(m.fs, metaPath, []byte(metaContent), 0644); err != nil {
			return fmt.Errorf("failed to write metadata: %w", err)
		}
	} else {
		if err := m.gitClient.PlainClone(pluginPath, plugin.Repo); err != nil {
			m.fs.RemoveAll(pluginPath) //nolint:errcheck
			return fmt.Errorf("failed to clone plugin: %w", err)
		}
	}

	return nil
}

func (m *Manager) getRepoName(repoURL string) string {
	hash := sha256.Sum256([]byte(repoURL))
	return hex.EncodeToString(hash[:])[:16]
}

func (m *Manager) createSymlink(source, dest string) error {
	if symlinkFs, ok := m.fs.(afero.Symlinker); ok {
		return symlinkFs.SymlinkIfPossible(source, dest)
	}
	return os.Symlink(source, dest)
}

func (m *Manager) Update(plugin Plugin) error {
	pluginPath := filepath.Join(m.pluginsDir, plugin.ID)

	exists, err := afero.DirExists(m.fs, pluginPath)
	if err != nil {
		return fmt.Errorf("failed to check if plugin exists: %w", err)
	}

	if !exists {
		systemPluginPath := filepath.Join("/etc/xdg/quickshell/dms-plugins", plugin.ID)
		systemExists, err := afero.DirExists(m.fs, systemPluginPath)
		if err != nil {
			return fmt.Errorf("failed to check if plugin exists: %w", err)
		}
		if systemExists {
			return fmt.Errorf("cannot update system plugin: %s", plugin.Name)
		}
		return fmt.Errorf("plugin not installed: %s", plugin.Name)
	}

	metaPath := pluginPath + ".meta"
	metaExists, err := afero.Exists(m.fs, metaPath)
	if err != nil {
		return fmt.Errorf("failed to check metadata: %w", err)
	}

	if metaExists {
		reposDir := filepath.Join(m.pluginsDir, ".repos")
		repoName := m.getRepoName(plugin.Repo)
		repoPath := filepath.Join(reposDir, repoName)

		// Try to pull, if it fails (e.g., shallow clone corruption), delete and re-clone
		if err := m.gitClient.Pull(repoPath); err != nil {
			// Repository is likely corrupted or has issues, delete and re-clone
			if err := m.fs.RemoveAll(repoPath); err != nil {
				return fmt.Errorf("failed to remove corrupted repository: %w", err)
			}

			if err := m.gitClient.PlainClone(repoPath, plugin.Repo); err != nil {
				return fmt.Errorf("failed to re-clone repository: %w", err)
			}
		}
	} else {
		// Try to pull, if it fails, delete and re-clone
		if err := m.gitClient.Pull(pluginPath); err != nil {
			if err := m.fs.RemoveAll(pluginPath); err != nil {
				return fmt.Errorf("failed to remove corrupted plugin: %w", err)
			}

			if err := m.gitClient.PlainClone(pluginPath, plugin.Repo); err != nil {
				return fmt.Errorf("failed to re-clone plugin: %w", err)
			}
		}
	}

	return nil
}

func (m *Manager) Uninstall(plugin Plugin) error {
	pluginPath := filepath.Join(m.pluginsDir, plugin.ID)

	exists, err := afero.DirExists(m.fs, pluginPath)
	if err != nil {
		return fmt.Errorf("failed to check if plugin exists: %w", err)
	}

	if !exists {
		systemPluginPath := filepath.Join("/etc/xdg/quickshell/dms-plugins", plugin.ID)
		systemExists, err := afero.DirExists(m.fs, systemPluginPath)
		if err != nil {
			return fmt.Errorf("failed to check if plugin exists: %w", err)
		}
		if systemExists {
			return fmt.Errorf("cannot uninstall system plugin: %s", plugin.Name)
		}
		return fmt.Errorf("plugin not installed: %s", plugin.Name)
	}

	metaPath := pluginPath + ".meta"
	metaExists, err := afero.Exists(m.fs, metaPath)
	if err != nil {
		return fmt.Errorf("failed to check metadata: %w", err)
	}

	if metaExists {
		reposDir := filepath.Join(m.pluginsDir, ".repos")
		repoName := m.getRepoName(plugin.Repo)
		repoPath := filepath.Join(reposDir, repoName)

		shouldCleanup, err := m.shouldCleanupRepo(repoPath, plugin.Repo, plugin.ID)
		if err != nil {
			return fmt.Errorf("failed to check repo cleanup: %w", err)
		}

		if err := m.fs.Remove(pluginPath); err != nil {
			return fmt.Errorf("failed to remove symlink: %w", err)
		}

		if err := m.fs.Remove(metaPath); err != nil {
			return fmt.Errorf("failed to remove metadata: %w", err)
		}

		if shouldCleanup {
			if err := m.fs.RemoveAll(repoPath); err != nil {
				return fmt.Errorf("failed to cleanup repository: %w", err)
			}
		}
	} else {
		if err := m.fs.RemoveAll(pluginPath); err != nil {
			return fmt.Errorf("failed to remove plugin: %w", err)
		}
	}

	return nil
}

func (m *Manager) shouldCleanupRepo(repoPath, repoURL, excludePlugin string) (bool, error) {
	installed, err := m.ListInstalled()
	if err != nil {
		return false, err
	}

	registry, err := NewRegistry()
	if err != nil {
		return false, err
	}

	allPlugins, err := registry.List()
	if err != nil {
		return false, err
	}

	for _, id := range installed {
		if id == excludePlugin {
			continue
		}

		for _, p := range allPlugins {
			if p.ID == id && p.Repo == repoURL && p.Path != "" {
				return false, nil
			}
		}
	}

	return true, nil
}

func (m *Manager) ListInstalled() ([]string, error) {
	installedMap := make(map[string]bool)

	exists, err := afero.DirExists(m.fs, m.pluginsDir)
	if err != nil {
		return nil, err
	}

	if exists {
		entries, err := afero.ReadDir(m.fs, m.pluginsDir)
		if err != nil {
			return nil, fmt.Errorf("failed to read plugins directory: %w", err)
		}

		for _, entry := range entries {
			name := entry.Name()
			if name == ".repos" || strings.HasSuffix(name, ".meta") {
				continue
			}

			fullPath := filepath.Join(m.pluginsDir, name)
			isPlugin := false

			if entry.IsDir() {
				isPlugin = true
			} else if entry.Mode()&os.ModeSymlink != 0 {
				isPlugin = true
			} else {
				info, err := m.fs.Stat(fullPath)
				if err == nil && info.IsDir() {
					isPlugin = true
				}
			}

			if isPlugin {
				// Read plugin.json to get the actual plugin ID
				pluginID := m.getPluginID(fullPath)
				if pluginID != "" {
					installedMap[pluginID] = true
				}
			}
		}
	}

	systemPluginsDir := "/etc/xdg/quickshell/dms-plugins"
	systemExists, err := afero.DirExists(m.fs, systemPluginsDir)
	if err == nil && systemExists {
		entries, err := afero.ReadDir(m.fs, systemPluginsDir)
		if err == nil {
			for _, entry := range entries {
				if entry.IsDir() {
					fullPath := filepath.Join(systemPluginsDir, entry.Name())
					// Read plugin.json to get the actual plugin ID
					pluginID := m.getPluginID(fullPath)
					if pluginID != "" {
						installedMap[pluginID] = true
					}
				}
			}
		}
	}

	var installed []string
	for name := range installedMap {
		installed = append(installed, name)
	}

	return installed, nil
}

// getPluginID reads the plugin.json file and returns the plugin ID
func (m *Manager) getPluginID(pluginPath string) string {
	manifestPath := filepath.Join(pluginPath, "plugin.json")
	data, err := afero.ReadFile(m.fs, manifestPath)
	if err != nil {
		return ""
	}

	var manifest struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(data, &manifest); err != nil {
		return ""
	}

	return manifest.ID
}

func (m *Manager) GetPluginsDir() string {
	return m.pluginsDir
}

func (m *Manager) HasUpdates(pluginID string, plugin Plugin) (bool, error) {
	pluginPath := filepath.Join(m.pluginsDir, pluginID)

	exists, err := afero.DirExists(m.fs, pluginPath)
	if err != nil {
		return false, fmt.Errorf("failed to check if plugin exists: %w", err)
	}

	if !exists {
		systemPluginPath := filepath.Join("/etc/xdg/quickshell/dms-plugins", pluginID)
		systemExists, err := afero.DirExists(m.fs, systemPluginPath)
		if err != nil {
			return false, fmt.Errorf("failed to check system plugin: %w", err)
		}
		if systemExists {
			return false, nil
		}
		return false, fmt.Errorf("plugin not installed: %s", pluginID)
	}

	// Check if there's a .meta file (plugin installed from a monorepo)
	metaPath := pluginPath + ".meta"
	metaExists, err := afero.Exists(m.fs, metaPath)
	if err != nil {
		return false, fmt.Errorf("failed to check metadata: %w", err)
	}

	if metaExists {
		// Plugin is from a monorepo, check the repo directory
		reposDir := filepath.Join(m.pluginsDir, ".repos")
		repoName := m.getRepoName(plugin.Repo)
		repoPath := filepath.Join(reposDir, repoName)

		return m.gitClient.HasUpdates(repoPath)
	}

	// Plugin is a standalone repo
	return m.gitClient.HasUpdates(pluginPath)
}
