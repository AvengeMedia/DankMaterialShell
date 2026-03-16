package tailscale

import (
	"context"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"tailscale.com/ipn"
	"tailscale.com/ipn/ipnstate"
)

// mockWatcher yields canned Notify events, then returns err or blocks until Close/context cancel.
type mockWatcher struct {
	events []ipn.Notify
	idx    int
	err    error
	done   chan struct{}
	ctx    context.Context
	mu     sync.Mutex
	closed bool
}

func newMockWatcher(ctx context.Context, events []ipn.Notify, err error) *mockWatcher {
	return &mockWatcher{
		events: events,
		err:    err,
		done:   make(chan struct{}),
		ctx:    ctx,
	}
}

func (w *mockWatcher) Next() (ipn.Notify, error) {
	w.mu.Lock()
	if w.idx < len(w.events) {
		n := w.events[w.idx]
		w.idx++
		w.mu.Unlock()
		return n, nil
	}
	if w.err != nil {
		err := w.err
		w.mu.Unlock()
		return ipn.Notify{}, err
	}
	w.mu.Unlock()
	select {
	case <-w.done:
		return ipn.Notify{}, fmt.Errorf("watcher closed")
	case <-w.ctx.Done():
		return ipn.Notify{}, w.ctx.Err()
	}
}

func (w *mockWatcher) Close() error {
	w.mu.Lock()
	defer w.mu.Unlock()
	if !w.closed {
		w.closed = true
		close(w.done)
	}
	return nil
}

// mockClient implements tailscaleClient for testing.
type mockClient struct {
	watchFn  func(ctx context.Context, mask ipn.NotifyWatchOpt) (ipnBusWatcher, error)
	statusFn func(ctx context.Context) (*ipnstate.Status, error)
}

func (c *mockClient) WatchIPNBus(ctx context.Context, mask ipn.NotifyWatchOpt) (ipnBusWatcher, error) {
	return c.watchFn(ctx, mask)
}

func (c *mockClient) Status(ctx context.Context) (*ipnstate.Status, error) {
	return c.statusFn(ctx)
}

func runningStatus() *ipnstate.Status {
	return &ipnstate.Status{
		Version:        "1.94.2",
		BackendState:   "Running",
		MagicDNSSuffix: "example.ts.net",
		CurrentTailnet: &ipnstate.TailnetStatus{
			Name:           "user@example.com",
			MagicDNSSuffix: "example.ts.net",
		},
		Self: &ipnstate.PeerStatus{
			HostName: "cachyos",
			DNSName:  "cachyos.example.ts.net.",
			OS:       "linux",
			Online:   true,
		},
	}
}

func TestWatchLoop_StateChange(t *testing.T) {
	stateVal := ipn.Running
	statusCalled := make(chan struct{}, 4)
	var watchCount int32

	client := &mockClient{
		watchFn: func(ctx context.Context, mask ipn.NotifyWatchOpt) (ipnBusWatcher, error) {
			watchCount++
			if watchCount == 1 {
				return newMockWatcher(ctx,
					[]ipn.Notify{{State: &stateVal}},
					fmt.Errorf("done"),
				), nil
			}
			return newMockWatcher(ctx, nil, nil), nil
		},
		statusFn: func(ctx context.Context) (*ipnstate.Status, error) {
			select {
			case statusCalled <- struct{}{}:
			default:
			}
			return runningStatus(), nil
		},
	}

	m := newManager(client)
	defer m.Close()

	require.Eventually(t, func() bool {
		return len(statusCalled) > 0
	}, 2*time.Second, 10*time.Millisecond)

	state := m.GetState()
	assert.True(t, state.Connected)
	assert.Equal(t, "Running", state.BackendState)
	assert.Equal(t, "cachyos", state.Self.Hostname)
}

func TestWatchLoop_Reconnect(t *testing.T) {
	watchCalled := make(chan struct{}, 4)

	client := &mockClient{
		watchFn: func(ctx context.Context, mask ipn.NotifyWatchOpt) (ipnBusWatcher, error) {
			select {
			case watchCalled <- struct{}{}:
			default:
			}
			if len(watchCalled) <= 1 {
				return nil, fmt.Errorf("connection refused")
			}
			return newMockWatcher(ctx, nil, nil), nil
		},
		statusFn: func(ctx context.Context) (*ipnstate.Status, error) {
			return runningStatus(), nil
		},
	}

	m := newManager(client)
	defer m.Close()

	require.Eventually(t, func() bool {
		state := m.GetState()
		return state.BackendState == "Unreachable"
	}, 2*time.Second, 10*time.Millisecond)

	require.Eventually(t, func() bool {
		return len(watchCalled) >= 2
	}, 3*time.Second, 50*time.Millisecond)
}

func TestManager_Subscribe(t *testing.T) {
	client := &mockClient{
		watchFn: func(ctx context.Context, mask ipn.NotifyWatchOpt) (ipnBusWatcher, error) {
			<-ctx.Done()
			return nil, ctx.Err()
		},
		statusFn: func(ctx context.Context) (*ipnstate.Status, error) {
			return runningStatus(), nil
		},
	}

	m := newManager(client)
	defer m.Close()

	ch := m.Subscribe("test-1")
	assert.NotNil(t, ch)

	ch2 := m.Subscribe("test-2")
	assert.NotNil(t, ch2)

	m.Unsubscribe("test-1")
	m.Unsubscribe("test-2")
}

func TestManager_Close(t *testing.T) {
	client := &mockClient{
		watchFn: func(ctx context.Context, mask ipn.NotifyWatchOpt) (ipnBusWatcher, error) {
			<-ctx.Done()
			return nil, ctx.Err()
		},
		statusFn: func(ctx context.Context) (*ipnstate.Status, error) {
			return runningStatus(), nil
		},
	}

	m := newManager(client)

	ch := m.Subscribe("test")
	assert.NotNil(t, ch)

	assert.NotPanics(t, func() {
		m.Close()
	})
}

func TestManager_RefreshState(t *testing.T) {
	client := &mockClient{
		watchFn: func(ctx context.Context, mask ipn.NotifyWatchOpt) (ipnBusWatcher, error) {
			<-ctx.Done()
			return nil, ctx.Err()
		},
		statusFn: func(ctx context.Context) (*ipnstate.Status, error) {
			return runningStatus(), nil
		},
	}

	m := newManager(client)
	defer m.Close()

	m.RefreshState()

	state := m.GetState()
	assert.True(t, state.Connected)
	assert.Equal(t, "cachyos", state.Self.Hostname)
}
