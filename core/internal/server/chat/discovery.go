package chat

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/chat"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
)

// systemPluginsDir mirrors what PluginService scans in the shell, so a chat
// plugin is discovered identically whether it was installed for one user or
// system-wide.
const systemPluginsDir = "/etc/xdg/quickshell/dms-plugins"

// pluginManifest is the subset of plugin.json this package cares about.
type pluginManifest struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Description string   `json:"description"`
	Version     string   `json:"version"`
	Author      string   `json:"author"`
	Type        string   `json:"type"`
	Icon        string   `json:"icon"`
	Bridge      []string `json:"bridge"`
	Settings    string   `json:"settings"`
	Warning     string   `json:"warning"`
}

// Provider is a discovered chat plugin.
type Provider struct {
	ID          string         `json:"id"`
	Name        string         `json:"name"`
	Description string         `json:"description"`
	Version     string         `json:"version"`
	Author      string         `json:"author"`
	Icon        string         `json:"icon"`
	Dir         string         `json:"dir"`
	Bridge      []string       `json:"-"`
	SettingsQML string         `json:"settingsQml,omitempty"`
	Warning     string         `json:"warning,omitempty"`
	MediaDir    string         `json:"-"`
	Settings    map[string]any `json:"-"`
}

// ProviderStatus is what the settings UI and CLI show for one provider.
type ProviderStatus struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Icon        string `json:"icon"`
	Description string `json:"description,omitempty"`
	SettingsQML string `json:"settingsQml,omitempty"`
	// Warning is a caveat the plugin author declared about their own provider,
	// shown prominently in settings. Declared by the plugin rather than known
	// to the shell, so the shell never hardcodes anything provider-specific.
	Warning      string   `json:"warning,omitempty"`
	Enabled      bool     `json:"enabled"`
	Running      bool     `json:"running"`
	State        string   `json:"state"`
	Capabilities []string `json:"capabilities"`
	Protocol     int      `json:"protocol,omitempty"`
	Restarts     int      `json:"restarts"`
	LastError    string   `json:"lastError,omitempty"`
	PID          int      `json:"pid,omitempty"`
	Unread       int      `json:"unread"`
	// Notifications is the policy actually in force for this provider, so the
	// settings UI shows what is true rather than what it last sent.
	Notifications chat.NotifyPrefs `json:"notifications"`
	StderrTail    []string         `json:"stderrTail,omitempty"`

	// The pending sign-in challenge, if the provider is waiting for one.
	// AuthMethod is "qr", "code" or "url"; AuthPayload is what to render.
	AuthMethod  string `json:"authMethod,omitempty"`
	AuthPayload string `json:"authPayload,omitempty"`
}

// discoverProviders scans the plugin directories for type "chat" plugins.
//
// A user plugin shadows a system one with the same id, matching how the shell
// resolves plugins.
func discoverProviders(userDir string) []Provider {
	found := map[string]Provider{}

	// System first, so user plugins overwrite them.
	for _, root := range []string{systemPluginsDir, userDir} {
		if root == "" {
			continue
		}
		for _, p := range scanPluginRoot(root) {
			found[p.ID] = p
		}
	}

	out := make([]Provider, 0, len(found))
	for _, p := range found {
		out = append(out, p)
	}
	return out
}

func scanPluginRoot(root string) []Provider {
	entries, err := os.ReadDir(root)
	if err != nil {
		if !os.IsNotExist(err) {
			log.Debugf("chat: cannot read plugin dir %s: %v", root, err)
		}
		return nil
	}

	var out []Provider
	for _, entry := range entries {
		// Symlinked plugin dirs are how the installer handles monorepo plugins,
		// so resolve rather than requiring a real directory here.
		info, err := os.Stat(filepath.Join(root, entry.Name()))
		if err != nil || !info.IsDir() {
			continue
		}

		dir := filepath.Join(root, entry.Name())
		p, err := loadProvider(dir)
		if err != nil {
			if !os.IsNotExist(err) {
				log.Debugf("chat: skipping %s: %v", dir, err)
			}
			continue
		}
		out = append(out, p)
	}
	return out
}

// loadProvider reads a plugin.json and returns it if it declares a chat bridge.
func loadProvider(dir string) (Provider, error) {
	data, err := os.ReadFile(filepath.Join(dir, "plugin.json"))
	if err != nil {
		return Provider{}, err
	}

	var m pluginManifest
	if err := json.Unmarshal(data, &m); err != nil {
		return Provider{}, fmt.Errorf("parse plugin.json: %w", err)
	}

	if m.Type != "chat" {
		return Provider{}, fmt.Errorf("not a chat plugin")
	}
	if m.ID == "" {
		return Provider{}, fmt.Errorf("manifest has no id")
	}
	if len(m.Bridge) == 0 {
		return Provider{}, fmt.Errorf("chat plugin %s declares no bridge command", m.ID)
	}

	bridge, err := resolveBridge(dir, m.Bridge)
	if err != nil {
		return Provider{}, err
	}

	name := m.Name
	if name == "" {
		name = m.ID
	}

	return Provider{
		ID:          m.ID,
		Name:        name,
		Description: m.Description,
		Version:     m.Version,
		Author:      m.Author,
		Icon:        m.Icon,
		Dir:         dir,
		Bridge:      bridge,
		SettingsQML: resolveRelative(dir, m.Settings),
		Warning:     m.Warning,
	}, nil
}

// resolveBridge turns a manifest's bridge argv into something executable,
// anchoring relative paths to the plugin directory.
//
// A bare name is left alone so a plugin may legitimately depend on something on
// PATH, but anything path-shaped must stay inside its own directory -- a
// manifest is not allowed to point the host at an arbitrary binary.
func resolveBridge(dir string, argv []string) ([]string, error) {
	if len(argv) == 0 {
		return nil, fmt.Errorf("empty bridge command")
	}

	out := make([]string, len(argv))
	copy(out, argv)

	exe := argv[0]
	if !strings.ContainsRune(exe, os.PathSeparator) {
		return out, nil
	}

	if filepath.IsAbs(exe) {
		return nil, fmt.Errorf("bridge command must be relative to the plugin directory, got %q", exe)
	}

	resolved := filepath.Join(dir, exe)
	if !withinDir(dir, resolved) {
		return nil, fmt.Errorf("bridge command escapes the plugin directory: %q", exe)
	}

	out[0] = resolved
	return out, nil
}

func resolveRelative(dir, rel string) string {
	if rel == "" {
		return ""
	}
	resolved := filepath.Join(dir, strings.TrimPrefix(rel, "./"))
	if !withinDir(dir, resolved) {
		return ""
	}
	return resolved
}

func withinDir(dir, path string) bool {
	rel, err := filepath.Rel(dir, path)
	if err != nil {
		return false
	}
	return rel != ".." && !strings.HasPrefix(rel, ".."+string(filepath.Separator))
}
