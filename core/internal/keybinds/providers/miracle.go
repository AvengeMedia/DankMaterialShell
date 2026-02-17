package providers

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/keybinds"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
)

type MiracleProvider struct {
	configPath string
}

func NewMiracleProvider(configPath string) *MiracleProvider {
	if configPath == "" {
		configDir, err := os.UserConfigDir()
		if err == nil {
			configPath = filepath.Join(configDir, "miracle-wm")
		}
	}
	return &MiracleProvider{configPath: configPath}
}

func (m *MiracleProvider) Name() string {
	return "miracle"
}

func (m *MiracleProvider) GetCheatSheet() (*keybinds.CheatSheet, error) {
	config, err := ParseMiracleConfig(m.configPath)
	if err != nil {
		return nil, fmt.Errorf("failed to parse miracle-wm config: %w", err)
	}

	bindings := MiracleConfigToBindings(config)
	categorizedBinds := make(map[string][]keybinds.Keybind)

	for _, kb := range bindings {
		category := m.categorizeAction(kb.Action)
		bind := keybinds.Keybind{
			Key:         m.formatKey(kb),
			Description: kb.Comment,
			Action:      kb.Action,
		}
		categorizedBinds[category] = append(categorizedBinds[category], bind)
	}

	return &keybinds.CheatSheet{
		Title:    "Miracle WM Keybinds",
		Provider: m.Name(),
		Binds:    categorizedBinds,
	}, nil
}

func (m *MiracleProvider) GetOverridePath() string {
	expanded, err := utils.ExpandPath(m.configPath)
	if err != nil {
		return filepath.Join(m.configPath, "config.yaml")
	}
	return filepath.Join(expanded, "config.yaml")
}

func (m *MiracleProvider) formatKey(kb MiracleKeyBinding) string {
	parts := make([]string, 0, len(kb.Mods)+1)
	parts = append(parts, kb.Mods...)
	parts = append(parts, kb.Key)
	return strings.Join(parts, "+")
}

func (m *MiracleProvider) categorizeAction(action string) string {
	switch {
	case strings.HasPrefix(action, "select_workspace_") || strings.HasPrefix(action, "move_to_workspace_"):
		return "Workspace"
	case strings.Contains(action, "select_") || strings.Contains(action, "move_"):
		return "Window"
	case action == "toggle_resize" || strings.HasPrefix(action, "resize_"):
		return "Window"
	case action == "fullscreen" || action == "toggle_floating" || action == "quit_active_window" || action == "toggle_pinned_to_workspace":
		return "Window"
	case action == "toggle_tabbing" || action == "toggle_stacking" || action == "request_vertical" || action == "request_horizontal":
		return "Layout"
	case action == "quit_compositor":
		return "System"
	case action == "terminal":
		return "Execute"
	case strings.HasPrefix(action, "magnifier_"):
		return "Accessibility"
	case strings.HasPrefix(action, "dms ") || strings.Contains(action, "dms ipc"):
		return "Execute"
	default:
		return "Execute"
	}
}
