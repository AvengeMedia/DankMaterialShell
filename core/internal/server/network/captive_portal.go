package network

import (
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
)

const (
	portalProbeURL       = "http://nmcheck.gnome.org/check_network_status.txt"
	portalProbeExpect    = "NetworkManager is online"
	portalProbeTimeout   = 5 * time.Second
	portalProbeInterval  = 30 * time.Second
	portalProbeMaxBody   = 4096
	portalFullProbeTicks = 10 // re-probe a healthy connection every ~5min, not every tick
)

// portalProbe checks a known endpoint to spot a captive portal: a redirect or an
// unexpected 200 body means traffic is being intercepted.
type portalProbe struct {
	mgr       *Manager
	client    *http.Client
	url       string
	trigger   chan struct{}
	stopChan  chan struct{}
	wg        sync.WaitGroup
	lastKey   string
	fullTicks int
}

func newPortalProbe(m *Manager) *portalProbe {
	probeURL := portalProbeURL
	if v := os.Getenv("DMS_CAPTIVE_PROBE_URL"); v != "" {
		probeURL = v
	}
	return &portalProbe{
		mgr:      m,
		url:      probeURL,
		trigger:  make(chan struct{}, 1),
		stopChan: make(chan struct{}),
		client: &http.Client{
			Timeout: portalProbeTimeout,
			CheckRedirect: func(req *http.Request, via []*http.Request) error {
				return http.ErrUseLastResponse
			},
		},
	}
}

func (p *portalProbe) start() {
	p.wg.Add(1)
	go p.run()
	p.kick()
}

func (p *portalProbe) stop() {
	close(p.stopChan)
	p.wg.Wait()
}

func (p *portalProbe) kick() {
	select {
	case p.trigger <- struct{}{}:
	default:
	}
}

func (p *portalProbe) run() {
	defer p.wg.Done()
	ticker := time.NewTicker(portalProbeInterval)
	defer ticker.Stop()
	for {
		select {
		case <-p.stopChan:
			return
		case <-p.trigger:
			p.probe(false)
		case <-ticker.C:
			p.probe(true)
		}
	}
}

func (p *portalProbe) probe(periodic bool) {
	m := p.mgr
	m.stateMutex.RLock()
	connected := m.state.WiFiConnected || m.state.EthernetConnected
	curConn := m.state.Connectivity
	key := fmt.Sprintf("%v|%s|%s", connected, m.state.WiFiSSID, m.state.EthernetIP)
	m.stateMutex.RUnlock()

	if !connected {
		p.lastKey = key
		p.set(ConnectivityNone, "")
		return
	}

	if periodic {
		if curConn == ConnectivityFull {
			p.fullTicks++
			if p.fullTicks < portalFullProbeTicks {
				return
			}
			p.fullTicks = 0
		}
	} else if key == p.lastKey {
		return
	}
	p.lastKey = key

	conn, loc := p.check()
	p.set(conn, loc)
}

func (p *portalProbe) check() (Connectivity, string) {
	req, err := http.NewRequest(http.MethodGet, p.url, nil)
	if err != nil {
		return ConnectivityUnknown, ""
	}
	req.Header.Set("User-Agent", "DankMaterialShell/captive-portal-check")

	resp, err := p.client.Do(req)
	if err != nil {
		return ConnectivityNone, ""
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 && resp.StatusCode < 400 {
		return ConnectivityPortal, p.resolveLocation(resp.Header.Get("Location"))
	}
	if resp.StatusCode == http.StatusNoContent {
		return ConnectivityFull, ""
	}
	// server/infra errors are not a portal
	if resp.StatusCode >= 400 {
		return ConnectivityUnknown, ""
	}

	body, _ := io.ReadAll(io.LimitReader(resp.Body, portalProbeMaxBody))
	if resp.StatusCode == http.StatusOK && strings.Contains(string(body), portalProbeExpect) {
		return ConnectivityFull, ""
	}

	return ConnectivityPortal, p.url
}

// resolveLocation turns a possibly-relative redirect target into an absolute url.
func (p *portalProbe) resolveLocation(loc string) string {
	if loc == "" {
		return p.url
	}
	base, err := url.Parse(p.url)
	if err != nil {
		return loc
	}
	ref, err := url.Parse(loc)
	if err != nil {
		return loc
	}
	return base.ResolveReference(ref).String()
}

func (p *portalProbe) set(conn Connectivity, loc string) {
	m := p.mgr
	m.stateMutex.Lock()
	changed := m.state.Connectivity != conn || m.state.PortalURL != loc
	m.state.Connectivity = conn
	m.state.PortalURL = loc
	m.stateMutex.Unlock()

	if !changed {
		return
	}
	if conn == ConnectivityPortal {
		log.Infof("[captive-portal] portal detected, login url: %s", loc)
	}
	m.notifySubscribers()
}
