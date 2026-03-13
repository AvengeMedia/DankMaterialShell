package wayland

import (
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"

	mocks_wlclient "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/wlclient"
)

func TestManager_ActorSerializesOutputStateAccess(t *testing.T) {
	m := &Manager{
		cmdq:     make(chan cmd, 8192),
		stopChan: make(chan struct{}),
	}

	m.wg.Add(1)
	go m.waylandActor()

	state := &outputState{
		id:           1,
		registryName: 100,
		rampSize:     256,
	}
	m.outputs.Store(state.id, state)

	var wg sync.WaitGroup
	const goroutines = 50
	const iterations = 100

	for i := 0; i < goroutines; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				m.post(func() {
					if out, ok := m.outputs.Load(state.id); ok {
						out.rampSize = uint32(j)
						out.failed = j%2 == 0
						out.retryCount = j
						out.lastFailTime = time.Now()
					}
				})
			}
		}(i)
	}

	wg.Wait()

	done := make(chan struct{})
	m.post(func() { close(done) })
	<-done

	close(m.stopChan)
	m.wg.Wait()
}

func TestManager_ConcurrentSubscriberAccess(t *testing.T) {
	m := &Manager{
		stopChan:      make(chan struct{}),
		dirty:         make(chan struct{}, 1),
		updateTrigger: make(chan struct{}, 1),
	}

	var wg sync.WaitGroup
	const goroutines = 20

	for i := 0; i < goroutines; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			subID := string(rune('a' + id))
			ch := m.Subscribe(subID)
			assert.NotNil(t, ch)
			time.Sleep(time.Millisecond)
			m.Unsubscribe(subID)
		}(i)
	}

	wg.Wait()
}

func TestManager_ConcurrentGetState(t *testing.T) {
	m := &Manager{
		state: &State{
			CurrentTemp: 5000,
			IsDay:       true,
		},
	}

	var wg sync.WaitGroup
	const goroutines = 50
	const iterations = 100

	for i := 0; i < goroutines/2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				s := m.GetState()
				assert.GreaterOrEqual(t, s.CurrentTemp, 0)
			}
		}()
	}

	for i := 0; i < goroutines/2; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				m.stateMutex.Lock()
				m.state = &State{
					CurrentTemp: 4000 + i*100,
					IsDay:       j%2 == 0,
				}
				m.stateMutex.Unlock()
			}
		}(i)
	}

	wg.Wait()
}

func TestManager_ConcurrentConfigAccess(t *testing.T) {
	m := &Manager{
		config: DefaultConfig(),
	}

	var wg sync.WaitGroup
	const goroutines = 30
	const iterations = 100

	for i := 0; i < goroutines/2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				m.configMutex.RLock()
				_ = m.config.LowTemp
				_ = m.config.HighTemp
				_ = m.config.Enabled
				m.configMutex.RUnlock()
			}
		}()
	}

	for i := 0; i < goroutines/2; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				m.configMutex.Lock()
				m.config.LowTemp = 3000 + j
				m.config.HighTemp = 7000 - j
				m.config.Enabled = j%2 == 0
				m.configMutex.Unlock()
			}
		}(i)
	}

	wg.Wait()
}

func TestManager_SyncmapOutputsConcurrentAccess(t *testing.T) {
	m := &Manager{}

	var wg sync.WaitGroup
	const goroutines = 30
	const iterations = 50

	for i := 0; i < goroutines; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			key := uint32(id)

			for j := 0; j < iterations; j++ {
				state := &outputState{
					id:       key,
					rampSize: uint32(j),
					failed:   j%2 == 0,
				}
				m.outputs.Store(key, state)

				if loaded, ok := m.outputs.Load(key); ok {
					assert.Equal(t, key, loaded.id)
				}

				m.outputs.Range(func(k uint32, v *outputState) bool {
					_ = v.rampSize
					_ = v.failed
					return true
				})
			}

			m.outputs.Delete(key)
		}(i)
	}

	wg.Wait()
}

func TestManager_LocationCacheConcurrentAccess(t *testing.T) {
	m := &Manager{}

	var wg sync.WaitGroup
	const goroutines = 20
	const iterations = 100

	for i := 0; i < goroutines/2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				m.locationMutex.RLock()
				_ = m.cachedIPLat
				_ = m.cachedIPLon
				m.locationMutex.RUnlock()
			}
		}()
	}

	for i := 0; i < goroutines/2; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				lat := float64(40 + i)
				lon := float64(-74 + j)
				m.locationMutex.Lock()
				m.cachedIPLat = &lat
				m.cachedIPLon = &lon
				m.locationMutex.Unlock()
			}
		}(i)
	}

	wg.Wait()
}

func TestManager_ScheduleConcurrentAccess(t *testing.T) {
	now := time.Now()
	m := &Manager{
		schedule: sunSchedule{
			times: SunTimes{
				Dawn:    now,
				Sunrise: now.Add(time.Hour),
				Sunset:  now.Add(12 * time.Hour),
				Night:   now.Add(13 * time.Hour),
			},
		},
	}

	var wg sync.WaitGroup
	const goroutines = 20
	const iterations = 100

	for i := 0; i < goroutines/2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				m.scheduleMutex.RLock()
				_ = m.schedule.times.Dawn
				_ = m.schedule.times.Sunrise
				_ = m.schedule.times.Sunset
				_ = m.schedule.condition
				m.scheduleMutex.RUnlock()
			}
		}()
	}

	for i := 0; i < goroutines/2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				m.scheduleMutex.Lock()
				m.schedule.times.Dawn = time.Now()
				m.schedule.times.Sunrise = time.Now().Add(time.Hour)
				m.schedule.condition = SunNormal
				m.scheduleMutex.Unlock()
			}
		}()
	}

	wg.Wait()
}

func TestInterpolate_EdgeCases(t *testing.T) {
	now := time.Now()

	tests := []struct {
		name     string
		now      time.Time
		start    time.Time
		stop     time.Time
		expected float64
	}{
		{
			name:     "same start and stop",
			now:      now,
			start:    now,
			stop:     now,
			expected: 1.0,
		},
		{
			name:     "now before start",
			now:      now,
			start:    now.Add(time.Hour),
			stop:     now.Add(2 * time.Hour),
			expected: 0.0,
		},
		{
			name:     "now after stop",
			now:      now.Add(3 * time.Hour),
			start:    now,
			stop:     now.Add(time.Hour),
			expected: 1.0,
		},
		{
			name:     "now at midpoint",
			now:      now.Add(30 * time.Minute),
			start:    now,
			stop:     now.Add(time.Hour),
			expected: 0.5,
		},
		{
			name:     "now equals start",
			now:      now,
			start:    now,
			stop:     now.Add(time.Hour),
			expected: 0.0,
		},
		{
			name:     "now equals stop",
			now:      now.Add(time.Hour),
			start:    now,
			stop:     now.Add(time.Hour),
			expected: 1.0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := interpolate(tt.now, tt.start, tt.stop)
			assert.InDelta(t, tt.expected, result, 0.01)
		})
	}
}

func TestGenerateGammaRamp_ZeroSize(t *testing.T) {
	ramp := GenerateGammaRamp(0, 5000, 1.0)
	assert.Empty(t, ramp.Red)
	assert.Empty(t, ramp.Green)
	assert.Empty(t, ramp.Blue)
}

func TestGenerateGammaRamp_ValidSizes(t *testing.T) {
	sizes := []uint32{1, 256, 1024}
	temps := []int{1000, 4000, 6500, 10000}
	gammas := []float64{0.5, 1.0, 2.0}

	for _, size := range sizes {
		for _, temp := range temps {
			for _, gamma := range gammas {
				ramp := GenerateGammaRamp(size, temp, gamma)
				assert.Len(t, ramp.Red, int(size))
				assert.Len(t, ramp.Green, int(size))
				assert.Len(t, ramp.Blue, int(size))
			}
		}
	}
}

func TestNotifySubscribers_NonBlocking(t *testing.T) {
	m := &Manager{
		dirty: make(chan struct{}, 1),
	}

	for i := 0; i < 10; i++ {
		m.notifySubscribers()
	}

	assert.Len(t, m.dirty, 1)
}

func TestNewManager_GetRegistryError(t *testing.T) {
	mockDisplay := mocks_wlclient.NewMockWaylandDisplay(t)

	mockDisplay.EXPECT().Context().Return(nil)
	mockDisplay.EXPECT().GetRegistry().Return(nil, errors.New("failed to get registry"))

	config := DefaultConfig()
	_, err := NewManager(mockDisplay, config)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "get registry")
}

func TestNewManager_InvalidConfig(t *testing.T) {
	mockDisplay := mocks_wlclient.NewMockWaylandDisplay(t)

	config := Config{
		LowTemp:  500,
		HighTemp: 6500,
		Gamma:    1.0,
	}

	_, err := NewManager(mockDisplay, config)
	assert.Error(t, err)
}
