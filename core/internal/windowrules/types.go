package windowrules

type MatchCriteria struct {
	AppID              string `json:"appId,omitempty"`
	Title              string `json:"title,omitempty"`
	IsFloating         *bool  `json:"isFloating,omitempty"`
	IsActive           *bool  `json:"isActive,omitempty"`
	IsFocused          *bool  `json:"isFocused,omitempty"`
	IsActiveInColumn   *bool  `json:"isActiveInColumn,omitempty"`
	IsWindowCastTarget *bool  `json:"isWindowCastTarget,omitempty"`
	IsUrgent           *bool  `json:"isUrgent,omitempty"`
	AtStartup          *bool  `json:"atStartup,omitempty"`
	XWayland           *bool  `json:"xwayland,omitempty"`
	Fullscreen         *bool  `json:"fullscreen,omitempty"`
	Pinned             *bool  `json:"pinned,omitempty"`
	Initialised        *bool  `json:"initialised,omitempty"`
}

type Actions struct {
	Opacity              *float64 `json:"opacity,omitempty"`
	OpenFloating         *bool    `json:"openFloating,omitempty"`
	OpenMaximized        *bool    `json:"openMaximized,omitempty"`
	OpenMaximizedToEdges *bool    `json:"openMaximizedToEdges,omitempty"`
	OpenFullscreen       *bool    `json:"openFullscreen,omitempty"`
	OpenFocused          *bool    `json:"openFocused,omitempty"`
	OpenOnOutput         string   `json:"openOnOutput,omitempty"`
	OpenOnWorkspace      string   `json:"openOnWorkspace,omitempty"`
	DefaultColumnWidth   string   `json:"defaultColumnWidth,omitempty"`
	DefaultWindowHeight  string   `json:"defaultWindowHeight,omitempty"`
	VariableRefreshRate  *bool    `json:"variableRefreshRate,omitempty"`
	BlockOutFrom         string   `json:"blockOutFrom,omitempty"`
	DefaultColumnDisplay string   `json:"defaultColumnDisplay,omitempty"`
	ScrollFactor         *float64 `json:"scrollFactor,omitempty"`
	CornerRadius         *int     `json:"cornerRadius,omitempty"`
	ClipToGeometry       *bool    `json:"clipToGeometry,omitempty"`
	TiledState           *bool    `json:"tiledState,omitempty"`
	MinWidth             *int     `json:"minWidth,omitempty"`
	MaxWidth             *int     `json:"maxWidth,omitempty"`
	MinHeight            *int     `json:"minHeight,omitempty"`
	MaxHeight            *int     `json:"maxHeight,omitempty"`
	BorderColor          string   `json:"borderColor,omitempty"`
	FocusRingColor       string   `json:"focusRingColor,omitempty"`
	FocusRingOff         *bool    `json:"focusRingOff,omitempty"`
	BorderOff            *bool    `json:"borderOff,omitempty"`
	DrawBorderWithBg     *bool    `json:"drawBorderWithBackground,omitempty"`
	Size                 string   `json:"size,omitempty"`
	Move                 string   `json:"move,omitempty"`
	Monitor              string   `json:"monitor,omitempty"`
	Workspace            string   `json:"workspace,omitempty"`
	Tile                 *bool    `json:"tile,omitempty"`
	NoFocus              *bool    `json:"nofocus,omitempty"`
	NoBorder             *bool    `json:"noborder,omitempty"`
	NoShadow             *bool    `json:"noshadow,omitempty"`
	NoDim                *bool    `json:"nodim,omitempty"`
	NoBlur               *bool    `json:"noblur,omitempty"`
	NoAnim               *bool    `json:"noanim,omitempty"`
	NoRounding           *bool    `json:"norounding,omitempty"`
	Pin                  *bool    `json:"pin,omitempty"`
	Opaque               *bool    `json:"opaque,omitempty"`
	ForcergbX            *bool    `json:"forcergbx,omitempty"`
	Idleinhibit          string   `json:"idleinhibit,omitempty"`
}

type WindowRule struct {
	ID            string        `json:"id"`
	Name          string        `json:"name,omitempty"`
	Enabled       bool          `json:"enabled"`
	MatchCriteria MatchCriteria `json:"matchCriteria"`
	Actions       Actions       `json:"actions"`
	Source        string        `json:"source,omitempty"`
}

type DMSRulesStatus struct {
	Exists          bool   `json:"exists"`
	Included        bool   `json:"included"`
	IncludePosition int    `json:"includePosition"`
	TotalIncludes   int    `json:"totalIncludes"`
	RulesAfterDMS   int    `json:"rulesAfterDms"`
	Effective       bool   `json:"effective"`
	OverriddenBy    int    `json:"overriddenBy"`
	StatusMessage   string `json:"statusMessage"`
	ConfigFormat    string `json:"configFormat,omitempty"`
	ReadOnly        bool   `json:"readOnly,omitempty"`
}

type RuleSet struct {
	Title            string          `json:"title"`
	Provider         string          `json:"provider"`
	Rules            []WindowRule    `json:"rules"`
	DMSRulesIncluded bool            `json:"dmsRulesIncluded"`
	DMSStatus        *DMSRulesStatus `json:"dmsStatus,omitempty"`
}

type Provider interface {
	Name() string
	GetRuleSet() (*RuleSet, error)
}

type WritableProvider interface {
	Provider
	SetRule(rule WindowRule) error
	RemoveRule(id string) error
	ReorderRules(ids []string) error
	GetOverridePath() string
}
