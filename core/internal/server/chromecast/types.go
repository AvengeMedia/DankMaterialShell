package chromecast

// Protocol identifies how a device is reached.
const (
	ProtocolChromecast = "chromecast" // Google Cast (_googlecast._tcp)
	ProtocolAirplay    = "airplay"    // AirPlay 2 (_airplay._tcp)
)

// Device is a Cast-compatible device discovered on the LAN (Chromecast or
// AirPlay).
type Device struct {
	ID       string `json:"id"`    // stable identifier: device UUID/id, or host:port when none is advertised
	Name     string `json:"name"`  // friendly name
	Model    string `json:"model"` // device model, e.g. "Chromecast Ultra" or "Hisense ..."
	Host     string `json:"host"`  // IPv4 address used to connect
	Port     int    `json:"port"`
	Protocol string `json:"protocol"` // ProtocolChromecast | ProtocolAirplay
}

// Playback describes what the connected device is currently playing.
type Playback struct {
	State       string  `json:"state"` // PLAYING, PAUSED, BUFFERING, IDLE
	Title       string  `json:"title"`
	Subtitle    string  `json:"subtitle"`
	Artist      string  `json:"artist"`
	AppName     string  `json:"appName"` // receiver app, e.g. "Default Media Receiver"
	CurrentTime float64 `json:"currentTime"`
	Duration    float64 `json:"duration"`
	Volume      float64 `json:"volume"` // 0.0–1.0
	Muted       bool    `json:"muted"`
}

// State is the full chromecast service state pushed to subscribers.
type State struct {
	Discovering   bool      `json:"discovering"`
	Devices       []Device  `json:"devices"`
	Connected     bool      `json:"connected"`
	ActiveDevice  *Device   `json:"activeDevice,omitempty"`
	Playback      *Playback `json:"playback,omitempty"`
	Screencasting bool      `json:"screencasting"`
	PreferredID   string    `json:"preferredId"`
}
