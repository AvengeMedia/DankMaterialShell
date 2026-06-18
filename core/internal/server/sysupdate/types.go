package sysupdate

type Phase string

const (
	PhaseIdle       Phase = "idle"
	PhaseRefreshing Phase = "refreshing"
	PhaseUpgrading  Phase = "upgrading"
	PhaseError      Phase = "error"
)

type RepoKind string

const (
	RepoSystem  RepoKind = "system"
	RepoAUR     RepoKind = "aur"
	RepoFlatpak RepoKind = "flatpak"
	RepoOSTree  RepoKind = "ostree"
)

type ErrorCode string

const (
	ErrCodeNone           ErrorCode = ""
	ErrCodeNoBackend      ErrorCode = "no-backend"
	ErrCodeBusy           ErrorCode = "busy"
	ErrCodeBackendFailed  ErrorCode = "backend-failed"
	ErrCodeTimeout        ErrorCode = "timeout"
	ErrCodeCancelled      ErrorCode = "cancelled"
	ErrCodeInvalidRequest ErrorCode = "invalid-request"
)

type Package struct {
	Name         string   `json:"name"`
	Repo         RepoKind `json:"repo"`
	Backend      string   `json:"backend"`
	FromVersion  string   `json:"fromVersion,omitempty"`
	ToVersion    string   `json:"toVersion,omitempty"`
	SizeBytes    int64    `json:"sizeBytes,omitempty"`
	ChangelogURL string   `json:"changelogUrl,omitempty"`
	Ref          string   `json:"-"`
}

type BackendInfo struct {
	ID             string   `json:"id"`
	DisplayName    string   `json:"displayName"`
	Repo           RepoKind `json:"repo"`
	NeedsAuth      bool     `json:"needsAuth"`
	RunsInTerminal bool     `json:"runsInTerminal"`
}

type ErrorInfo struct {
	Code    ErrorCode `json:"code,omitempty"`
	Message string    `json:"message,omitempty"`
	Hint    string    `json:"hint,omitempty"`
}

type State struct {
	Phase            Phase         `json:"phase"`
	Distro           string        `json:"distro,omitempty"`
	DistroPretty     string        `json:"distroPretty,omitempty"`
	Backends         []BackendInfo `json:"backends"`
	Packages         []Package     `json:"packages"`
	Count            int           `json:"count"`
	IntervalSeconds  int           `json:"intervalSeconds"`
	LastCheckUnix    int64         `json:"lastCheckUnix,omitempty"`
	LastSuccessUnix  int64         `json:"lastSuccessUnix,omitempty"`
	NextCheckUnix    int64         `json:"nextCheckUnix,omitempty"`
	OperationID      string        `json:"operationId,omitempty"`
	OperationStarted int64         `json:"operationStartedUnix,omitempty"`
	RecentLog        []string      `json:"recentLog,omitempty"`
	Error            *ErrorInfo    `json:"error,omitempty"`
}

type UpgradeOptions struct {
	IncludeFlatpak bool
	IncludeAUR     bool
	DryRun         bool
	UseSudo        bool
	AttachStdio    bool
	CustomCommand  string
	Terminal       string
	Targets        []Package
}

type RefreshOptions struct {
	Force bool
}
