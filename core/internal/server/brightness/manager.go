package brightness

import (
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
)

func NewManager() (*Manager, error) {
	return NewManagerWithOptions(false)
}

func NewManagerWithOptions(exponential bool) (*Manager, error) {
	m := &Manager{
		stopChan:    make(chan struct{}),
		exponential: exponential,
	}

	go m.initLogind()
	go m.initSysfs()
	go m.initDDC()

	return m, nil
}

func (m *Manager) initLogind() {
	log.Debug("Initializing logind backend...")
	logind, err := NewLogindBackend()
	if err != nil {
		log.Infof("Logind backend not available: %v", err)
		log.Info("Will use direct sysfs access for brightness control")
		return
	}

	m.logindBackend = logind
	m.logindReady = true
	log.Info("Logind backend initialized - will use for brightness control")
}

func (m *Manager) initSysfs() {
	log.Debug("Initializing sysfs backend...")
	sysfs, err := NewSysfsBackend()
	if err != nil {
		log.Warnf("Failed to initialize sysfs backend: %v", err)
		return
	}

	devices, err := sysfs.GetDevices()
	if err != nil {
		log.Warnf("Failed to get initial sysfs devices: %v", err)
		m.sysfsBackend = sysfs
		m.sysfsReady = true
		m.updateState()
		return
	}

	log.Infof("Sysfs backend initialized with %d devices", len(devices))
	for _, d := range devices {
		log.Debugf("  - %s: %s (%d%%)", d.ID, d.Name, d.CurrentPercent)
	}

	m.sysfsBackend = sysfs
	m.sysfsReady = true
	m.updateState()
}

func (m *Manager) initDDC() {
	ddc, err := NewDDCBackend()
	if err != nil {
		log.Debugf("Failed to initialize DDC backend: %v", err)
		return
	}

	m.ddcBackend = ddc
	m.ddcReady = true
	log.Info("DDC backend initialized")

	m.updateState()
}

func (m *Manager) Rescan() {
	log.Debug("Rescanning brightness devices...")
	m.updateState()
}

func sortDevices(devices []Device) {
	sort.Slice(devices, func(i, j int) bool {
		classOrder := map[DeviceClass]int{
			ClassBacklight: 0,
			ClassDDC:       1,
			ClassLED:       2,
		}

		orderI := classOrder[devices[i].Class]
		orderJ := classOrder[devices[j].Class]

		if orderI != orderJ {
			return orderI < orderJ
		}

		return devices[i].Name < devices[j].Name
	})
}

func stateChanged(old, new State) bool {
	if len(old.Devices) != len(new.Devices) {
		return true
	}

	oldMap := make(map[string]Device)
	for _, d := range old.Devices {
		oldMap[d.ID] = d
	}

	for _, newDev := range new.Devices {
		oldDev, exists := oldMap[newDev.ID]
		if !exists {
			return true
		}
		if oldDev.Current != newDev.Current || oldDev.Max != newDev.Max {
			return true
		}
	}

	return false
}

func (m *Manager) updateState() {
	allDevices := make([]Device, 0)

	if m.sysfsReady && m.sysfsBackend != nil {
		devices, err := m.sysfsBackend.GetDevices()
		if err != nil {
			log.Debugf("Failed to get sysfs devices: %v", err)
		}
		if err == nil {
			allDevices = append(allDevices, devices...)
		}
	}

	if m.ddcReady && m.ddcBackend != nil {
		devices, err := m.ddcBackend.GetDevices()
		if err != nil {
			log.Debugf("Failed to get DDC devices: %v", err)
		}
		if err == nil {
			allDevices = append(allDevices, devices...)
		}
	}

	sortDevices(allDevices)

	m.stateMutex.Lock()
	oldState := m.state
	newState := State{Devices: allDevices}

	if !stateChanged(oldState, newState) {
		m.stateMutex.Unlock()
		return
	}

	m.state = newState
	m.stateMutex.Unlock()
	log.Debugf("State changed, notifying subscribers")
	m.NotifySubscribers()
}

func (m *Manager) SetBrightness(deviceID string, percent int) error {
	return m.SetBrightnessWithMode(deviceID, percent, m.exponential)
}

func (m *Manager) SetBrightnessWithMode(deviceID string, percent int, exponential bool) error {
	return m.SetBrightnessWithExponent(deviceID, percent, exponential, 1.2)
}

func (m *Manager) SetBrightnessWithExponent(deviceID string, percent int, exponential bool, exponent float64) error {
	if percent < 0 {
		return fmt.Errorf("percent out of range: %d", percent)
	}

	log.Debugf("SetBrightness: %s to %d%%", deviceID, percent)

	m.stateMutex.Lock()
	currentState := m.state
	var found bool
	var deviceClass DeviceClass
	var deviceIndex int

	log.Debugf("Current state has %d devices", len(currentState.Devices))

	for i, dev := range currentState.Devices {
		if dev.ID == deviceID {
			found = true
			deviceClass = dev.Class
			deviceIndex = i
			break
		}
	}

	if !found {
		m.stateMutex.Unlock()
		log.Debugf("Device not found in state: %s", deviceID)
		return fmt.Errorf("device not found: %s", deviceID)
	}

	newDevices := make([]Device, len(currentState.Devices))
	copy(newDevices, currentState.Devices)
	newDevices[deviceIndex].CurrentPercent = percent
	m.state = State{Devices: newDevices}
	m.stateMutex.Unlock()

	var err error
	if deviceClass == ClassDDC {
		log.Debugf("Calling DDC backend for %s", deviceID)
		err = m.ddcBackend.SetBrightnessWithExponent(deviceID, percent, exponential, exponent, func() {
			m.updateState()
			m.debouncedBroadcast(deviceID)
		})
	} else if m.logindReady && m.logindBackend != nil {
		log.Debugf("Calling logind backend for %s", deviceID)
		err = m.setViaSysfsWithLogindWithExponent(deviceID, percent, exponential, exponent)
	} else {
		log.Debugf("Calling sysfs backend for %s", deviceID)
		err = m.sysfsBackend.SetBrightnessWithExponent(deviceID, percent, exponential, exponent)
	}

	if err != nil {
		m.updateState()
		return fmt.Errorf("failed to set brightness: %w", err)
	}

	if deviceClass != ClassDDC {
		log.Debugf("Queueing broadcast for %s", deviceID)
		m.debouncedBroadcast(deviceID)
	}
	return nil
}

func (m *Manager) IncrementBrightness(deviceID string, step int) error {
	return m.IncrementBrightnessWithMode(deviceID, step, m.exponential)
}

func (m *Manager) IncrementBrightnessWithMode(deviceID string, step int, exponential bool) error {
	return m.IncrementBrightnessWithExponent(deviceID, step, exponential, 1.2)
}

func (m *Manager) IncrementBrightnessWithExponent(deviceID string, step int, exponential bool, exponent float64) error {
	m.stateMutex.RLock()
	currentState := m.state
	m.stateMutex.RUnlock()

	var currentPercent int
	var found bool

	for _, dev := range currentState.Devices {
		if dev.ID == deviceID {
			currentPercent = dev.CurrentPercent
			found = true
			break
		}
	}

	if !found {
		return fmt.Errorf("device not found: %s", deviceID)
	}

	newPercent := currentPercent + step
	if newPercent > 100 {
		newPercent = 100
	}
	if newPercent < 0 {
		newPercent = 0
	}

	return m.SetBrightnessWithExponent(deviceID, newPercent, exponential, exponent)
}

func (m *Manager) DecrementBrightness(deviceID string, step int) error {
	return m.IncrementBrightness(deviceID, -step)
}

func (m *Manager) setViaSysfsWithLogindWithExponent(deviceID string, percent int, exponential bool, exponent float64) error {
	parts := strings.SplitN(deviceID, ":", 2)
	if len(parts) != 2 {
		return fmt.Errorf("invalid device id: %s", deviceID)
	}

	subsystem := parts[0]
	name := parts[1]

	dev, err := m.sysfsBackend.GetDevice(deviceID)
	if err != nil {
		return err
	}

	value := m.sysfsBackend.PercentToValueWithExponent(percent, dev, exponential, exponent)

	if m.logindBackend == nil {
		return m.sysfsBackend.SetBrightnessWithExponent(deviceID, percent, exponential, exponent)
	}

	err = m.logindBackend.SetBrightness(subsystem, name, uint32(value))
	if err != nil {
		log.Debugf("logind SetBrightness failed, falling back to direct sysfs: %v", err)
		return m.sysfsBackend.SetBrightnessWithExponent(deviceID, percent, exponential, exponent)
	}

	log.Debugf("set %s to %d%% (%d/%d) via logind", deviceID, percent, value, dev.maxBrightness)
	return nil
}

func (m *Manager) debouncedBroadcast(deviceID string) {
	m.broadcastMutex.Lock()
	defer m.broadcastMutex.Unlock()

	m.broadcastPending = true
	m.pendingDeviceID = deviceID

	if m.broadcastTimer == nil {
		m.broadcastTimer = time.AfterFunc(150*time.Millisecond, func() {
			m.broadcastMutex.Lock()
			pending := m.broadcastPending
			deviceID := m.pendingDeviceID
			m.broadcastPending = false
			m.pendingDeviceID = ""
			m.broadcastMutex.Unlock()

			if !pending || deviceID == "" {
				return
			}

			m.broadcastDeviceUpdate(deviceID)
		})
	} else {
		m.broadcastTimer.Reset(150 * time.Millisecond)
	}
}

func (m *Manager) broadcastDeviceUpdate(deviceID string) {
	m.stateMutex.RLock()
	var targetDevice *Device
	for _, dev := range m.state.Devices {
		if dev.ID == deviceID {
			devCopy := dev
			targetDevice = &devCopy
			break
		}
	}
	m.stateMutex.RUnlock()

	if targetDevice == nil {
		log.Debugf("Device not found for broadcast: %s", deviceID)
		return
	}

	update := DeviceUpdate{Device: *targetDevice}

	log.Debugf("Broadcasting device update: %s at %d%%", deviceID, targetDevice.CurrentPercent)

	m.updateSubscribers.Range(func(key string, ch chan DeviceUpdate) bool {
		select {
		case ch <- update:
		default:
		}
		return true
	})
}
