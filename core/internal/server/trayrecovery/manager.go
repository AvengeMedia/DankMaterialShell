package trayrecovery

import (
	"fmt"
	"sync"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/loginctl"
	"github.com/godbus/dbus/v5"
	"golang.org/x/sys/unix"
)

const resumeDelay = 3 * time.Second

type Manager struct {
	conn     *dbus.Conn
	stopChan chan struct{}
	wg       sync.WaitGroup
}

func NewManager() (*Manager, error) {
	conn, err := dbus.ConnectSessionBus()
	if err != nil {
		return nil, fmt.Errorf("failed to connect to session bus: %w", err)
	}

	m := &Manager{
		conn:     conn,
		stopChan: make(chan struct{}),
	}

	// Only run a startup scan when the system has been suspended at least once.
	// On a fresh boot CLOCK_BOOTTIME ≈ CLOCK_MONOTONIC (difference ~0).
	// After any suspend/resume cycle the difference grows by the time spent
	// sleeping.  This avoids duplicate registrations on normal boot where apps
	// are still starting up and will register their own tray icons shortly.
	if timeSuspended() > 5*time.Second {
		go m.scheduleRecovery()
	}

	return m, nil
}

// WatchLoginctl subscribes to loginctl session state changes and triggers
// tray recovery after resume from suspend (PrepareForSleep false transition).
// This handles the case where the process survives suspend.
func (m *Manager) WatchLoginctl(lm *loginctl.Manager) {
	ch := lm.Subscribe("tray-recovery")
	m.wg.Add(1)
	go func() {
		defer m.wg.Done()
		defer lm.Unsubscribe("tray-recovery")

		wasSleeping := false
		for {
			select {
			case <-m.stopChan:
				return
			case state, ok := <-ch:
				if !ok {
					return
				}
				if state.PreparingForSleep {
					wasSleeping = true
					continue
				}
				if wasSleeping {
					wasSleeping = false
					go m.scheduleRecovery()
				}
			}
		}
	}()
}

func (m *Manager) scheduleRecovery() {
	select {
	case <-time.After(resumeDelay):
		m.recoverTrayItems()
	case <-m.stopChan:
	}
}

func (m *Manager) Close() {
	select {
	case <-m.stopChan:
		return
	default:
		close(m.stopChan)
	}
	m.wg.Wait()
	if m.conn != nil {
		m.conn.Close()
	}
	log.Info("TrayRecovery manager closed")
}

// timeSuspended returns how long the system has spent in suspend since boot.
// It is the difference between CLOCK_BOOTTIME (includes suspend) and
// CLOCK_MONOTONIC (excludes suspend).
func timeSuspended() time.Duration {
	var bt, mt unix.Timespec
	if err := unix.ClockGettime(unix.CLOCK_BOOTTIME, &bt); err != nil {
		return 0
	}
	if err := unix.ClockGettime(unix.CLOCK_MONOTONIC, &mt); err != nil {
		return 0
	}
	diff := (bt.Sec-mt.Sec)*int64(time.Second) + (bt.Nsec - mt.Nsec)
	if diff < 0 {
		return 0
	}
	return time.Duration(diff)
}
