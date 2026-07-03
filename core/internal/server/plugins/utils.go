package plugins

import (
	"net/url"
	"sort"
	"strings"

	coreplugins "github.com/AvengeMedia/DankMaterialShell/core/internal/plugins"
)

func pluginInfoFromPlugin(plugin coreplugins.Plugin) PluginInfo {
	return PluginInfo{
		ID:           plugin.ID,
		Name:         plugin.Name,
		Category:     plugin.Category,
		Author:       plugin.Author,
		Description:  plugin.Description,
		Repo:         plugin.Repo,
		Path:         plugin.Path,
		Screenshot:   normalizeScreenshotURL(plugin.Screenshot),
		Capabilities: plugin.Capabilities,
		Compositors:  plugin.Compositors,
		Dependencies: plugin.Dependencies,
		FirstParty:   isFirstPartyRepo(plugin.Repo),
		Featured:     plugin.Featured,
		RequiresDMS:  plugin.RequiresDMS,
	}
}

func isFirstPartyRepo(repo string) bool {
	return strings.HasPrefix(repo, "https://github.com/AvengeMedia")
}

func normalizeScreenshotURL(raw string) string {
	screenshotURL := strings.TrimSpace(raw)
	if screenshotURL == "" {
		return ""
	}

	parsed, err := url.Parse(screenshotURL)
	if err != nil {
		return screenshotURL
	}

	host := strings.ToLower(parsed.Host)
	if host != "github.com" && host != "www.github.com" {
		return screenshotURL
	}

	parts := strings.Split(strings.Trim(parsed.EscapedPath(), "/"), "/")
	if len(parts) < 5 || (parts[2] != "blob" && parts[2] != "raw") {
		return screenshotURL
	}

	rawParts := append([]string{parts[0], parts[1], parts[3]}, parts[4:]...)
	return "https://raw.githubusercontent.com/" + strings.Join(rawParts, "/")
}

func SortPluginInfoByFirstParty(pluginInfos []PluginInfo) {
	sort.SliceStable(pluginInfos, func(i, j int) bool {
		isFirstPartyI := isFirstPartyRepo(pluginInfos[i].Repo)
		isFirstPartyJ := isFirstPartyRepo(pluginInfos[j].Repo)
		if isFirstPartyI != isFirstPartyJ {
			return isFirstPartyI
		}
		return false
	})
}
