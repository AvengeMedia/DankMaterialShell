package dwl

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
	s := &State{TagCount: 9}
	assert.True(t, stateChanged(s, nil))
	assert.True(t, stateChanged(nil, s))
}

func TestStateChanged_TagCountDiffers(t *testing.T) {
	a := &State{TagCount: 9, Outputs: make(map[string]*OutputState), Layouts: []string{}}
	b := &State{TagCount: 10, Outputs: make(map[string]*OutputState), Layouts: []string{}}
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_LayoutLengthDiffers(t *testing.T) {
	a := &State{TagCount: 9, Layouts: []string{"tile"}, Outputs: make(map[string]*OutputState)}
	b := &State{TagCount: 9, Layouts: []string{"tile", "monocle"}, Outputs: make(map[string]*OutputState)}
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_ActiveOutputDiffers(t *testing.T) {
	a := &State{TagCount: 9, ActiveOutput: "eDP-1", Outputs: make(map[string]*OutputState), Layouts: []string{}}
	b := &State{TagCount: 9, ActiveOutput: "HDMI-A-1", Outputs: make(map[string]*OutputState), Layouts: []string{}}
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_OutputCountDiffers(t *testing.T) {
	a := &State{
		TagCount: 9,
		Outputs:  map[string]*OutputState{"eDP-1": {}},
		Layouts:  []string{},
	}
	b := &State{
		TagCount: 9,
		Outputs:  map[string]*OutputState{},
		Layouts:  []string{},
	}
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_OutputFieldsDiffer(t *testing.T) {
	a := &State{
		TagCount: 9,
		Layouts:  []string{},
		Outputs: map[string]*OutputState{
			"eDP-1": {Active: 1, Layout: 0, Title: "Firefox"},
		},
	}
	b := &State{
		TagCount: 9,
		Layouts:  []string{},
		Outputs: map[string]*OutputState{
			"eDP-1": {Active: 0, Layout: 0, Title: "Firefox"},
		},
	}
	assert.True(t, stateChanged(a, b))

	b.Outputs["eDP-1"].Active = 1
	b.Outputs["eDP-1"].Layout = 1
	assert.True(t, stateChanged(a, b))

	b.Outputs["eDP-1"].Layout = 0
	b.Outputs["eDP-1"].Title = "Code"
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_TagsDiffer(t *testing.T) {
	a := &State{
		TagCount: 9,
		Layouts:  []string{},
		Outputs: map[string]*OutputState{
			"eDP-1": {Tags: []TagState{{Tag: 1, State: 1, Clients: 2, Focused: 1}}},
		},
	}
	b := &State{
		TagCount: 9,
		Layouts:  []string{},
		Outputs: map[string]*OutputState{
			"eDP-1": {Tags: []TagState{{Tag: 1, State: 2, Clients: 2, Focused: 1}}},
		},
	}
	assert.True(t, stateChanged(a, b))

	b.Outputs["eDP-1"].Tags[0].State = 1
	b.Outputs["eDP-1"].Tags[0].Clients = 3
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_Equal(t *testing.T) {
	a := &State{
		TagCount:     9,
		ActiveOutput: "eDP-1",
		Layouts:      []string{"tile", "monocle"},
		Outputs: map[string]*OutputState{
			"eDP-1": {
				Name:         "eDP-1",
				Active:       1,
				Layout:       0,
				LayoutSymbol: "[]=",
				Title:        "Firefox",
				AppID:        "firefox",
				KbLayout:     "us",
				Keymode:      "",
				Tags:         []TagState{{Tag: 1, State: 1, Clients: 2, Focused: 1}},
			},
		},
	}
	b := &State{
		TagCount:     9,
		ActiveOutput: "eDP-1",
		Layouts:      []string{"tile", "monocle"},
		Outputs: map[string]*OutputState{
			"eDP-1": {
				Name:         "eDP-1",
				Active:       1,
				Layout:       0,
				LayoutSymbol: "[]=",
				Title:        "Firefox",
				AppID:        "firefox",
				KbLayout:     "us",
				Keymode:      "",
				Tags:         []TagState{{Tag: 1, State: 1, Clients: 2, Focused: 1}},
			},
		},
	}
	assert.False(t, stateChanged(a, b))
}

func TestManager_ConcurrentGetState(t *testing.T) {
	m := &Manager{
		state: &State{
			TagCount: 9,
			Layouts:  []string{"tile"},
			Outputs:  map[string]*OutputState{"eDP-1": {Name: "eDP-1"}},
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
				_ = s.TagCount
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
					TagCount: uint32(j % 10),
					Layouts:  []string{"tile", "monocle"},
					Outputs:  map[string]*OutputState{"eDP-1": {Active: uint32(j % 2)}},
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
					id:     key,
					name:   "test-output",
					active: uint32(j % 2),
					tags:   []TagState{{Tag: uint32(j), State: 1}},
				}
				m.outputs.Store(key, state)

				if loaded, ok := m.outputs.Load(key); ok {
					assert.Equal(t, key, loaded.id)
				}

				m.outputs.Range(func(k uint32, v *outputState) bool {
					_ = v.name
					_ = v.active
					return true
				})
			}

			m.outputs.Delete(key)
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
	assert.NotNil(t, s.Layouts)
	assert.Equal(t, uint32(0), s.TagCount)
}

func TestTagState_Fields(t *testing.T) {
	tag := TagState{
		Tag:     1,
		State:   2,
		Clients: 3,
		Focused: 1,
	}

	assert.Equal(t, uint32(1), tag.Tag)
	assert.Equal(t, uint32(2), tag.State)
	assert.Equal(t, uint32(3), tag.Clients)
	assert.Equal(t, uint32(1), tag.Focused)
}

func TestOutputState_Fields(t *testing.T) {
	out := OutputState{
		Name:         "eDP-1",
		Active:       1,
		Tags:         []TagState{{Tag: 1}},
		Layout:       0,
		LayoutSymbol: "[]=",
		Title:        "Firefox",
		AppID:        "firefox",
		KbLayout:     "us",
		Keymode:      "",
	}

	assert.Equal(t, "eDP-1", out.Name)
	assert.Equal(t, uint32(1), out.Active)
	assert.Len(t, out.Tags, 1)
	assert.Equal(t, "[]=", out.LayoutSymbol)
}

func TestStateChanged_NewOutputAppears(t *testing.T) {
	a := &State{
		TagCount: 9,
		Layouts:  []string{},
		Outputs: map[string]*OutputState{
			"eDP-1": {Name: "eDP-1"},
		},
	}
	b := &State{
		TagCount: 9,
		Layouts:  []string{},
		Outputs: map[string]*OutputState{
			"eDP-1":    {Name: "eDP-1"},
			"HDMI-A-1": {Name: "HDMI-A-1"},
		},
	}
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_TagsLengthDiffers(t *testing.T) {
	a := &State{
		TagCount: 9,
		Layouts:  []string{},
		Outputs: map[string]*OutputState{
			"eDP-1": {Tags: []TagState{{Tag: 1}}},
		},
	}
	b := &State{
		TagCount: 9,
		Layouts:  []string{},
		Outputs: map[string]*OutputState{
			"eDP-1": {Tags: []TagState{{Tag: 1}, {Tag: 2}}},
		},
	}
	assert.True(t, stateChanged(a, b))
}
