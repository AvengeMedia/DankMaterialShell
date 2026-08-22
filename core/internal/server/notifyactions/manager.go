package notifyactions

import (
	"os/exec"
	"path/filepath"
	"sync"
	"syscall"

	"github.com/godbus/dbus/v5"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
)

const (
	notifyPath      = "/org/freedesktop/Notifications"
	notifyInterface = "org.freedesktop.Notifications"
	actionInvoked   = notifyInterface + ".ActionInvoked"
	closed          = notifyInterface + ".NotificationClosed"
)

type Manager struct {
	conn    *dbus.Conn
	signals chan *dbus.Signal
	mu      sync.Mutex
	watched map[uint32]string
}

func NewManager() (*Manager, error) {
	conn, err := dbus.SessionBus()
	if err != nil {
		return nil, err
	}
	if err := conn.AddMatchSignal(dbus.WithMatchObjectPath(notifyPath), dbus.WithMatchInterface(notifyInterface)); err != nil {
		return nil, err
	}
	m := &Manager{
		conn:    conn,
		signals: make(chan *dbus.Signal, 32),
		watched: make(map[uint32]string),
	}
	conn.Signal(m.signals)
	go m.loop()
	return m, nil
}

func (m *Manager) Watch(id uint32, path string) {
	m.mu.Lock()
	m.watched[id] = path
	m.mu.Unlock()
}

func (m *Manager) Close() {
	m.conn.RemoveSignal(m.signals)
	_ = m.conn.RemoveMatchSignal(dbus.WithMatchObjectPath(notifyPath), dbus.WithMatchInterface(notifyInterface))
	close(m.signals)
}

func (m *Manager) loop() {
	for sig := range m.signals {
		switch sig.Name {
		case actionInvoked:
			m.handleAction(sig)
		case closed:
			m.forget(sig)
		}
	}
}

func (m *Manager) take(sig *dbus.Signal) (string, bool) {
	if len(sig.Body) < 1 {
		return "", false
	}
	id, ok := sig.Body[0].(uint32)
	if !ok {
		return "", false
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	path, ok := m.watched[id]
	if !ok {
		return "", false
	}
	delete(m.watched, id)
	return path, true
}

func (m *Manager) forget(sig *dbus.Signal) {
	m.take(sig)
}

func (m *Manager) handleAction(sig *dbus.Signal) {
	if len(sig.Body) < 2 {
		return
	}
	action, ok := sig.Body[1].(string)
	if !ok {
		return
	}
	path, ok := m.take(sig)
	if !ok {
		return
	}
	if action == "folder" {
		path = filepath.Dir(path)
	}
	openPath(path)
}

func openPath(path string) {
	cmd := exec.Command("xdg-open", path)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := cmd.Start(); err != nil {
		log.Warnf("notifyactions: xdg-open %s: %v", path, err)
		return
	}
	go func() { _ = cmd.Wait() }()
}
