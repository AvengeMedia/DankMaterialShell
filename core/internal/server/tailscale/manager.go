package tailscale

import (
	"context"
	"sync"
	"sync/atomic"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/pkg/syncmap"
	"tailscale.com/client/local"
	"tailscale.com/ipn"
	"tailscale.com/ipn/ipnstate"
)

const (
	statusTimeout  = 3 * time.Second
	debounceWindow = 150 * time.Millisecond
)

// tailscaleClient abstracts the Tailscale local API for testing.
type tailscaleClient interface {
	WatchIPNBus(ctx context.Context, mask ipn.NotifyWatchOpt) (ipnBusWatcher, error)
	Status(ctx context.Context) (*ipnstate.Status, error)
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
}

// NewManager creates a new Tailscale manager and starts watching the IPN bus.
func NewManager(socketPath string) *Manager {
	lc := &local.Client{Socket: socketPath}
	return newManager(&localClientWrapper{client: lc})
}

func newManager(client tailscaleClient) *Manager {
	ctx, cancel := context.WithCancel(context.Background())
	m := &Manager{
		state:  &TailscaleState{},
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

	mask := ipn.NotifyInitialState | ipn.NotifyInitialNetMap | ipn.NotifyRateLimit
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
				m.updateState(&TailscaleState{Connected: false, BackendState: "Unreachable"})
				unreachableSent = true
			}
			select {
			case <-ctx.Done():
				return
			case <-time.After(backoff):
			}
			backoff = min(backoff*2, 30*time.Second)
			continue
		}

		unreachableSent = false
		backoff = time.Second
		log.Info("[Tailscale] Connected to IPN bus")
		m.markAvailable()

		for {
			notify, err := watcher.Next()
			if err != nil {
				log.Warnf("[Tailscale] IPN bus error: %v", err)
				break
			}

			if notify.State == nil && notify.NetMap == nil {
				continue
			}
			select {
			case m.dirty <- struct{}{}:
			default:
			}
		}

		watcher.Close()
	}
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

	status, err := m.client.Status(statusCtx)
	if err != nil {
		log.Warnf("[Tailscale] Failed to fetch status: %v", err)
		return
	}

	state := convertStatus(status)
	m.updateState(state)
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

	status, err := m.client.Status(ctx)
	if err != nil {
		log.Warnf("[Tailscale] Failed to refresh state: %v", err)
		return
	}

	state := convertStatus(status)
	m.updateState(state)
}
