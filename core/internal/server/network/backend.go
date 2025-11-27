package network

type Backend interface {
	Initialize() error
	Close()

	GetWiFiEnabled() (bool, error)
	SetWiFiEnabled(enabled bool) error

	ScanWiFi() error
	ScanWiFiDevice(device string) error
	GetWiFiNetworkDetails(ssid string) (*NetworkInfoResponse, error)
	GetWiFiDevices() []WiFiDevice

	ConnectWiFi(req ConnectionRequest) error
	DisconnectWiFi() error
	DisconnectWiFiDevice(device string) error
	ForgetWiFiNetwork(ssid string) error
	SetWiFiAutoconnect(ssid string, autoconnect bool) error

	GetWiredConnections() ([]WiredConnection, error)
	GetWiredNetworkDetails(uuid string) (*WiredNetworkInfoResponse, error)
	ConnectEthernet() error
	DisconnectEthernet() error
	ActivateWiredConnection(uuid string) error

	ListVPNProfiles() ([]VPNProfile, error)
	ListActiveVPN() ([]VPNActive, error)
	ConnectVPN(uuidOrName string, singleActive bool) error
	DisconnectVPN(uuidOrName string) error
	DisconnectAllVPN() error
	ClearVPNCredentials(uuidOrName string) error

	GetCurrentState() (*BackendState, error)

	StartMonitoring(onStateChange func()) error
	StopMonitoring()

	GetPromptBroker() PromptBroker
	SetPromptBroker(broker PromptBroker) error
	SubmitCredentials(token string, secrets map[string]string, save bool) error
	CancelCredentials(token string) error
}

type BackendState struct {
	Backend                string
	NetworkStatus          NetworkStatus
	EthernetIP             string
	EthernetDevice         string
	EthernetConnected      bool
	EthernetConnectionUuid string
	WiFiIP                 string
	WiFiDevice             string
	WiFiConnected          bool
	WiFiEnabled            bool
	WiFiSSID               string
	WiFiBSSID              string
	WiFiSignal             uint8
	WiFiNetworks           []WiFiNetwork
	WiFiDevices            []WiFiDevice
	WiredConnections       []WiredConnection
	VPNProfiles            []VPNProfile
	VPNActive              []VPNActive
	IsConnecting           bool
	ConnectingSSID         string
	ConnectingDevice       string
	IsConnectingVPN        bool
	ConnectingVPNUUID      string
	LastError              string
}
