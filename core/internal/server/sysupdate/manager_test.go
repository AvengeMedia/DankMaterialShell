package sysupdate

import (
	"context"
	"slices"
	"strings"
	"testing"
)

type customUpgradeTestBackend struct {
	pacmanBackend
	checks int
}

func (b *customUpgradeTestBackend) CheckUpdates(context.Context) ([]Package, error) {
	b.checks++
	return nil, nil
}

func TestCustomUpgradeFailure(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("PATH", dir)
	writeUpdateExecutable(t, dir, "fake-terminal", `while [ "$#" -gt 0 ] && [ "$1" != sh ]; do shift; done
[ "$#" -gt 0 ] || exit 99
shift
exec /bin/sh "$@"`)

	backend := &customUpgradeTestBackend{}
	m := &Manager{
		selection:   Selection{System: backend},
		notifyDirty: make(chan struct{}, 1),
		stopChan:    make(chan struct{}),
	}
	m.runCustomUpgrade(t.Context(), UpgradeOptions{
		Terminal:      "fake-terminal",
		CustomCommand: "false",
	})

	state := m.GetState()
	if state.Phase != PhaseError {
		t.Errorf("phase = %s, want %s", state.Phase, PhaseError)
	}
	if state.Error == nil || state.Error.Code != ErrCodeBackendFailed || !strings.Contains(state.Error.Message, "exit status 1") {
		t.Errorf("error = %#v, want backend-failed with exit status 1", state.Error)
	}
	if slices.Contains(state.RecentLog, "Upgrade complete.") {
		t.Error("failed custom upgrade logged success")
	}
	if backend.checks != 0 {
		t.Errorf("failed custom upgrade refreshed %d times", backend.checks)
	}
}
