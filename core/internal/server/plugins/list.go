package plugins

import (
	"fmt"
	"net"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/plugins"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
)

func HandleList(conn net.Conn, req models.Request) {
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
		result[i] = PluginInfo{
			ID:           p.ID,
			Name:         p.Name,
			Category:     p.Category,
			Author:       p.Author,
			Description:  p.Description,
			Repo:         p.Repo,
			Path:         p.Path,
			Capabilities: p.Capabilities,
			Compositors:  p.Compositors,
			Dependencies: p.Dependencies,
			Installed:    installed,
			FirstParty:   strings.HasPrefix(p.Repo, "https://github.com/AvengeMedia"),
			Featured:     p.Featured,
			RequiresDMS:  p.RequiresDMS,
			Upvotes:      fb.Upvotes,
			Status:       fb.Status,
			IssueURL:     fb.IssueURL,
		}
	}

	models.Respond(conn, req.ID, result)
}
