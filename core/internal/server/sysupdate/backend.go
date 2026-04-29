package sysupdate

import (
	"context"
	"os/exec"
	"sync"
)

type Backend interface {
	ID() string
	DisplayName() string
	Repo() RepoKind
	IsAvailable(ctx context.Context) bool
	NeedsAuth() bool
	RunsInTerminal() bool
	CheckUpdates(ctx context.Context) ([]Package, error)
	Upgrade(ctx context.Context, opts UpgradeOptions, onLine func(string)) error
}

type Selection struct {
	System  Backend
	Overlay []Backend
}

func (s Selection) All() []Backend {
	if s.System == nil {
		return s.Overlay
	}
	out := make([]Backend, 0, 1+len(s.Overlay))
	out = append(out, s.System)
	out = append(out, s.Overlay...)
	return out
}

func (s Selection) Info() []BackendInfo {
	all := s.All()
	out := make([]BackendInfo, 0, len(all))
	for _, b := range all {
		out = append(out, BackendInfo{
			ID:             b.ID(),
			DisplayName:    b.DisplayName(),
			Repo:           b.Repo(),
			NeedsAuth:      b.NeedsAuth(),
			RunsInTerminal: b.RunsInTerminal(),
		})
	}
	return out
}

var (
	registryMu       sync.RWMutex
	systemCandidates []func() Backend
	overlayCandidate []func() Backend
)

func RegisterSystemBackend(factory func() Backend) {
	registryMu.Lock()
	defer registryMu.Unlock()
	systemCandidates = append(systemCandidates, factory)
}

func RegisterOverlayBackend(factory func() Backend) {
	registryMu.Lock()
	defer registryMu.Unlock()
	overlayCandidate = append(overlayCandidate, factory)
}

func Select(ctx context.Context) Selection {
	registryMu.RLock()
	sys := append([]func() Backend(nil), systemCandidates...)
	ov := append([]func() Backend(nil), overlayCandidate...)
	registryMu.RUnlock()

	var sel Selection
	for _, factory := range sys {
		b := factory()
		if !b.IsAvailable(ctx) {
			continue
		}
		sel.System = b
		break
	}
	for _, factory := range ov {
		b := factory()
		if !b.IsAvailable(ctx) {
			continue
		}
		sel.Overlay = append(sel.Overlay, b)
	}
	return sel
}

func commandExists(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}
