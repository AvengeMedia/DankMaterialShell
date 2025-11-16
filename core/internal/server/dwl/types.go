package dwl

import (
	"sync"

	wlclient "github.com/AvengeMedia/DankMaterialShell/core/pkg/go-wayland/wayland/client"
	"github.com/AvengeMedia/DankMaterialShell/core/pkg/syncmap"
)

type TagState struct {
	Tag     uint32 `json:"tag"`
	State   uint32 `json:"state"`
	Clients uint32 `json:"clients"`
	Focused uint32 `json:"focused"`
}

type OutputState struct {
	Name         string     `json:"name"`
	Active       uint32     `json:"active"`
	Tags         []TagState `json:"tags"`
	Layout       uint32     `json:"layout"`
	LayoutSymbol string     `json:"layoutSymbol"`
	Title        string     `json:"title"`
	AppID        string     `json:"appId"`
}

type State struct {
	Outputs      map[string]*OutputState `json:"outputs"`
	TagCount     uint32                  `json:"tagCount"`
	Layouts      []string                `json:"layouts"`
	ActiveOutput string                  `json:"activeOutput"`
}

type cmd struct {
	fn func()
}

type Manager struct {
	display  *wlclient.Display
	ctx      *wlclient.Context
	registry *wlclient.Registry
	manager  interface{}

	outputs syncmap.Map[uint32, *outputState]

	tagCount uint32
	layouts  []string

	wlMutex        sync.Mutex
	cmdq           chan cmd
	outputSetupReq chan uint32
	stopChan       chan struct{}
	wg             sync.WaitGroup

	subscribers  syncmap.Map[string, chan State]
	dirty        chan struct{}
	notifierWg   sync.WaitGroup
	lastNotified *State

	stateMutex sync.RWMutex
	state      *State
}

type outputState struct {
	id           uint32
	registryName uint32
	output       *wlclient.Output
	ipcOutput    interface{}
	name         string
	active       uint32
	tags         []TagState
	layout       uint32
	layoutSymbol string
	title        string
	appID        string
}

func (m *Manager) GetState() State {
	m.stateMutex.RLock()
	defer m.stateMutex.RUnlock()
	if m.state == nil {
		return State{
			Outputs:  make(map[string]*OutputState),
			Layouts:  []string{},
			TagCount: 0,
		}
	}
	stateCopy := *m.state
	return stateCopy
}

func (m *Manager) Subscribe(id string) chan State {
	ch := make(chan State, 64)

	m.subscribers.Store(id, ch)

	return ch
}

func (m *Manager) Unsubscribe(id string) {
	if val, ok := m.subscribers.LoadAndDelete(id); ok {
		close(val)
	}
}

func (m *Manager) notifySubscribers() {
	select {
	case m.dirty <- struct{}{}:
	default:
	}
}

func stateChanged(old, new *State) bool {
	if old == nil || new == nil {
		return true
	}
	if old.TagCount != new.TagCount {
		return true
	}
	if len(old.Layouts) != len(new.Layouts) {
		return true
	}
	if old.ActiveOutput != new.ActiveOutput {
		return true
	}
	if len(old.Outputs) != len(new.Outputs) {
		return true
	}

	for name, newOut := range new.Outputs {
		oldOut, exists := old.Outputs[name]
		if !exists {
			return true
		}
		if oldOut.Active != newOut.Active {
			return true
		}
		if oldOut.Layout != newOut.Layout {
			return true
		}
		if oldOut.LayoutSymbol != newOut.LayoutSymbol {
			return true
		}
		if oldOut.Title != newOut.Title {
			return true
		}
		if oldOut.AppID != newOut.AppID {
			return true
		}
		if len(oldOut.Tags) != len(newOut.Tags) {
			return true
		}
		for i, newTag := range newOut.Tags {
			if i >= len(oldOut.Tags) {
				return true
			}
			oldTag := oldOut.Tags[i]
			if oldTag.Tag != newTag.Tag || oldTag.State != newTag.State ||
				oldTag.Clients != newTag.Clients || oldTag.Focused != newTag.Focused {
				return true
			}
		}
	}

	return false
}
