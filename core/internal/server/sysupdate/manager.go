package sysupdate

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"os"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/pkg/syncmap"
)

const (
	defaultIntervalSeconds = 30 * 60
	minIntervalSeconds     = 5 * 60
	checkTimeout           = 5 * time.Minute
	upgradeTimeout         = 30 * time.Minute
)

type Manager struct {
	mu          sync.RWMutex
	state       State
	subscribers syncmap.Map[string, chan State]

	selection Selection

	notifyDirty chan struct{}
	stopChan    chan struct{}
	notifierWG  sync.WaitGroup
	schedulerWG sync.WaitGroup

	acquireCount int32
	wakeSched    chan struct{}

	opMu     sync.Mutex
	opCtx    context.Context
	opCancel context.CancelFunc
}

func NewManager() (*Manager, error) {
	m := &Manager{
		notifyDirty: make(chan struct{}, 1),
		stopChan:    make(chan struct{}),
		wakeSched:   make(chan struct{}, 1),
	}
	m.state = State{
		Phase:           PhaseIdle,
		IntervalSeconds: defaultIntervalSeconds,
		Backends:        []BackendInfo{},
		Packages:        []Package{},
	}

	id, pretty := readOSRelease()
	m.state.Distro = id
	m.state.DistroPretty = pretty

	m.selection = Select(context.Background())
	m.state.Backends = m.selection.Info()
	if len(m.state.Backends) == 0 {
		m.state.Error = &ErrorInfo{
			Code:    ErrCodeNoBackend,
			Message: "no supported package manager found",
			Hint:    "install a supported package manager (pacman, dnf, apt, zypper) or flatpak",
		}
	}

	m.notifierWG.Add(1)
	go m.notifier()

	m.schedulerWG.Add(1)
	go m.scheduler()

	go m.runRefresh(context.Background())

	return m, nil
}

func (m *Manager) GetState() State {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return cloneState(m.state)
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

func (m *Manager) Close() {
	select {
	case <-m.stopChan:
		return
	default:
		close(m.stopChan)
	}
	m.opMu.Lock()
	if m.opCancel != nil {
		m.opCancel()
	}
	m.opMu.Unlock()
	select {
	case m.wakeSched <- struct{}{}:
	default:
	}
	m.schedulerWG.Wait()
	m.notifierWG.Wait()
	m.subscribers.Range(func(key string, ch chan State) bool {
		close(ch)
		m.subscribers.Delete(key)
		return true
	})
}

func (m *Manager) SetInterval(seconds int) {
	if seconds < minIntervalSeconds {
		seconds = minIntervalSeconds
	}
	m.mu.Lock()
	m.state.IntervalSeconds = seconds
	m.mu.Unlock()
	m.markDirty()
}

func (m *Manager) Refresh(opts RefreshOptions) {
	m.mu.RLock()
	phase := m.state.Phase
	m.mu.RUnlock()

	switch {
	case phase == PhaseUpgrading:
		return
	case phase == PhaseRefreshing && !opts.Force:
		return
	}
	go m.runRefresh(context.Background())
}

func (m *Manager) Upgrade(opts UpgradeOptions) error {
	if len(m.selection.All()) == 0 {
		return errors.New("no backend available")
	}

	m.opMu.Lock()
	if m.opCancel != nil {
		m.opMu.Unlock()
		return errors.New("operation already running")
	}
	ctx, cancel := context.WithTimeout(context.Background(), upgradeTimeout)
	m.opCtx = ctx
	m.opCancel = cancel
	m.opMu.Unlock()

	go m.runUpgrade(ctx, opts)
	return nil
}

func (m *Manager) Cancel() {
	m.opMu.Lock()
	cancel := m.opCancel
	m.opMu.Unlock()
	if cancel == nil {
		return
	}
	cancel()
}

func (m *Manager) Acquire() {
	first := atomic.AddInt32(&m.acquireCount, 1) == 1
	select {
	case m.wakeSched <- struct{}{}:
	default:
	}
	if first {
		go m.runRefresh(context.Background())
	}
}

func (m *Manager) Release() {
	if atomic.AddInt32(&m.acquireCount, -1) < 0 {
		atomic.StoreInt32(&m.acquireCount, 0)
	}
}

func (m *Manager) scheduler() {
	defer m.schedulerWG.Done()
	for {
		if atomic.LoadInt32(&m.acquireCount) == 0 {
			select {
			case <-m.stopChan:
				return
			case <-m.wakeSched:
			}
			continue
		}

		m.mu.RLock()
		interval := m.state.IntervalSeconds
		m.mu.RUnlock()
		if interval < minIntervalSeconds {
			interval = minIntervalSeconds
		}
		t := time.NewTimer(time.Duration(interval) * time.Second)
		select {
		case <-m.stopChan:
			t.Stop()
			return
		case <-m.wakeSched:
			t.Stop()
		case <-t.C:
			m.runRefresh(context.Background())
		}
	}
}

func (m *Manager) runRefresh(parent context.Context) {
	if len(m.selection.All()) == 0 {
		return
	}

	ctx, cancel := context.WithTimeout(parent, checkTimeout)
	defer cancel()

	m.mu.Lock()
	if m.state.Phase == PhaseUpgrading {
		m.mu.Unlock()
		return
	}
	m.state.Phase = PhaseRefreshing
	m.state.Error = nil
	m.mu.Unlock()
	m.markDirty()

	type backendResult struct {
		pkgs []Package
		err  error
	}
	backends := m.selection.All()
	results := make([]backendResult, len(backends))
	var wg sync.WaitGroup
	for i, b := range backends {
		wg.Add(1)
		go func(i int, b Backend) {
			defer wg.Done()
			pkgs, err := b.CheckUpdates(ctx)
			results[i] = backendResult{pkgs: pkgs, err: err}
		}(i, b)
	}
	wg.Wait()

	now := time.Now().Unix()
	m.mu.Lock()
	m.state.LastCheckUnix = now
	m.state.Packages = m.state.Packages[:0]
	var firstErr error
	for i, r := range results {
		if r.err != nil {
			if firstErr == nil {
				firstErr = fmt.Errorf("%s: %w", backends[i].ID(), r.err)
			}
			continue
		}
		m.state.Packages = append(m.state.Packages, r.pkgs...)
	}
	m.state.Count = len(m.state.Packages)
	if firstErr != nil {
		m.state.Phase = PhaseError
		m.state.Error = &ErrorInfo{Code: ErrCodeBackendFailed, Message: firstErr.Error()}
	} else {
		m.state.Phase = PhaseIdle
		m.state.LastSuccessUnix = now
		m.state.NextCheckUnix = now + int64(m.state.IntervalSeconds)
	}
	m.mu.Unlock()
	m.markDirty()
}

func (m *Manager) runUpgrade(ctx context.Context, opts UpgradeOptions) {
	defer func() {
		m.opMu.Lock()
		if m.opCancel != nil {
			m.opCancel = nil
			m.opCtx = nil
		}
		m.opMu.Unlock()
	}()

	combined, err := buildBundledCommand(m.selection, opts)
	if err != nil {
		m.setError(ErrCodeNoBackend, err.Error())
		return
	}

	term := findTerminal(opts.Terminal)
	if term == "" {
		m.setError(ErrCodeBackendFailed, "no terminal found (pick one in DMS settings, set $TERMINAL, or install kitty/ghostty/foot/alacritty)")
		return
	}

	opID := fmt.Sprintf("op-%d", time.Now().UnixNano())
	m.mu.Lock()
	m.state.Phase = PhaseUpgrading
	m.state.OperationID = opID
	m.state.OperationStarted = time.Now().Unix()
	m.state.Error = nil
	m.mu.Unlock()
	m.markDirty()

	argv := wrapInTerminal(term, "DMS — System Update", combined)
	if err := Run(ctx, argv); err != nil {
		code := ErrCodeBackendFailed
		switch {
		case errors.Is(ctx.Err(), context.DeadlineExceeded):
			code = ErrCodeTimeout
		case errors.Is(ctx.Err(), context.Canceled):
			code = ErrCodeCancelled
		}
		m.mu.Lock()
		m.state.Phase = PhaseError
		m.state.Error = &ErrorInfo{Code: code, Message: err.Error()}
		m.mu.Unlock()
		m.markDirty()
		return
	}

	m.mu.Lock()
	m.state.Phase = PhaseIdle
	m.state.OperationID = ""
	m.state.OperationStarted = 0
	m.mu.Unlock()
	m.markDirty()
	go m.runRefresh(context.Background())
}

func buildBundledCommand(sel Selection, opts UpgradeOptions) (string, error) {
	if opts.CustomCommand != "" {
		return opts.CustomCommand, nil
	}
	backends := upgradeBackends(sel, opts)
	if len(backends) == 0 {
		return "", errors.New("no backend selected for upgrade")
	}
	parts := make([]string, 0, len(backends))
	for _, b := range backends {
		cmd, err := b.UpgradeCommand(opts)
		if err != nil {
			return "", fmt.Errorf("%s: %w", b.ID(), err)
		}
		if cmd == "" {
			continue
		}
		parts = append(parts, cmd)
	}
	if len(parts) == 0 {
		return "", errors.New("no backend produced an upgrade command")
	}
	return strings.Join(parts, " && "), nil
}

func upgradeBackends(sel Selection, opts UpgradeOptions) []Backend {
	var out []Backend
	if sel.System != nil {
		out = append(out, sel.System)
	}
	for _, b := range sel.Overlay {
		switch {
		case b.Repo() == RepoFlatpak && !opts.IncludeFlatpak:
			continue
		}
		out = append(out, b)
	}
	return out
}

func (m *Manager) setError(code ErrorCode, msg string) {
	m.mu.Lock()
	m.state.Phase = PhaseError
	m.state.Error = &ErrorInfo{Code: code, Message: msg}
	m.mu.Unlock()
	m.markDirty()
}

func (m *Manager) markDirty() {
	select {
	case m.notifyDirty <- struct{}{}:
	default:
	}
}

func (m *Manager) notifier() {
	defer m.notifierWG.Done()
	for {
		select {
		case <-m.stopChan:
			return
		case <-m.notifyDirty:
			snap := m.GetState()
			m.subscribers.Range(func(key string, ch chan State) bool {
				select {
				case ch <- snap:
				default:
				}
				return true
			})
		}
	}
}

func cloneState(s State) State {
	out := s
	out.Backends = append([]BackendInfo(nil), s.Backends...)
	out.Packages = append([]Package(nil), s.Packages...)
	if s.Error != nil {
		errCopy := *s.Error
		out.Error = &errCopy
	}
	return out
}

func readOSRelease() (id, pretty string) {
	f, err := os.Open("/etc/os-release")
	if err != nil {
		return "", ""
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		k, v, ok := strings.Cut(scanner.Text(), "=")
		if !ok {
			continue
		}
		v = strings.Trim(v, "\"")
		switch k {
		case "ID":
			id = v
		case "PRETTY_NAME":
			pretty = v
		}
	}
	if err := scanner.Err(); err != nil {
		log.Debugf("[sysupdate] read os-release: %v", err)
	}
	return id, pretty
}
