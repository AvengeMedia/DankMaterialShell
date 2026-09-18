package themes

import (
	"fmt"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/themes"
	"github.com/AvengeMedia/dankgo/ipc"
)

func HandleUninstall(conn *ipc.ConnWriter, req ipc.Request) {
	idOrName, ok := models.Get[string](req, "name")
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'name' parameter")
		return
	}

	manager, err := themes.NewManager()
	if err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to create manager: %v", err))
		return
	}

	registry, err := themes.NewRegistry()
	if err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to create registry: %v", err))
		return
	}

	themeList, _ := registry.List()
	theme := themes.FindByIDOrName(idOrName, themeList)

	if theme != nil {
		installed, err := manager.IsInstalled(*theme)
		if err != nil {
			models.RespondError(conn, req.ID, fmt.Sprintf("failed to check if theme is installed: %v", err))
			return
		}
		if !installed {
			models.RespondError(conn, req.ID, fmt.Sprintf("theme not installed: %s", idOrName))
			return
		}
		if err := manager.Uninstall(*theme); err != nil {
			models.RespondError(conn, req.ID, fmt.Sprintf("failed to uninstall theme: %v", err))
			return
		}
		models.Respond(conn, req.ID, models.SuccessResult{
			Success: true,
			Message: fmt.Sprintf("theme uninstalled: %s", theme.Name),
		})
		return
	}

	if err := manager.UninstallByID(idOrName); err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("theme not found: %s", idOrName))
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{
		Success: true,
		Message: fmt.Sprintf("theme uninstalled: %s", idOrName),
	})
}
