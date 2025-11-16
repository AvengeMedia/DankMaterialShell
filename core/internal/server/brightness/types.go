package brightness

import (
	"sync"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/pkg/syncmap"
)

type DeviceClass string

const (
	ClassBacklight DeviceClass = "backlight"
	ClassLED       DeviceClass = "leds"
	ClassDDC       DeviceClass = "ddc"
)

type Device struct {
	Class          DeviceClass `json:"class"`
	ID             string      `json:"id"`
	Name           string      `json:"name"`
	Current        int         `json:"current"`
	Max            int         `json:"max"`
	CurrentPercent int         `json:"currentPercent"`
	Backend        string      `json:"backend"`
}

type State struct {
	Devices []Device `json:"devices"`
}

type DeviceUpdate struct {
	Device Device `json:"device"`
}

type Request struct {
	ID     interface{}            `json:"id"`
	Method string                 `json:"method"`
	Params map[string]interface{} `json:"params"`
}

type Manager struct {
	logindBackend *LogindBackend
	sysfsBackend  *SysfsBackend
	ddcBackend    *DDCBackend

	logindReady bool
	sysfsReady  bool
	ddcReady    bool

	exponential bool

	stateMutex sync.RWMutex
	state      State

	subscribers       syncmap.Map[string, chan State]
	updateSubscribers syncmap.Map[string, chan DeviceUpdate]

	broadcastMutex   sync.Mutex
	broadcastTimer   *time.Timer
	broadcastPending bool
	pendingDeviceID  string

	stopChan chan struct{}
}

type SysfsBackend struct {
	basePath string
	classes  []string

	deviceCache syncmap.Map[string, *sysfsDevice]
}

type sysfsDevice struct {
	class         DeviceClass
	id            string
	name          string
	maxBrightness int
	minValue      int
}

type DDCBackend struct {
	devices syncmap.Map[string, *ddcDevice]

	scanMutex    sync.Mutex
	lastScan     time.Time
	scanInterval time.Duration

	debounceMutex   sync.Mutex
	debounceTimers  map[string]*time.Timer
	debouncePending map[string]ddcPendingSet
}

type ddcPendingSet struct {
	percent  int
	callback func()
}

type ddcDevice struct {
	bus            int
	addr           int
	id             string
	name           string
	max            int
	lastBrightness int
}

type ddcCapability struct {
	vcp     byte
	max     int
	current int
}

type SetBrightnessParams struct {
	Device      string  `json:"device"`
	Percent     int     `json:"percent"`
	Exponential bool    `json:"exponential,omitempty"`
	Exponent    float64 `json:"exponent,omitempty"`
}

func (m *Manager) Subscribe(id string) chan State {
	ch := make(chan State, 16)

	m.subscribers.Store(id, ch)

	return ch
}

func (m *Manager) Unsubscribe(id string) {

	if val, ok := m.subscribers.LoadAndDelete(id); ok {
		close(val)

	}

}

func (m *Manager) SubscribeUpdates(id string) chan DeviceUpdate {
	ch := make(chan DeviceUpdate, 16)
	m.updateSubscribers.Store(id, ch)
	return ch
}

func (m *Manager) UnsubscribeUpdates(id string) {
	if val, ok := m.updateSubscribers.LoadAndDelete(id); ok {
		close(val)
	}
}

func (m *Manager) NotifySubscribers() {
	m.stateMutex.RLock()
	state := m.state
	m.stateMutex.RUnlock()

	m.subscribers.Range(func(key string, ch chan State) bool {
		select {
		case ch <- state:
		default:
		}
		return true
	})
}

func (m *Manager) GetState() State {
	m.stateMutex.RLock()
	defer m.stateMutex.RUnlock()
	return m.state
}

func (m *Manager) Close() {
	close(m.stopChan)

	m.subscribers.Range(func(key string, ch chan State) bool {
		close(ch)
		m.subscribers.Delete(key)
		return true
	})
	m.updateSubscribers.Range(func(key string, ch chan DeviceUpdate) bool {
		close(ch)
		m.updateSubscribers.Delete(key)
		return true
	})

	if m.logindBackend != nil {
		m.logindBackend.Close()
	}

	if m.ddcBackend != nil {
		m.ddcBackend.Close()
	}
}
