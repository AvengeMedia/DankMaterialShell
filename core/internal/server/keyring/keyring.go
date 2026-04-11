package keyring

import (
	"bytes"
	"fmt"
	"os/exec"
)

// runner abstracts process execution so the unlock flow can be tested without
// actually invoking gnome-keyring-daemon.
type runner func(password string) error

// lookPath is overridable in tests.
var lookPath = exec.LookPath

// run is the package-level runner. Tests replace it to capture invocations.
var run runner = defaultRun

func defaultRun(password string) error {
	path, err := lookPath("gnome-keyring-daemon")
	if err != nil {
		return nil // not installed, nothing to do
	}

	cmd := exec.Command(path, "--unlock")
	cmd.Stdin = bytes.NewBufferString(password)
	cmd.Stdout = nil
	cmd.Stderr = nil

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("gnome-keyring-daemon --unlock failed: %w", err)
	}
	return nil
}

// Unlock pipes the given password to `gnome-keyring-daemon --unlock` via stdin,
// mirroring what pam_gnome_keyring.so does during pam_open_session. This
// ensures the login keyring is unlocked after lock-screen authentication
// without requiring Quickshell to call pam_open_session itself.
//
// If gnome-keyring-daemon is not installed, this is a no-op.
func Unlock(password string) error {
	return run(password)
}
