package plugins

type PluginInfo struct {
	ID           string   `json:"id"`
	Name         string   `json:"name"`
	Category     string   `json:"category,omitempty"`
	Author       string   `json:"author,omitempty"`
	Description  string   `json:"description,omitempty"`
	Repo         string   `json:"repo,omitempty"`
	Path         string   `json:"path,omitempty"`
	Capabilities []string `json:"capabilities,omitempty"`
	Compositors  []string `json:"compositors,omitempty"`
	Dependencies []string `json:"dependencies,omitempty"`
	Installed    bool     `json:"installed,omitempty"`
	FirstParty   bool     `json:"firstParty,omitempty"`
	Featured     bool     `json:"featured,omitempty"`
	Note         string   `json:"note,omitempty"`
	HasUpdate    bool     `json:"hasUpdate,omitempty"`
	RequiresDMS  string   `json:"requires_dms,omitempty"`
	Upvotes      int      `json:"upvotes,omitempty"`
	Status       []string `json:"status,omitempty"`
	IssueURL     string   `json:"issueUrl,omitempty"`
}

type SuccessResult struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}
