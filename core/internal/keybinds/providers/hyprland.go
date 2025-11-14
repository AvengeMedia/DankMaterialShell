package providers

import (
	"fmt"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/keybinds"
)

type HyprlandProvider struct {
	configPath string
}

func NewHyprlandProvider(configPath string) *HyprlandProvider {
	if configPath == "" {
		configPath = "$HOME/.config/hypr"
	}
	return &HyprlandProvider{
		configPath: configPath,
	}
}

func (h *HyprlandProvider) Name() string {
	return "hyprland"
}

func (h *HyprlandProvider) GetCheatSheet() (*keybinds.CheatSheet, error) {
	section, err := ParseHyprlandKeys(h.configPath)
	if err != nil {
		return nil, fmt.Errorf("failed to parse hyprland config: %w", err)
	}

	categorizedBinds := make(map[string][]keybinds.Keybind)
	h.convertSection(section, "", categorizedBinds)

	return &keybinds.CheatSheet{
		Title:    "Hyprland Keybinds",
		Provider: h.Name(),
		Binds:    categorizedBinds,
	}, nil
}

func (h *HyprlandProvider) convertSection(section *HyprlandSection, subcategory string, categorizedBinds map[string][]keybinds.Keybind) {
	currentSubcat := subcategory
	if section.Name != "" {
		currentSubcat = section.Name
	}

	for _, kb := range section.Keybinds {
		category := h.categorizeByDispatcher(kb.Dispatcher)
		bind := h.convertKeybind(&kb, currentSubcat)
		categorizedBinds[category] = append(categorizedBinds[category], bind)
	}

	for _, child := range section.Children {
		h.convertSection(&child, currentSubcat, categorizedBinds)
	}
}

func (h *HyprlandProvider) categorizeByDispatcher(dispatcher string) string {
	switch {
	case strings.Contains(dispatcher, "workspace"):
		return "Workspace"
	case strings.Contains(dispatcher, "monitor"):
		return "Monitor"
	case strings.Contains(dispatcher, "window") ||
		strings.Contains(dispatcher, "focus") ||
		strings.Contains(dispatcher, "move") ||
		strings.Contains(dispatcher, "swap") ||
		strings.Contains(dispatcher, "resize") ||
		dispatcher == "killactive" ||
		dispatcher == "fullscreen" ||
		dispatcher == "togglefloating" ||
		dispatcher == "pin" ||
		dispatcher == "fakefullscreen" ||
		dispatcher == "splitratio" ||
		dispatcher == "resizeactive":
		return "Window"
	case dispatcher == "exec":
		return "Execute"
	case dispatcher == "exit" || strings.Contains(dispatcher, "dpms"):
		return "System"
	default:
		return "Other"
	}
}

func (h *HyprlandProvider) convertKeybind(kb *HyprlandKeyBinding, subcategory string) keybinds.Keybind {
	key := h.formatKey(kb)
	desc := kb.Comment

	if desc == "" {
		desc = h.generateDescription(kb.Dispatcher, kb.Params)
	}

	return keybinds.Keybind{
		Key:         key,
		Description: desc,
		Subcategory: subcategory,
	}
}

func (h *HyprlandProvider) generateDescription(dispatcher, params string) string {
	if params != "" {
		return dispatcher + " " + params
	}
	return dispatcher
}

func (h *HyprlandProvider) formatKey(kb *HyprlandKeyBinding) string {
	parts := make([]string, 0, len(kb.Mods)+1)
	parts = append(parts, kb.Mods...)
	parts = append(parts, kb.Key)
	return strings.Join(parts, "+")
}
