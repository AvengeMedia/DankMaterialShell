package plugins

import (
	"fmt"
	"net"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/plugins"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
)

func HandleListInstalled(conn net.Conn, req models.Request) {
	manager, err := plugins.NewManager()
	if err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to create manager: %v", err))
		return
	}

	installedNames, err := manager.ListInstalled()
	if err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to list installed plugins: %v", err))
		return
	}

	registry, err := plugins.NewRegistry()
	if err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to create registry: %v", err))
		return
	}

	allPlugins, err := registry.List()
	if err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to list plugins: %v", err))
		return
	}

	pluginMap := make(map[string]plugins.Plugin)
	for _, p := range allPlugins {
		pluginMap[p.ID] = p
	}

	result := make([]PluginInfo, 0, len(installedNames))
	for _, id := range installedNames {
		if plugin, ok := pluginMap[id]; ok {
			hasUpdate := false
			if hasUpdates, err := manager.HasUpdates(id, plugin); err == nil {
				hasUpdate = hasUpdates
			}

			info := pluginInfoFromPlugin(plugin)
			info.HasUpdate = hasUpdate
			result = append(result, info)
		} else {
			result = append(result, PluginInfo{
				ID:   id,
				Name: id,
				Note: "not in registry",
			})
		}
	}

	SortPluginInfoByFirstParty(result)

	models.Respond(conn, req.ID, result)
}
