package clipboard

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sync"
	"time"

	bolt "go.etcd.io/bbolt"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/wlcontext"
	wlclient "github.com/AvengeMedia/DankMaterialShell/core/pkg/go-wayland/wayland/client"
)

type Config struct {
	MaxHistory     int   `json:"maxHistory"`
	MaxEntrySize   int64 `json:"maxEntrySize"`
	AutoClearDays  int   `json:"autoClearDays"`
	ClearAtStartup bool  `json:"clearAtStartup"`
	Disabled       bool  `json:"disabled"`
}

func DefaultConfig() Config {
	return Config{
		MaxHistory:     100,
		MaxEntrySize:   5 * 1024 * 1024,
		AutoClearDays:  0,
		ClearAtStartup: false,
	}
}

func getConfigPath() (string, error) {
	configDir, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(configDir, "DankMaterialShell", "clsettings.json"), nil
}

func LoadConfig() Config {
	cfg := DefaultConfig()

	path, err := getConfigPath()
	if err != nil {
		return cfg
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return cfg
	}

	if err := json.Unmarshal(data, &cfg); err != nil {
		return DefaultConfig()
	}
	return cfg
}

func SaveConfig(cfg Config) error {
	path, err := getConfigPath()
	if err != nil {
		return err
	}

	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return err
	}

	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(path, data, 0644)
}

type SearchParams struct {
	Query    string `json:"query"`
	MimeType string `json:"mimeType"`
	IsImage  *bool  `json:"isImage"`
	Limit    int    `json:"limit"`
	Offset   int    `json:"offset"`
	Before   *int64 `json:"before"`
	After    *int64 `json:"after"`
}

type SearchResult struct {
	Entries []Entry `json:"entries"`
	Total   int     `json:"total"`
	HasMore bool    `json:"hasMore"`
}

type Entry struct {
	ID        uint64    `json:"id"`
	Data      []byte    `json:"data,omitempty"`
	MimeType  string    `json:"mimeType"`
	Preview   string    `json:"preview"`
	Size      int       `json:"size"`
	Timestamp time.Time `json:"timestamp"`
	IsImage   bool      `json:"isImage"`
	Hash      uint64    `json:"hash,omitempty"`
}

type State struct {
	Enabled bool    `json:"enabled"`
	History []Entry `json:"history"`
	Current *Entry  `json:"current,omitempty"`
}

type Manager struct {
	config      Config
	configMutex sync.RWMutex
	configPath  string

	display wlclient.WaylandDisplay
	wlCtx   wlcontext.WaylandContext

	registry       *wlclient.Registry
	dataControlMgr any
	seat           *wlclient.Seat
	dataDevice     any
	currentOffer   any
	currentSource  any
	seatName       uint32
	mimeTypes      []string
	offerMimeTypes map[any][]string
	offerMutex     sync.RWMutex
	offerRegistry  map[uint32]any

	sourceMimeTypes []string
	sourceMutex     sync.RWMutex

	persistData      map[string][]byte
	persistMimeTypes []string
	persistMutex     sync.RWMutex

	isOwner   bool
	ownerLock sync.Mutex

	initialized bool

	alive    bool
	stopChan chan struct{}

	db     *bolt.DB
	dbPath string

	state      *State
	stateMutex sync.RWMutex

	subscribers map[string]chan State
	subMutex    sync.RWMutex
	dirty       chan struct{}
	notifierWg  sync.WaitGroup
	lastState   *State
}

func (m *Manager) GetState() State {
	m.stateMutex.RLock()
	defer m.stateMutex.RUnlock()
	if m.state == nil {
		return State{}
	}
	return *m.state
}

func (m *Manager) Subscribe(id string) chan State {
	ch := make(chan State, 64)
	m.subMutex.Lock()
	m.subscribers[id] = ch
	m.subMutex.Unlock()
	return ch
}

func (m *Manager) Unsubscribe(id string) {
	m.subMutex.Lock()
	if ch, ok := m.subscribers[id]; ok {
		close(ch)
		delete(m.subscribers, id)
	}
	m.subMutex.Unlock()
}

func (m *Manager) notifySubscribers() {
	select {
	case m.dirty <- struct{}{}:
	default:
	}
}
