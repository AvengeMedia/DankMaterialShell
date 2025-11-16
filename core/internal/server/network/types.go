package network

import (
	"sync"

	"github.com/AvengeMedia/DankMaterialShell/core/pkg/syncmap"
	"github.com/godbus/dbus/v5"
)

type NetworkStatus string

const (
	StatusDisconnected NetworkStatus = "disconnected"
	StatusEthernet     NetworkStatus = "ethernet"
	StatusWiFi         NetworkStatus = "wifi"
	StatusVPN          NetworkStatus = "vpn"
)

type ConnectionPreference string

const (
	PreferenceAuto     ConnectionPreference = "auto"
	PreferenceWiFi     ConnectionPreference = "wifi"
	PreferenceEthernet ConnectionPreference = "ethernet"
)

type WiFiNetwork struct {
	SSID        string `json:"ssid"`
	BSSID       string `json:"bssid"`
	Signal      uint8  `json:"signal"`
	Secured     bool   `json:"secured"`
	Enterprise  bool   `json:"enterprise"`
	Connected   bool   `json:"connected"`
	Saved       bool   `json:"saved"`
	Autoconnect bool   `json:"autoconnect"`
	Frequency   uint32 `json:"frequency"`
	Mode        string `json:"mode"`
	Rate        uint32 `json:"rate"`
	Channel     uint32 `json:"channel"`
}

type VPNProfile struct {
	Name        string `json:"name"`
	UUID        string `json:"uuid"`
	Type        string `json:"type"`
	ServiceType string `json:"serviceType"`
}

type VPNActive struct {
	Name   string `json:"name"`
	UUID   string `json:"uuid"`
	Device string `json:"device,omitempty"`
	State  string `json:"state,omitempty"`
	Type   string `json:"type"`
	Plugin string `json:"serviceType"`
}

type VPNState struct {
	Profiles []VPNProfile `json:"profiles"`
	Active   []VPNActive  `json:"activeConnections"`
}

type NetworkState struct {
	Backend                string               `json:"backend"`
	NetworkStatus          NetworkStatus        `json:"networkStatus"`
	Preference             ConnectionPreference `json:"preference"`
	EthernetIP             string               `json:"ethernetIP"`
	EthernetDevice         string               `json:"ethernetDevice"`
	EthernetConnected      bool                 `json:"ethernetConnected"`
	EthernetConnectionUuid string               `json:"ethernetConnectionUuid"`
	WiFiIP                 string               `json:"wifiIP"`
	WiFiDevice             string               `json:"wifiDevice"`
	WiFiConnected          bool                 `json:"wifiConnected"`
	WiFiEnabled            bool                 `json:"wifiEnabled"`
	WiFiSSID               string               `json:"wifiSSID"`
	WiFiBSSID              string               `json:"wifiBSSID"`
	WiFiSignal             uint8                `json:"wifiSignal"`
	WiFiNetworks           []WiFiNetwork        `json:"wifiNetworks"`
	WiredConnections       []WiredConnection    `json:"wiredConnections"`
	VPNProfiles            []VPNProfile         `json:"vpnProfiles"`
	VPNActive              []VPNActive          `json:"vpnActive"`
	IsConnecting           bool                 `json:"isConnecting"`
	ConnectingSSID         string               `json:"connectingSSID"`
	LastError              string               `json:"lastError"`
}

type ConnectionRequest struct {
	SSID              string `json:"ssid"`
	Password          string `json:"password,omitempty"`
	Username          string `json:"username,omitempty"`
	AnonymousIdentity string `json:"anonymousIdentity,omitempty"`
	DomainSuffixMatch string `json:"domainSuffixMatch,omitempty"`
	Interactive       bool   `json:"interactive,omitempty"`
}

type WiredConnection struct {
	Path     dbus.ObjectPath `json:"path"`
	ID       string          `json:"id"`
	UUID     string          `json:"uuid"`
	Type     string          `json:"type"`
	IsActive bool            `json:"isActive"`
}

type PriorityUpdate struct {
	Preference ConnectionPreference `json:"preference"`
}

type Manager struct {
	backend               Backend
	state                 *NetworkState
	stateMutex            sync.RWMutex
	subscribers           syncmap.Map[string, chan NetworkState]
	stopChan              chan struct{}
	dirty                 chan struct{}
	notifierWg            sync.WaitGroup
	lastNotifiedState     *NetworkState
	credentialSubscribers syncmap.Map[string, chan CredentialPrompt]
}

type EventType string

const (
	EventStateChanged    EventType = "state_changed"
	EventNetworksUpdated EventType = "networks_updated"
	EventConnecting      EventType = "connecting"
	EventConnected       EventType = "connected"
	EventDisconnected    EventType = "disconnected"
	EventError           EventType = "error"
)

type NetworkEvent struct {
	Type EventType    `json:"type"`
	Data NetworkState `json:"data"`
}

type PromptRequest struct {
	Name           string   `json:"name"`
	SSID           string   `json:"ssid"`
	ConnType       string   `json:"connType"`
	VpnService     string   `json:"vpnService"`
	SettingName    string   `json:"setting"`
	Fields         []string `json:"fields"`
	Hints          []string `json:"hints"`
	Reason         string   `json:"reason"`
	ConnectionId   string   `json:"connectionId"`
	ConnectionUuid string   `json:"connectionUuid"`
	ConnectionPath string   `json:"connectionPath"`
}

type PromptReply struct {
	Secrets map[string]string `json:"secrets"`
	Save    bool              `json:"save"`
	Cancel  bool              `json:"cancel"`
}

type CredentialPrompt struct {
	Token          string   `json:"token"`
	Name           string   `json:"name"`
	SSID           string   `json:"ssid"`
	ConnType       string   `json:"connType"`
	VpnService     string   `json:"vpnService"`
	Setting        string   `json:"setting"`
	Fields         []string `json:"fields"`
	Hints          []string `json:"hints"`
	Reason         string   `json:"reason"`
	ConnectionId   string   `json:"connectionId"`
	ConnectionUuid string   `json:"connectionUuid"`
}

type NetworkInfoResponse struct {
	SSID  string        `json:"ssid"`
	Bands []WiFiNetwork `json:"bands"`
}

type WiredNetworkInfoResponse struct {
	UUID   string        `json:"uuid"`
	IFace  string        `json:"iface"`
	Driver string        `json:"driver"`
	HwAddr string        `json:"hwAddr"`
	Speed  string        `json:"speed"`
	IPv4   WiredIPConfig `json:"IPv4s"`
	IPv6   WiredIPConfig `json:"IPv6s"`
}

type WiredIPConfig struct {
	IPs     []string `json:"ips"`
	Gateway string   `json:"gateway"`
	DNS     string   `json:"dns"`
}
