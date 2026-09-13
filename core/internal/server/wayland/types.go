package wayland

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"sync"
	"sync/atomic"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/errdefs"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/geolocation"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/icc"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/screenshot"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
	"github.com/AvengeMedia/dankgo/syncmap"
	wlclient "github.com/AvengeMedia/dankgo/wayland/client"
	"github.com/godbus/dbus/v5"
)

type GammaState int

const (
	StateNormal GammaState = iota
	StateTransition
	StateStatic
)

type Config struct {
	Outputs           []string
	LowTemp           int
	HighTemp          int
	Latitude          *float64
	Longitude         *float64
	UseIPLocation     bool
	ManualSunrise     *time.Time
	ManualSunset      *time.Time
	ManualDuration    *time.Duration
	Gamma             float64
	Contrast          float64
	Enabled           bool
	ElevationTwilight float64
	ElevationDaylight float64
	ICCProfiles       map[string]string `json:"iccProfiles,omitempty"` // outputName -> ICC file path
	OutputTemps       map[string]int    `json:"outputTemps,omitempty"` // outputName -> per-output color temperature (K)
}

type State struct {
	Config         Config                `json:"config"`
	CurrentTemp    int                   `json:"currentTemp"`
	NextTransition time.Time             `json:"nextTransition"`
	SunriseTime    time.Time             `json:"sunriseTime"`
	SunsetTime     time.Time             `json:"sunsetTime"`
	DawnTime       time.Time             `json:"dawnTime"`
	NightTime      time.Time             `json:"nightTime"`
	IsDay          bool                  `json:"isDay"`
	SunPosition    float64               `json:"sunPosition"`
	ICCProfiles    map[string]*ICCStatus `json:"iccProfiles,omitempty"` // outputName -> status
	OutputTemps    map[string]int        `json:"outputTemps,omitempty"` // outputName -> current temp
}

// ICCStatus represents the ICC profile status for a single output.
type ICCStatus struct {
	Path        string `json:"path"`        // ICC file path
	Description string `json:"description"` // ICC profile description
	Version     string `json:"version"`     // ICC version
	ColorSpace  string `json:"colorSpace"`  // e.g., "RGB"
	HasVCGT     bool   `json:"hasVCGT"`     // has video card gamma table
	Active      bool   `json:"active"`      // currently applied

	// Descriptive profile metadata, surfaced in the UI so a profile can be
	// identified without leaving the settings page.
	Class          string  `json:"class,omitempty"`          // "mntr", "scnr", "prtr"
	TRCKind        string  `json:"trcKind,omitempty"`        // "identity", "gamma", "table", "mixed"
	TRCGamma       float64 `json:"trcGamma,omitempty"`       // when TRCKind is "gamma"
	TRCEntries     int     `json:"trcEntries,omitempty"`     // when TRCKind is "table"
	VCGTChannels   int     `json:"vcgtChannels,omitempty"`   // channels in the video card gamma table
	VCGTEntries    int     `json:"vcgtEntries,omitempty"`    // entries per channel
	WhitePointX    float64 `json:"whitePointX,omitempty"`    // chromaticity x
	WhitePointY    float64 `json:"whitePointY,omitempty"`    // chromaticity y
	WhitePointCCT  int     `json:"whitePointCCT,omitempty"`  // correlated color temperature (K)
	WhitePointName string  `json:"whitePointName,omitempty"` // "D50", "D65", ...
	Size           int64   `json:"size,omitempty"`           // profile file size in bytes
	Modified       int64   `json:"modified,omitempty"`       // profile file mtime, unix seconds
}

type cmd struct {
	fn func()
}

type sunSchedule struct {
	times         SunTimes
	condition     SunCondition
	dawnStepTime  time.Duration
	nightStepTime time.Duration
	calcDay       time.Time
}

type Manager struct {
	config      Config
	configMutex sync.RWMutex
	state       *State
	stateMutex  sync.RWMutex

	display             wlclient.WaylandDisplay
	ctx                 *wlclient.Context
	registry            *wlclient.Registry
	gammaControl        any
	availableOutputs    []*wlclient.Output
	availOutputsMu      sync.RWMutex
	outputRegNames      syncmap.Map[uint32, uint32]
	outputNames         syncmap.Map[uint32, string] // outputID -> wl_output name string (e.g., "DP-1")
	outputs             syncmap.Map[uint32, *outputState]
	controlsInitialized bool
	connectionDead      atomic.Bool

	cmdq  chan cmd
	alive bool

	stopChan      chan struct{}
	updateTrigger chan struct{}
	wg            sync.WaitGroup

	schedule      sunSchedule
	scheduleMutex sync.RWMutex
	gammaState    GammaState

	cachedIPLat   *float64
	cachedIPLon   *float64
	locationMutex sync.RWMutex

	subscribers  syncmap.Map[string, chan State]
	dirty        chan struct{}
	notifierWg   sync.WaitGroup
	lastNotified *State

	dbusConn   *dbus.Conn
	dbusSignal chan *dbus.Signal

	geoClient geolocation.Client
}

type outputState struct {
	id           uint32
	registryName uint32
	output       *wlclient.Output
	gammaControl any
	rampSize     uint32
	failed       bool
	isVirtual    bool
	retryCount   int
	lastFailTime time.Time
	lastTemp     int
	lastGamma    float64
	lastContrast float64
	iccPath      string       // path to ICC profile file, empty if not set
	iccProfile   *icc.Profile // cached parsed ICC profile (nil if not loaded)
	outputTemp   int          // per-output color temperature (K), 0 = use global temp
}

func DefaultConfig() Config {
	return Config{
		Outputs:           []string{},
		LowTemp:           4000,
		HighTemp:          6500,
		Gamma:             1.0,
		Contrast:          1.0,
		Enabled:           false,
		ElevationTwilight: -6.0,
		ElevationDaylight: 3.0,
	}
}

// DMSConfigDir returns the compositor-specific DMS config directory, matching
// the layout used by the shell and `dms setup` (niri/dms, hypr/dms, mango/dms).
func DMSConfigDir() string {
	return filepath.Join(utils.XDGConfigHome(), compositorConfigDirName(), "dms")
}

// ICCProfilesDir returns the directory scanned for ICC profile files.
func ICCProfilesDir() string {
	return filepath.Join(DMSConfigDir(), "icc")
}

// compositorConfigDirName maps the running compositor to its DMS config
// directory name. Compositors without a DMS config layout fall back to niri.
func compositorConfigDirName() string {
	switch screenshot.DetectCompositor() {
	case screenshot.CompositorHyprland:
		return "hypr"
	case screenshot.CompositorMango:
		return "mango"
	default:
		return "niri"
	}
}

// getConfigPath returns the path to the wayland config file.
func getConfigPath() (string, error) {
	dir := DMSConfigDir()
	if !filepath.IsAbs(dir) {
		return "", fmt.Errorf("could not determine DMS config directory")
	}
	return filepath.Join(dir, "wayland.json"), nil
}

// LoadConfig reads the wayland config from disk, falling back to DefaultConfig.
func LoadConfig() Config {
	path, err := getConfigPath()
	if err != nil {
		return DefaultConfig()
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return DefaultConfig()
	}
	var cfg Config
	if err := json.Unmarshal(data, &cfg); err != nil {
		return DefaultConfig()
	}
	// Ensure defaults are set for missing fields (keep in sync with DefaultConfig)
	def := DefaultConfig()
	if cfg.HighTemp == 0 {
		cfg.HighTemp = def.HighTemp
	}
	if cfg.LowTemp == 0 {
		cfg.LowTemp = def.LowTemp
	}
	if cfg.Gamma == 0 {
		cfg.Gamma = def.Gamma
	}
	if cfg.Contrast == 0 {
		cfg.Contrast = def.Contrast
	}
	if cfg.ElevationTwilight == 0 {
		cfg.ElevationTwilight = def.ElevationTwilight
	}
	if cfg.ElevationDaylight == 0 {
		cfg.ElevationDaylight = def.ElevationDaylight
	}
	if cfg.Outputs == nil {
		cfg.Outputs = []string{}
	}
	if cfg.ICCProfiles == nil {
		cfg.ICCProfiles = make(map[string]string)
	}
	if cfg.OutputTemps == nil {
		cfg.OutputTemps = make(map[string]int)
	}
	return cfg
}

// SaveConfig writes the wayland config to disk.
func SaveConfig(cfg Config) error {
	path, err := getConfigPath()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0o644)
}

func (c *Config) Validate() error {
	if c.LowTemp < 1000 || c.LowTemp > 10000 {
		return errdefs.ErrInvalidTemperature
	}
	if c.HighTemp < 1000 || c.HighTemp > 10000 {
		return errdefs.ErrInvalidTemperature
	}
	if c.LowTemp > c.HighTemp {
		return errdefs.ErrInvalidTemperature
	}
	if c.Gamma <= 0 || c.Gamma > 10 {
		return errdefs.ErrInvalidGamma
	}
	if c.Contrast < 0.5 || c.Contrast > 2 {
		return errdefs.ErrInvalidContrast
	}
	if c.Latitude != nil && (math.Abs(*c.Latitude) > 90) {
		return errdefs.ErrInvalidLocation
	}
	if c.Longitude != nil && (math.Abs(*c.Longitude) > 180) {
		return errdefs.ErrInvalidLocation
	}
	if (c.Latitude != nil) != (c.Longitude != nil) {
		return errdefs.ErrInvalidLocation
	}
	if (c.ManualSunrise != nil) != (c.ManualSunset != nil) {
		return errdefs.ErrInvalidManualTimes
	}
	if c.ManualDuration != nil && (*c.ManualDuration < 0 || *c.ManualDuration > 6*time.Hour) {
		return errdefs.ErrInvalidDuration
	}
	return nil
}

func (m *Manager) GetState() State {
	m.stateMutex.RLock()
	defer m.stateMutex.RUnlock()
	if m.state == nil {
		return State{}
	}
	return *m.state
}

func (m *Manager) Subscribe(id string) chan State {
	ch := make(chan State, 64)
	m.subscribers.Store(id, ch)
	return ch
}

func (m *Manager) Unsubscribe(id string) {
	if val, ok := m.subscribers.LoadAndDelete(id); ok {
		close(val)
	}
}

func (m *Manager) notifySubscribers() {
	select {
	case m.dirty <- struct{}{}:
	default:
	}
}

func stateChanged(old, new *State) bool {
	if old == nil || new == nil {
		return true
	}
	if old.CurrentTemp != new.CurrentTemp {
		return true
	}
	if old.IsDay != new.IsDay {
		return true
	}
	if !old.NextTransition.Equal(new.NextTransition) {
		return true
	}
	if !old.SunriseTime.Equal(new.SunriseTime) {
		return true
	}
	if !old.SunsetTime.Equal(new.SunsetTime) {
		return true
	}
	if old.Config.Enabled != new.Config.Enabled {
		return true
	}
	if old.Config.Gamma != new.Config.Gamma || old.Config.Contrast != new.Config.Contrast {
		return true
	}
	if old.SunPosition != new.SunPosition {
		return true
	}
	return false
}
