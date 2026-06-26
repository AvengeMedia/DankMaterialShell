package network

import (
	"fmt"
	"os/exec"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/godbus/dbus/v5"
)

const (
	priorityHigh    = int32(100)
	priorityLow     = int32(10)
	priorityDefault = int32(0)

	metricPreferred    = int64(100)
	metricNonPreferred = int64(300)
	metricDefault      = int64(100)
)

func (m *Manager) SetConnectionPreference(pref ConnectionPreference) error {
	switch pref {
	case PreferenceWiFi, PreferenceEthernet, PreferenceAuto:
	default:
		return fmt.Errorf("invalid preference: %s", pref)
	}

	m.stateMutex.Lock()
	m.state.Preference = pref
	m.stateMutex.Unlock()

	if _, ok := m.backend.(*NetworkManagerBackend); !ok {
		m.notifySubscribers()
		return nil
	}

	switch pref {
	case PreferenceWiFi:
		return m.prioritizeWiFi()
	case PreferenceEthernet:
		return m.prioritizeEthernet()
	case PreferenceAuto:
		return m.balancePriorities()
	}

	return nil
}

func (m *Manager) prioritizeWiFi() error {
	if err := m.setConnectionPriority("802-11-wireless", priorityHigh, metricPreferred); err != nil {
		log.Warnf("Failed to set WiFi priority: %v", err)
	}

	if err := m.setConnectionPriority("802-3-ethernet", priorityLow, metricNonPreferred); err != nil {
		log.Warnf("Failed to set Ethernet priority: %v", err)
	}

	m.reapplyActiveConnections()
	m.notifySubscribers()
	return nil
}

func (m *Manager) prioritizeEthernet() error {
	if err := m.setConnectionPriority("802-3-ethernet", priorityHigh, metricPreferred); err != nil {
		log.Warnf("Failed to set Ethernet priority: %v", err)
	}

	if err := m.setConnectionPriority("802-11-wireless", priorityLow, metricNonPreferred); err != nil {
		log.Warnf("Failed to set WiFi priority: %v", err)
	}

	m.reapplyActiveConnections()
	m.notifySubscribers()
	return nil
}

func (m *Manager) balancePriorities() error {
	if err := m.setConnectionPriority("802-3-ethernet", priorityDefault, metricDefault); err != nil {
		log.Warnf("Failed to reset Ethernet priority: %v", err)
	}

	if err := m.setConnectionPriority("802-11-wireless", priorityDefault, metricDefault); err != nil {
		log.Warnf("Failed to reset WiFi priority: %v", err)
	}

	m.reapplyActiveConnections()
	m.notifySubscribers()
	return nil
}

func (m *Manager) reapplyActiveConnections() {
	m.stateMutex.RLock()
	ethDev := m.state.EthernetDevice
	wifiDev := m.state.WiFiDevice
	m.stateMutex.RUnlock()

	if ethDev != "" {
		exec.Command("nmcli", "dev", "reapply", ethDev).Run()
	}
	if wifiDev != "" {
		exec.Command("nmcli", "dev", "reapply", wifiDev).Run()
	}
}

func (m *Manager) setConnectionPriority(connType string, autoconnectPriority int32, routeMetric int64) error {
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		return fmt.Errorf("failed to connect to system bus: %w", err)
	}
	defer conn.Close()

	settingsObj := conn.Object("org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager/Settings")

	var connPaths []dbus.ObjectPath
	if err := settingsObj.Call("org.freedesktop.NetworkManager.Settings.ListConnections", 0).Store(&connPaths); err != nil {
		return fmt.Errorf("failed to list connections: %w", err)
	}

	for _, connPath := range connPaths {
		connObj := conn.Object("org.freedesktop.NetworkManager", connPath)

		var settings map[string]map[string]dbus.Variant
		if err := connObj.Call("org.freedesktop.NetworkManager.Settings.Connection.GetSettings", 0).Store(&settings); err != nil {
			continue
		}

		connSection, ok := settings["connection"]
		if !ok {
			continue
		}

		typeVariant, ok := connSection["type"]
		if !ok {
			continue
		}

		cType, ok := typeVariant.Value().(string)
		if !ok || cType != connType {
			continue
		}

		// AP-mode profiles (hotspots) are not routing candidates; leave their
		// autoconnect priority and metrics alone.
		if cType == "802-11-wireless" {
			if wifiSection, ok := settings["802-11-wireless"]; ok {
				if modeVariant, ok := wifiSection["mode"]; ok {
					if mode, _ := modeVariant.Value().(string); mode == "ap" {
						continue
					}
				}
			}
		}

		connName := ""
		if idVariant, ok := connSection["id"]; ok {
			connName, _ = idVariant.Value().(string)
		}

		if connName == "" {
			continue
		}

		if err := exec.Command("nmcli", "con", "mod", connName,
			"connection.autoconnect-priority", fmt.Sprintf("%d", autoconnectPriority),
			"ipv4.route-metric", fmt.Sprintf("%d", routeMetric),
			"ipv6.route-metric", fmt.Sprintf("%d", routeMetric)).Run(); err != nil {
			log.Warnf("Failed to set priority for %s: %v", connName, err)
			continue
		}

		log.Infof("Updated %v: autoconnect-priority=%d, route-metric=%d", connName, autoconnectPriority, routeMetric)
	}

	return nil
}

func (m *Manager) GetConnectionPreference() ConnectionPreference {
	m.stateMutex.RLock()
	defer m.stateMutex.RUnlock()
	return m.state.Preference
}

func (m *Manager) WasRecentlyFailed(ssid string) bool {
	nm, ok := m.backend.(*NetworkManagerBackend)
	if !ok {
		return false
	}

	nm.failedMutex.RLock()
	defer nm.failedMutex.RUnlock()

	if nm.lastFailedSSID != ssid {
		return false
	}

	elapsed := time.Now().Unix() - nm.lastFailedTime
	return elapsed < 10
}
