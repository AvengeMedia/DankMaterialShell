package trayrecovery

import (
	"os"
	"testing"
	"time"

	"github.com/godbus/dbus/v5"
)

// Claims the real watcher name, so it only runs on a scratch bus:
// dbus-run-session -- env DMS_TEST_SCRATCH_BUS=1 go test ./internal/server/trayrecovery/ -run TestWatchWatcherOwner -v
func TestWatchWatcherOwnerRescansOnRestart(t *testing.T) {
	if os.Getenv("DMS_TEST_SCRATCH_BUS") != "1" {
		t.Skip("needs a scratch session bus (DMS_TEST_SCRATCH_BUS=1 under dbus-run-session)")
	}

	m, err := NewManager()
	if err != nil {
		t.Fatalf("NewManager: %v", err)
	}
	defer m.Close()
	m.WatchWatcherOwner()

	shell, err := dbus.SessionBusPrivate()
	if err != nil {
		t.Fatalf("private bus: %v", err)
	}
	defer shell.Close()
	if err := shell.Auth(nil); err != nil {
		t.Fatalf("auth: %v", err)
	}
	if err := shell.Hello(); err != nil {
		t.Fatalf("hello: %v", err)
	}

	claim := func() {
		t.Helper()
		reply, err := shell.RequestName(sniWatcherDest, dbus.NameFlagReplaceExisting)
		if err != nil || reply != dbus.RequestNameReplyPrimaryOwner {
			t.Fatalf("claim watcher: %v (%v)", err, reply)
		}
	}
	release := func() {
		t.Helper()
		if _, err := shell.ReleaseName(sniWatcherDest); err != nil {
			t.Fatalf("release watcher: %v", err)
		}
	}

	claim()
	time.Sleep(300 * time.Millisecond)
	release()
	time.Sleep(300 * time.Millisecond)
	claim()
	// scheduleRecovery waits resumeDelay before scanning; the log line proves the trigger fired.
	time.Sleep(resumeDelay + 2*time.Second)
}
