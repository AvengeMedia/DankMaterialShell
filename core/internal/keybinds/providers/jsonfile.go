package providers

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/keybinds"
)

type JSONFileProvider struct {
	filePath string
	name     string
}

func NewJSONFileProvider(filePath string) (*JSONFileProvider, error) {
	if filePath == "" {
		return nil, fmt.Errorf("file path cannot be empty")
	}

	expandedPath, err := expandPath(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to expand path: %w", err)
	}

	name := filepath.Base(expandedPath)
	name = name[:len(name)-len(filepath.Ext(name))]

	return &JSONFileProvider{
		filePath: expandedPath,
		name:     name,
	}, nil
}

func (j *JSONFileProvider) Name() string {
	return j.name
}

func (j *JSONFileProvider) GetCheatSheet() (*keybinds.CheatSheet, error) {
	data, err := os.ReadFile(j.filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to read file: %w", err)
	}

	var rawData map[string]any
	if err := json.Unmarshal(data, &rawData); err != nil {
		return nil, fmt.Errorf("failed to parse JSON: %w", err)
	}

	title, _ := rawData["title"].(string)
	provider, _ := rawData["provider"].(string)
	if provider == "" {
		provider = j.name
	}

	categorizedBinds := make(map[string][]keybinds.Keybind)

	bindsRaw, ok := rawData["binds"]
	if !ok {
		return nil, fmt.Errorf("missing 'binds' field")
	}

	switch binds := bindsRaw.(type) {
	case map[string]any:
		for category, categoryBindsRaw := range binds {
			categoryBindsList, ok := categoryBindsRaw.([]any)
			if !ok {
				continue
			}

			var keybindsList []keybinds.Keybind
			categoryBindsJSON, _ := json.Marshal(categoryBindsList)
			if err := json.Unmarshal(categoryBindsJSON, &keybindsList); err != nil {
				continue
			}

			categorizedBinds[category] = keybindsList
		}

	case []any:
		flatBindsJSON, _ := json.Marshal(binds)
		var flatBinds []struct {
			Key         string `json:"key"`
			Description string `json:"desc"`
			Action      string `json:"action,omitempty"`
			Category    string `json:"cat,omitempty"`
			Subcategory string `json:"subcat,omitempty"`
		}
		if err := json.Unmarshal(flatBindsJSON, &flatBinds); err != nil {
			return nil, fmt.Errorf("failed to parse flat binds array: %w", err)
		}

		for _, bind := range flatBinds {
			category := bind.Category
			if category == "" {
				category = "Other"
			}

			kb := keybinds.Keybind{
				Key:         bind.Key,
				Description: bind.Description,
				Action:      bind.Action,
				Subcategory: bind.Subcategory,
			}
			categorizedBinds[category] = append(categorizedBinds[category], kb)
		}

	default:
		return nil, fmt.Errorf("'binds' must be either an object (categorized) or array (flat)")
	}

	return &keybinds.CheatSheet{
		Title:    title,
		Provider: provider,
		Binds:    categorizedBinds,
	}, nil
}

func expandPath(path string) (string, error) {
	expandedPath := os.ExpandEnv(path)

	if strings.HasPrefix(expandedPath, "~") {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		expandedPath = filepath.Join(home, expandedPath[1:])
	}

	return filepath.Clean(expandedPath), nil
}
