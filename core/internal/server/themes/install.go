package themes

import (
	"fmt"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/themes"
	"github.com/AvengeMedia/dankgo/ipc"
)

func HandleInstall(conn *ipc.ConnWriter, req ipc.Request) {
	idOrName, ok := models.Get[string](req, "name")
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'name' parameter")
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

	theme := themes.FindByIDOrName(idOrName, themeList)
	if theme == nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("theme not found: %s", idOrName))
		return
	}

	manager, err := themes.NewManager()
	if err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to create manager: %v", err))
		return
	}

	registryThemeDir := registry.GetThemeDir(theme.SourceDir)
	if err := manager.Install(*theme, registryThemeDir); err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to install theme: %v", err))
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{
		Success: true,
		Message: fmt.Sprintf("theme installed: %s", theme.Name),
	})
}
