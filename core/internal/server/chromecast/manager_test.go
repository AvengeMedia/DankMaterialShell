package chromecast

import (
	"context"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/grandcat/zeroconf"
	"github.com/vishen/go-chromecast/cast"
	castdns "github.com/vishen/go-chromecast/dns"
)

// blockingCatCmd returns a `cat` command that genuinely blocks (its stdin is a
// pipe whose write end stays open until test cleanup), so the subprocess stays
// alive for the test instead of reading EOF from /dev/null and exiting at once.
// Stand-in for the cast helper / doubletake; no sleeps, no timing.
func blockingCatCmd(t *testing.T) *exec.Cmd {
	t.Helper()
	pr, pw, err := os.Pipe()
	if err != nil {
		t.Fatalf("pipe: %v", err)
	}
	t.Cleanup(func() {
		pw.Close()
		pr.Close()
	})
	c := exec.Command("cat")
	c.Stdin = pr
	return c
}

// withDiscoverFunc swaps the package discovery function for the duration of a
// test and restores it afterwards.
func withDiscoverFunc(t *testing.T, fn func(ctx context.Context, iface *net.Interface) (<-chan castdns.CastEntry, error)) {
	t.Helper()
	prev := discoverFunc
	discoverFunc = fn
	t.Cleanup(func() { discoverFunc = prev })
}

// TestMain disables real AirPlay (zeroconf) discovery for all tests by default;
// airplay-specific tests override airplayDiscoverFunc.
func TestMain(m *testing.M) {
	// Never touch the real system bus / mDNS in tests; drive discovery through
	// the overridable fakes only.
	avahiAvailableFunc = func() bool { return false }
	airplayDiscoverFunc = func(ctx context.Context) (<-chan Device, error) {
		ch := make(chan Device)
		go func() { <-ctx.Done(); close(ch) }()
		return ch, nil
	}
	discoverFunc = func(ctx context.Context, iface *net.Interface) (<-chan castdns.CastEntry, error) {
		ch := make(chan castdns.CastEntry)
		go func() { <-ctx.Done(); close(ch) }()
		return ch, nil
	}
	os.Exit(m.Run())
}

func withAirplayDiscoverFunc(t *testing.T, fn func(ctx context.Context) (<-chan Device, error)) {
	t.Helper()
	prev := airplayDiscoverFunc
	airplayDiscoverFunc = fn
	t.Cleanup(func() { airplayDiscoverFunc = prev })
}

// emitOnce returns a discovery func that emits the given devices then stays open
// until ctx is cancelled.
func emitOnceAirplay(devs ...Device) func(ctx context.Context) (<-chan Device, error) {
	return func(ctx context.Context) (<-chan Device, error) {
		out := make(chan Device, len(devs))
		for _, d := range devs {
			out <- d
		}
		go func() { <-ctx.Done(); close(out) }()
		return out, nil
	}
}

func emitOnceChromecast(entries ...castdns.CastEntry) func(ctx context.Context, iface *net.Interface) (<-chan castdns.CastEntry, error) {
	return func(ctx context.Context, iface *net.Interface) (<-chan castdns.CastEntry, error) {
		out := make(chan castdns.CastEntry, len(entries))
		for _, e := range entries {
			out <- e
		}
		go func() { <-ctx.Done(); close(out) }()
		return out, nil
	}
}

func TestDiscoversBothProtocols(t *testing.T) {
	withDiscoverFunc(t, emitOnceChromecast(castdns.CastEntry{
		UUID: "cc1", DeviceName: "Living Room", Device: "Chromecast", Port: 8009, AddrV4: net.IPv4(192, 168, 1, 5),
	}))
	withAirplayDiscoverFunc(t, emitOnceAirplay(Device{
		ID: "ap1", Name: "TV de la sala", Model: "Hisense", Host: "192.168.1.6", Port: 7000, Protocol: ProtocolAirplay,
	}))

	m := NewManager()
	defer m.Close()
	sub := m.Subscribe("test")
	if err := m.StartDiscovery(); err != nil {
		t.Fatalf("StartDiscovery: %v", err)
	}

	got := waitForState(t, sub, func(s State) bool { return len(s.Devices) == 2 })

	byProto := map[string]Device{}
	for _, d := range got.Devices {
		byProto[d.Protocol] = d
	}
	if byProto[ProtocolChromecast].ID != "cc1" {
		t.Errorf("missing/incorrect chromecast device: %+v", byProto)
	}
	if byProto[ProtocolAirplay].ID != "ap1" || byProto[ProtocolAirplay].Port != 7000 {
		t.Errorf("missing/incorrect airplay device: %+v", byProto)
	}
}

func TestConnectAirplayStartsMirror(t *testing.T) {
	prev := buildDoubletakeCmd
	buildDoubletakeCmd = func(host string) *exec.Cmd { return blockingCatCmd(t) }
	defer func() { buildDoubletakeCmd = prev }()

	withDiscoverFunc(t, emitOnceChromecast())
	withAirplayDiscoverFunc(t, emitOnceAirplay(Device{
		ID: "ap1", Name: "TV de la sala", Host: "192.168.4.33", Port: 7000, Protocol: ProtocolAirplay,
	}))

	m := NewManager()
	defer m.Close()
	sub := m.Subscribe("test")
	if err := m.StartDiscovery(); err != nil {
		t.Fatalf("StartDiscovery: %v", err)
	}
	waitForState(t, sub, func(s State) bool { return len(s.Devices) == 1 })

	if err := m.Connect("ap1"); err != nil {
		t.Fatalf("Connect(airplay): %v", err)
	}
	got := waitForState(t, sub, func(s State) bool { return s.Connected && s.Screencasting })
	if got.ActiveDevice == nil || got.ActiveDevice.Protocol != ProtocolAirplay {
		t.Fatalf("expected active airplay device, got %+v", got.ActiveDevice)
	}
	if !m.airplay.isRunning() {
		t.Fatal("expected airplay mirror running")
	}

	m.Disconnect()
	got = waitForState(t, sub, func(s State) bool { return !s.Connected })
	if m.airplay.isRunning() {
		t.Fatal("expected airplay mirror stopped")
	}
	if got.Screencasting {
		t.Fatal("expected screencasting cleared on disconnect")
	}
}

func TestAirplayEntryNormalization(t *testing.T) {
	dev := airplayEntryToDevice(&zeroconf.ServiceEntry{
		ServiceRecord: zeroconf.ServiceRecord{Instance: "TV de la sala"},
		HostName:      "LinuxTV.local.",
		Port:          7000,
		AddrIPv4:      []net.IP{net.IPv4(192, 168, 4, 33)},
		Text:          []string{"deviceid=AA:BB:CC:DD:EE:FF", "model=55A6QU"},
	})
	if dev.Protocol != ProtocolAirplay || dev.ID != "airplay:TV de la sala" || dev.Model != "55A6QU" || dev.Host != "192.168.4.33" {
		t.Fatalf("unexpected normalization: %+v", dev)
	}
}

// The same device must keep the same ID across browses even when the deviceid
// TXT and/or the A record are dropped under mDNS port contention — the id is
// derived from the always-present instance name, not the flaky TXT or host:port.
func TestAirplayEntryStableIDWithoutTXT(t *testing.T) {
	full := airplayEntryToDevice(&zeroconf.ServiceEntry{
		ServiceRecord: zeroconf.ServiceRecord{Instance: "TV de la sala"},
		HostName:      "LinuxTV.local.",
		Port:          7000,
		AddrIPv4:      []net.IP{net.IPv4(192, 168, 4, 33)},
		Text:          []string{"deviceid=AA:BB:CC:DD:EE:FF", "model=55A6QU"},
	})
	// A later browse that lost the TXT record and the resolved address.
	partial := airplayEntryToDevice(&zeroconf.ServiceEntry{
		ServiceRecord: zeroconf.ServiceRecord{Instance: "TV de la sala"},
		HostName:      "LinuxTV.local.",
		Port:          7000,
	})
	if partial.ID != full.ID {
		t.Fatalf("id flipped across browses: full=%q partial=%q", full.ID, partial.ID)
	}
}

func TestUnescapeDNS(t *testing.T) {
	cases := map[string]string{
		`TV de la sala`:                  "TV de la sala",
		`Geoffrey\226\128\153s\ MacBook`: "Geoffrey’s MacBook",
		`Mac\ Pro\ \(2\)`:                "Mac Pro (2)",
	}
	for in, want := range cases {
		if got := unescapeDNS(in); got != want {
			t.Errorf("unescapeDNS(%q) = %q, want %q", in, got, want)
		}
	}
}

// withNewAppFunc swaps the cast-application constructor for the test duration.
func withNewAppFunc(t *testing.T, fn func() castApp) {
	t.Helper()
	prev := newAppFunc
	newAppFunc = fn
	t.Cleanup(func() { newAppFunc = prev })
}

// fakeApp is a test double for the go-chromecast Application.
type fakeApp struct {
	mu       sync.Mutex
	startErr error
	started  bool
	closed   bool
	app      *cast.Application
	media    *cast.Media
	vol      *cast.Volume

	loadedURL    string
	loadedType   string
	unpaused     bool
	paused       bool
	mediaStopped bool
	seekedTo     float32
	volumeSet    float32
	muteSet      bool
}

func (f *fakeApp) Start(addr string, port int) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.started = true
	return f.startErr
}

func (f *fakeApp) Update() error { return nil }

func (f *fakeApp) Status() (*cast.Application, *cast.Media, *cast.Volume) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.app, f.media, f.vol
}

func (f *fakeApp) Load(url string, startTime int, contentType string, transcode, detach, forceDetach bool) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.loadedURL = url
	f.loadedType = contentType
	return nil
}

func (f *fakeApp) Unpause() error { f.mu.Lock(); defer f.mu.Unlock(); f.unpaused = true; return nil }
func (f *fakeApp) Pause() error   { f.mu.Lock(); defer f.mu.Unlock(); f.paused = true; return nil }
func (f *fakeApp) StopMedia() error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.mediaStopped = true
	return nil
}
func (f *fakeApp) SeekToTime(v float32) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.seekedTo = v
	return nil
}
func (f *fakeApp) SetVolume(v float32) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.volumeSet = v
	return nil
}
func (f *fakeApp) SetMuted(v bool) error { f.mu.Lock(); defer f.mu.Unlock(); f.muteSet = v; return nil }

func (f *fakeApp) Close(stopMedia bool) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.closed = true
	return nil
}

// discoverOneDevice installs a discovery func that emits a single device and
// then blocks until cancelled, and starts discovery on the manager.
func discoverOneDevice(t *testing.T, m *Manager, entry castdns.CastEntry) {
	t.Helper()
	emit := make(chan castdns.CastEntry, 1)
	emit <- entry
	withDiscoverFunc(t, func(ctx context.Context, iface *net.Interface) (<-chan castdns.CastEntry, error) {
		out := make(chan castdns.CastEntry)
		go func() {
			defer close(out)
			for {
				select {
				case <-ctx.Done():
					return
				case e := <-emit:
					out <- e
				}
			}
		}()
		return out, nil
	})
	sub := m.Subscribe("discover-helper")
	defer m.Unsubscribe("discover-helper")
	if err := m.StartDiscovery(); err != nil {
		t.Fatalf("StartDiscovery: %v", err)
	}
	waitForState(t, sub, func(s State) bool { return len(s.Devices) == 1 })
}

// waitForState reads states from ch until pred is satisfied or it times out.
func waitForState(t *testing.T, ch chan State, pred func(State) bool) State {
	t.Helper()
	timeout := time.After(2 * time.Second)
	for {
		select {
		case s := <-ch:
			if pred(s) {
				return s
			}
		case <-timeout:
			t.Fatal("timed out waiting for expected state")
		}
	}
}

func TestStartDiscoveryBroadcastsDevices(t *testing.T) {
	entries := make(chan castdns.CastEntry, 2)
	withDiscoverFunc(t, func(ctx context.Context, iface *net.Interface) (<-chan castdns.CastEntry, error) {
		out := make(chan castdns.CastEntry)
		go func() {
			defer close(out)
			for {
				select {
				case <-ctx.Done():
					return
				case e, ok := <-entries:
					if !ok {
						return
					}
					out <- e
				}
			}
		}()
		return out, nil
	})

	m := NewManager()
	defer m.Close()

	sub := m.Subscribe("test")

	if err := m.StartDiscovery(); err != nil {
		t.Fatalf("StartDiscovery: %v", err)
	}

	// First broadcast is the empty in-progress state.
	waitForState(t, sub, func(s State) bool { return s.Discovering && len(s.Devices) == 0 })

	entries <- castdns.CastEntry{UUID: "uuid-b", DeviceName: "Bedroom", Device: "Chromecast", Port: 8009}
	entries <- castdns.CastEntry{UUID: "uuid-a", DeviceName: "Attic", Device: "Google Nest", Port: 8009}

	got := waitForState(t, sub, func(s State) bool { return len(s.Devices) == 2 })

	// snapshot must be sorted by Name for stable UI ordering.
	if got.Devices[0].Name != "Attic" || got.Devices[1].Name != "Bedroom" {
		t.Fatalf("devices not sorted by name: %+v", got.Devices)
	}
	if !got.Discovering {
		t.Fatal("expected Discovering=true while scan is active")
	}
}

func TestStartDiscoveryIsIdempotent(t *testing.T) {
	withDiscoverFunc(t, func(ctx context.Context, iface *net.Interface) (<-chan castdns.CastEntry, error) {
		out := make(chan castdns.CastEntry)
		go func() {
			<-ctx.Done()
			close(out)
		}()
		return out, nil
	})

	m := NewManager()
	defer m.Close()

	if err := m.StartDiscovery(); err != nil {
		t.Fatalf("StartDiscovery: %v", err)
	}
	if err := m.StartDiscovery(); err != nil {
		t.Fatalf("second StartDiscovery should be a no-op, got: %v", err)
	}
	if !m.GetState().Discovering {
		t.Fatal("expected Discovering=true")
	}
}

func TestStopDiscoveryEndsScan(t *testing.T) {
	withDiscoverFunc(t, func(ctx context.Context, iface *net.Interface) (<-chan castdns.CastEntry, error) {
		out := make(chan castdns.CastEntry)
		go func() {
			<-ctx.Done()
			close(out)
		}()
		return out, nil
	})

	m := NewManager()
	defer m.Close()

	sub := m.Subscribe("test")
	if err := m.StartDiscovery(); err != nil {
		t.Fatalf("StartDiscovery: %v", err)
	}
	waitForState(t, sub, func(s State) bool { return s.Discovering })

	m.StopDiscovery()
	waitForState(t, sub, func(s State) bool { return !s.Discovering })
}

// A device without a UUID must still be tracked (keyed by host:port) rather
// than dropped or collapsed with other UUID-less devices.
func TestDeviceWithoutUUIDIsKeyedByHostPort(t *testing.T) {
	entries := make(chan castdns.CastEntry, 2)
	withDiscoverFunc(t, func(ctx context.Context, iface *net.Interface) (<-chan castdns.CastEntry, error) {
		out := make(chan castdns.CastEntry)
		go func() {
			defer close(out)
			for {
				select {
				case <-ctx.Done():
					return
				case e, ok := <-entries:
					if !ok {
						return
					}
					out <- e
				}
			}
		}()
		return out, nil
	})

	m := NewManager()
	defer m.Close()
	sub := m.Subscribe("test")
	if err := m.StartDiscovery(); err != nil {
		t.Fatalf("StartDiscovery: %v", err)
	}

	entries <- castdns.CastEntry{AddrV4: net.IPv4(192, 168, 1, 10), Port: 8009}
	entries <- castdns.CastEntry{AddrV4: net.IPv4(192, 168, 1, 11), Port: 8009}

	waitForState(t, sub, func(s State) bool { return len(s.Devices) == 2 })
}

func TestConnectBroadcastsPlayback(t *testing.T) {
	fake := &fakeApp{
		app:   &cast.Application{DisplayName: "Default Media Receiver"},
		media: &cast.Media{PlayerState: "PLAYING", CurrentTime: 12, Media: cast.MediaItem{Duration: 200, Metadata: cast.MediaMetadata{Title: "Song"}}},
		vol:   &cast.Volume{Level: 0.5, Muted: false},
	}
	withNewAppFunc(t, func() castApp { return fake })

	m := NewManager()
	defer m.Close()
	discoverOneDevice(t, m, castdns.CastEntry{UUID: "dev1", DeviceName: "Living Room", Port: 8009, AddrV4: net.IPv4(192, 168, 1, 5)})

	sub := m.Subscribe("test")
	if err := m.Connect("dev1"); err != nil {
		t.Fatalf("Connect: %v", err)
	}

	got := waitForState(t, sub, func(s State) bool {
		return s.Connected && s.Playback != nil && s.Playback.State == "PLAYING"
	})
	if !fake.started {
		t.Fatal("expected Start to be called on the app")
	}
	if got.ActiveDevice == nil || got.ActiveDevice.ID != "dev1" {
		t.Fatalf("expected active device dev1, got %+v", got.ActiveDevice)
	}
	if got.Playback.Title != "Song" || got.Playback.Duration != 200 || got.Playback.Volume != 0.5 {
		t.Fatalf("unexpected playback: %+v", got.Playback)
	}
}

// connectFake wires a discovered device + fake app and connects to it,
// returning the manager and fake for assertions.
func connectFake(t *testing.T, fake *fakeApp) *Manager {
	t.Helper()
	withNewAppFunc(t, func() castApp { return fake })
	m := NewManager()
	t.Cleanup(m.Close)
	discoverOneDevice(t, m, castdns.CastEntry{UUID: "dev1", DeviceName: "TV", Port: 8009, AddrV4: net.IPv4(192, 168, 1, 5)})
	if err := m.Connect("dev1"); err != nil {
		t.Fatalf("Connect: %v", err)
	}
	return m
}

func TestCastLoadsMedia(t *testing.T) {
	fake := &fakeApp{app: &cast.Application{DisplayName: "Receiver"}}
	m := connectFake(t, fake)

	if err := m.Cast("http://example.com/v.mp4", "video/mp4"); err != nil {
		t.Fatalf("Cast: %v", err)
	}
	if fake.loadedURL != "http://example.com/v.mp4" || fake.loadedType != "video/mp4" {
		t.Fatalf("unexpected load: url=%q type=%q", fake.loadedURL, fake.loadedType)
	}
}

func TestTransportControlsCallThrough(t *testing.T) {
	fake := &fakeApp{app: &cast.Application{DisplayName: "Receiver"}}
	m := connectFake(t, fake)

	if err := m.Play(); err != nil || !fake.unpaused {
		t.Fatalf("Play: err=%v unpaused=%v", err, fake.unpaused)
	}
	if err := m.Pause(); err != nil || !fake.paused {
		t.Fatalf("Pause: err=%v paused=%v", err, fake.paused)
	}
	if err := m.Seek(42.5); err != nil || fake.seekedTo != 42.5 {
		t.Fatalf("Seek: err=%v seekedTo=%v", err, fake.seekedTo)
	}
	if err := m.SetVolume(0.25); err != nil || fake.volumeSet != 0.25 {
		t.Fatalf("SetVolume: err=%v volumeSet=%v", err, fake.volumeSet)
	}
	if err := m.SetMuted(true); err != nil || !fake.muteSet {
		t.Fatalf("SetMuted: err=%v muteSet=%v", err, fake.muteSet)
	}
	if err := m.StopPlayback(); err != nil || !fake.mediaStopped {
		t.Fatalf("StopPlayback: err=%v mediaStopped=%v", err, fake.mediaStopped)
	}
}

func TestControlsErrorWhenNotConnected(t *testing.T) {
	m := NewManager()
	defer m.Close()
	if err := m.Cast("http://x/y.mp4", ""); err != errNotConnected {
		t.Fatalf("expected errNotConnected, got %v", err)
	}
	if err := m.Play(); err != errNotConnected {
		t.Fatalf("expected errNotConnected from Play, got %v", err)
	}
}

// withStubCapture stubs the capture helper with `cat` (blocks on stdin, no
// timing), a fixed local IP, and a fake portal session so tests never touch the
// network, GStreamer, or the real screen-share dialog.
func withStubCapture(t *testing.T) {
	t.Helper()
	prevCmd := buildHelperCmd
	prevIP := outboundIPFunc
	prevPortal := requestScreencast
	buildHelperCmd = func(outDir string, nodeID uint32) *exec.Cmd { return blockingCatCmd(t) }
	outboundIPFunc = func(host string) (string, error) { return "127.0.0.1", nil }
	requestScreencast = func(ctx context.Context) (*PortalSession, error) {
		r, w, err := os.Pipe()
		if err != nil {
			return nil, err
		}
		w.Close()
		return &PortalSession{Fd: r, NodeID: 7}, nil
	}
	t.Cleanup(func() {
		buildHelperCmd = prevCmd
		outboundIPFunc = prevIP
		requestScreencast = prevPortal
	})
}

func TestCastScreenStartsCaptureAndCasts(t *testing.T) {
	withStubCapture(t)
	fake := &fakeApp{app: &cast.Application{DisplayName: "Receiver"}}
	m := connectFake(t, fake)

	sub := m.Subscribe("test")
	if err := m.CastScreen(); err != nil {
		t.Fatalf("CastScreen: %v", err)
	}

	if !strings.HasSuffix(fake.loadedURL, "/"+hlsPlaylist) {
		t.Fatalf("expected HLS playlist URL, got %q", fake.loadedURL)
	}
	if fake.loadedType != hlsContentType {
		t.Fatalf("expected HLS content type, got %q", fake.loadedType)
	}
	waitForState(t, sub, func(s State) bool { return s.Screencasting })
	if !m.screen.isRunning() {
		t.Fatal("expected screen streamer to be running")
	}

	m.StopScreen()
	waitForState(t, sub, func(s State) bool { return !s.Screencasting })
	if m.screen.isRunning() {
		t.Fatal("expected screen streamer to be stopped")
	}
}

func TestCastScreenRequiresConnection(t *testing.T) {
	withStubCapture(t)
	m := NewManager()
	defer m.Close()
	if err := m.CastScreen(); err != errNotConnected {
		t.Fatalf("expected errNotConnected, got %v", err)
	}
}

func TestScreenStreamerServesHLSDir(t *testing.T) {
	withStubCapture(t)

	s := &screenStreamer{}
	url, err := s.start("127.0.0.1", nil)
	if err != nil {
		t.Fatalf("start: %v", err)
	}
	defer s.stop()

	// Drop a file into the served directory and fetch it back.
	if err := os.WriteFile(filepath.Join(s.dir, hlsPlaylist), []byte("#EXTM3U\n"), 0o644); err != nil {
		t.Fatalf("write playlist: %v", err)
	}
	resp, err := http.Get(url)
	if err != nil {
		t.Fatalf("GET %s: %v", url, err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK || !strings.Contains(string(body), "#EXTM3U") {
		t.Fatalf("unexpected response: status=%d body=%q", resp.StatusCode, string(body))
	}
}

// withTempConfig points config persistence at a temp file for the test.
func withTempConfig(t *testing.T) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "castsettings.json")
	prev := configPathFunc
	configPathFunc = func() (string, error) { return path, nil }
	t.Cleanup(func() { configPathFunc = prev })
}

func TestSetPreferredPersistsAndReloads(t *testing.T) {
	withTempConfig(t)

	m := NewManager()
	m.SetPreferred("dev-42")
	if m.GetState().PreferredID != "dev-42" {
		t.Fatalf("expected preferred dev-42, got %q", m.GetState().PreferredID)
	}

	// A fresh manager must load the persisted preference.
	m2 := NewManager()
	if m2.GetState().PreferredID != "dev-42" {
		t.Fatalf("preference not reloaded, got %q", m2.GetState().PreferredID)
	}

	m2.ClearPreferred()
	m3 := NewManager()
	if m3.GetState().PreferredID != "" {
		t.Fatalf("expected cleared preference, got %q", m3.GetState().PreferredID)
	}
}

func TestAutoReconnectsToPreferredDevice(t *testing.T) {
	withTempConfig(t)
	fake := &fakeApp{app: &cast.Application{DisplayName: "Receiver"}}
	withNewAppFunc(t, func() castApp { return fake })

	m := NewManager()
	defer m.Close()
	m.SetPreferred("dev1")

	sub := m.Subscribe("test")
	// Discover the preferred device; the manager should auto-connect.
	discoverOneDevice(t, m, castdns.CastEntry{UUID: "dev1", DeviceName: "Living Room", Port: 8009, AddrV4: net.IPv4(192, 168, 1, 5)})

	got := waitForState(t, sub, func(s State) bool { return s.Connected })
	if got.ActiveDevice == nil || got.ActiveDevice.ID != "dev1" {
		t.Fatalf("expected auto-connect to dev1, got %+v", got.ActiveDevice)
	}
	if !fake.started {
		t.Fatal("expected Start to be called during auto-reconnect")
	}
}

func TestAutoConnectsToPreferredAirplayDevice(t *testing.T) {
	withTempConfig(t)
	prev := buildDoubletakeCmd
	buildDoubletakeCmd = func(host string) *exec.Cmd { return blockingCatCmd(t) }
	defer func() { buildDoubletakeCmd = prev }()

	m := NewManager()
	defer m.Close()
	m.SetPreferred("airplay:Living Room TV")

	sub := m.Subscribe("test")
	// The preferred AirPlay device appears: auto-connect must start the mirror.
	m.upsertDevice(Device{ID: "airplay:Living Room TV", Name: "Living Room TV", Host: "192.168.4.40", Port: 7000, Protocol: ProtocolAirplay})

	got := waitForState(t, sub, func(s State) bool { return s.Connected && s.Screencasting })
	if got.ActiveDevice == nil || got.ActiveDevice.ID != "airplay:Living Room TV" {
		t.Fatalf("expected auto-connect to preferred airplay device, got %+v", got.ActiveDevice)
	}
	if !m.airplay.isRunning() {
		t.Fatal("expected airplay mirror running after auto-connect")
	}
}

func TestConnectUnknownDeviceErrors(t *testing.T) {
	withNewAppFunc(t, func() castApp { return &fakeApp{} })
	m := NewManager()
	defer m.Close()
	if err := m.Connect("nope"); err == nil {
		t.Fatal("expected error connecting to unknown device")
	}
}

func TestDisconnectClearsStateAndClosesApp(t *testing.T) {
	fake := &fakeApp{app: &cast.Application{DisplayName: "Receiver"}}
	withNewAppFunc(t, func() castApp { return fake })

	m := NewManager()
	defer m.Close()
	discoverOneDevice(t, m, castdns.CastEntry{UUID: "dev1", DeviceName: "Kitchen", Port: 8009, AddrV4: net.IPv4(192, 168, 1, 6)})

	sub := m.Subscribe("test")
	if err := m.Connect("dev1"); err != nil {
		t.Fatalf("Connect: %v", err)
	}
	waitForState(t, sub, func(s State) bool { return s.Connected })

	m.Disconnect()
	got := waitForState(t, sub, func(s State) bool { return !s.Connected })
	if got.ActiveDevice != nil || got.Playback != nil {
		t.Fatalf("expected cleared state, got %+v", got)
	}
	if !fake.closed {
		t.Fatal("expected Close to be called on the app")
	}
}
