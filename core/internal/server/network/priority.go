package network

import (
	"fmt"
	"time"

	"github.com/Wifx/gonetworkmanager/v2"
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
	if err := m.setConnectionMetrics("802-11-wireless", 50); err != nil {
		return err
	}

	if err := m.setConnectionMetrics("802-3-ethernet", 100); err != nil {
		return err
	}

	m.notifySubscribers()
	return nil
}

func (m *Manager) prioritizeEthernet() error {
	if err := m.setConnectionMetrics("802-3-ethernet", 50); err != nil {
		return err
	}

	if err := m.setConnectionMetrics("802-11-wireless", 100); err != nil {
		return err
	}

	m.notifySubscribers()
	return nil
}

func (m *Manager) balancePriorities() error {
	if err := m.setConnectionMetrics("802-3-ethernet", 50); err != nil {
		return err
	}

	if err := m.setConnectionMetrics("802-11-wireless", 50); err != nil {
		return err
	}

	m.notifySubscribers()
	return nil
}

func (m *Manager) setConnectionMetrics(connType string, metric uint32) error {
	settingsMgr, err := gonetworkmanager.NewSettings()
	if err != nil {
		return fmt.Errorf("failed to get settings: %w", err)
	}

	connections, err := settingsMgr.ListConnections()
	if err != nil {
		return fmt.Errorf("failed to get connections: %w", err)
	}

	for _, conn := range connections {
		connSettings, err := conn.GetSettings()
		if err != nil {
			continue
		}

		if connMeta, ok := connSettings["connection"]; ok {
			if cType, ok := connMeta["type"].(string); ok && cType == connType {
				if connSettings["ipv4"] == nil {
					connSettings["ipv4"] = make(map[string]any)
				}
				if ipv4Map := connSettings["ipv4"]; ipv4Map != nil {
					ipv4Map["route-metric"] = int64(metric)
				}

				if connSettings["ipv6"] == nil {
					connSettings["ipv6"] = make(map[string]any)
				}
				if ipv6Map := connSettings["ipv6"]; ipv6Map != nil {
					ipv6Map["route-metric"] = int64(metric)
				}

				err = conn.Update(connSettings)
				if err != nil {
					continue
				}
			}
		}
	}

	return nil
}

func (m *Manager) GetConnectionPreference() ConnectionPreference {
	m.stateMutex.RLock()
	defer m.stateMutex.RUnlock()
	return m.state.Preference
}

func (m *Manager) WasRecentlyFailed(ssid string) bool {
	if nm, ok := m.backend.(*NetworkManagerBackend); ok {
		nm.failedMutex.RLock()
		defer nm.failedMutex.RUnlock()

		if nm.lastFailedSSID == ssid {
			elapsed := time.Now().Unix() - nm.lastFailedTime
			return elapsed < 10
		}
	}
	return false
}
