package providers

import (
	"fmt"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/keybinds"
)

type SwayProvider struct {
	configPath string
}

func NewSwayProvider(configPath string) *SwayProvider {
	if configPath == "" {
		configPath = "$HOME/.config/sway"
	}
	return &SwayProvider{
		configPath: configPath,
	}
}

func (s *SwayProvider) Name() string {
	return "sway"
}

func (s *SwayProvider) GetCheatSheet() (*keybinds.CheatSheet, error) {
	section, err := ParseSwayKeys(s.configPath)
	if err != nil {
		return nil, fmt.Errorf("failed to parse sway config: %w", err)
	}

	categorizedBinds := make(map[string][]keybinds.Keybind)
	s.convertSection(section, "", categorizedBinds)

	return &keybinds.CheatSheet{
		Title:    "Sway Keybinds",
		Provider: s.Name(),
		Binds:    categorizedBinds,
	}, nil
}

func (s *SwayProvider) convertSection(section *SwaySection, subcategory string, categorizedBinds map[string][]keybinds.Keybind) {
	currentSubcat := subcategory
	if section.Name != "" {
		currentSubcat = section.Name
	}

	for _, kb := range section.Keybinds {
		category := s.categorizeByCommand(kb.Command)
		bind := s.convertKeybind(&kb, currentSubcat)
		categorizedBinds[category] = append(categorizedBinds[category], bind)
	}

	for _, child := range section.Children {
		s.convertSection(&child, currentSubcat, categorizedBinds)
	}
}

func (s *SwayProvider) categorizeByCommand(command string) string {
	command = strings.ToLower(command)

	switch {
	case strings.Contains(command, "scratchpad"):
		return "Scratchpad"
	case strings.Contains(command, "workspace") && strings.Contains(command, "output"):
		return "Monitor"
	case strings.Contains(command, "workspace"):
		return "Workspace"
	case strings.Contains(command, "output"):
		return "Monitor"
	case strings.Contains(command, "layout"):
		return "Layout"
	case command == "kill" ||
		command == "fullscreen" || strings.Contains(command, "fullscreen") ||
		command == "floating toggle" || strings.Contains(command, "floating") ||
		strings.Contains(command, "focus") ||
		strings.Contains(command, "move") ||
		strings.Contains(command, "resize") ||
		strings.Contains(command, "split"):
		return "Window"
	case strings.HasPrefix(command, "exec"):
		return "Execute"
	case command == "exit" || command == "reload":
		return "System"
	default:
		return "Other"
	}
}

func (s *SwayProvider) convertKeybind(kb *SwayKeyBinding, subcategory string) keybinds.Keybind {
	key := s.formatKey(kb)
	desc := kb.Comment

	if desc == "" {
		desc = kb.Command
	}

	return keybinds.Keybind{
		Key:         key,
		Description: desc,
		Subcategory: subcategory,
	}
}

func (s *SwayProvider) formatKey(kb *SwayKeyBinding) string {
	parts := make([]string, 0, len(kb.Mods)+1)
	parts = append(parts, kb.Mods...)
	parts = append(parts, kb.Key)
	return strings.Join(parts, "+")
}
