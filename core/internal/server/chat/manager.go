package chat

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/chat"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/dankgo/syncmap"
)

const (
	// Deep enough to absorb a history-sync burst without stalling the bridge
	// reader, shallow enough that a wedged store surfaces as dropped events
	// rather than unbounded memory growth.
	ingestQueueDepth = 4096

	// UI updates are coalesced over this window. A five-thousand-message
	// backfill should cost a handful of redraws, not five thousand.
	coalesceWindow = 150 * time.Millisecond

	// How often the media cache is swept.
	gcInterval = 1 * time.Hour
)

// ingestEvent is one bridge frame queued for processing.
type ingestEvent struct {
	provider string
	frame    bridgeFrame
	// internal marks events the host synthesised rather than a bridge sending.
	internal bool
}

// State is the snapshot pushed to subscribers.
type State struct {
	Providers []ProviderStatus `json:"providers"`
	Chats     []chat.Chat      `json:"chats"`
	// Sync reports backfill progress per provider, present only while syncing.
	Sync map[string]SyncProgress `json:"sync,omitempty"`
}

// SyncProgress is a provider's backfill progress.
type SyncProgress struct {
	Done  int `json:"done"`
	Total int `json:"total"`
}

// Config is the user's chat preferences, pushed down from the shell.
type Config struct {
	NotificationsEnabled bool  `json:"notificationsEnabled"`
	NotificationPreview  bool  `json:"notificationPreview"`
	NotifyGroups         bool  `json:"notifyGroups"`
	NotifyArchived       bool  `json:"notifyArchived"`
	HistoryRetentionDays int   `json:"historyRetentionDays"`
	MediaCacheMaxBytes   int64 `json:"mediaCacheMaxBytes"`
}

// Manager owns the store, the media cache and every running bridge.
type Manager struct {
	store  *chat.HistoryStore
	media  *chat.Media
	notify *chat.NotifyPolicy

	userPluginDir string

	mu        sync.RWMutex
	providers map[string]Provider
	bridges   map[string]*bridge
	enabled   map[string]bool
	sync      map[string]SyncProgress
	config    Config
	// prefs holds per-provider notification overrides. Absent means "use the
	// global defaults in config".
	prefs map[string]chat.NotifyPrefs

	events      chan ingestEvent
	subscribers syncmap.Map[string, chan State]

	dirty     chan struct{}
	stopChan  chan struct{}
	stopOnce  sync.Once
	wg        sync.WaitGroup
	startedAt time.Time
}

// NewManager opens the store and discovers installed chat plugins. Bridges are
// not started until a provider is enabled.
func NewManager() (*Manager, error) {
	dbPath, err := HistoryPath()
	if err != nil {
		return nil, err
	}

	store, err := chat.OpenHistory(dbPath)
	if err != nil {
		return nil, err
	}

	mediaRoot, err := MediaRoot()
	if err != nil {
		store.Close()
		return nil, err
	}
	media := chat.NewMedia(mediaRoot, 0)

	m := &Manager{
		store:         store,
		media:         media,
		notify:        chat.NewNotifyPolicy(store, media),
		userPluginDir: userPluginDir(),
		providers:     map[string]Provider{},
		bridges:       map[string]*bridge{},
		enabled:       map[string]bool{},
		sync:          map[string]SyncProgress{},
		prefs:         map[string]chat.NotifyPrefs{},
		events:        make(chan ingestEvent, ingestQueueDepth),
		dirty:         make(chan struct{}, 1),
		stopChan:      make(chan struct{}),
		startedAt:     time.Now(),
		config: Config{
			NotificationsEnabled: true,
			NotificationPreview:  true,
			NotifyGroups:         true,
			NotifyArchived:       false,
		},
	}

	m.Rescan()

	m.wg.Add(3)
	go m.ingestLoop()
	go m.broadcastLoop()
	go m.gcLoop()

	return m, nil
}

// Rescan re-reads the plugin directories, picking up newly installed or
// removed chat plugins without a restart.
func (m *Manager) Rescan() {
	found := discoverProviders(m.userPluginDir)

	m.mu.Lock()
	defer m.mu.Unlock()

	seen := map[string]bool{}
	for _, p := range found {
		seen[p.ID] = true
		p.MediaDir = m.media.DirFor(p.ID)

		// Preserve settings already pushed down for a provider we knew about.
		if existing, ok := m.providers[p.ID]; ok {
			p.Settings = existing.Settings
		}
		m.providers[p.ID] = p
	}

	// A plugin that has been uninstalled should not keep a bridge running.
	for id := range m.providers {
		if seen[id] {
			continue
		}
		if b, ok := m.bridges[id]; ok {
			go b.Stop()
			delete(m.bridges, id)
		}
		delete(m.providers, id)
		delete(m.enabled, id)
	}

	log.Debugf("chat: discovered %d chat provider(s)", len(m.providers))
}

// SetConfig applies the user's chat preferences.
func (m *Manager) SetConfig(c Config) {
	m.mu.Lock()
	m.config = c
	m.mu.Unlock()

	if c.MediaCacheMaxBytes > 0 {
		root := m.media.Root()
		m.media = chat.NewMedia(root, c.MediaCacheMaxBytes)
	}
}

// SetProviderPrefs overrides the notification policy for one provider.
func (m *Manager) SetProviderPrefs(providerID string, prefs chat.NotifyPrefs) {
	m.mu.Lock()
	m.prefs[providerID] = prefs
	m.mu.Unlock()
}

// ProviderPrefs is the effective policy for a provider: its own overrides if
// the user has set any, otherwise the global defaults.
func (m *Manager) ProviderPrefs(providerID string) chat.NotifyPrefs {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if prefs, ok := m.prefs[providerID]; ok {
		return prefs
	}
	return chat.NotifyPrefs{
		Enabled:  m.config.NotificationsEnabled,
		Preview:  m.config.NotificationPreview,
		Groups:   m.config.NotifyGroups,
		Archived: m.config.NotifyArchived,
	}
}

// GetConfig returns the current preferences.
func (m *Manager) GetConfig() Config {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.config
}

// ---------------------------------------------------------------- lifecycle

// SetEnabled starts or stops a provider's bridge.
func (m *Manager) SetEnabled(ctx context.Context, providerID string, enabled bool, settings map[string]any) error {
	m.mu.Lock()
	p, ok := m.providers[providerID]
	if !ok {
		m.mu.Unlock()
		return fmt.Errorf("unknown chat provider %q", providerID)
	}
	if settings != nil {
		p.Settings = settings
		m.providers[providerID] = p
	}
	m.enabled[providerID] = enabled
	existing := m.bridges[providerID]
	m.mu.Unlock()

	if !enabled {
		if existing != nil {
			existing.Stop()
			m.mu.Lock()
			delete(m.bridges, providerID)
			m.mu.Unlock()
		}
		m.markDirty()
		return nil
	}

	if existing != nil {
		existing.Reconfigure(p.Settings)
		m.markDirty()
		return nil
	}

	if _, err := m.media.EnsureDirFor(providerID); err != nil {
		return err
	}

	b := newBridge(p, m.events)
	m.mu.Lock()
	m.bridges[providerID] = b
	m.mu.Unlock()

	if err := b.Start(context.Background()); err != nil {
		return err
	}

	m.markDirty()
	return nil
}

// SetProviderSettings pushes changed settings down to a running bridge.
func (m *Manager) SetProviderSettings(providerID string, settings map[string]any) error {
	m.mu.Lock()
	p, ok := m.providers[providerID]
	if !ok {
		m.mu.Unlock()
		return fmt.Errorf("unknown chat provider %q", providerID)
	}
	p.Settings = settings
	m.providers[providerID] = p
	b := m.bridges[providerID]
	m.mu.Unlock()

	if b != nil {
		b.Reconfigure(settings)
	}
	return nil
}

// Close stops every bridge and closes the store.
func (m *Manager) Close() error {
	m.stopOnce.Do(func() { close(m.stopChan) })

	m.mu.Lock()
	bridges := make([]*bridge, 0, len(m.bridges))
	for _, b := range m.bridges {
		bridges = append(bridges, b)
	}
	m.bridges = map[string]*bridge{}
	m.mu.Unlock()

	var wg sync.WaitGroup
	for _, b := range bridges {
		wg.Add(1)
		go func(b *bridge) {
			defer wg.Done()
			b.Stop()
		}(b)
	}
	wg.Wait()

	m.wg.Wait()
	return m.store.Close()
}

// ---------------------------------------------------------------- accessors

// Store exposes the message store to request handlers.
func (m *Manager) Store() *chat.HistoryStore { return m.store }

// Media exposes the attachment cache.
func (m *Manager) Media() *chat.Media { return m.media }

// Notify exposes the notification policy, so the shell can report focus.
func (m *Manager) Notify() *chat.NotifyPolicy { return m.notify }

// bridgeFor returns a running bridge, or an error naming why not.
func (m *Manager) bridgeFor(providerID string) (*bridge, error) {
	m.mu.RLock()
	b, ok := m.bridges[providerID]
	_, known := m.providers[providerID]
	m.mu.RUnlock()

	if !ok {
		if !known {
			return nil, fmt.Errorf("unknown chat provider %q", providerID)
		}
		return nil, fmt.Errorf("chat provider %q is not enabled", providerID)
	}
	return b, nil
}

// Providers returns the status of every discovered provider.
func (m *Manager) Providers(ctx context.Context) []ProviderStatus {
	m.mu.RLock()
	providers := make([]Provider, 0, len(m.providers))
	for _, p := range m.providers {
		providers = append(providers, p)
	}
	bridges := make(map[string]*bridge, len(m.bridges))
	for id, b := range m.bridges {
		bridges[id] = b
	}
	enabled := make(map[string]bool, len(m.enabled))
	for id, e := range m.enabled {
		enabled[id] = e
	}
	m.mu.RUnlock()

	unread := map[string]int{}
	if chats, err := m.store.Chats(ctx, 500); err == nil {
		for _, c := range chats {
			if !c.Archived {
				unread[c.Provider] += c.Unread
			}
		}
	}

	out := make([]ProviderStatus, 0, len(providers))
	for _, p := range providers {
		var status ProviderStatus
		if b, ok := bridges[p.ID]; ok {
			status = b.Status()
		} else {
			status = ProviderStatus{
				ID:    p.ID,
				Name:  p.Name,
				Icon:  p.Icon,
				State: chat.StateDisconnected,
			}
		}
		status.Enabled = enabled[p.ID]
		status.Description = p.Description
		status.SettingsQML = p.SettingsQML
		status.Warning = p.Warning
		status.Unread = unread[p.ID]
		status.Notifications = m.ProviderPrefs(p.ID)
		out = append(out, status)
	}
	return out
}

// GetState builds the snapshot handed to a new subscriber.
func (m *Manager) GetState() State {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	chats, err := m.store.Chats(ctx, 200)
	if err != nil {
		log.Warnf("chat: failed to read chats: %v", err)
	}

	m.mu.RLock()
	var progress map[string]SyncProgress
	if len(m.sync) > 0 {
		progress = make(map[string]SyncProgress, len(m.sync))
		for id, p := range m.sync {
			progress[id] = p
		}
	}
	m.mu.RUnlock()

	return State{
		Providers: m.Providers(ctx),
		Chats:     chats,
		Sync:      progress,
	}
}

// ---------------------------------------------------------------- subscribe

// Subscribe registers a state channel for a client.
func (m *Manager) Subscribe(id string) chan State {
	ch := make(chan State, 8)
	m.subscribers.Store(id, ch)
	return ch
}

// Unsubscribe removes a client's channel.
func (m *Manager) Unsubscribe(id string) {
	if ch, ok := m.subscribers.LoadAndDelete(id); ok {
		close(ch)
	}
}

// markDirty schedules a state broadcast. Coalescing happens in broadcastLoop.
func (m *Manager) markDirty() {
	select {
	case m.dirty <- struct{}{}:
	default:
	}
}

// broadcastLoop pushes state to subscribers, at most once per coalesce window.
func (m *Manager) broadcastLoop() {
	defer m.wg.Done()

	for {
		select {
		case <-m.stopChan:
			return
		case <-m.dirty:
		}

		// Absorb the rest of the burst before doing the work of building state.
		select {
		case <-time.After(coalesceWindow):
		case <-m.stopChan:
			return
		}
		// Drain anything that arrived during the window.
		select {
		case <-m.dirty:
		default:
		}

		state := m.GetState()
		m.subscribers.Range(func(_ string, ch chan State) bool {
			select {
			case ch <- state:
			default:
				// A subscriber that cannot keep up gets the next snapshot;
				// state is absolute, so a skipped one loses nothing.
			}
			return true
		})
	}
}

// gcLoop sweeps the media cache and applies history retention.
func (m *Manager) gcLoop() {
	defer m.wg.Done()

	ticker := time.NewTicker(gcInterval)
	defer ticker.Stop()

	for {
		select {
		case <-m.stopChan:
			return
		case <-ticker.C:
		}

		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)

		if freed, err := m.media.GC(ctx, m.store); err != nil {
			log.Warnf("chat: media gc failed: %v", err)
		} else if freed > 0 {
			log.Infof("chat: media cache evicted %d bytes", freed)
		}

		if days := m.GetConfig().HistoryRetentionDays; days > 0 {
			cutoff := time.Now().AddDate(0, 0, -days).UnixMilli()
			if n, err := m.store.TrimOlderThan(ctx, cutoff); err != nil {
				log.Warnf("chat: history trim failed: %v", err)
			} else if n > 0 {
				log.Infof("chat: trimmed %d message(s) past retention", n)
				m.markDirty()
			}
		}

		cancel()
	}
}

// ---------------------------------------------------------------- paths

// HistoryPath is where the shared message store lives.
//
// Data, not cache: message history is not regenerable, so it must survive a
// cache wipe.
func HistoryPath() (string, error) {
	dir, err := dataDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "chat", "history.db"), nil
}

// MediaRoot is where cached attachments live. Cache, not data: every file here
// can be fetched again from its provider.
func MediaRoot() (string, error) {
	dir, err := os.UserCacheDir()
	if err != nil {
		return "", fmt.Errorf("locate cache dir: %w", err)
	}
	return filepath.Join(dir, "DankMaterialShell", "chat", "media"), nil
}

func dataDir() (string, error) {
	if xdg := os.Getenv("XDG_DATA_HOME"); xdg != "" {
		return filepath.Join(xdg, "DankMaterialShell"), nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("locate home dir: %w", err)
	}
	return filepath.Join(home, ".local", "share", "DankMaterialShell"), nil
}

func userPluginDir() string {
	configDir, err := os.UserConfigDir()
	if err != nil {
		return ""
	}
	return filepath.Join(configDir, "DankMaterialShell", "plugins")
}

// settingsJSON renders a value for logging without leaking large payloads.
func settingsJSON(v any) string {
	b, err := json.Marshal(v)
	if err != nil {
		return "?"
	}
	if len(b) > 200 {
		return string(b[:200]) + "…"
	}
	return string(b)
}
