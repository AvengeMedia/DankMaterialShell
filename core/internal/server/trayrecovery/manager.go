package trayrecovery

import (
	"fmt"
	"sync"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/loginctl"
	"github.com/godbus/dbus/v5"
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

	// Run a startup scan after a delay — covers the case where the process
	// was killed during suspend and restarted by systemd (Type=dbus).
	// The fresh process never sees the PrepareForSleep true→false transition,
	// so the loginctl watcher alone is not enough.
	go m.scheduleRecovery()

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
