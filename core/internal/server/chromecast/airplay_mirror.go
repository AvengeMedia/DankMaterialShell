package chromecast

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"sync"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
)

// defaultPortRange is the fixed UDP/TCP window doubletake confines its AirPlay
// back-channel ports to, so users can open exactly this range in their firewall.
const defaultPortRange = "60000-60010"

// doubletakePath resolves the doubletake binary (the AirPlay 2 protocol sender).
// doubletake is a separate GPLv3 process, never linked into the MIT core.
func doubletakePath() string {
	if p := os.Getenv("DMS_DOUBLETAKE"); p != "" {
		return p
	}
	return "doubletake"
}

func portRange() string {
	if r := os.Getenv("DMS_CAST_PORT_RANGE"); r != "" {
		return r
	}
	return defaultPortRange
}

// buildDoubletakeCmd builds the doubletake mirror invocation for host.
// doubletake captures via the go-gst library itself (see the fork at
// github.com/domenkozar/doubletake), so no capture hook is needed here.
// Overridable in tests.
var buildDoubletakeCmd = func(host string) *exec.Cmd {
	return exec.Command(doubletakePath(),
		"-target", host,
		"-port-range", portRange(),
		"-no-audio",
	)
}

// airplayMirror manages the doubletake subprocess that mirrors the screen to an
// AirPlay 2 receiver.
type airplayMirror struct {
	mu      sync.Mutex
	cmd     *exec.Cmd
	running bool
}

// start launches doubletake mirroring to host. onExit fires if the process ends
// on its own (not via stop), so the manager can clear connection state.
func (a *airplayMirror) start(host string, onExit func()) error {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.running {
		return fmt.Errorf("airplay mirror already running")
	}

	cmd := buildDoubletakeCmd(host)
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		if errors.Is(err, exec.ErrNotFound) {
			return fmt.Errorf("AirPlay mirroring requires 'doubletake' — install it (or set DMS_DOUBLETAKE)")
		}
		return fmt.Errorf("start doubletake: %w", err)
	}
	a.cmd = cmd
	a.running = true
	log.Infof("[Cast] AirPlay mirror started -> %s", host)

	go func() {
		_ = cmd.Wait()
		a.mu.Lock()
		unexpected := a.running // still true => we didn't stop() it
		a.running = false
		a.cmd = nil
		a.mu.Unlock()
		if unexpected {
			log.Warn("[Cast] AirPlay mirror exited unexpectedly")
			if onExit != nil {
				onExit()
			}
		}
	}()
	return nil
}

// stop terminates the doubletake subprocess.
func (a *airplayMirror) stop() {
	a.mu.Lock()
	defer a.mu.Unlock()
	if !a.running {
		return
	}
	a.running = false
	if a.cmd != nil && a.cmd.Process != nil {
		_ = a.cmd.Process.Kill()
	}
	a.cmd = nil
	log.Info("[Cast] AirPlay mirror stopped")
}

func (a *airplayMirror) isRunning() bool {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.running
}
