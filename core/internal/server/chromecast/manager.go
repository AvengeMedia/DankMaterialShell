package chromecast

import (
	"context"
	"errors"
	"fmt"
	"net"
	"sort"
	"sync"
	"sync/atomic"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/pkg/syncmap"
	castapp "github.com/vishen/go-chromecast/application"
	"github.com/vishen/go-chromecast/cast"
	castdns "github.com/vishen/go-chromecast/dns"
)

// pollInterval is how often the connected device is polled for playback status.
// The Cast protocol does not push media progress, so we refresh on a timer and
// broadcast only when something actually changes.
const pollInterval = time.Second

// discoverFunc abstracts mDNS discovery so the manager can be unit-tested
// without a real LAN. Defaults to the go-chromecast implementation.
var discoverFunc = func(ctx context.Context, iface *net.Interface) (<-chan castdns.CastEntry, error) {
	return castdns.DiscoverCastDNSEntries(ctx, iface)
}

// castApp is the slice of the go-chromecast Application API the manager uses.
// It exists so connection logic can be unit-tested with a fake.
type castApp interface {
	Start(addr string, port int) error
	Update() error
	Status() (*cast.Application, *cast.Media, *cast.Volume)
	Load(filenameOrURL string, startTime int, contentType string, transcode, detach, forceDetach bool) error
	Unpause() error
	Pause() error
	StopMedia() error
	SeekToTime(value float32) error
	SetVolume(value float32) error
	SetMuted(value bool) error
	Close(stopMedia bool) error
}

// errNotConnected is returned by control actions when no device is connected.
var errNotConnected = errors.New("not connected to a device")

// newAppFunc constructs a cast application. Overridable in tests.
var newAppFunc = func() castApp {
	return castapp.NewApplication()
}

// Manager discovers Cast devices via mDNS and broadcasts device-list changes
// to subscribers. Discovery is explicitly started/stopped by clients so the
// mDNS browser only runs while a UI is interested in the results.
type Manager struct {
	mu             sync.RWMutex
	devices        map[string]Device
	discovering    bool
	discoverCancel context.CancelFunc
	discoverGen    uint64 // bumped on every (re)start/stop so a stale wg-drain can't clear a newer scan

	// connMu serializes connection lifecycle transitions (Connect/Disconnect)
	// so two overlapping attempts can't both install an app or undo each other.
	connMu sync.Mutex
	// appMu serializes every call into the go-chromecast Application, which is
	// not concurrent-safe; the poll loop and IPC control actions both call it.
	appMu sync.Mutex

	// Connection state (guarded by mu; blocking network calls are never made
	// while the lock is held).
	app                   castApp
	connCancel            context.CancelFunc
	connected             bool
	autoConnecting        bool // guards against overlapping auto-reconnect attempts
	suppressAutoReconnect bool // set when the user explicitly disconnects, so a re-announce doesn't auto-reconnect
	activeDevice          Device
	playback              *Playback
	screencasting         bool
	preferredID           string

	screen      *screenStreamer
	airplay     *airplayMirror
	subscribers syncmap.Map[string, chan State]
	sendMu      sync.Mutex // serializes broadcast sends vs. subscriber-channel closes
	closed      atomic.Bool
}

// callApp runs a single Application call while holding appMu. The go-chromecast
// Application mutates a shared requestID/resultChanMap without locking, so the
// poll loop and concurrent IPC control actions must not call into it at once
// (doing so races and can crash the process with "concurrent map writes").
func (m *Manager) callApp(app castApp, fn func(castApp) error) error {
	m.appMu.Lock()
	defer m.appMu.Unlock()
	return fn(app)
}

// statusOf reads the Application's cached status under appMu (Status() reads
// fields Update() writes, so it must be serialized with the other app calls).
func (m *Manager) statusOf(app castApp) (*cast.Application, *cast.Media, *cast.Volume) {
	m.appMu.Lock()
	defer m.appMu.Unlock()
	return app.Status()
}

// NewManager creates a chromecast manager. Discovery does not start until
// StartDiscovery is called.
func NewManager() *Manager {
	cfg := loadConfig()
	return &Manager{
		devices:     make(map[string]Device),
		screen:      &screenStreamer{},
		airplay:     &airplayMirror{},
		preferredID: cfg.PreferredID,
	}
}

// rebrowseInterval paces the self-healing re-browse on the built-in mDNS
// fallback: every interval the resolver is recreated so a browser that missed
// responses (port 5353 is shared with other mDNS listeners) gets another chance.
const rebrowseInterval = 10 * time.Second

// StartDiscovery begins discovery for both Chromecast (_googlecast._tcp) and
// AirPlay (_airplay._tcp) devices. It is a no-op if discovery is already
// running. Newly seen devices from either protocol are merged into one list and
// broadcast to subscribers. When avahi-daemon is available, browsing goes
// through it (no parallel mDNS stack, no port contention); otherwise the
// built-in zeroconf/go-chromecast browsers run with periodic self-healing.
func (m *Manager) StartDiscovery() error {
	m.mu.Lock()
	if m.discovering {
		m.mu.Unlock()
		return nil
	}

	ctx, cancel := context.WithCancel(context.Background())
	m.discoverCancel = cancel
	m.discovering = true
	m.discoverGen++
	gen := m.discoverGen
	m.devices = make(map[string]Device) // fresh list per scan
	m.mu.Unlock()

	sources := m.discoverySources(ctx)

	log.Info("[Cast] Discovery started")
	m.broadcast()

	var wg sync.WaitGroup
	for _, src := range sources {
		wg.Add(1)
		go func(ch <-chan Device) {
			defer wg.Done()
			for dev := range ch {
				m.upsertDevice(dev)
			}
		}(src)
	}

	// Mark discovery stopped once every source has ended — but only if this is
	// still the active scan. A StopDiscovery + StartDiscovery can replace this
	// session while its sources are still draining; the gen check stops that
	// stale drain from clearing the newer scan's discovering flag.
	go func() {
		wg.Wait()
		m.mu.Lock()
		stale := m.discoverGen != gen
		if !stale {
			m.discovering = false
			m.discoverCancel = nil
		}
		m.mu.Unlock()
		if !stale {
			log.Info("[Cast] Discovery stopped")
			m.broadcast()
		}
	}()

	return nil
}

// discoverySources picks the discovery backend and returns one Device channel
// per protocol. Prefers avahi; falls back to the built-in self-healing mDNS
// browsers. Errors only if no source could be started at all.
func (m *Manager) discoverySources(ctx context.Context) []<-chan Device {
	useAvahi := avahiAvailableFunc()
	if useAvahi {
		log.Info("[Cast] Using avahi for mDNS discovery")
	}
	// One source per protocol, each choosing avahi or its built-in browser
	// independently — so a single avahi browse failure degrades only that
	// protocol to its fallback instead of silently dropping it.
	cc := m.protocolSource(ctx, useAvahi, "_googlecast._tcp", ProtocolChromecast, func(c context.Context) (<-chan Device, error) {
		return castEntriesToDevices(discoverFunc(c, nil))
	})
	ap := m.protocolSource(ctx, useAvahi, "_airplay._tcp", ProtocolAirplay, func(c context.Context) (<-chan Device, error) {
		return airplayDiscoverFunc(c)
	})
	return []<-chan Device{cc, ap}
}

// protocolSource returns the device channel for one protocol: avahi when it is
// available and its browse starts, otherwise the built-in self-healing browser.
func (m *Manager) protocolSource(ctx context.Context, useAvahi bool, serviceType, proto string, builtin func(context.Context) (<-chan Device, error)) <-chan Device {
	if useAvahi {
		ch, err := avahiBrowseFunc(ctx, serviceType, proto)
		if err == nil {
			return ch
		}
		log.Warnf("[Cast] avahi browse %s failed (%v); falling back to built-in mDNS", serviceType, err)
	}
	return m.selfHealBrowse(ctx, builtin)
}

// selfHealBrowse repeatedly runs mk with a fresh per-cycle context so a browser
// that missed mDNS responses re-queries on the next cycle. Devices are forwarded
// as they arrive; the loop ends when ctx is cancelled.
func (m *Manager) selfHealBrowse(ctx context.Context, mk func(context.Context) (<-chan Device, error)) <-chan Device {
	out := make(chan Device, 8)
	go func() {
		defer close(out)
		for ctx.Err() == nil {
			cycleCtx, cancel := context.WithTimeout(ctx, rebrowseInterval)
			if ch, err := mk(cycleCtx); err == nil {
				for dev := range ch {
					select {
					case out <- dev:
					case <-ctx.Done():
						cancel()
						return
					}
				}
			}
			<-cycleCtx.Done() // pace re-browses and honor cancellation
			cancel()
		}
	}()
	return out
}

// castEntriesToDevices adapts the go-chromecast discovery channel to Devices.
func castEntriesToDevices(in <-chan castdns.CastEntry, err error) (<-chan Device, error) {
	if err != nil {
		return nil, err
	}
	out := make(chan Device, 8)
	go func() {
		defer close(out)
		for e := range in {
			out <- Device{
				ID:       e.UUID,
				Name:     e.DeviceName,
				Model:    e.Device,
				Host:     e.GetAddr(),
				Port:     e.Port,
				Protocol: ProtocolChromecast,
			}
		}
	}()
	return out, nil
}

// upsertDevice merges a discovered device into the list, assigns a stable key,
// broadcasts, and auto-reconnects to the preferred device when it appears.
func (m *Manager) upsertDevice(dev Device) {
	key := dev.ID
	if key == "" {
		key = fmt.Sprintf("%s:%d", dev.Host, dev.Port)
	}
	dev.ID = key
	if dev.Name == "" {
		dev.Name = key
	}

	m.mu.Lock()
	existing, known := m.devices[key]
	changed := !known || existing != dev
	m.devices[key] = dev
	// Auto-reconnect to the preferred device when it (re)appears, for either
	// protocol — Connect dispatches Chromecast vs AirPlay (which starts the
	// mirror). For AirPlay this auto-starts a screen mirror; the screen-share
	// portal only prompts on the first grant (the restore token auto-grants
	// after), so it isn't intrusive on later reconnects. autoConnecting prevents
	// overlapping attempts from rapid/duplicate discovery events.
	shouldReconnect := m.preferredID == key && !m.connected && !m.autoConnecting && !m.suppressAutoReconnect
	if shouldReconnect {
		m.autoConnecting = true
	}
	m.mu.Unlock()
	// Discovery re-announces and the self-heal re-browse re-emit unchanged
	// devices on a loop; only snapshot/sort/broadcast when something actually
	// changed to avoid re-pushing an identical list to every subscriber.
	if changed {
		log.Debugf("[Cast] Discovered %s %s (%s) at %s:%d", dev.Protocol, dev.Name, dev.Model, dev.Host, dev.Port)
		m.broadcast()
	}

	if shouldReconnect {
		log.Infof("[Cast] Auto-reconnecting to preferred device %s", dev.Name)
		go func(id string) {
			if err := m.Connect(id); err != nil {
				log.Warnf("[Cast] Auto-reconnect failed: %v", err)
			}
			m.mu.Lock()
			m.autoConnecting = false
			m.mu.Unlock()
		}(key)
	}
}

// StopDiscovery cancels an in-flight mDNS browse. Safe to call when not
// discovering.
func (m *Manager) StopDiscovery() {
	m.mu.Lock()
	cancel := m.discoverCancel
	m.discoverCancel = nil
	// Clear synchronously (don't wait for the async source drain) so an
	// immediate StartDiscovery isn't a no-op, and bump the generation so the
	// in-flight drain goroutine won't touch the next scan's state.
	wasDiscovering := m.discovering
	m.discovering = false
	m.discoverGen++
	m.mu.Unlock()

	if cancel != nil {
		cancel()
	}
	// The stale drain goroutine won't broadcast (its gen no longer matches), so
	// publish the stopped state here.
	if wasDiscovering {
		m.broadcast()
	}
}

// Connect opens a control connection to the device with the given ID and
// begins polling it for playback status. Any existing connection is dropped
// first. The device must have been seen by discovery.
func (m *Manager) Connect(id string) error {
	m.connMu.Lock()
	defer m.connMu.Unlock()
	return m.connectLocked(id)
}

// connectLocked performs the connection. Callers hold connMu so connect and
// disconnect transitions never overlap (which previously let two concurrent
// connects both install an app, leaking the first connection and its poll loop).
func (m *Manager) connectLocked(id string) error {
	m.mu.Lock()
	// An explicit connect re-engages auto-reconnect for future re-announces.
	m.suppressAutoReconnect = false
	dev, ok := m.devices[id]
	hasSession := m.connected || m.app != nil
	m.mu.Unlock()

	if !ok {
		return fmt.Errorf("unknown device: %s", id)
	}

	// AirPlay devices use the mirroring path (doubletake), not the Cast protocol.
	if dev.Protocol == ProtocolAirplay {
		return m.connectAirplayLocked(dev)
	}

	// Drop any existing session first — a Chromecast app OR an AirPlay mirror.
	// m.app is nil for AirPlay, so the connected check is what catches it.
	if hasSession {
		m.disconnectLocked()
	}

	app := newAppFunc()
	if err := m.callApp(app, func(a castApp) error { return a.Start(dev.Host, dev.Port) }); err != nil {
		return fmt.Errorf("connect to %s: %w", dev.Name, err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	m.mu.Lock()
	m.app = app
	m.connCancel = cancel
	m.connected = true
	m.activeDevice = dev
	m.playback = nil
	m.mu.Unlock()

	log.Infof("[Chromecast] Connected to %s (%s:%d)", dev.Name, dev.Host, dev.Port)
	m.broadcast()

	// Prime playback state, then poll for changes until disconnected.
	if err := m.callApp(app, func(a castApp) error { return a.Update() }); err != nil {
		log.Warnf("[Chromecast] Initial status update failed: %v", err)
	}
	m.refreshPlayback(app)

	go m.pollLoop(ctx, app)
	return nil
}

// connectAirplayLocked starts mirroring the screen to an AirPlay 2 device via
// doubletake. For AirPlay, connecting and mirroring are the same action.
// Callers hold connMu.
func (m *Manager) connectAirplayLocked(dev Device) error {
	m.disconnectLocked() // drop any existing connection first

	onExit := func() {
		m.mu.Lock()
		m.connected = false
		m.activeDevice = Device{}
		m.screencasting = false
		m.mu.Unlock()
		m.broadcast()
	}
	if err := m.airplay.start(dev.Host, onExit); err != nil {
		return err
	}

	m.mu.Lock()
	m.connected = true
	m.activeDevice = dev
	m.screencasting = true // AirPlay connect == screen mirroring
	m.mu.Unlock()
	log.Infof("[Cast] Connected to AirPlay device %s (%s)", dev.Name, dev.Host)
	m.broadcast()
	return nil
}

// Disconnect closes the active control connection, if any, and stops any
// in-progress screen mirroring. This is the user-initiated path, so it suppresses
// auto-reconnect until the next explicit connect/preference change.
func (m *Manager) Disconnect() {
	m.connMu.Lock()
	defer m.connMu.Unlock()
	m.mu.Lock()
	m.suppressAutoReconnect = true
	m.mu.Unlock()
	m.disconnectLocked()
}

// disconnectLocked tears down the active session (Cast app and/or AirPlay
// mirror) and clears connection state. Callers hold connMu.
func (m *Manager) disconnectLocked() {
	m.screen.stop()
	m.airplay.stop()

	m.mu.Lock()
	cancel := m.connCancel
	app := m.app
	m.app = nil
	m.connCancel = nil
	m.connected = false
	m.activeDevice = Device{}
	m.playback = nil
	m.screencasting = false
	m.mu.Unlock()

	if cancel != nil {
		cancel()
	}
	if app != nil {
		if err := m.callApp(app, func(a castApp) error { return a.Close(false) }); err != nil {
			log.Debugf("[Chromecast] Error closing connection: %v", err)
		}
		log.Info("[Chromecast] Disconnected")
	}
	m.broadcast()
}

// SetPreferred records a device as the auto-reconnect target and persists it.
// An empty id clears the preference.
func (m *Manager) SetPreferred(id string) {
	m.mu.Lock()
	m.preferredID = id
	// Choosing a preferred device is an opt-in to auto-connect, so lift any
	// suppression left by an earlier explicit disconnect.
	m.suppressAutoReconnect = false
	name := ""
	if dev, ok := m.devices[id]; ok {
		name = dev.Name
	}
	m.mu.Unlock()

	if err := saveConfig(Config{PreferredID: id, PreferredName: name}); err != nil {
		log.Warnf("[Chromecast] Failed to persist preferred device: %v", err)
	}
	m.broadcast()
}

// ClearPreferred removes the auto-reconnect preference.
func (m *Manager) ClearPreferred() {
	m.SetPreferred("")
}

// startupScanWindow bounds how long the boot-time reconnect scan runs.
const startupScanWindow = 30 * time.Second

// StartupReconnect runs a bounded discovery scan if a preferred device is set,
// so the shell can reconnect to it without any UI being open. The scan stops
// itself after startupScanWindow; the discovery loop auto-connects if the
// preferred device shows up in the meantime.
func (m *Manager) StartupReconnect() {
	m.mu.RLock()
	preferred := m.preferredID
	m.mu.RUnlock()
	if preferred == "" {
		return
	}

	log.Infof("[Chromecast] Scanning for preferred device for up to %s", startupScanWindow)
	if err := m.StartDiscovery(); err != nil {
		log.Warnf("[Chromecast] Startup scan failed to start: %v", err)
		return
	}
	time.AfterFunc(startupScanWindow, func() {
		// Only stop if we never connected; an active connection means a UI or
		// the auto-reconnect already took over.
		m.mu.RLock()
		connected := m.connected
		m.mu.RUnlock()
		if !connected {
			m.StopDiscovery()
		}
	})
}

// currentApp returns the active connection or errNotConnected.
func (m *Manager) currentApp() (castApp, error) {
	m.mu.RLock()
	app := m.app
	m.mu.RUnlock()
	if app == nil {
		return nil, errNotConnected
	}
	return app, nil
}

// Cast loads a media URL (or local file path) on the connected device. An empty
// contentType lets the library infer it from the extension.
func (m *Manager) Cast(url, contentType string) error {
	app, err := m.currentApp()
	if err != nil {
		return err
	}
	if err := m.callApp(app, func(a castApp) error { return a.Load(url, 0, contentType, false, false, false) }); err != nil {
		return fmt.Errorf("load media: %w", err)
	}
	m.afterControl(app)
	return nil
}

// CastScreen mirrors the local screen to the connected device by capturing it
// to an HLS stream and casting that stream's URL. This is the buffered "laggy
// mirror" path — expect multi-second latency, not real-time mirroring.
func (m *Manager) CastScreen() error {
	m.mu.RLock()
	app := m.app
	host := m.activeDevice.Host
	m.mu.RUnlock()
	if app == nil {
		return errNotConnected
	}

	ip, err := outboundIPFunc(host)
	if err != nil {
		return fmt.Errorf("determine local address: %w", err)
	}

	// onExit fires if the capture helper dies on its own, so the UI doesn't get
	// stuck showing "Mirroring" with a dead/zombie helper.
	onExit := func() {
		m.mu.Lock()
		wasCasting := m.screencasting
		m.screencasting = false
		m.mu.Unlock()
		if wasCasting {
			log.Warn("[Cast] Screen capture helper exited unexpectedly")
			m.broadcast()
		}
	}

	url, err := m.screen.start(ip, onExit)
	if err != nil {
		return err
	}

	if err := m.callApp(app, func(a castApp) error { return a.Load(url, 0, hlsContentType, false, false, false) }); err != nil {
		m.screen.stop()
		return fmt.Errorf("cast screen stream: %w", err)
	}

	m.mu.Lock()
	m.screencasting = true
	m.mu.Unlock()

	m.broadcast()
	m.afterControl(app)
	return nil
}

// StopScreen stops screen mirroring (the capture pipeline and HLS server). It
// leaves the device connection intact.
func (m *Manager) StopScreen() {
	m.screen.stop()
	m.mu.Lock()
	wasCasting := m.screencasting
	m.screencasting = false
	app := m.app
	m.mu.Unlock()

	if app != nil {
		_ = m.callApp(app, func(a castApp) error { return a.StopMedia() })
	}
	if wasCasting {
		m.broadcast()
	}
}

// control runs a transport action against the connected app and refreshes state.
func (m *Manager) control(fn func(castApp) error) error {
	app, err := m.currentApp()
	if err != nil {
		return err
	}
	if err := m.callApp(app, fn); err != nil {
		return err
	}
	m.afterControl(app)
	return nil
}

// afterControl refreshes status after a state-changing action so subscribers
// see the result without waiting for the next poll tick.
func (m *Manager) afterControl(app castApp) {
	if err := m.callApp(app, func(a castApp) error { return a.Update() }); err != nil {
		log.Debugf("[Chromecast] Post-action status update failed: %v", err)
	}
	m.refreshPlayback(app)
}

func (m *Manager) Play() error  { return m.control(func(a castApp) error { return a.Unpause() }) }
func (m *Manager) Pause() error { return m.control(func(a castApp) error { return a.Pause() }) }
func (m *Manager) StopPlayback() error {
	return m.control(func(a castApp) error { return a.StopMedia() })
}
func (m *Manager) Seek(seconds float64) error {
	return m.control(func(a castApp) error { return a.SeekToTime(float32(seconds)) })
}
func (m *Manager) SetVolume(level float64) error {
	return m.control(func(a castApp) error { return a.SetVolume(float32(level)) })
}
func (m *Manager) SetMuted(muted bool) error {
	return m.control(func(a castApp) error { return a.SetMuted(muted) })
}

// pollLoop refreshes playback status on a timer until the context is cancelled.
func (m *Manager) pollLoop(ctx context.Context, app castApp) {
	ticker := time.NewTicker(pollInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if err := m.callApp(app, func(a castApp) error { return a.Update() }); err != nil {
				log.Debugf("[Chromecast] Status update failed: %v", err)
				continue
			}
			m.refreshPlayback(app)
		}
	}
}

// refreshPlayback reads the app's cached status and broadcasts if it changed.
func (m *Manager) refreshPlayback(app castApp) {
	pb := buildPlayback(m.statusOf(app))

	m.mu.Lock()
	// Ignore late refreshes from a connection we've already dropped.
	if m.app != app {
		m.mu.Unlock()
		return
	}
	changed := !playbackEqual(m.playback, pb)
	m.playback = pb
	m.mu.Unlock()

	if changed {
		m.broadcast()
	}
}

// buildPlayback maps the go-chromecast status into our Playback model, or nil
// when nothing is loaded.
func buildPlayback(app *cast.Application, media *cast.Media, vol *cast.Volume) *Playback {
	if app == nil && media == nil {
		return nil
	}
	pb := &Playback{}
	if app != nil {
		pb.AppName = app.DisplayName
		if pb.AppName == "" {
			pb.AppName = app.StatusText
		}
	}
	if media != nil {
		pb.State = media.PlayerState
		pb.CurrentTime = float64(media.CurrentTime)
		pb.Duration = float64(media.Media.Duration)
		pb.Title = media.Media.Metadata.Title
		pb.Subtitle = media.Media.Metadata.Subtitle
		pb.Artist = media.Media.Metadata.Artist
	}
	if vol != nil {
		pb.Volume = float64(vol.Level)
		pb.Muted = vol.Muted
	}
	return pb
}

func playbackEqual(a, b *Playback) bool {
	if a == nil || b == nil {
		return a == b
	}
	return *a == *b
}

// GetState returns a snapshot of the current discovery state and device list.
func (m *Manager) GetState() State {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.snapshot()
}

// snapshot builds a State value. Caller must hold at least a read lock.
func (m *Manager) snapshot() State {
	devices := make([]Device, 0, len(m.devices))
	for _, d := range m.devices {
		devices = append(devices, d)
	}
	// Stable ordering so the UI list doesn't reshuffle between updates.
	sort.Slice(devices, func(i, j int) bool {
		if devices[i].Name != devices[j].Name {
			return devices[i].Name < devices[j].Name
		}
		return devices[i].ID < devices[j].ID
	})

	state := State{
		Discovering:   m.discovering,
		Devices:       devices,
		Connected:     m.connected,
		Playback:      m.playback,
		Screencasting: m.screencasting,
		PreferredID:   m.preferredID,
	}
	if m.connected {
		dev := m.activeDevice
		state.ActiveDevice = &dev
	}
	return state
}

// Subscribe creates a buffered channel for the given client ID.
func (m *Manager) Subscribe(clientID string) chan State {
	ch := make(chan State, 64)
	m.subscribers.Store(clientID, ch)
	return ch
}

// Unsubscribe removes and closes the subscriber channel.
func (m *Manager) Unsubscribe(clientID string) {
	if val, ok := m.subscribers.LoadAndDelete(clientID); ok {
		// Serialize with broadcast so a concurrent send can't hit a closed channel.
		m.sendMu.Lock()
		close(val)
		m.sendMu.Unlock()
	}
}

func (m *Manager) broadcast() {
	if m.closed.Load() {
		return
	}
	m.mu.RLock()
	state := m.snapshot()
	m.mu.RUnlock()

	m.sendMu.Lock()
	defer m.sendMu.Unlock()
	m.subscribers.Range(func(key string, ch chan State) bool {
		select {
		case ch <- state:
		default:
		}
		return true
	})
}

// Close stops discovery, drops any active connection, and closes all
// subscriber channels.
func (m *Manager) Close() {
	m.closed.Store(true)
	m.StopDiscovery()
	m.Disconnect()

	m.sendMu.Lock()
	defer m.sendMu.Unlock()
	m.subscribers.Range(func(key string, ch chan State) bool {
		close(ch)
		m.subscribers.Delete(key)
		return true
	})
}
