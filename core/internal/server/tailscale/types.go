package tailscale

// TailscaleState represents the current state of the Tailscale daemon.
type TailscaleState struct {
	Connected      bool   `json:"connected"`
	Version        string `json:"version"`
	BackendState   string `json:"backendState"`
	MagicDNSSuffix string `json:"magicDnsSuffix"`
	TailnetName    string `json:"tailnetName"`
	Self           Peer   `json:"self"`
	Peers          []Peer `json:"peers"`
}

// Peer represents a single node in the Tailscale network.
type Peer struct {
	ID            string   `json:"id"`
	Hostname      string   `json:"hostname"`
	DNSName       string   `json:"dnsName"`
	TailscaleIP   string   `json:"tailscaleIp"`
	TailscaleIPv6 string   `json:"tailscaleIpv6,omitempty"`
	OS            string   `json:"os"`
	Online        bool     `json:"online"`
	LastSeen      string   `json:"lastSeen,omitempty"`
	ExitNode      bool     `json:"exitNode"`
	Tags          []string `json:"tags,omitempty"`
	Owner         string   `json:"owner"`
	Relay         string   `json:"relay,omitempty"`
	Active        bool     `json:"active"`
	RxBytes       int64    `json:"rxBytes"`
	TxBytes       int64    `json:"txBytes"`
}
