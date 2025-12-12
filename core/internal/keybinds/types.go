package keybinds

type Keybind struct {
	Key           string   `json:"key"`
	Description   string   `json:"desc"`
	Action        string   `json:"action,omitempty"`
	Subcategory   string   `json:"subcat,omitempty"`
	Source        string   `json:"source,omitempty"`
	HideOnOverlay bool     `json:"hideOnOverlay,omitempty"`
	CooldownMs    int      `json:"cooldownMs,omitempty"`
	Conflict      *Keybind `json:"conflict,omitempty"`
}

type DMSBindsStatus struct {
	Exists          bool   `json:"exists"`
	Included        bool   `json:"included"`
	IncludePosition int    `json:"includePosition"`
	TotalIncludes   int    `json:"totalIncludes"`
	BindsAfterDMS   int    `json:"bindsAfterDms"`
	Effective       bool   `json:"effective"`
	OverriddenBy    int    `json:"overriddenBy"`
	StatusMessage   string `json:"statusMessage"`
}

type CheatSheet struct {
	Title            string               `json:"title"`
	Provider         string               `json:"provider"`
	Binds            map[string][]Keybind `json:"binds"`
	DMSBindsIncluded bool                 `json:"dmsBindsIncluded"`
	DMSStatus        *DMSBindsStatus      `json:"dmsStatus,omitempty"`
}

type Provider interface {
	Name() string
	GetCheatSheet() (*CheatSheet, error)
}

type WritableProvider interface {
	Provider
	SetBind(key, action, description string, options map[string]any) error
	RemoveBind(key string) error
	GetOverridePath() string
}
