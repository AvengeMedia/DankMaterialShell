package evdev

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	evdev "github.com/holoplot/go-evdev"
)

const (
	evKeyType      = 0x01
	evLedType      = 0x11
	keyCapslockKey = 58
	ledCapslockKey = 1
	keyStateOn     = 1
)

type EvdevDevice interface {
	Name() (string, error)
	Path() string
	Close() error
	ReadOne() (*evdev.InputEvent, error)
	State(t evdev.EvType) (evdev.StateMap, error)
}

type Manager struct {
	device      EvdevDevice
	state       State
	stateMutex  sync.RWMutex
	subscribers map[string]chan State
	subMutex    sync.RWMutex
	closeChan   chan struct{}
	closeOnce   sync.Once
}

func NewManager() (*Manager, error) {
	device, err := findKeyboard()
	if err != nil {
		return nil, fmt.Errorf("failed to find keyboard: %w", err)
	}

	initialCapsLock := readInitialCapsLockState(device)

	m := &Manager{
		device:      device,
		state:       State{Available: true, CapsLock: initialCapsLock},
		subscribers: make(map[string]chan State),
		closeChan:   make(chan struct{}),
	}

	go m.monitorCapsLock()

	return m, nil
}

func readInitialCapsLockState(device EvdevDevice) bool {
	ledStates, err := device.State(evLedType)
	if err != nil {
		log.Debugf("Could not read LED state: %v", err)
		return false
	}

	return ledStates[ledCapslockKey]
}

func findKeyboard() (EvdevDevice, error) {
	pattern := "/dev/input/event*"
	matches, err := filepath.Glob(pattern)
	if err != nil {
		return nil, fmt.Errorf("failed to glob input devices: %w", err)
	}

	if len(matches) == 0 {
		return nil, fmt.Errorf("no input devices found")
	}

	for _, path := range matches {
		device, err := evdev.Open(path)
		if err != nil {
			continue
		}

		if isKeyboard(device) {
			deviceName, _ := device.Name()
			log.Debugf("Found keyboard: %s at %s", deviceName, path)
			return device, nil
		}

		device.Close()
	}

	return nil, fmt.Errorf("no keyboard device found")
}

func isKeyboard(device EvdevDevice) bool {
	deviceName, err := device.Name()
	if err != nil {
		return false
	}

	name := strings.ToLower(deviceName)

	switch {
	case strings.Contains(name, "keyboard"):
		return true
	case strings.Contains(name, "kbd"):
		return true
	case strings.Contains(name, "input") && strings.Contains(name, "key"):
		return true
	default:
		return false
	}
}

func (m *Manager) monitorCapsLock() {
	defer func() {
		if r := recover(); r != nil {
			log.Errorf("Panic in evdev monitor: %v", r)
		}
	}()

	for {
		select {
		case <-m.closeChan:
			return
		default:
		}

		event, err := m.device.ReadOne()
		if err != nil {
			if !isClosedError(err) {
				log.Warnf("Failed to read evdev event: %v", err)
			}
			time.Sleep(100 * time.Millisecond)
			continue
		}

		if event == nil {
			continue
		}

		if event.Type == evKeyType && event.Code == keyCapslockKey && event.Value == keyStateOn {
			m.toggleCapsLock()
		}
	}
}

func isClosedError(err error) bool {
	if err == nil {
		return false
	}

	errStr := err.Error()
	switch {
	case strings.Contains(errStr, "closed"):
		return true
	case strings.Contains(errStr, "bad file descriptor"):
		return true
	default:
		return false
	}
}

func (m *Manager) toggleCapsLock() {
	m.stateMutex.Lock()
	m.state.CapsLock = !m.state.CapsLock
	newState := m.state
	m.stateMutex.Unlock()

	log.Debugf("Caps lock toggled: %v", newState.CapsLock)
	m.notifySubscribers(newState)
}

func (m *Manager) GetState() State {
	m.stateMutex.RLock()
	defer m.stateMutex.RUnlock()
	return m.state
}

func (m *Manager) Subscribe(id string) chan State {
	m.subMutex.Lock()
	defer m.subMutex.Unlock()

	ch := make(chan State, 16)
	m.subscribers[id] = ch
	return ch
}

func (m *Manager) Unsubscribe(id string) {
	m.subMutex.Lock()
	defer m.subMutex.Unlock()

	if ch, ok := m.subscribers[id]; ok {
		close(ch)
		delete(m.subscribers, id)
	}
}

func (m *Manager) notifySubscribers(state State) {
	m.subMutex.RLock()
	defer m.subMutex.RUnlock()

	for _, ch := range m.subscribers {
		select {
		case ch <- state:
		default:
		}
	}
}

func (m *Manager) Close() {
	m.closeOnce.Do(func() {
		close(m.closeChan)

		if m.device != nil {
			if err := m.device.Close(); err != nil && !isClosedError(err) {
				log.Warnf("Error closing evdev device: %v", err)
			}
		}

		m.subMutex.Lock()
		for id, ch := range m.subscribers {
			close(ch)
			delete(m.subscribers, id)
		}
		m.subMutex.Unlock()
	})
}

func InitializeManager() (*Manager, error) {
	if os.Getuid() != 0 && !hasInputGroupAccess() {
		return nil, fmt.Errorf("insufficient permissions to access input devices")
	}

	return NewManager()
}

func hasInputGroupAccess() bool {
	pattern := "/dev/input/event*"
	matches, err := filepath.Glob(pattern)
	if err != nil || len(matches) == 0 {
		return false
	}

	testFile, err := os.Open(matches[0])
	if err != nil {
		return false
	}
	testFile.Close()
	return true
}
