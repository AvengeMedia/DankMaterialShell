package themes

import (
	"encoding/json"
	"errors"
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
const envRegistriesKey = "DMS_THEME_REGISTRIES"

// RegistryConfig identifies a single registry source.
type RegistryConfig struct {
	// Name is a short identifier used for the per-registry cache subdir.
	Name string
	// URL is the git URL of the registry repository.
	URL string
}

// ParseRegistriesFromEnv reads DMS_THEME_REGISTRIES (comma-separated URLs)
// and returns the resulting configs. Defaults to the official registry when
// the env var is unset, empty, or contains no valid URLs.
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

type ColorScheme struct {
	Primary                 string `json:"primary,omitempty"`
	PrimaryText             string `json:"primaryText,omitempty"`
	PrimaryContainer        string `json:"primaryContainer,omitempty"`
	Secondary               string `json:"secondary,omitempty"`
	Surface                 string `json:"surface,omitempty"`
	SurfaceText             string `json:"surfaceText,omitempty"`
	SurfaceVariant          string `json:"surfaceVariant,omitempty"`
	SurfaceVariantText      string `json:"surfaceVariantText,omitempty"`
	SurfaceTint             string `json:"surfaceTint,omitempty"`
	Background              string `json:"background,omitempty"`
	BackgroundText          string `json:"backgroundText,omitempty"`
	Outline                 string `json:"outline,omitempty"`
	SurfaceContainer        string `json:"surfaceContainer,omitempty"`
	SurfaceContainerHigh    string `json:"surfaceContainerHigh,omitempty"`
	SurfaceContainerHighest string `json:"surfaceContainerHighest,omitempty"`
	Error                   string `json:"error,omitempty"`
	Warning                 string `json:"warning,omitempty"`
	Info                    string `json:"info,omitempty"`
}

type ThemeVariant struct {
	ID    string      `json:"id"`
	Name  string      `json:"name"`
	Dark  ColorScheme `json:"dark,omitempty"`
	Light ColorScheme `json:"light,omitempty"`
}

type ThemeFlavor struct {
	ID    string      `json:"id"`
	Name  string      `json:"name"`
	Dark  ColorScheme `json:"dark,omitempty"`
	Light ColorScheme `json:"light,omitempty"`
}

type ThemeAccent struct {
	ID           string                 `json:"id"`
	Name         string                 `json:"name"`
	FlavorColors map[string]ColorScheme `json:"-"`
}

func (a *ThemeAccent) UnmarshalJSON(data []byte) error {
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	a.FlavorColors = make(map[string]ColorScheme)
	var mErr error
	for key, value := range raw {
		switch key {
		case "id":
			mErr = errors.Join(mErr, json.Unmarshal(value, &a.ID))
		case "name":
			mErr = errors.Join(mErr, json.Unmarshal(value, &a.Name))
		default:
			var colors ColorScheme
			if err := json.Unmarshal(value, &colors); err == nil {
				a.FlavorColors[key] = colors
			} else {
				mErr = errors.Join(mErr, fmt.Errorf("failed to unmarshal flavor colors for key %s: %w", key, err))
			}
		}
	}
	return mErr
}

func (a ThemeAccent) MarshalJSON() ([]byte, error) {
	m := map[string]any{
		"id":   a.ID,
		"name": a.Name,
	}
	for k, v := range a.FlavorColors {
		m[k] = v
	}
	return json.Marshal(m)
}

type MultiVariantDefaults struct {
	Dark  map[string]string `json:"dark,omitempty"`
	Light map[string]string `json:"light,omitempty"`
}

type ThemeVariants struct {
	Type     string                `json:"type,omitempty"`
	Default  string                `json:"default,omitempty"`
	Defaults *MultiVariantDefaults `json:"defaults,omitempty"`
	Options  []ThemeVariant        `json:"options,omitempty"`
	Flavors  []ThemeFlavor         `json:"flavors,omitempty"`
	Accents  []ThemeAccent         `json:"accents,omitempty"`
}

type ThemeWCAGGroup struct {
	Level     string   `json:"level"`
	MinRatio  float64  `json:"minRatio"`
	WorstPair []string `json:"worstPair,omitempty"`
}

type ThemeWCAGBreakdown struct {
	Name      string `json:"name"`
	Mode      string `json:"mode"`
	Level     string `json:"level"`
	BodyLevel string `json:"bodyLevel"`
}

type ThemeWCAGMode struct {
	Level     string               `json:"level"`
	MinRatio  float64              `json:"minRatio"`
	WorstPair []string             `json:"worstPair,omitempty"`
	Body      *ThemeWCAGGroup      `json:"body,omitempty"`
	Accent    *ThemeWCAGGroup      `json:"accent,omitempty"`
	NonText   *ThemeWCAGGroup      `json:"nonText,omitempty"`
	Variants  map[string]string    `json:"variants,omitempty"`
	Breakdown []ThemeWCAGBreakdown `json:"breakdown,omitempty"`
}

type ThemeWCAG struct {
	Level string         `json:"level"`
	Dark  *ThemeWCAGMode `json:"dark,omitempty"`
	Light *ThemeWCAGMode `json:"light,omitempty"`
}

type Theme struct {
	ID          string         `json:"id"`
	Name        string         `json:"name"`
	Version     string         `json:"version"`
	Author      string         `json:"author"`
	Description string         `json:"description"`
	Dark        ColorScheme    `json:"dark"`
	Light       ColorScheme    `json:"light"`
	Variants    *ThemeVariants `json:"variants,omitempty"`
	WCAG        *ThemeWCAG     `json:"wcag,omitempty"`
	PreviewPath string         `json:"-"`
	SourceDir   string         `json:"sourceDir,omitempty"`
}

type GitClient interface {
	PlainClone(path string, url string) error
	Pull(path string) error
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

type Registry struct {
	fs         afero.Fs
	cacheDir   string // base cache dir; per-registry subdirs live underneath
	registries []RegistryConfig
	themes     []Theme
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

// loadThemesFrom reads theme directories from one registry's cache subdir.
func (r *Registry) loadThemesFrom(dir string) ([]Theme, error) {
	themesDir := filepath.Join(dir, "themes")
	entries, err := afero.ReadDir(r.fs, themesDir)
	if err != nil {
		return nil, fmt.Errorf("failed to read themes directory: %w", err)
	}

	var themes []Theme
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		themeDir := filepath.Join(themesDir, entry.Name())
		themeFile := filepath.Join(themeDir, "theme.json")

		data, err := afero.ReadFile(r.fs, themeFile)
		if err != nil {
			continue
		}

		var theme Theme
		if err := json.Unmarshal(data, &theme); err != nil {
			continue
		}

		if theme.ID == "" {
			theme.ID = entry.Name()
		}
		theme.SourceDir = entry.Name()
		theme.WCAG = loadThemeWCAG(r.fs, themeDir)

		previewPath := filepath.Join(themeDir, "preview.svg")
		if exists, _ := afero.Exists(r.fs, previewPath); exists {
			theme.PreviewPath = previewPath
		}

		themes = append(themes, theme)
	}
	return themes, nil
}

// migrateLegacyCache moves a pre-multi-registry themes cache into the new
// per-registry layout. Idempotent.
func (r *Registry) migrateLegacyCache() error {
	legacyDir := filepath.Join(r.cacheDir, "themes")
	exists, err := afero.DirExists(r.fs, legacyDir)
	if err != nil || !exists {
		return nil
	}
	targetDir := filepath.Join(r.cacheDir, "official", "themes")
	exists, err = afero.DirExists(r.fs, targetDir)
	if err != nil {
		return fmt.Errorf("failed to check target cache directory: %w", err)
	}
	if exists {
		return r.fs.RemoveAll(legacyDir)
	}
	if err := r.fs.MkdirAll(filepath.Join(r.cacheDir, "official"), 0o755); err != nil {
		return fmt.Errorf("failed to create official cache directory: %w", err)
	}
	return r.fs.Rename(legacyDir, targetDir)
}

func (r *Registry) Update() error {
	if err := r.migrateLegacyCache(); err != nil {
		return err
	}
	r.themes = []Theme{}
	seen := make(map[string]struct{})
	for _, cfg := range r.registries {
		if err := r.updateOne(cfg); err != nil {
			return fmt.Errorf("registry %s: %w", cfg.Name, err)
		}
		themes, err := r.loadThemesFrom(r.cacheDirFor(cfg))
		if err != nil {
			return fmt.Errorf("registry %s: %w", cfg.Name, err)
		}
		// Declaration-order dedupe: first occurrence of an ID wins.
		for _, t := range themes {
			if _, dup := seen[t.ID]; dup {
				continue
			}
			seen[t.ID] = struct{}{}
			r.themes = append(r.themes, t)
		}
	}
	return nil
}

func loadThemeWCAG(fs afero.Fs, themeDir string) *ThemeWCAG {
	data, err := afero.ReadFile(fs, filepath.Join(themeDir, "wcag.json"))
	if err != nil {
		return nil
	}

	var wcag ThemeWCAG
	if err := json.Unmarshal(data, &wcag); err != nil {
		return nil
	}

	return &wcag
}

func (r *Registry) List() ([]Theme, error) {
	if len(r.themes) == 0 {
		if err := r.Update(); err != nil {
			return nil, err
		}
	}

	return SortByFirstParty(r.themes), nil
}

func (r *Registry) Search(query string) ([]Theme, error) {
	allThemes, err := r.List()
	if err != nil {
		return nil, err
	}

	if query == "" {
		return allThemes, nil
	}

	return SortByFirstParty(FuzzySearch(query, allThemes)), nil
}

func (r *Registry) Get(idOrName string) (*Theme, error) {
	themes, err := r.List()
	if err != nil {
		return nil, err
	}

	for _, t := range themes {
		if t.ID == idOrName {
			return &t, nil
		}
	}

	for _, t := range themes {
		if t.Name == idOrName {
			return &t, nil
		}
	}

	return nil, fmt.Errorf("theme not found: %s", idOrName)
}

func (r *Registry) GetThemeSourcePath(themeID string) string {
	// Themes may live under any registry's subdir. Search them all; first hit wins.
	for _, cfg := range r.registries {
		candidate := filepath.Join(r.cacheDirFor(cfg), "themes", themeID, "theme.json")
		if exists, _ := afero.Exists(r.fs, candidate); exists {
			return candidate
		}
	}
	// Fallback to first registry (legacy path semantics).
	return filepath.Join(r.cacheDirFor(r.registries[0]), "themes", themeID, "theme.json")
}

func (r *Registry) GetThemeDir(themeID string) string {
	for _, cfg := range r.registries {
		candidate := filepath.Join(r.cacheDirFor(cfg), "themes", themeID)
		if exists, _ := afero.DirExists(r.fs, candidate); exists {
			return candidate
		}
	}
	return filepath.Join(r.cacheDirFor(r.registries[0]), "themes", themeID)
}

func SortByFirstParty(themes []Theme) []Theme {
	return themes
}
