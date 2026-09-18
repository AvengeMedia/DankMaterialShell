package themes

import (
	"fmt"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/themes"
	"github.com/AvengeMedia/dankgo/ipc"
)

func addVariantsInfo(info *ThemeInfo, variants *themes.ThemeVariants) {
	if variants == nil {
		return
	}

	if variants.Type == "multi" {
		if len(variants.Flavors) == 0 && len(variants.Accents) == 0 {
			return
		}
		info.HasVariants = true
		info.Variants = &VariantsInfo{
			Type:    "multi",
			Flavors: make([]FlavorInfo, len(variants.Flavors)),
			Accents: make([]AccentInfo, len(variants.Accents)),
		}
		if variants.Defaults != nil {
			info.Variants.Defaults = &MultiDefaults{
				Dark:  variants.Defaults.Dark,
				Light: variants.Defaults.Light,
			}
		}
		for i, f := range variants.Flavors {
			mode := ""
			switch {
			case f.Dark.Primary != "" && f.Light.Primary != "":
				mode = "both"
			case f.Dark.Primary != "":
				mode = "dark"
			case f.Light.Primary != "":
				mode = "light"
			default:
				if f.Dark.Surface != "" {
					mode = "dark"
				} else if f.Light.Surface != "" {
					mode = "light"
				}
			}
			info.Variants.Flavors[i] = FlavorInfo{ID: f.ID, Name: f.Name, Mode: mode}
		}
		for i, a := range variants.Accents {
			color := ""
			if colors, ok := a.FlavorColors["mocha"]; ok && colors.Primary != "" {
				color = colors.Primary
			} else if colors, ok := a.FlavorColors["latte"]; ok && colors.Primary != "" {
				color = colors.Primary
			} else {
				for _, c := range a.FlavorColors {
					if c.Primary != "" {
						color = c.Primary
						break
					}
				}
			}
			info.Variants.Accents[i] = AccentInfo{ID: a.ID, Name: a.Name, Color: color}
		}
		return
	}

	if len(variants.Options) == 0 {
		return
	}
	info.HasVariants = true
	info.Variants = &VariantsInfo{
		Default: variants.Default,
		Options: make([]VariantInfo, len(variants.Options)),
	}
	for i, v := range variants.Options {
		info.Variants.Options[i] = VariantInfo{ID: v.ID, Name: v.Name}
	}
}

func HandleListInstalled(conn *ipc.ConnWriter, req ipc.Request) {
	manager, err := themes.NewManager()
	if err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to create manager: %v", err))
		return
	}

	installedIDs, err := manager.ListInstalled()
	if err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to list installed themes: %v", err))
		return
	}

	themeMap := make(map[string]themes.Theme)
	if registry, err := themes.NewRegistry(); err == nil {
		if allThemes, err := registry.List(); err == nil {
			for _, t := range allThemes {
				themeMap[t.ID] = t
			}
		}
	}

	result := make([]ThemeInfo, 0, len(installedIDs))
	for _, id := range installedIDs {
		if theme, ok := themeMap[id]; ok {
			hasUpdate := false
			if hasUpdates, err := manager.HasUpdates(id, theme); err == nil {
				hasUpdate = hasUpdates
			}

			info := ThemeInfo{
				ID:          theme.ID,
				Name:        theme.Name,
				Version:     theme.Version,
				Author:      theme.Author,
				Description: theme.Description,
				SourceDir:   id,
				FirstParty:  isFirstParty(theme.Author),
				HasUpdate:   hasUpdate,
			}
			addVariantsInfo(&info, theme.Variants)
			result = append(result, info)
		} else {
			installed, err := manager.GetInstalledTheme(id)
			if err != nil {
				result = append(result, ThemeInfo{
					ID:        id,
					Name:      id,
					SourceDir: id,
				})
				continue
			}
			info := ThemeInfo{
				ID:          installed.ID,
				Name:        installed.Name,
				Version:     installed.Version,
				Author:      installed.Author,
				Description: installed.Description,
				SourceDir:   id,
				FirstParty:  isFirstParty(installed.Author),
			}
			addVariantsInfo(&info, installed.Variants)
			result = append(result, info)
		}
	}

	models.Respond(conn, req.ID, result)
}
