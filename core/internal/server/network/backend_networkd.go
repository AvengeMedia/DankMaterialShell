package network

import (
	"encoding/json"
	"fmt"
	"net"
	"strings"
	"sync"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/godbus/dbus/v5"
)

const (
	networkdBusName      = "org.freedesktop.network1"
	networkdManagerPath  = "/org/freedesktop/network1"
	networkdManagerIface = "org.freedesktop.network1.Manager"
	networkdLinkIface    = "org.freedesktop.network1.Link"
)

type linkInfo struct {
	ifindex  int32
	name     string
	path     dbus.ObjectPath
	opState  string
	linkType string
}

func (l *linkInfo) isWired() bool {
	if l.linkType != "" {
		return l.linkType == "ether"
	}
	if looksVirtual(l.name) || strings.HasPrefix(l.name, "wlan") || strings.HasPrefix(l.name, "wlp") {
		return false
	}
	return true
}

func (l *linkInfo) isWireless() bool {
	if l.linkType != "" {
		return l.linkType == "wlan"
	}
	return strings.HasPrefix(l.name, "wlan") || strings.HasPrefix(l.name, "wlp")
}

func looksVirtual(name string) bool {
	virtualPrefixes := []string{
		"lo", "docker", "veth", "virbr", "br-", "vnet", "tun", "tap",
		"vboxnet", "vmnet", "kube", "cni", "flannel", "cali",
	}
	for _, prefix := range virtualPrefixes {
		if strings.HasPrefix(name, prefix) {
			return true
		}
	}
	return false
}

type SystemdNetworkdBackend struct {
	conn          *dbus.Conn
	managerPath   dbus.ObjectPath
	links         map[string]*linkInfo
	linksMutex    sync.RWMutex
	state         *BackendState
	stateMutex    sync.RWMutex
	onStateChange func()
	stopChan      chan struct{}
	signals       chan *dbus.Signal
	sigWG         sync.WaitGroup
}

func NewSystemdNetworkdBackend() (*SystemdNetworkdBackend, error) {
	return &SystemdNetworkdBackend{
		managerPath: networkdManagerPath,
		links:       make(map[string]*linkInfo),
		state: &BackendState{
			Backend:      "networkd",
			WiFiNetworks: []WiFiNetwork{},
		},
		stopChan: make(chan struct{}),
	}, nil
}

func (b *SystemdNetworkdBackend) Initialize() error {
	c, err := dbus.ConnectSystemBus()
	if err != nil {
		return fmt.Errorf("connect bus: %w", err)
	}
	b.conn = c

	if err := b.enumerateLinks(); err != nil {
		c.Close()
		return fmt.Errorf("enumerate links: %w", err)
	}

	if err := b.updateState(); err != nil {
		c.Close()
		return fmt.Errorf("update initial state: %w", err)
	}

	return nil
}

func (b *SystemdNetworkdBackend) Close() {
	close(b.stopChan)
	b.StopMonitoring()

	if b.conn != nil {
		b.conn.Close()
	}
}

func (b *SystemdNetworkdBackend) enumerateLinks() error {
	obj := b.conn.Object(networkdBusName, b.managerPath)

	var links []struct {
		Ifindex int32
		Name    string
		Path    dbus.ObjectPath
	}
	err := obj.Call(networkdManagerIface+".ListLinks", 0).Store(&links)
	if err != nil {
		return fmt.Errorf("ListLinks: %w", err)
	}

	b.linksMutex.Lock()
	defer b.linksMutex.Unlock()

	for _, l := range links {
		if existing, ok := b.links[l.Name]; ok && existing.path == l.Path {
			existing.ifindex = l.Ifindex
			continue
		}
		info := &linkInfo{
			ifindex:  l.Ifindex,
			name:     l.Name,
			path:     l.Path,
			linkType: b.fetchLinkType(l.Path),
		}
		b.links[l.Name] = info
		log.Debugf("networkd: enumerated link %s (ifindex=%d, path=%s, type=%q)", l.Name, l.Ifindex, l.Path, info.linkType)
	}

	return nil
}

// fetchLinkType queries networkd's Describe method and extracts the link Type
// (e.g. "ether", "wlan", "loopback", "none"). Returns empty on failure; callers
// fall back to name-prefix heuristics in that case. The Type is fixed at link
// creation by the kernel, so callers cache the result for the lifetime of the
// linkInfo and only refetch when a link is re-created at a new D-Bus path.
func (b *SystemdNetworkdBackend) fetchLinkType(path dbus.ObjectPath) string {
	linkObj := b.conn.Object(networkdBusName, path)
	var describeJSON string
	if err := linkObj.Call(networkdLinkIface+".Describe", 0).Store(&describeJSON); err != nil {
		return ""
	}
	return parseDescribeType(describeJSON)
}

// parseDescribeType extracts the top-level "Type" field from a networkd
// Describe payload. Returns empty when the JSON is malformed or the field is
// absent, signalling callers to fall back to name-prefix heuristics.
func parseDescribeType(describeJSON string) string {
	var parsed struct {
		Type string `json:"Type"`
	}
	if err := json.Unmarshal([]byte(describeJSON), &parsed); err != nil {
		return ""
	}
	return parsed.Type
}

func (b *SystemdNetworkdBackend) updateState() error {
	b.linksMutex.RLock()
	defer b.linksMutex.RUnlock()

	var wiredIface *linkInfo
	var wifiIface *linkInfo

	for _, link := range b.links {
		if !link.isWired() && !link.isWireless() {
			continue
		}

		linkObj := b.conn.Object(networkdBusName, link.path)
		opStateVar, err := linkObj.GetProperty(networkdLinkIface + ".OperationalState")
		if err == nil {
			if opState, ok := opStateVar.Value().(string); ok {
				link.opState = opState
			}
		}

		if link.isWireless() {
			if wifiIface == nil || link.opState == "routable" || link.opState == "carrier" {
				wifiIface = link
			}
		} else if link.isWired() {
			if wiredIface == nil || link.opState == "routable" || link.opState == "carrier" {
				wiredIface = link
			}
		}
	}

	var wiredConns []WiredConnection
	var ethernetDevices []EthernetDevice
	for name, link := range b.links {
		if !link.isWired() {
			continue
		}

		active := link.opState == "routable" || link.opState == "carrier"
		wiredConns = append(wiredConns, WiredConnection{
			Path:     link.path,
			ID:       name,
			UUID:     "wired:" + name,
			Type:     "ethernet",
			IsActive: active,
		})

		var ip string
		var hwAddr string
		if iface, err := net.InterfaceByName(name); err == nil {
			hwAddr = iface.HardwareAddr.String()
			if addrs := b.getAddresses(name); len(addrs) > 0 {
				ip = addrs[0]
			}
		}

		stateStr := "disconnected"
		switch link.opState {
		case "routable":
			stateStr = "routable"
		case "carrier":
			stateStr = "carrier"
		case "degraded":
			stateStr = "degraded"
		case "no-carrier":
			stateStr = "no-carrier"
		case "off":
			stateStr = "off"
		}

		ethernetDevices = append(ethernetDevices, EthernetDevice{
			Name:      name,
			HwAddress: hwAddr,
			State:     stateStr,
			Connected: active,
			IP:        ip,
		})
	}

	b.stateMutex.Lock()
	defer b.stateMutex.Unlock()

	b.state.NetworkStatus = StatusDisconnected
	b.state.EthernetConnected = false
	b.state.EthernetIP = ""
	b.state.WiFiConnected = false
	b.state.WiFiIP = ""
	b.state.WiredConnections = wiredConns
	b.state.EthernetDevices = ethernetDevices

	if wiredIface != nil {
		b.state.EthernetDevice = wiredIface.name
		log.Debugf("networkd: wired interface %s opState=%s", wiredIface.name, wiredIface.opState)
		if wiredIface.opState == "routable" || wiredIface.opState == "carrier" {
			b.state.EthernetConnected = true
			b.state.NetworkStatus = StatusEthernet

			if addrs := b.getAddresses(wiredIface.name); len(addrs) > 0 {
				b.state.EthernetIP = addrs[0]
				log.Debugf("networkd: ethernet IP %s on %s", addrs[0], wiredIface.name)
			}
		}
	}

	if wifiIface != nil {
		b.state.WiFiDevice = wifiIface.name
		log.Debugf("networkd: wifi interface %s opState=%s", wifiIface.name, wifiIface.opState)
		if wifiIface.opState == "routable" || wifiIface.opState == "carrier" {
			b.state.WiFiConnected = true

			if addrs := b.getAddresses(wifiIface.name); len(addrs) > 0 {
				b.state.WiFiIP = addrs[0]
				log.Debugf("networkd: wifi IP %s on %s", addrs[0], wifiIface.name)
				if b.state.NetworkStatus == StatusDisconnected {
					b.state.NetworkStatus = StatusWiFi
				}
			}
		}
	}

	return nil
}

func (b *SystemdNetworkdBackend) getAddresses(ifname string) []string {
	iface, err := net.InterfaceByName(ifname)
	if err != nil {
		return nil
	}

	addrs, err := iface.Addrs()
	if err != nil {
		return nil
	}

	var result []string
	for _, addr := range addrs {
		if ipnet, ok := addr.(*net.IPNet); ok {
			if ipv4 := ipnet.IP.To4(); ipv4 != nil {
				result = append(result, ipv4.String())
			}
		}
	}
	return result
}

func (b *SystemdNetworkdBackend) GetCurrentState() (*BackendState, error) {
	b.stateMutex.RLock()
	defer b.stateMutex.RUnlock()
	s := *b.state
	return &s, nil
}

func (b *SystemdNetworkdBackend) GetPromptBroker() PromptBroker {
	return nil
}

func (b *SystemdNetworkdBackend) SetPromptBroker(broker PromptBroker) error {
	return nil
}

func (b *SystemdNetworkdBackend) SubmitCredentials(token string, secrets map[string]string, save bool) error {
	return fmt.Errorf("credentials not needed by networkd backend")
}

func (b *SystemdNetworkdBackend) CancelCredentials(token string) error {
	return fmt.Errorf("credentials not needed by networkd backend")
}

func (b *SystemdNetworkdBackend) EnsureDhcpUp(ifname string) error {
	b.linksMutex.RLock()
	link, exists := b.links[ifname]
	b.linksMutex.RUnlock()

	if !exists {
		return fmt.Errorf("interface %s not found", ifname)
	}

	linkObj := b.conn.Object(networkdBusName, link.path)
	return linkObj.Call(networkdLinkIface+".Reconfigure", 0).Err
}
