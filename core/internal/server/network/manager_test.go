package network

import (
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestManager_GetState(t *testing.T) {
	state := &NetworkState{
		NetworkStatus: StatusWiFi,
		WiFiSSID:      "TestNetwork",
		WiFiConnected: true,
	}

	manager := &Manager{
		state:      state,
		stateMutex: sync.RWMutex{},
	}

	result := manager.GetState()
	assert.Equal(t, StatusWiFi, result.NetworkStatus)
	assert.Equal(t, "TestNetwork", result.WiFiSSID)
	assert.True(t, result.WiFiConnected)
}

func TestManager_NotifySubscribers(t *testing.T) {
	manager := &Manager{
		state: &NetworkState{
			NetworkStatus: StatusWiFi,
		},
		stateMutex: sync.RWMutex{},
		stopChan:   make(chan struct{}),
		dirty:      make(chan struct{}, 1),
	}
	manager.notifierWg.Add(1)
	go manager.notifier()

	ch := make(chan NetworkState, 10)
	manager.subscribers.Store("test-client", ch)

	manager.notifySubscribers()

	select {
	case state := <-ch:
		assert.Equal(t, StatusWiFi, state.NetworkStatus)
	case <-time.After(200 * time.Millisecond):
		t.Fatal("did not receive state update")
	}

	close(manager.stopChan)
	manager.notifierWg.Wait()
}

func TestManager_NotifySubscribers_Debounce(t *testing.T) {
	manager := &Manager{
		state: &NetworkState{
			NetworkStatus: StatusWiFi,
		},
		stateMutex: sync.RWMutex{},
		stopChan:   make(chan struct{}),
		dirty:      make(chan struct{}, 1),
	}
	manager.notifierWg.Add(1)
	go manager.notifier()

	ch := make(chan NetworkState, 10)
	manager.subscribers.Store("test-client", ch)

	manager.notifySubscribers()
	manager.notifySubscribers()
	manager.notifySubscribers()

	receivedCount := 0
	timeout := time.After(200 * time.Millisecond)
	for {
		select {
		case <-ch:
			receivedCount++
		case <-timeout:
			assert.Equal(t, 1, receivedCount, "should receive exactly one debounced update")
			close(manager.stopChan)
			manager.notifierWg.Wait()
			return
		}
	}
}

func TestManager_Close(t *testing.T) {
	manager := &Manager{
		state:      &NetworkState{},
		stateMutex: sync.RWMutex{},
		stopChan:   make(chan struct{}),
	}

	ch1 := make(chan NetworkState, 1)
	ch2 := make(chan NetworkState, 1)
	manager.subscribers.Store("client1", ch1)
	manager.subscribers.Store("client2", ch2)

	manager.Close()

	select {
	case <-manager.stopChan:
	case <-time.After(100 * time.Millisecond):
		t.Fatal("stopChan not closed")
	}

	_, ok1 := <-ch1
	_, ok2 := <-ch2
	assert.False(t, ok1, "ch1 should be closed")
	assert.False(t, ok2, "ch2 should be closed")

	count := 0
	manager.subscribers.Range(func(key string, ch chan NetworkState) bool { count++; return true })
	assert.Equal(t, 0, count)
}

func TestManager_Subscribe(t *testing.T) {
	manager := &Manager{
		state: &NetworkState{},
	}

	ch := manager.Subscribe("test-client")
	assert.NotNil(t, ch)
	assert.Equal(t, 64, cap(ch))

	_, exists := manager.subscribers.Load("test-client")
	assert.True(t, exists)
}

func TestManager_Unsubscribe(t *testing.T) {
	manager := &Manager{
		state: &NetworkState{},
	}

	ch := manager.Subscribe("test-client")

	manager.Unsubscribe("test-client")

	_, ok := <-ch
	assert.False(t, ok)

	_, exists := manager.subscribers.Load("test-client")
	assert.False(t, exists)
}

func TestNewManager(t *testing.T) {
	t.Run("attempts to create manager", func(t *testing.T) {
		manager, err := NewManager()
		if err != nil {
			assert.Nil(t, manager)
		} else {
			assert.NotNil(t, manager)
			assert.NotNil(t, manager.state)
			assert.NotNil(t, manager.subscribers)
			assert.NotNil(t, manager.stopChan)

			manager.Close()
		}
	})
}

func TestManager_GetState_ThreadSafe(t *testing.T) {
	manager := &Manager{
		state: &NetworkState{
			NetworkStatus: StatusWiFi,
			WiFiSSID:      "TestNetwork",
		},
		stateMutex: sync.RWMutex{},
	}

	done := make(chan bool)
	for i := 0; i < 10; i++ {
		go func() {
			state := manager.GetState()
			assert.Equal(t, StatusWiFi, state.NetworkStatus)
			done <- true
		}()
	}

	for i := 0; i < 10; i++ {
		select {
		case <-done:
		case <-time.After(1 * time.Second):
			t.Fatal("timeout waiting for goroutines")
		}
	}
}
