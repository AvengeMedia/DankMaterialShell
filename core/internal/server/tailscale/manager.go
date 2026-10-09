package tailscale

import (
	"context"
	"errors"
	"fmt"
	"net/netip"
	"slices"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/dankgo/syncmap"
	"tailscale.com/client/local"
	"tailscale.com/client/tailscale/apitype"
	"tailscale.com/ipn"
	"tailscale.com/ipn/ipnstate"
	"tailscale.com/net/netutil"
	"tailscale.com/tailcfg"
)

const (
	statusTimeout  = 3 * time.Second
	debounceWindow = 150 * time.Millisecond
)

// tailscaleClient abstracts the Tailscale local API for testing.
type tailscaleClient interface {
	WatchIPNBus(ctx context.Context, mask ipn.NotifyWatchOpt) (ipnBusWatcher, error)
	Status(ctx context.Context) (*ipnstate.Status, error)
	GetPrefs(ctx context.Context) (*ipn.Prefs, error)
	EditPrefs(ctx context.Context, mp *ipn.MaskedPrefs) (*ipn.Prefs, error)
	StartLoginInteractive(ctx context.Context) error
	Logout(ctx context.Context) error
	ProfileStatus(ctx context.Context) (ipn.LoginProfile, []ipn.LoginProfile, error)
	SwitchProfile(ctx context.Context, id ipn.ProfileID) error
	SwitchToEmptyProfile(ctx context.Context) error
	SuggestExitNode(ctx context.Context) (apitype.ExitNodeSuggestionResponse, error)
	CheckIPForwarding(ctx context.Context) error
}

// ipnBusWatcher abstracts the IPN bus watcher for testing.
type ipnBusWatcher interface {
	Next() (ipn.Notify, error)
	Close() error
}

// localClientWrapper wraps local.Client to satisfy tailscaleClient.
type localClientWrapper struct {
	client *local.Client
}

func (w *localClientWrapper) WatchIPNBus(ctx context.Context, mask ipn.NotifyWatchOpt) (ipnBusWatcher, error) {
	return w.client.WatchIPNBus(ctx, mask)
}

func (w *localClientWrapper) Status(ctx context.Context) (*ipnstate.Status, error) {
	return w.client.Status(ctx)
}

func (w *localClientWrapper) GetPrefs(ctx context.Context) (*ipn.Prefs, error) {
	return w.client.GetPrefs(ctx)
}

func (w *localClientWrapper) EditPrefs(ctx context.Context, mp *ipn.MaskedPrefs) (*ipn.Prefs, error) {
	return w.client.EditPrefs(ctx, mp)
}

func (w *localClientWrapper) StartLoginInteractive(ctx context.Context) error {
	return w.client.StartLoginInteractive(ctx)
}

func (w *localClientWrapper) Logout(ctx context.Context) error {
	return w.client.Logout(ctx)
}

func (w *localClientWrapper) ProfileStatus(ctx context.Context) (ipn.LoginProfile, []ipn.LoginProfile, error) {
	return w.client.ProfileStatus(ctx)
}

func (w *localClientWrapper) SwitchProfile(ctx context.Context, id ipn.ProfileID) error {
	return w.client.SwitchProfile(ctx, id)
}

func (w *localClientWrapper) SwitchToEmptyProfile(ctx context.Context) error {
	return w.client.SwitchToEmptyProfile(ctx)
}

func (w *localClientWrapper) SuggestExitNode(ctx context.Context) (apitype.ExitNodeSuggestionResponse, error) {
	return w.client.SuggestExitNode(ctx)
}

func (w *localClientWrapper) CheckIPForwarding(ctx context.Context) error {
	return w.client.CheckIPForwarding(ctx)
}

// Manager manages Tailscale state via IPN bus events and subscriber notifications.
type Manager struct {
	state                *TailscaleState
	stateMutex           sync.RWMutex
	subscribers          syncmap.Map[string, chan TailscaleState]
	client               tailscaleClient
	ctx                  context.Context
	cancel               context.CancelFunc
	watchWG              sync.WaitGroup
	closed               atomic.Bool
	dirty                chan struct{}
	available            atomic.Bool
	availabilityCallback atomic.Pointer[func(bool)]
	authURL              atomic.Pointer[string]
}

// NewManager creates a new Tailscale manager and starts watching the IPN bus.
func NewManager(socketPath string) *Manager {
	lc := &local.Client{Socket: socketPath}
	return newManager(&localClientWrapper{client: lc})
}

func newManager(client tailscaleClient) *Manager {
	ctx, cancel := context.WithCancel(context.Background())
	m := &Manager{
		state:  &TailscaleState{Prefs: TailscalePrefs{AdvertiseRoutes: []string{}}},
		client: client,
		ctx:    ctx,
		cancel: cancel,
		dirty:  make(chan struct{}, 1),
	}

	m.watchWG.Add(2)
	go m.watchLoop(ctx)
	go m.debounceLoop(ctx)

	return m
}

func (m *Manager) watchLoop(ctx context.Context) {
	defer m.watchWG.Done()

	mask := ipn.NotifyInitialState | ipn.NotifyInitialPrefs | ipn.NotifyInitialNetMap | ipn.NotifyRateLimit
	backoff := time.Second
	unreachableSent := false

	for {
		select {
		case <-ctx.Done():
			return
		default:
		}

		watcher, err := m.client.WatchIPNBus(ctx, mask)
		if err != nil {
			if !unreachableSent {
				m.updateState(&TailscaleState{BackendState: "Unreachable", Prefs: TailscalePrefs{AdvertiseRoutes: []string{}}})
				unreachableSent = true
			}
			if !sleepBackoff(ctx, &backoff) {
				return
			}
			continue
		}

		unreachableSent = false
		log.Info("[Tailscale] Connected to IPN bus")
		m.markAvailable()
		// A still-pending login URL is re-sent with the initial state.
		m.authURL.Store(nil)

		select {
		case m.dirty <- struct{}{}:
		default:
		}

		for {
			n, err := watcher.Next()
			if err != nil {
				log.Warnf("[Tailscale] IPN bus error: %v", err)
				break
			}

			switch {
			case n.BrowseToURL != nil:
				m.authURL.Store(n.BrowseToURL)
			case n.LoginFinished != nil, n.State != nil && *n.State == ipn.Running:
				m.authURL.Store(nil)
			}

			backoff = time.Second

			select {
			case m.dirty <- struct{}{}:
			default:
			}
		}

		watcher.Close()

		if !sleepBackoff(ctx, &backoff) {
			return
		}
	}
}

func sleepBackoff(ctx context.Context, backoff *time.Duration) bool {
	select {
	case <-ctx.Done():
		return false
	case <-time.After(*backoff):
	}
	*backoff = min(*backoff*2, 30*time.Second)
	return true
}

// debounceLoop coalesces rapid bus notifications into a single Status RPC
// per debounceWindow, since NetMap events can fire many times per second
// on busy tailnets.
func (m *Manager) debounceLoop(ctx context.Context) {
	defer m.watchWG.Done()

	for {
		select {
		case <-ctx.Done():
			return
		case <-m.dirty:
		}

		timer := time.NewTimer(debounceWindow)
		collecting := true
		for collecting {
			select {
			case <-ctx.Done():
				timer.Stop()
				return
			case <-m.dirty:
			case <-timer.C:
				collecting = false
			}
		}

		m.fetchAndBroadcast(ctx)
	}
}

func (m *Manager) fetchAndBroadcast(ctx context.Context) {
	statusCtx, cancel := context.WithTimeout(ctx, statusTimeout)
	defer cancel()

	state, err := m.fetchState(statusCtx)
	if err != nil {
		log.Warnf("[Tailscale] Failed to fetch status: %v", err)
		return
	}

	m.updateState(state)
}

// fetchState fetches the current status and merges in pref-derived fields
// (e.g. exit-node LAN access) that are not present in the IPN status itself.
func (m *Manager) fetchState(ctx context.Context) (*TailscaleState, error) {
	status, err := m.client.Status(ctx)
	if err != nil {
		return nil, err
	}

	state := convertStatus(status)
	state.Prefs.AdvertiseRoutes = []string{}
	if u := m.authURL.Load(); u != nil {
		state.AuthURL = *u
	}

	// Prefs carry settings the status does not expose. Treat a prefs failure
	// as non-fatal so status still updates.
	if prefs, err := m.client.GetPrefs(ctx); err != nil {
		log.Warnf("[Tailscale] Failed to fetch prefs: %v", err)
	} else if prefs != nil {
		state.ExitNodeAllowLANAccess = prefs.ExitNodeAllowLANAccess
		state.Prefs = convertPrefs(prefs)
	}

	return state, nil
}

func convertPrefs(p *ipn.Prefs) TailscalePrefs {
	routes, exitNode := splitAdvertisedRoutes(p.AdvertiseRoutes)
	out := TailscalePrefs{
		AcceptRoutes:      p.RouteAll,
		AcceptDNS:         p.CorpDNS,
		ShieldsUp:         p.ShieldsUp,
		RunSSH:            p.RunSSH,
		Hostname:          p.Hostname,
		AdvertiseExitNode: exitNode,
		AdvertiseRoutes:   make([]string, len(routes)),
	}
	for i, r := range routes {
		out.AdvertiseRoutes[i] = r.String()
	}
	return out
}

// splitAdvertisedRoutes separates subnet routes from the default routes;
// a node is an exit node only when it advertises both 0.0.0.0/0 and ::/0.
func splitAdvertisedRoutes(all []netip.Prefix) (routes []netip.Prefix, exitNode bool) {
	var v4, v6 bool
	for _, p := range all {
		switch {
		case p.Bits() == 0 && p.Addr().Is4():
			v4 = true
		case p.Bits() == 0:
			v6 = true
		default:
			routes = append(routes, p)
		}
	}
	return routes, v4 && v6
}

func (m *Manager) updateState(state *TailscaleState) {
	m.stateMutex.Lock()
	m.state = state
	m.stateMutex.Unlock()

	m.broadcastState(*state)
}

func (m *Manager) broadcastState(state TailscaleState) {
	if m.closed.Load() {
		return
	}
	m.subscribers.Range(func(key string, ch chan TailscaleState) bool {
		select {
		case ch <- state:
		default:
		}
		return true
	})
}

// IsAvailable reports whether tailscaled has been reachable via the IPN bus
// at least once since the manager started. False means tailscaled appears
// to not be installed or has never been running.
func (m *Manager) IsAvailable() bool {
	return m.available.Load()
}

// SetAvailabilityCallback registers a callback fired when the manager
// transitions from unavailable to available. Replaces any previously set
// callback. Must be set before the manager has a chance to detect tailscaled.
func (m *Manager) SetAvailabilityCallback(cb func(bool)) {
	m.availabilityCallback.Store(&cb)
}

func (m *Manager) markAvailable() {
	if m.available.Swap(true) {
		return
	}
	if cb := m.availabilityCallback.Load(); cb != nil {
		(*cb)(true)
	}
}

// GetState returns a copy of the current Tailscale state.
func (m *Manager) GetState() TailscaleState {
	m.stateMutex.RLock()
	defer m.stateMutex.RUnlock()

	if m.state == nil {
		return TailscaleState{}
	}
	return *m.state
}

// Subscribe creates a buffered channel for the given client ID.
func (m *Manager) Subscribe(clientID string) chan TailscaleState {
	ch := make(chan TailscaleState, 64)
	m.subscribers.Store(clientID, ch)
	return ch
}

// Unsubscribe removes and closes the subscriber channel.
func (m *Manager) Unsubscribe(clientID string) {
	if val, ok := m.subscribers.LoadAndDelete(clientID); ok {
		close(val)
	}
}

// Close stops the watch loop and closes all subscriber channels.
func (m *Manager) Close() {
	m.closed.Store(true)
	m.cancel()
	m.watchWG.Wait()

	m.subscribers.Range(func(key string, ch chan TailscaleState) bool {
		close(ch)
		m.subscribers.Delete(key)
		return true
	})
}

// RefreshState triggers an immediate status fetch and broadcasts.
func (m *Manager) RefreshState() {
	ctx, cancel := context.WithTimeout(m.ctx, statusTimeout)
	defer cancel()

	state, err := m.fetchState(ctx)
	if err != nil {
		log.Warnf("[Tailscale] Failed to refresh state: %v", err)
		return
	}

	m.updateState(state)
}

// Connect brings the Tailscale backend up (WantRunning = true).
func (m *Manager) Connect() error {
	return m.editPrefs(&ipn.MaskedPrefs{
		Prefs:          ipn.Prefs{WantRunning: true},
		WantRunningSet: true,
	})
}

// Disconnect brings the Tailscale backend down (WantRunning = false).
func (m *Manager) Disconnect() error {
	return m.editPrefs(&ipn.MaskedPrefs{
		Prefs:          ipn.Prefs{WantRunning: false},
		WantRunningSet: true,
	})
}

// SetExitNode selects the exit node identified by its stable node ID. An empty
// id clears the current exit node. Mirrors `tailscale set --exit-node=<id>`,
// which also clears any legacy IP-based exit node so a stale ExitNodeIP cannot
// silently take precedence over the now-empty ID.
func (m *Manager) SetExitNode(id string) error {
	return m.editPrefs(&ipn.MaskedPrefs{
		Prefs:         ipn.Prefs{ExitNodeID: tailcfg.StableNodeID(id)},
		ExitNodeIDSet: true,
		ExitNodeIPSet: true,
	})
}

// SetAllowLANAccess toggles whether locally accessible subnets remain
// reachable while an exit node is in use.
func (m *Manager) SetAllowLANAccess(enabled bool) error {
	return m.editPrefs(&ipn.MaskedPrefs{
		Prefs:                     ipn.Prefs{ExitNodeAllowLANAccess: enabled},
		ExitNodeAllowLANAccessSet: true,
	})
}

// editPrefs applies a masked prefs edit and refreshes state so subscribers see
// the result immediately, in addition to the IPN bus notification it triggers.
func (m *Manager) editPrefs(mp *ipn.MaskedPrefs) error {
	err := m.withTimeout(func(ctx context.Context) error {
		_, err := m.client.EditPrefs(ctx, mp)
		return err
	})
	if err != nil {
		return err
	}

	m.RefreshState()
	return nil
}

// SetPrefs returns tailscaled's IP forwarding warning, if any. AdvertiseRoutes
// is shared by routes and the exit-node flag, so changing one keeps the other.
func (m *Manager) SetPrefs(p PrefsPatch) (string, error) {
	mp := &ipn.MaskedPrefs{}
	if p.AcceptRoutes != nil {
		mp.RouteAll, mp.RouteAllSet = *p.AcceptRoutes, true
	}
	if p.AcceptDNS != nil {
		mp.CorpDNS, mp.CorpDNSSet = *p.AcceptDNS, true
	}
	if p.ShieldsUp != nil {
		mp.ShieldsUp, mp.ShieldsUpSet = *p.ShieldsUp, true
	}
	if p.RunSSH != nil {
		mp.RunSSH, mp.RunSSHSet = *p.RunSSH, true
	}
	if p.Hostname != nil {
		mp.Hostname, mp.HostnameSet = *p.Hostname, true
	}

	routesRequested := p.AdvertiseExitNode != nil || p.AdvertiseRoutes != nil
	routesTouched := routesRequested
	if routesTouched {
		routes, current, err := m.advertisedRoutes(p)
		if err != nil {
			return "", err
		}
		if slices.Equal(routes, current) {
			routesTouched = false
		} else {
			mp.AdvertiseRoutes, mp.AdvertiseRoutesSet = routes, true
		}
	}

	if !mp.RouteAllSet && !mp.CorpDNSSet && !mp.ShieldsUpSet && !mp.RunSSHSet && !mp.HostnameSet && !mp.AdvertiseRoutesSet {
		if !routesRequested {
			return "", errors.New("no changes")
		}
		return "", nil
	}

	if err := m.editPrefs(mp); err != nil {
		return "", err
	}

	if !routesTouched || len(mp.AdvertiseRoutes) == 0 {
		return "", nil
	}
	if err := m.withTimeout(m.client.CheckIPForwarding); err != nil {
		return err.Error(), nil
	}
	return "", nil
}

// advertisedRoutes returns the routes to set and the ones currently stored.
func (m *Manager) advertisedRoutes(p PrefsPatch) ([]netip.Prefix, []netip.Prefix, error) {
	if p.AdvertiseRoutes != nil {
		for _, s := range *p.AdvertiseRoutes {
			r, err := netip.ParsePrefix(s)
			if err != nil {
				return nil, nil, fmt.Errorf("invalid route %q", s)
			}
			if r.Bits() == 0 {
				return nil, nil, fmt.Errorf("route %q is a default route; use the exit node setting", s)
			}
		}
	}

	var current *ipn.Prefs
	err := m.withTimeout(func(ctx context.Context) (err error) {
		current, err = m.client.GetPrefs(ctx)
		return err
	})
	if err != nil {
		return nil, nil, err
	}
	if current == nil {
		return nil, nil, errors.New("tailscaled returned no prefs")
	}
	stored, exitNode := splitAdvertisedRoutes(current.AdvertiseRoutes)

	routes := make([]string, len(stored))
	for i, r := range stored {
		routes[i] = r.String()
	}
	if p.AdvertiseRoutes != nil {
		routes = *p.AdvertiseRoutes
	}
	if p.AdvertiseExitNode != nil {
		exitNode = *p.AdvertiseExitNode
	}
	want, err := netutil.CalcAdvertiseRoutes(strings.Join(routes, ","), exitNode)
	return want, current.AdvertiseRoutes, err
}

func (m *Manager) withTimeout(fn func(ctx context.Context) error) error {
	ctx, cancel := context.WithTimeout(m.ctx, statusTimeout)
	defer cancel()
	return fn(ctx)
}

// Login starts an interactive login; the URL to open arrives on the IPN bus
// and surfaces as TailscaleState.AuthURL.
func (m *Manager) Login() error {
	return m.withTimeout(m.client.StartLoginInteractive)
}

// Logout logs the current account out.
func (m *Manager) Logout() error {
	if err := m.withTimeout(m.client.Logout); err != nil {
		return err
	}
	m.RefreshState()
	return nil
}

// Profiles lists the known accounts. ProfileStatus needs LocalAPI write
// access, so an access-denied error means DMS cannot change Tailscale.
func (m *Manager) Profiles() (ProfilesResult, error) {
	var current ipn.LoginProfile
	var all []ipn.LoginProfile
	err := m.withTimeout(func(ctx context.Context) (err error) {
		current, all, err = m.client.ProfileStatus(ctx)
		return err
	})
	if local.IsAccessDeniedError(err) {
		return ProfilesResult{}, nil
	}
	if err != nil {
		return ProfilesResult{}, err
	}

	res := ProfilesResult{
		CanOperate: true,
		Current:    string(current.ID),
		Profiles:   make([]TailscaleProfile, len(all)),
	}
	for i, p := range all {
		tailnet := p.NetworkProfile.DisplayName
		if tailnet == "" {
			tailnet = p.NetworkProfile.DomainName
		}
		res.Profiles[i] = TailscaleProfile{ID: string(p.ID), Name: p.Name, Tailnet: tailnet}
	}
	slices.SortFunc(res.Profiles, func(a, b TailscaleProfile) int { return strings.Compare(a.Name, b.Name) })
	return res, nil
}

// SwitchProfile switches to the account with the given profile ID.
func (m *Manager) SwitchProfile(id string) error {
	if id == "" {
		return errors.New("profile id is required")
	}
	err := m.withTimeout(func(ctx context.Context) error {
		return m.client.SwitchProfile(ctx, ipn.ProfileID(id))
	})
	if err != nil {
		return err
	}
	m.RefreshState()
	return nil
}

// AddProfile switches to a new empty profile and starts logging it in.
func (m *Manager) AddProfile() error {
	return m.withTimeout(func(ctx context.Context) error {
		if err := m.client.SwitchToEmptyProfile(ctx); err != nil {
			return err
		}
		return m.client.StartLoginInteractive(ctx)
	})
}

// SuggestExitNode returns tailscaled's recommended exit node.
func (m *Manager) SuggestExitNode() (ExitNodeSuggestion, error) {
	var s apitype.ExitNodeSuggestionResponse
	err := m.withTimeout(func(ctx context.Context) (err error) {
		s, err = m.client.SuggestExitNode(ctx)
		return err
	})
	if err != nil {
		return ExitNodeSuggestion{}, err
	}
	return ExitNodeSuggestion{ID: string(s.ID), Name: s.Name}, nil
}
