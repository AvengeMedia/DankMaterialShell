package cups

import (
	"errors"
	"fmt"
	"sync"
	"testing"

	mocks_cups "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/cups"
	"github.com/AvengeMedia/DankMaterialShell/core/pkg/ipp"
	"github.com/stretchr/testify/assert"
)

func TestNewManager(t *testing.T) {
	m := &Manager{
		state: &CUPSState{
			Printers: make(map[string]*Printer),
		},
		client:   nil,
		stopChan: make(chan struct{}),
		dirty:    make(chan struct{}, 1),
	}

	assert.NotNil(t, m)
	assert.NotNil(t, m.state)
}

func TestManager_GetState(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)

	m := &Manager{
		state: &CUPSState{
			Printers: map[string]*Printer{
				"test-printer": {
					Name:  "test-printer",
					State: "idle",
				},
			},
		},
		client:   mockClient,
		stopChan: make(chan struct{}),
		dirty:    make(chan struct{}, 1),
	}

	state := m.GetState()
	assert.Equal(t, 1, len(state.Printers))
	assert.Equal(t, "test-printer", state.Printers["test-printer"].Name)
}

func TestManager_Subscribe(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)

	m := &Manager{
		state: &CUPSState{
			Printers: make(map[string]*Printer),
		},
		client:   mockClient,
		stopChan: make(chan struct{}),
		dirty:    make(chan struct{}, 1),
	}

	ch := m.Subscribe("test-client")
	assert.NotNil(t, ch)

	count := 0
	m.subscribers.Range(func(key string, ch chan CUPSState) bool {
		count++
		return true
	})
	assert.Equal(t, 1, count)

	m.Unsubscribe("test-client")
	count = 0
	m.subscribers.Range(func(key string, ch chan CUPSState) bool {
		count++
		return true
	})
	assert.Equal(t, 0, count)
}

// mirrors the real managers: eventChan guarded by mu, conn/running deliberately
// unsynchronized so overlapping Start/Stop trips the race detector
type stubSubscription struct {
	mu      sync.Mutex
	events  chan SubscriptionEvent
	conn    *int
	running bool
}

func (s *stubSubscription) Start() error {
	if s.running {
		return errors.New("already running")
	}
	s.running = true

	s.mu.Lock()
	s.events = make(chan SubscriptionEvent)
	s.mu.Unlock()

	v := 0
	s.conn = &v
	*s.conn++

	return nil
}

func (s *stubSubscription) Stop() {
	if !s.running {
		return
	}
	s.running = false
	s.conn = nil

	s.mu.Lock()
	close(s.events)
	s.mu.Unlock()
}

func (s *stubSubscription) Events() <-chan SubscriptionEvent {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.events
}

func TestManager_SubscribeUnsubscribeRace(t *testing.T) {
	m := NewTestManager(mocks_cups.NewMockCUPSClientInterface(t), nil)
	m.subscription = &stubSubscription{}

	var wg sync.WaitGroup
	for i := range 8 {
		wg.Go(func() {
			id := fmt.Sprintf("client-%d", i)
			for range 50 {
				m.Subscribe(id)
				m.Unsubscribe(id)
			}
		})
	}
	wg.Wait()
}

func TestManager_Close(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)

	m := &Manager{
		state: &CUPSState{
			Printers: make(map[string]*Printer),
		},
		client:   mockClient,
		stopChan: make(chan struct{}),
		dirty:    make(chan struct{}, 1),
	}

	m.eventWG.Go(func() {
		<-m.stopChan
	})

	m.notifierWg.Go(func() {
		<-m.stopChan
	})

	m.Close()
	count := 0
	m.subscribers.Range(func(key string, ch chan CUPSState) bool {
		count++
		return true
	})
	assert.Equal(t, 0, count)
}

func TestStateChanged(t *testing.T) {
	tests := []struct {
		name     string
		oldState *CUPSState
		newState *CUPSState
		want     bool
	}{
		{
			name: "no change",
			oldState: &CUPSState{
				Printers: map[string]*Printer{
					"p1": {Name: "p1", State: "idle"},
				},
			},
			newState: &CUPSState{
				Printers: map[string]*Printer{
					"p1": {Name: "p1", State: "idle"},
				},
			},
			want: false,
		},
		{
			name: "state changed",
			oldState: &CUPSState{
				Printers: map[string]*Printer{
					"p1": {Name: "p1", State: "idle"},
				},
			},
			newState: &CUPSState{
				Printers: map[string]*Printer{
					"p1": {Name: "p1", State: "processing"},
				},
			},
			want: true,
		},
		{
			name: "printer added",
			oldState: &CUPSState{
				Printers: map[string]*Printer{},
			},
			newState: &CUPSState{
				Printers: map[string]*Printer{
					"p1": {Name: "p1", State: "idle"},
				},
			},
			want: true,
		},
		{
			name: "printer removed",
			oldState: &CUPSState{
				Printers: map[string]*Printer{
					"p1": {Name: "p1", State: "idle"},
				},
			},
			newState: &CUPSState{
				Printers: map[string]*Printer{},
			},
			want: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := stateChanged(tt.oldState, tt.newState)
			assert.Equal(t, tt.want, got)
		})
	}
}

func TestParsePrinterState(t *testing.T) {
	tests := []struct {
		name  string
		attrs ipp.Attributes
		want  string
	}{
		{
			name: "idle",
			attrs: ipp.Attributes{
				ipp.AttributePrinterState: []ipp.Attribute{{Value: 3}},
			},
			want: "idle",
		},
		{
			name: "processing",
			attrs: ipp.Attributes{
				ipp.AttributePrinterState: []ipp.Attribute{{Value: 4}},
			},
			want: "processing",
		},
		{
			name: "stopped",
			attrs: ipp.Attributes{
				ipp.AttributePrinterState: []ipp.Attribute{{Value: 5}},
			},
			want: "stopped",
		},
		{
			name:  "unknown",
			attrs: ipp.Attributes{},
			want:  "unknown",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := parsePrinterState(tt.attrs)
			assert.Equal(t, tt.want, got)
		})
	}
}

func TestParseJobState(t *testing.T) {
	tests := []struct {
		name  string
		attrs ipp.Attributes
		want  string
	}{
		{
			name: "pending",
			attrs: ipp.Attributes{
				ipp.AttributeJobState: []ipp.Attribute{{Value: 3}},
			},
			want: "pending",
		},
		{
			name: "processing",
			attrs: ipp.Attributes{
				ipp.AttributeJobState: []ipp.Attribute{{Value: 5}},
			},
			want: "processing",
		},
		{
			name: "completed",
			attrs: ipp.Attributes{
				ipp.AttributeJobState: []ipp.Attribute{{Value: 9}},
			},
			want: "completed",
		},
		{
			name:  "unknown",
			attrs: ipp.Attributes{},
			want:  "unknown",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := parseJobState(tt.attrs)
			assert.Equal(t, tt.want, got)
		})
	}
}

func TestGetStringAttr(t *testing.T) {
	tests := []struct {
		name  string
		attrs ipp.Attributes
		key   string
		want  string
	}{
		{
			name: "string value",
			attrs: ipp.Attributes{
				"test-key": []ipp.Attribute{{Value: "test-value"}},
			},
			key:  "test-key",
			want: "test-value",
		},
		{
			name:  "missing key",
			attrs: ipp.Attributes{},
			key:   "missing",
			want:  "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := getStringAttr(tt.attrs, tt.key)
			assert.Equal(t, tt.want, got)
		})
	}
}

func TestGetIntAttr(t *testing.T) {
	tests := []struct {
		name  string
		attrs ipp.Attributes
		key   string
		want  int
	}{
		{
			name: "int value",
			attrs: ipp.Attributes{
				"test-key": []ipp.Attribute{{Value: 42}},
			},
			key:  "test-key",
			want: 42,
		},
		{
			name:  "missing key",
			attrs: ipp.Attributes{},
			key:   "missing",
			want:  0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := getIntAttr(tt.attrs, tt.key)
			assert.Equal(t, tt.want, got)
		})
	}
}

func TestGetBoolAttr(t *testing.T) {
	tests := []struct {
		name  string
		attrs ipp.Attributes
		key   string
		want  bool
	}{
		{
			name: "true value",
			attrs: ipp.Attributes{
				"test-key": []ipp.Attribute{{Value: true}},
			},
			key:  "test-key",
			want: true,
		},
		{
			name: "false value",
			attrs: ipp.Attributes{
				"test-key": []ipp.Attribute{{Value: false}},
			},
			key:  "test-key",
			want: false,
		},
		{
			name:  "missing key",
			attrs: ipp.Attributes{},
			key:   "missing",
			want:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := getBoolAttr(tt.attrs, tt.key)
			assert.Equal(t, tt.want, got)
		})
	}
}
