package tailscale

import (
	"context"
	"net/http"
	"reflect"
	"sync"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/pkg/syncmap"
	"tailscale.com/client/local"
)

const (
	pollInterval = 30 * time.Second
	pollTimeout  = 3 * time.Second
)

// Manager manages Tailscale state polling and subscriber notifications.
type Manager struct {
	state       *TailscaleState
	stateMutex  sync.RWMutex
	subscribers syncmap.Map[string, chan TailscaleState]
	stopChan    chan struct{}
	pollWG      sync.WaitGroup
	lastState   *TailscaleState
	client      local.Client
}

// NewManager creates a new Tailscale manager. It performs an initial poll
// and starts background polling.
func NewManager(socketPath string) (*Manager, error) {
	m := &Manager{
		state:    &TailscaleState{},
		client:   local.Client{Socket: socketPath},
		stopChan: make(chan struct{}),
	}

	if err := m.poll(); err != nil {
		log.Warnf("[Tailscale] Initial poll failed: %v", err)
	}

	m.pollWG.Add(1)
	go m.pollLoop()

	return m, nil
}

// newTestManager creates a manager with a custom HTTP transport for testing.
func newTestManager(transport http.RoundTripper) *Manager {
	return &Manager{
		state:    &TailscaleState{},
		client:   local.Client{Transport: transport},
		stopChan: make(chan struct{}),
	}
}

// poll fetches the current Tailscale status and updates the manager state.
func (m *Manager) poll() error {
	ctx, cancel := context.WithTimeout(context.Background(), pollTimeout)
	defer cancel()

	status, err := m.client.Status(ctx)
	if err != nil {
		return err
	}

	state := convertStatus(status)

	m.stateMutex.Lock()
	m.state = state
	m.stateMutex.Unlock()

	return nil
}

// pollLoop runs on a ticker, polling Tailscale every pollInterval and notifying subscribers if state changed.
func (m *Manager) pollLoop() {
	defer m.pollWG.Done()

	ticker := time.NewTicker(pollInterval)
	defer ticker.Stop()

	for {
		select {
		case <-m.stopChan:
			return
		case <-ticker.C:
			if err := m.poll(); err != nil {
				log.Warnf("[Tailscale] Poll failed: %v", err)
				m.stateMutex.Lock()
				m.state = &TailscaleState{Connected: false, BackendState: "Unreachable"}
				m.stateMutex.Unlock()
			}
			m.checkAndNotify()
		}
	}
}

// checkAndNotify compares the current state with the last notified state and broadcasts if changed.
func (m *Manager) checkAndNotify() {
	m.stateMutex.RLock()
	current := m.state
	m.stateMutex.RUnlock()

	if !reflect.DeepEqual(m.lastState, current) {
		stateCopy := *current
		m.lastState = &stateCopy
		m.broadcastState(*current)
	}
}

// broadcastState sends the given state to all subscriber channels.
func (m *Manager) broadcastState(state TailscaleState) {
	m.subscribers.Range(func(key string, ch chan TailscaleState) bool {
		select {
		case ch <- state:
		default:
		}
		return true
	})
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

// Subscribe creates a buffered channel for the given client ID and stores it.
func (m *Manager) Subscribe(clientID string) chan TailscaleState {
	ch := make(chan TailscaleState, 64)
	m.subscribers.Store(clientID, ch)
	return ch
}

// Unsubscribe removes and closes the subscriber channel for the given client ID.
func (m *Manager) Unsubscribe(clientID string) {
	if val, ok := m.subscribers.LoadAndDelete(clientID); ok {
		close(val)
	}
}

// Close stops the polling goroutine and closes all subscriber channels.
func (m *Manager) Close() {
	close(m.stopChan)
	m.pollWG.Wait()

	m.subscribers.Range(func(key string, ch chan TailscaleState) bool {
		close(ch)
		m.subscribers.Delete(key)
		return true
	})
}

// RefreshState triggers an immediate poll and notifies subscribers if state changed.
func (m *Manager) RefreshState() {
	if err := m.poll(); err != nil {
		log.Warnf("[Tailscale] Failed to refresh state: %v", err)
		return
	}
	m.checkAndNotify()
}
