package providers

import (
	"fmt"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/keybinds"
)

type MangoWCProvider struct {
	configPath string
}

func NewMangoWCProvider(configPath string) *MangoWCProvider {
	if configPath == "" {
		configPath = "$HOME/.config/mango"
	}
	return &MangoWCProvider{
		configPath: configPath,
	}
}

func (m *MangoWCProvider) Name() string {
	return "mangowc"
}

func (m *MangoWCProvider) GetCheatSheet() (*keybinds.CheatSheet, error) {
	keybinds_list, err := ParseMangoWCKeys(m.configPath)
	if err != nil {
		return nil, fmt.Errorf("failed to parse mangowc config: %w", err)
	}

	categorizedBinds := make(map[string][]keybinds.Keybind)
	for _, kb := range keybinds_list {
		category := m.categorizeByCommand(kb.Command)
		bind := m.convertKeybind(&kb)
		categorizedBinds[category] = append(categorizedBinds[category], bind)
	}

	return &keybinds.CheatSheet{
		Title:    "MangoWC Keybinds",
		Provider: m.Name(),
		Binds:    categorizedBinds,
	}, nil
}

func (m *MangoWCProvider) categorizeByCommand(command string) string {
	switch {
	case strings.Contains(command, "mon"):
		return "Monitor"
	case command == "toggleoverview":
		return "Overview"
	case command == "toggle_scratchpad":
		return "Scratchpad"
	case strings.Contains(command, "layout") || strings.Contains(command, "proportion"):
		return "Layout"
	case strings.Contains(command, "gaps"):
		return "Gaps"
	case strings.Contains(command, "view") || strings.Contains(command, "tag"):
		return "Tags"
	case command == "focusstack" ||
		command == "focusdir" ||
		command == "exchange_client" ||
		command == "killclient" ||
		command == "togglefloating" ||
		command == "togglefullscreen" ||
		command == "togglefakefullscreen" ||
		command == "togglemaximizescreen" ||
		command == "toggleglobal" ||
		command == "toggleoverlay" ||
		command == "minimized" ||
		command == "restore_minimized" ||
		command == "movewin" ||
		command == "resizewin":
		return "Window"
	case command == "spawn" || command == "spawn_shell":
		return "Execute"
	case command == "quit" || command == "reload_config":
		return "System"
	default:
		return "Other"
	}
}

func (m *MangoWCProvider) convertKeybind(kb *MangoWCKeyBinding) keybinds.Keybind {
	key := m.formatKey(kb)
	desc := kb.Comment

	if desc == "" {
		desc = m.generateDescription(kb.Command, kb.Params)
	}

	return keybinds.Keybind{
		Key:         key,
		Description: desc,
	}
}

func (m *MangoWCProvider) generateDescription(command, params string) string {
	if params != "" {
		return command + " " + params
	}
	return command
}

func (m *MangoWCProvider) formatKey(kb *MangoWCKeyBinding) string {
	parts := make([]string, 0, len(kb.Mods)+1)
	parts = append(parts, kb.Mods...)
	parts = append(parts, kb.Key)
	return strings.Join(parts, "+")
}
