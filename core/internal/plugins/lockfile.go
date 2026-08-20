package plugins

import (
	"encoding/json"
	"fmt"
	"maps"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/spf13/afero"
)

const pluginLockfileVersion = 1

var gitCommitPattern = regexp.MustCompile(`^[0-9a-fA-F]{40}$`)

var scpLikeRepoPattern = regexp.MustCompile(`^[^@:/\s]+@[^@:/\s]+:\S+$`)

type PluginLockfile struct {
	LockfileVersion int                     `json:"lockfileVersion"`
	Plugins         map[string]LockedPlugin `json:"plugins"`
}

type LockedPlugin struct {
	Repo   string `json:"repo"`
	Path   string `json:"path,omitempty"`
	Commit string `json:"commit"`
}

type LockStore struct {
	fs   afero.Fs
	path string
}

func NewLockStore(fs afero.Fs, path string) *LockStore {
	return &LockStore{fs: fs, path: path}
}

func NewPluginLockfile() PluginLockfile {
	return PluginLockfile{
		LockfileVersion: pluginLockfileVersion,
		Plugins:         make(map[string]LockedPlugin),
	}
}

func (s *LockStore) Path() string {
	return s.path
}

func (s *LockStore) Exists() (bool, error) {
	return afero.Exists(s.fs, s.path)
}

func (s *LockStore) Load() (PluginLockfile, error) {
	data, err := afero.ReadFile(s.fs, s.path)
	if err != nil {
		if os.IsNotExist(err) {
			return NewPluginLockfile(), nil
		}
		return PluginLockfile{}, fmt.Errorf("failed to read plugin lockfile: %w", err)
	}

	return ParsePluginLockfile(data)
}

func ParsePluginLockfile(data []byte) (PluginLockfile, error) {
	var lock PluginLockfile
	if err := json.Unmarshal(data, &lock); err != nil {
		return PluginLockfile{}, fmt.Errorf("failed to parse plugin lockfile: %w", err)
	}
	if lock.Plugins == nil {
		lock.Plugins = make(map[string]LockedPlugin)
	}
	if err := lock.Validate(); err != nil {
		return PluginLockfile{}, err
	}
	return lock, nil
}

func (s *LockStore) Write(lock PluginLockfile) error {
	if err := lock.Validate(); err != nil {
		return err
	}

	data, err := json.MarshalIndent(lock, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to encode plugin lockfile: %w", err)
	}
	data = append(data, '\n')

	if err := s.fs.MkdirAll(filepath.Dir(s.path), 0o755); err != nil {
		return fmt.Errorf("failed to create plugin lockfile directory: %w", err)
	}

	tmpPath := s.path + ".tmp"
	if err := afero.WriteFile(s.fs, tmpPath, data, 0o644); err != nil {
		return fmt.Errorf("failed to write temporary plugin lockfile: %w", err)
	}
	defer s.fs.Remove(tmpPath) //nolint:errcheck

	if err := s.fs.Rename(tmpPath, s.path); err != nil {
		return fmt.Errorf("failed to replace plugin lockfile: %w", err)
	}
	return nil
}

func (lock PluginLockfile) Validate() error {
	if lock.LockfileVersion != pluginLockfileVersion {
		return fmt.Errorf("unsupported plugin lockfile version %d (expected %d)", lock.LockfileVersion, pluginLockfileVersion)
	}

	repoCommits := make(map[string]string)
	for id, plugin := range lock.Plugins {
		if !isSafePluginPathComponent(id) {
			return fmt.Errorf("invalid locked plugin id: %q", id)
		}
		if strings.TrimSpace(plugin.Repo) == "" {
			return fmt.Errorf("locked plugin %q has no repository", id)
		}
		if err := validatePluginRepo(plugin.Repo); err != nil {
			return fmt.Errorf("locked plugin %q: %w", id, err)
		}
		if !gitCommitPattern.MatchString(plugin.Commit) {
			return fmt.Errorf("locked plugin %q has invalid commit %q", id, plugin.Commit)
		}
		if err := validatePluginRepoPath(plugin.Path); err != nil {
			return fmt.Errorf("locked plugin %q: %w", id, err)
		}
		if commit, ok := repoCommits[plugin.Repo]; ok && !strings.EqualFold(commit, plugin.Commit) {
			return fmt.Errorf("plugins from repository %q must use the same commit", plugin.Repo)
		}
		repoCommits[plugin.Repo] = plugin.Commit
	}
	return nil
}

func validatePluginRepo(repo string) error {
	parsed, err := url.Parse(repo)
	if err != nil {
		if scpLikeRepoPattern.MatchString(repo) {
			return nil
		}
		return fmt.Errorf("invalid repository URL %q", repo)
	}
	if parsed.User == nil {
		return nil
	}
	if _, hasPassword := parsed.User.Password(); hasPassword {
		return fmt.Errorf("repository URL must not contain credentials")
	}
	switch parsed.Scheme {
	case "http", "https":
		return fmt.Errorf("repository URL must not contain credentials")
	}
	return nil
}

func validatePluginRepoPath(path string) error {
	if path == "" {
		return nil
	}
	clean := filepath.Clean(path)
	if filepath.IsAbs(clean) || clean == ".." || strings.HasPrefix(clean, ".."+string(filepath.Separator)) {
		return fmt.Errorf("invalid repository path %q", path)
	}
	return nil
}

func (lock PluginLockfile) IDs() []string {
	ids := make([]string, 0, len(lock.Plugins))
	for id := range lock.Plugins {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	return ids
}

func (lock *PluginLockfile) SetRepositoryCommit(repo, commit string) {
	for id, plugin := range lock.Plugins {
		if plugin.Repo != repo {
			continue
		}
		plugin.Commit = commit
		lock.Plugins[id] = plugin
	}
}

func (lock PluginLockfile) Clone() PluginLockfile {
	cloned := NewPluginLockfile()
	maps.Copy(cloned.Plugins, lock.Plugins)
	return cloned
}
