package wlroutput

import (
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestStateChanged_BothNil(t *testing.T) {
	assert.True(t, stateChanged(nil, nil))
}

func TestStateChanged_OneNil(t *testing.T) {
	s := &State{Serial: 1}
	assert.True(t, stateChanged(s, nil))
	assert.True(t, stateChanged(nil, s))
}

func TestStateChanged_SerialDiffers(t *testing.T) {
	a := &State{Serial: 1, Outputs: []Output{}}
	b := &State{Serial: 2, Outputs: []Output{}}
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_OutputCountDiffers(t *testing.T) {
	a := &State{Serial: 1, Outputs: []Output{{Name: "eDP-1"}}}
	b := &State{Serial: 1, Outputs: []Output{}}
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_OutputNameDiffers(t *testing.T) {
	a := &State{Serial: 1, Outputs: []Output{{Name: "eDP-1", Enabled: true}}}
	b := &State{Serial: 1, Outputs: []Output{{Name: "HDMI-A-1", Enabled: true}}}
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_OutputEnabledDiffers(t *testing.T) {
	a := &State{Serial: 1, Outputs: []Output{{Name: "eDP-1", Enabled: true}}}
	b := &State{Serial: 1, Outputs: []Output{{Name: "eDP-1", Enabled: false}}}
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_OutputPositionDiffers(t *testing.T) {
	a := &State{Serial: 1, Outputs: []Output{{Name: "eDP-1", X: 0, Y: 0}}}
	b := &State{Serial: 1, Outputs: []Output{{Name: "eDP-1", X: 1920, Y: 0}}}
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_OutputTransformDiffers(t *testing.T) {
	a := &State{Serial: 1, Outputs: []Output{{Name: "eDP-1", Transform: 0}}}
	b := &State{Serial: 1, Outputs: []Output{{Name: "eDP-1", Transform: 1}}}
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_OutputScaleDiffers(t *testing.T) {
	a := &State{Serial: 1, Outputs: []Output{{Name: "eDP-1", Scale: 1.0}}}
	b := &State{Serial: 1, Outputs: []Output{{Name: "eDP-1", Scale: 2.0}}}
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_OutputAdaptiveSyncDiffers(t *testing.T) {
	a := &State{Serial: 1, Outputs: []Output{{Name: "eDP-1", AdaptiveSync: 0}}}
	b := &State{Serial: 1, Outputs: []Output{{Name: "eDP-1", AdaptiveSync: 1}}}
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_CurrentModeNilVsNonNil(t *testing.T) {
	a := &State{Serial: 1, Outputs: []Output{{Name: "eDP-1", CurrentMode: nil}}}
	b := &State{Serial: 1, Outputs: []Output{{Name: "eDP-1", CurrentMode: &OutputMode{Width: 1920}}}}
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_CurrentModeDiffers(t *testing.T) {
	a := &State{Serial: 1, Outputs: []Output{{
		Name:        "eDP-1",
		CurrentMode: &OutputMode{Width: 1920, Height: 1080, Refresh: 60000},
	}}}
	b := &State{Serial: 1, Outputs: []Output{{
		Name:        "eDP-1",
		CurrentMode: &OutputMode{Width: 2560, Height: 1440, Refresh: 60000},
	}}}
	assert.True(t, stateChanged(a, b))

	b.Outputs[0].CurrentMode.Width = 1920
	b.Outputs[0].CurrentMode.Height = 1080
	b.Outputs[0].CurrentMode.Refresh = 144000
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_ModesLengthDiffers(t *testing.T) {
	a := &State{Serial: 1, Outputs: []Output{{Name: "eDP-1", Modes: []OutputMode{{Width: 1920}}}}}
	b := &State{Serial: 1, Outputs: []Output{{Name: "eDP-1", Modes: []OutputMode{{Width: 1920}, {Width: 1280}}}}}
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_Equal(t *testing.T) {
	mode := OutputMode{Width: 1920, Height: 1080, Refresh: 60000, Preferred: true}
	a := &State{
		Serial: 5,
		Outputs: []Output{{
			Name:           "eDP-1",
			Description:    "Built-in display",
			Make:           "BOE",
			Model:          "0x0ABC",
			SerialNumber:   "12345",
			PhysicalWidth:  309,
			PhysicalHeight: 174,
			Enabled:        true,
			X:              0,
			Y:              0,
			Transform:      0,
			Scale:          1.0,
			CurrentMode:    &mode,
			Modes:          []OutputMode{mode},
			AdaptiveSync:   0,
		}},
	}
	b := &State{
		Serial: 5,
		Outputs: []Output{{
			Name:           "eDP-1",
			Description:    "Built-in display",
			Make:           "BOE",
			Model:          "0x0ABC",
			SerialNumber:   "12345",
			PhysicalWidth:  309,
			PhysicalHeight: 174,
			Enabled:        true,
			X:              0,
			Y:              0,
			Transform:      0,
			Scale:          1.0,
			CurrentMode:    &mode,
			Modes:          []OutputMode{mode},
			AdaptiveSync:   0,
		}},
	}
	assert.False(t, stateChanged(a, b))
}

func TestManager_ConcurrentGetState(t *testing.T) {
	m := &Manager{
		state: &State{
			Serial:  1,
			Outputs: []Output{{Name: "eDP-1", Enabled: true}},
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
				_ = s.Serial
				_ = s.Outputs
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
					Serial:  uint32(j),
					Outputs: []Output{{Name: "eDP-1", Scale: float64(j % 3)}},
				}
				m.stateMutex.Unlock()
			}
		}(i)
	}

	wg.Wait()
}

func TestManager_ConcurrentSubscriberAccess(t *testing.T) {
	m := &Manager{
		stopChan: make(chan struct{}),
		dirty:    make(chan struct{}, 1),
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

func TestManager_SyncmapHeadsConcurrentAccess(t *testing.T) {
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
				state := &headState{
					id:      key,
					name:    "test-head",
					enabled: j%2 == 0,
					scale:   float64(j % 3),
					modeIDs: []uint32{uint32(j)},
				}
				m.heads.Store(key, state)

				if loaded, ok := m.heads.Load(key); ok {
					assert.Equal(t, key, loaded.id)
				}

				m.heads.Range(func(k uint32, v *headState) bool {
					_ = v.name
					_ = v.enabled
					return true
				})
			}

			m.heads.Delete(key)
		}(i)
	}

	wg.Wait()
}

func TestManager_SyncmapModesConcurrentAccess(t *testing.T) {
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
				state := &modeState{
					id:        key,
					width:     int32(1920 + j),
					height:    int32(1080 + j),
					refresh:   60000,
					preferred: j == 0,
				}
				m.modes.Store(key, state)

				if loaded, ok := m.modes.Load(key); ok {
					assert.Equal(t, key, loaded.id)
				}

				m.modes.Range(func(k uint32, v *modeState) bool {
					_ = v.width
					_ = v.height
					return true
				})
			}

			m.modes.Delete(key)
		}(i)
	}

	wg.Wait()
}

func TestManager_NotifySubscribersNonBlocking(t *testing.T) {
	m := &Manager{
		dirty: make(chan struct{}, 1),
	}

	for i := 0; i < 10; i++ {
		m.notifySubscribers()
	}

	assert.Len(t, m.dirty, 1)
}

func TestManager_PostQueueFull(t *testing.T) {
	m := &Manager{
		cmdq:     make(chan cmd, 2),
		stopChan: make(chan struct{}),
	}

	m.post(func() {})
	m.post(func() {})
	m.post(func() {})
	m.post(func() {})

	assert.Len(t, m.cmdq, 2)
}

func TestManager_GetStateNilState(t *testing.T) {
	m := &Manager{}

	s := m.GetState()
	assert.NotNil(t, s.Outputs)
	assert.Equal(t, uint32(0), s.Serial)
}

func TestManager_FatalErrorChannel(t *testing.T) {
	m := &Manager{
		fatalError: make(chan error, 1),
	}

	ch := m.FatalError()
	assert.NotNil(t, ch)

	m.fatalError <- assert.AnError
	err := <-ch
	assert.Error(t, err)
}

func TestOutputMode_Fields(t *testing.T) {
	mode := OutputMode{
		Width:     1920,
		Height:    1080,
		Refresh:   60000,
		Preferred: true,
		ID:        42,
	}

	assert.Equal(t, int32(1920), mode.Width)
	assert.Equal(t, int32(1080), mode.Height)
	assert.Equal(t, int32(60000), mode.Refresh)
	assert.True(t, mode.Preferred)
	assert.Equal(t, uint32(42), mode.ID)
}

func TestOutput_Fields(t *testing.T) {
	out := Output{
		Name:           "eDP-1",
		Description:    "Built-in display",
		Make:           "BOE",
		Model:          "0x0ABC",
		SerialNumber:   "12345",
		PhysicalWidth:  309,
		PhysicalHeight: 174,
		Enabled:        true,
		X:              0,
		Y:              0,
		Transform:      0,
		Scale:          1.5,
		AdaptiveSync:   1,
		ID:             1,
	}

	assert.Equal(t, "eDP-1", out.Name)
	assert.Equal(t, "Built-in display", out.Description)
	assert.True(t, out.Enabled)
	assert.Equal(t, float64(1.5), out.Scale)
	assert.Equal(t, uint32(1), out.AdaptiveSync)
}

func TestHeadState_ModeIDsSlice(t *testing.T) {
	head := &headState{
		id:      1,
		modeIDs: make([]uint32, 0),
	}

	head.modeIDs = append(head.modeIDs, 1, 2, 3)
	assert.Len(t, head.modeIDs, 3)
	assert.Equal(t, uint32(1), head.modeIDs[0])
}

func TestStateChanged_BothCurrentModeNil(t *testing.T) {
	a := &State{Serial: 1, Outputs: []Output{{Name: "eDP-1", CurrentMode: nil}}}
	b := &State{Serial: 1, Outputs: []Output{{Name: "eDP-1", CurrentMode: nil}}}
	assert.False(t, stateChanged(a, b))
}

func TestStateChanged_IndexOutOfBounds(t *testing.T) {
	a := &State{Serial: 1, Outputs: []Output{{Name: "eDP-1"}}}
	b := &State{Serial: 1, Outputs: []Output{{Name: "eDP-1"}, {Name: "HDMI-A-1"}}}
	assert.True(t, stateChanged(a, b))
}
