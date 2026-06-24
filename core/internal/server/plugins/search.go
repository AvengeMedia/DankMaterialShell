package plugins

import (
	"fmt"
	"net"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/plugins"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
)

func HandleSearch(conn net.Conn, req models.Request) {
	query, ok := models.Get[string](req, "query")
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'query' parameter")
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

	searchResults := plugins.FuzzySearch(query, pluginList)

	if category := models.GetOr(req, "category", ""); category != "" {
		searchResults = plugins.FilterByCategory(category, searchResults)
	}

	if compositor := models.GetOr(req, "compositor", ""); compositor != "" {
		searchResults = plugins.FilterByCompositor(compositor, searchResults)
	}

	if capability := models.GetOr(req, "capability", ""); capability != "" {
		searchResults = plugins.FilterByCapability(capability, searchResults)
	}

	searchResults = plugins.SortByFirstParty(searchResults)

	manager, err := plugins.NewManager()
	if err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to create manager: %v", err))
		return
	}

	result := make([]PluginInfo, len(searchResults))
	for i, p := range searchResults {
		installed, _ := manager.IsInstalled(p)
		info := pluginInfoFromPlugin(p)
		info.Installed = installed
		result[i] = info
	}

	models.Respond(conn, req.ID, result)
}
