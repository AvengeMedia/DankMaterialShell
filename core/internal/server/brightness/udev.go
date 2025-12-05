package brightness

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/pilebones/go-udev/netlink"
)

type UdevMonitor struct {
	stop chan struct{}
}

func NewUdevMonitor(manager *Manager) *UdevMonitor {
	m := &UdevMonitor{
		stop: make(chan struct{}),
	}

	go m.run(manager)
	return m
}

func (m *UdevMonitor) run(manager *Manager) {
	conn := &netlink.UEventConn{}
	if err := conn.Connect(netlink.UdevEvent); err != nil {
		log.Errorf("Failed to connect to udev netlink: %v", err)
		return
	}
	defer conn.Close()

	matcher := &netlink.RuleDefinitions{
		Rules: []netlink.RuleDefinition{
			{Env: map[string]string{"SUBSYSTEM": "backlight"}},
			// ! TODO: most drivers dont emit this for leds?
			// ! inotify brightness_hw_changed works, but thn some devices dont do that...
			// ! So for now the GUI just shows OSDs for leds, without reflecting actual HW value
			// {Env: map[string]string{"SUBSYSTEM": "leds"}},
		},
	}
	if err := matcher.Compile(); err != nil {
		log.Errorf("Failed to compile udev matcher: %v", err)
		return
	}

	events := make(chan netlink.UEvent)
	errs := make(chan error)
	conn.Monitor(events, errs, matcher)

	log.Info("Udev monitor started for backlight/leds events")

	for {
		select {
		case <-m.stop:
			return
		case err := <-errs:
			log.Errorf("Udev monitor error: %v", err)
			return
		case event := <-events:
			m.handleEvent(manager, event)
		}
	}
}

func (m *UdevMonitor) handleEvent(manager *Manager, event netlink.UEvent) {
	subsystem := event.Env["SUBSYSTEM"]
	devpath := event.Env["DEVPATH"]

	if subsystem == "" || devpath == "" {
		return
	}

	sysname := filepath.Base(devpath)
	action := string(event.Action)

	switch action {
	case "change":
		m.handleChange(manager, subsystem, sysname)
	case "add", "remove":
		log.Debugf("Udev %s event: %s:%s - triggering rescan", action, subsystem, sysname)
		manager.Rescan()
	}
}

func (m *UdevMonitor) handleChange(manager *Manager, subsystem, sysname string) {
	deviceID := subsystem + ":" + sysname

	if manager.sysfsBackend == nil {
		return
	}

	brightnessPath := filepath.Join(manager.sysfsBackend.basePath, subsystem, sysname, "brightness")
	data, err := os.ReadFile(brightnessPath)
	if err != nil {
		log.Debugf("Udev change event for %s but failed to read brightness: %v", deviceID, err)
		return
	}

	brightness, err := strconv.Atoi(strings.TrimSpace(string(data)))
	if err != nil {
		log.Debugf("Failed to parse brightness for %s: %v", deviceID, err)
		return
	}

	manager.handleUdevBrightnessChange(deviceID, brightness)
}

func (m *UdevMonitor) Close() {
	close(m.stop)
}

func (m *Manager) handleUdevBrightnessChange(deviceID string, rawBrightness int) {
	if m.sysfsBackend == nil {
		return
	}

	dev, err := m.sysfsBackend.GetDevice(deviceID)
	if err != nil {
		log.Debugf("Udev event for unknown device %s: %v", deviceID, err)
		return
	}

	percent := m.sysfsBackend.ValueToPercent(rawBrightness, dev, false)

	m.stateMutex.Lock()
	var found bool
	for i, d := range m.state.Devices {
		if d.ID != deviceID {
			continue
		}
		found = true
		if d.Current == rawBrightness {
			m.stateMutex.Unlock()
			return
		}
		m.state.Devices[i].Current = rawBrightness
		m.state.Devices[i].CurrentPercent = percent
		break
	}
	m.stateMutex.Unlock()

	if !found {
		log.Debugf("Udev event for device not in state: %s", deviceID)
		return
	}

	log.Debugf("Udev brightness change: %s -> %d (%d%%)", deviceID, rawBrightness, percent)
	m.broadcastDeviceUpdate(deviceID)
}
