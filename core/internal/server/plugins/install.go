package plugins

import (
	"fmt"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/plugins"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/dankgo/ipc"
)

func HandleInstall(conn *ipc.ConnWriter, req ipc.Request) {
	idOrName, ok := models.Get[string](req, "name")
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'name' parameter")
		return
	}

	registry, err := plugins.NewRegistry()
	if err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to create registry: %v", err))
		return
	}

	pluginList, err := registry.List()
	if err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to list plugins: %v", err))
		return
	}

	// First, try to find by ID (preferred method)
	var plugin *plugins.Plugin
	for _, p := range pluginList {
		if p.ID == idOrName {
			plugin = &p
			break
		}
	}

	// Fallback to name for backward compatibility
	if plugin == nil {
		for _, p := range pluginList {
			if p.Name == idOrName {
				plugin = &p
				break
			}
		}
	}

	if plugin == nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("plugin not found: %s", idOrName))
		return
	}

	manager, err := plugins.NewManager()
	if err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to create manager: %v", err))
		return
	}

	if err := manager.Install(*plugin); err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to install plugin: %v", err))
		return
	}

	models.Respond(conn, req.ID, SuccessResult{
		Success: true,
		Message: fmt.Sprintf("plugin installed: %s", plugin.Name),
	})
}
