package plugins

import (
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/plugins"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	git "github.com/go-git/go-git/v6"
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

			diffURL := getGitDiffURL(manager.GetPluginsDir(), plugin.ID, plugin.Repo)

			result = append(result, PluginInfo{
				ID:           plugin.ID,
				Name:         plugin.Name,
				Category:     plugin.Category,
				Author:       plugin.Author,
				Description:  plugin.Description,
				Repo:         plugin.Repo,
				Path:         plugin.Path,
				Capabilities: plugin.Capabilities,
				Compositors:  plugin.Compositors,
				Dependencies: plugin.Dependencies,
				FirstParty:   strings.HasPrefix(plugin.Repo, "https://github.com/AvengeMedia"),
				HasUpdate:    hasUpdate,
				RequiresDMS:  plugin.RequiresDMS,
				DiffURL:      diffURL,
			})
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

func getGitDiffURL(pluginsDir string, pluginID string, repoURL string) string {
	if repoURL == "" {
		return ""
	}

	repoURL = strings.TrimSuffix(repoURL, ".git")

	// Standalone path
	pluginPath := filepath.Join(pluginsDir, pluginID)
	metaPath := pluginPath + ".meta"

	// If metadata file exists, it's a monorepo
	if _, err := os.Stat(metaPath); err == nil {
		reposDir := filepath.Join(pluginsDir, ".repos")
		parts := strings.Split(repoURL, "/")
		repoName := parts[len(parts)-1]
		pluginPath = filepath.Join(reposDir, repoName)
	}

	repo, err := git.PlainOpen(pluginPath)
	if err != nil {
		return repoURL
	}

	head, err := repo.Head()
	if err != nil {
		return repoURL
	}
	localHash := head.Hash().String()

	remote, err := repo.Remote("origin")
	if err != nil {
		return repoURL
	}

	refs, err := remote.List(&git.ListOptions{})
	if err != nil {
		return repoURL
	}

	var remoteHead string
	for _, ref := range refs {
		if ref.Name().IsBranch() {
			if ref.Name().Short() == "main" || ref.Name().Short() == "master" {
				remoteHead = ref.Hash().String()
				break
			}
		}
	}

	if remoteHead != "" && localHash != "" && localHash != remoteHead {
		return fmt.Sprintf("%s/compare/%s...%s", repoURL, localHash[:7], remoteHead[:7])
	}

	return repoURL
}
