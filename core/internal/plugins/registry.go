package plugins

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/go-git/go-git/v6"
	"github.com/spf13/afero"
)

const defaultRegistryURL = "https://github.com/AvengeMedia/dms-plugin-registry.git"

// envRegistriesKey is the env var consulted at registry construction time.
// Comma-separated list of git URLs. Empty/unset → defaultRegistryURL.
const envRegistriesKey = "DMS_PLUGIN_REGISTRIES"

// RegistryConfig identifies a single registry source.
type RegistryConfig struct {
	// Name is a short identifier used for the per-registry cache subdir
	// (e.g. "official", "louzt"). Defaults to "r<N>" when only URL given.
	Name string
	// URL is the git URL of the registry repository.
	URL string
}

// ParseRegistriesFromEnv reads DMS_PLUGIN_REGISTRIES (comma-separated URLs)
// and returns the resulting configs. Defaults to the official registry when
// the env var is unset, empty, or contains no valid URLs.
//
// This is the only point that decides which registries the running DMS sees.
// Callers (CLI, server, manager) construct Registry without arguments; they
// inherit the env-driven list transparently.
func ParseRegistriesFromEnv() []RegistryConfig {
	raw := strings.TrimSpace(os.Getenv(envRegistriesKey))
	if raw == "" {
		return []RegistryConfig{{Name: "official", URL: defaultRegistryURL}}
	}
	var configs []RegistryConfig
	for i, part := range strings.Split(raw, ",") {
		url := strings.TrimSpace(part)
		if url == "" {
			continue
		}
		configs = append(configs, RegistryConfig{
			Name: fmt.Sprintf("r%d", i),
			URL:  url,
		})
	}
	if len(configs) == 0 {
		return []RegistryConfig{{Name: "official", URL: defaultRegistryURL}}
	}
	return configs
}

type Plugin struct {
	ID           string   `json:"id"`
	Name         string   `json:"name"`
	Capabilities []string `json:"capabilities"`
	Category     string   `json:"category"`
	Repo         string   `json:"repo"`
	Path         string   `json:"path,omitempty"`
	Author       string   `json:"author"`
	Description  string   `json:"description"`
	Dependencies []string `json:"dependencies,omitempty"`
	Compositors  []string `json:"compositors"`
	Distro       []string `json:"distro"`
	Screenshot   string   `json:"screenshot,omitempty"`
	RequiresDMS  string   `json:"requires_dms,omitempty"`
	Featured     bool     `json:"featured,omitempty"`
}

type GitClient interface {
	PlainClone(path string, url string) error
	Pull(path string) error
	HasUpdates(path string) (hasUpdates bool, localHash string, remoteHash string, err error)
}

type realGitClient struct{}

func (g *realGitClient) PlainClone(path string, url string) error {
	_, err := git.PlainClone(path, &git.CloneOptions{
		URL:      url,
		Progress: os.Stdout,
	})
	return err
}

func (g *realGitClient) Pull(path string) error {
	repo, err := git.PlainOpen(path)
	if err != nil {
		return err
	}

	worktree, err := repo.Worktree()
	if err != nil {
		return err
	}

	err = worktree.Pull(&git.PullOptions{})
	if err != nil && err.Error() != "already up-to-date" {
		return err
	}

	return nil
}

func (g *realGitClient) HasUpdates(path string) (bool, string, string, error) {
	repo, err := git.PlainOpen(path)
	if err != nil {
		return false, "", "", err
	}

	// Fetch remote changes
	err = repo.Fetch(&git.FetchOptions{})
	if err != nil && err.Error() != "already up-to-date" {
		// If fetch fails, we can't determine if there are updates
		// Return false and the error
		return false, "", "", err
	}

	// Get the HEAD reference
	head, err := repo.Head()
	if err != nil {
		return false, "", "", err
	}

	// Get the remote HEAD reference (typically origin/HEAD or origin/main or origin/master)
	remote, err := repo.Remote("origin")
	if err != nil {
		return false, "", "", err
	}

	refs, err := remote.List(&git.ListOptions{})
	if err != nil {
		return false, "", "", err
	}

	// Find the default branch remote ref
	var remoteHead string
	for _, ref := range refs {
		if ref.Name().IsBranch() {
			// Try common branch names
			if ref.Name().Short() == "main" || ref.Name().Short() == "master" {
				remoteHead = ref.Hash().String()
				break
			}
		}
	}

	localHash := head.Hash().String()
	// If we couldn't find a remote HEAD, assume no updates
	if remoteHead == "" {
		return false, localHash, "", nil
	}

	// Compare local HEAD with remote HEAD
	return localHash != remoteHead, localHash, remoteHead, nil
}

type Registry struct {
	fs         afero.Fs
	cacheDir   string // base cache dir; per-registry subdirs live underneath
	registries []RegistryConfig
	plugins    []Plugin
	git        GitClient
}

func NewRegistry() (*Registry, error) {
	return NewRegistryWithFs(afero.NewOsFs())
}

func NewRegistryWithFs(fs afero.Fs) (*Registry, error) {
	cacheDir := getCacheDir()
	return &Registry{
		fs:         fs,
		cacheDir:   cacheDir,
		registries: ParseRegistriesFromEnv(),
		git:        &realGitClient{},
	}, nil
}

// cacheDirFor returns the per-registry cache subdir.
func (r *Registry) cacheDirFor(cfg RegistryConfig) string {
	return filepath.Join(r.cacheDir, cfg.Name)
}

func getCacheDir() string {
	return filepath.Join(os.TempDir(), "dankdots-plugin-registry")
}

// updateOne clones or pulls a single registry into its cache subdir.
// Mirrors the previous single-repo Update logic but scoped per registry.
func (r *Registry) updateOne(cfg RegistryConfig) error {
	dir := r.cacheDirFor(cfg)
	exists, err := afero.DirExists(r.fs, dir)
	if err != nil {
		return fmt.Errorf("failed to check cache directory: %w", err)
	}

	if !exists {
		if err := r.fs.MkdirAll(filepath.Dir(dir), 0o755); err != nil {
			return fmt.Errorf("failed to create cache directory: %w", err)
		}
		if err := r.git.PlainClone(dir, cfg.URL); err != nil {
			return fmt.Errorf("failed to clone registry %s: %w", cfg.Name, err)
		}
	} else {
		if err := r.git.Pull(dir); err != nil {
			if err := r.fs.RemoveAll(dir); err != nil {
				return fmt.Errorf("failed to remove corrupted registry: %w", err)
			}
			if err := r.fs.MkdirAll(filepath.Dir(dir), 0o755); err != nil {
				return fmt.Errorf("failed to create cache directory: %w", err)
			}
			if err := r.git.PlainClone(dir, cfg.URL); err != nil {
				return fmt.Errorf("failed to re-clone registry %s: %w", cfg.Name, err)
			}
		}
	}
	return nil
}

// loadPluginsFrom reads plugin JSON files from one registry's cache subdir.
func (r *Registry) loadPluginsFrom(dir string) ([]Plugin, error) {
	pluginsDir := filepath.Join(dir, "plugins")
	entries, err := afero.ReadDir(r.fs, pluginsDir)
	if err != nil {
		return nil, fmt.Errorf("failed to read plugins directory: %w", err)
	}

	var plugins []Plugin
	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".json" {
			continue
		}

		data, err := afero.ReadFile(r.fs, filepath.Join(pluginsDir, entry.Name()))
		if err != nil {
			continue
		}

		var plugin Plugin
		if err := json.Unmarshal(data, &plugin); err != nil {
			continue
		}

		if plugin.ID == "" {
			plugin.ID = strings.TrimSuffix(entry.Name(), ".json")
		}

		plugins = append(plugins, plugin)
	}
	return plugins, nil
}

func (r *Registry) Update() error {
	r.plugins = []Plugin{}
	for _, cfg := range r.registries {
		if err := r.updateOne(cfg); err != nil {
			return err
		}
		plugins, err := r.loadPluginsFrom(r.cacheDirFor(cfg))
		if err != nil {
			return err
		}
		r.plugins = append(r.plugins, plugins...)
	}
	return nil
}

func (r *Registry) List() ([]Plugin, error) {
	if len(r.plugins) == 0 {
		if err := r.Update(); err != nil {
			return nil, err
		}
	}

	return SortByFirstParty(r.plugins), nil
}

func (r *Registry) Search(query string) ([]Plugin, error) {
	allPlugins, err := r.List()
	if err != nil {
		return nil, err
	}

	if query == "" {
		return allPlugins, nil
	}

	return SortByFirstParty(FuzzySearch(query, allPlugins)), nil
}

func (r *Registry) Get(idOrName string) (*Plugin, error) {
	plugins, err := r.List()
	if err != nil {
		return nil, err
	}

	// First, try to find by ID (preferred method)
	for _, p := range plugins {
		if p.ID == idOrName {
			return &p, nil
		}
	}

	// Fallback to name for backward compatibility
	for _, p := range plugins {
		if p.Name == idOrName {
			return &p, nil
		}
	}

	return nil, fmt.Errorf("plugin not found: %s", idOrName)
}
