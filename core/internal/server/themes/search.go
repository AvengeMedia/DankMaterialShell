package themes

import (
	"fmt"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/themes"
)

func HandleSearch(conn *models.Conn, req models.Request) {
	query, ok := models.Get[string](req, "query")
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'query' parameter")
		return
	}

	registry, err := themes.NewRegistry()
	if err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to create registry: %v", err))
		return
	}

	themeList, err := registry.List()
	if err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to list themes: %v", err))
		return
	}

	searchResults := themes.FuzzySearch(query, themeList)

	manager, err := themes.NewManager()
	if err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to create manager: %v", err))
		return
	}

	result := make([]ThemeInfo, len(searchResults))
	for i, t := range searchResults {
		installed, _ := manager.IsInstalled(t)
		result[i] = ThemeInfo{
			ID:          t.ID,
			Name:        t.Name,
			Version:     t.Version,
			Author:      t.Author,
			Description: t.Description,
			Installed:   installed,
			FirstParty:  isFirstParty(t.Author),
			WCAG:        t.WCAG,
		}
	}

	models.Respond(conn, req.ID, result)
}
