package chromecast

import (
	"encoding/json"
	"os"
	"path/filepath"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
)

// Config persists user preferences for the chromecast service.
type Config struct {
	// PreferredID is the stable ID of the device to auto-reconnect to. Empty
	// means no preferred device.
	PreferredID string `json:"preferredId"`
	// PreferredName is kept for display only (the ID is authoritative).
	PreferredName string `json:"preferredName"`
}

// configPathFunc resolves the config file path. Overridable in tests.
var configPathFunc = func() (string, error) {
	return filepath.Join(utils.XDGConfigHome(), "DankMaterialShell", "castsettings.json"), nil
}

func loadConfig() Config {
	var cfg Config
	path, err := configPathFunc()
	if err != nil {
		return cfg
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return cfg
	}
	if err := json.Unmarshal(data, &cfg); err != nil {
		return Config{}
	}
	return cfg
}

func saveConfig(cfg Config) error {
	path, err := configPathFunc()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0o644)
}
