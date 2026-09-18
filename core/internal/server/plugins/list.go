package plugins

import (
	"fmt"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/plugins"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/dankgo/ipc"
)

func HandleList(conn *ipc.ConnWriter, req ipc.Request) {
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

	manager, err := plugins.NewManager()
	if err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to create manager: %v", err))
		return
	}

	feedback := plugins.FetchFeedback()

	result := make([]PluginInfo, len(pluginList))
	for i, p := range pluginList {
		installed, _ := manager.IsInstalled(p)
		fb := feedback[p.ID]
		info := pluginInfoFromPlugin(p)
		info.Installed = installed
		info.Upvotes = fb.Upvotes
		info.Status = fb.Status
		info.IssueURL = fb.IssueURL
		info.Similar = fb.Similar
		result[i] = info
	}

	models.Respond(conn, req.ID, result)
}
