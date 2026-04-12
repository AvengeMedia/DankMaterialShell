package network

import (
	"fmt"
	"net"
	"strconv"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/Wifx/gonetworkmanager/v2"
	"github.com/godbus/dbus/v5"
)

// ModemManager D-Bus constants
const (
	mmInterface      = "org.freedesktop.ModemManager1"
	mmModemInterface = "org.freedesktop.ModemManager1.Modem"
	mmModem3GPP      = "org.freedesktop.ModemManager1.Modem.Modem3gpp"
	mmModemCDMA      = "org.freedesktop.ModemManager1.Modem.ModemCdma"
	mmPath           = "/org/freedesktop/ModemManager1"
	mmObjectManager  = "org.freedesktop.DBus.ObjectManager"
)

// getModemManagerCellularDetails fetches cellular details from ModemManager via D-Bus
func (b *NetworkManagerBackend) getModemManagerCellularDetails(iface string) (operator, technology string, signal uint8) {
	log.Debug("getModemManagerCellularDetails called for interface: %s", iface)

	if b.dbusConn == nil {
		log.Warn("D-Bus connection is nil, cannot fetch ModemManager data")
		return "", "", 0
	}

	// Get list of modems from ObjectManager
	var result map[dbus.ObjectPath]map[string]map[string]dbus.Variant
	err := b.dbusConn.Object(mmInterface, mmPath).Call(mmObjectManager+".GetManagedObjects", 0).Store(&result)
	if err != nil {
		log.Error("Failed to get ModemManager modems: %v", err)
		return "", "", 0
	}

	log.Debug("Found %d ModemManager objects", len(result))

	// Find the modem matching our interface
	for _, obj := range result {
		modemData, ok := obj[mmModemInterface]
		if !ok {
			continue
		}

		// Get the primary port/interface
		var device string
		if v, ok := modemData["PrimaryPort"]; ok {
			device = v.Value().(string)
		} else if v, ok := modemData["Device"]; ok {
			device = v.Value().(string)
		}

		log.Debug("Checking modem with device: %s against iface: %s", device, iface)

		// Match by interface name (e.g., "wwan0mbim0")
		if device != iface && !strings.Contains(device, iface) && !strings.Contains(iface, device) {
			log.Debug("Modem device %s does not match interface %s", device, iface)
			continue
		}

		log.Debug("Found matching modem for interface %s", iface)

		// Get signal quality
		if v, ok := modemData["SignalQuality"]; ok {
			// SignalQuality is a struct (array) with [signal_strength, recent]
			sigData := v.Value().([]interface{})
			if len(sigData) > 0 {
				switch val := sigData[0].(type) {
				case uint32:
					signal = uint8(val)
				case int32:
					signal = uint8(val)
				case uint8:
					signal = val
				}
			}
		}

		// Get access technology
		if v, ok := modemData["AccessTechnologies"]; ok {
			tech := v.Value().(uint32)
			technology = convertAccessTechnology(tech)
		}

		// Try 3GPP interface for operator name
		if gppData, ok := obj[mmModem3GPP]; ok {
			if v, ok := gppData["OperatorName"]; ok {
				operator = v.Value().(string)
			}
		}

		// Fallback to CDMA interface for operator name
		if operator == "" {
			if cdmaData, ok := obj[mmModemCDMA]; ok {
				if v, ok := cdmaData["Nid"]; ok {
					nid := v.Value().(uint32)
					operator = fmt.Sprintf("CDMA Network %d", nid)
				}
			}
		}

		// Get operator from 3GPP registration state if not found
		if operator == "" {
			if gppData, ok := obj[mmModem3GPP]; ok {
				if v, ok := gppData["RegistrationState"]; ok {
					state := v.Value().(uint32)
					// 1 = idle, 2 = home, 3 = searching, 4 = denied, 5 = roaming
					if state == 2 {
						operator = "Home Network"
					} else if state == 5 {
						operator = "Roaming"
					}
				}
			}
		}

		log.Debug("ModemManager cellular details for %s: operator=%s, tech=%s, signal=%d", iface, operator, technology, signal)
		return operator, technology, signal
	}

	log.Warn("No matching modem found for interface %s", iface)
	return "", "", 0
}

// convertAccessTechnology converts ModemManager access tech bits to string
func convertAccessTechnology(tech uint32) string {
	// ModemManager MM_MODEM_ACCESS_TECHNOLOGY_* constants
	const (
		MM_MODEM_ACCESS_TECHNOLOGY_UNKNOWN    = 0
		MM_MODEM_ACCESS_TECHNOLOGY_GPRS       = 1 << 0
		MM_MODEM_ACCESS_TECHNOLOGY_EDGE       = 1 << 1
		MM_MODEM_ACCESS_TECHNOLOGY_UMTS       = 1 << 2
		MM_MODEM_ACCESS_TECHNOLOGY_HSDPA      = 1 << 3
		MM_MODEM_ACCESS_TECHNOLOGY_HSUPA      = 1 << 4
		MM_MODEM_ACCESS_TECHNOLOGY_HSPA       = 1 << 5
		MM_MODEM_ACCESS_TECHNOLOGY_HSPA_PLUS  = 1 << 6
		MM_MODEM_ACCESS_TECHNOLOGY_1XRTT      = 1 << 7
		MM_MODEM_ACCESS_TECHNOLOGY_EVDO0      = 1 << 8
		MM_MODEM_ACCESS_TECHNOLOGY_EVDOA      = 1 << 9
		MM_MODEM_ACCESS_TECHNOLOGY_EVDOB      = 1 << 10
		MM_MODEM_ACCESS_TECHNOLOGY_LTE        = 1 << 11
		MM_MODEM_ACCESS_TECHNOLOGY_5GNR       = 1 << 12
		MM_MODEM_ACCESS_TECHNOLOGY_LTE_CAT_M  = 1 << 13
		MM_MODEM_ACCESS_TECHNOLOGY_LTE_NB_IOT = 1 << 14
	)

	// Return the highest/best technology
	switch {
	case tech&MM_MODEM_ACCESS_TECHNOLOGY_5GNR != 0:
		return "5G"
	case tech&MM_MODEM_ACCESS_TECHNOLOGY_LTE != 0:
		return "4G"
	case tech&MM_MODEM_ACCESS_TECHNOLOGY_LTE_CAT_M != 0:
		return "LTE-M"
	case tech&MM_MODEM_ACCESS_TECHNOLOGY_LTE_NB_IOT != 0:
		return "NB-IoT"
	case tech&MM_MODEM_ACCESS_TECHNOLOGY_HSPA_PLUS != 0:
		return "HSPA+"
	case tech&MM_MODEM_ACCESS_TECHNOLOGY_HSPA != 0:
		return "HSPA"
	case tech&MM_MODEM_ACCESS_TECHNOLOGY_HSDPA != 0:
		return "HSDPA"
	case tech&MM_MODEM_ACCESS_TECHNOLOGY_HSUPA != 0:
		return "HSUPA"
	case tech&MM_MODEM_ACCESS_TECHNOLOGY_UMTS != 0:
		return "3G"
	case tech&MM_MODEM_ACCESS_TECHNOLOGY_EDGE != 0:
		return "EDGE"
	case tech&MM_MODEM_ACCESS_TECHNOLOGY_GPRS != 0:
		return "GPRS"
	case tech&MM_MODEM_ACCESS_TECHNOLOGY_EVDOB != 0:
		return "EV-DO B"
	case tech&MM_MODEM_ACCESS_TECHNOLOGY_EVDOA != 0:
		return "EV-DO A"
	case tech&MM_MODEM_ACCESS_TECHNOLOGY_EVDO0 != 0:
		return "EV-DO"
	case tech&MM_MODEM_ACCESS_TECHNOLOGY_1XRTT != 0:
		return "1xRTT"
	default:
		return ""
	}
}

func (b *NetworkManagerBackend) GetCellularEnabled() (bool, error) {
	nm := b.nmConn.(gonetworkmanager.NetworkManager)
	return nm.GetPropertyWwanEnabled()
}

func (b *NetworkManagerBackend) SetCellularEnabled(enabled bool) error {
	// gonetworkmanager lacks SetPropertyWwanEnabled, use raw D-Bus
	conn := b.dbusConn
	if conn == nil {
		var err error
		conn, err = dbus.ConnectSystemBus()
		if err != nil {
			return fmt.Errorf("failed to connect to system bus: %w", err)
		}
		defer conn.Close()
	}
	obj := conn.Object(dbusNMInterface, dbus.ObjectPath(dbusNMPath))
	err := obj.Call(dbusPropsInterface+".Set", 0, dbusNMInterface, "WwanEnabled", dbus.MakeVariant(enabled)).Err
	if err != nil {
		return fmt.Errorf("failed to set cellular enabled: %w", err)
	}

	b.stateMutex.Lock()
	b.state.CellularEnabled = enabled
	b.stateMutex.Unlock()

	if b.onStateChange != nil {
		b.onStateChange()
	}

	return nil
}

func (b *NetworkManagerBackend) GetCellularDevices() []CellularDevice {
	b.stateMutex.RLock()
	defer b.stateMutex.RUnlock()
	return append([]CellularDevice(nil), b.state.CellularDevices...)
}

func (b *NetworkManagerBackend) GetCellularConnections() ([]CellularConnection, error) {
	return b.listCellularConnections()
}

func (b *NetworkManagerBackend) GetCellularNetworkDetails(uuid string) (*CellularNetworkInfoResponse, error) {
	// Find the cellular device
	b.stateMutex.RLock()
	devices := b.state.CellularDevices
	b.stateMutex.RUnlock()

	if len(devices) == 0 {
		return nil, fmt.Errorf("no cellular device available")
	}

	// For now, use the first available device
	dev := devices[0]

	s := b.settings
	if s == nil {
		var err error
		s, err = gonetworkmanager.NewSettings()
		if err != nil {
			return nil, fmt.Errorf("failed to get settings: %w", err)
		}
		b.settings = s
	}

	settingsMgr := s.(gonetworkmanager.Settings)
	connections, err := settingsMgr.ListConnections()
	if err != nil {
		return nil, fmt.Errorf("failed to get connections: %w", err)
	}

	var targetConn gonetworkmanager.Connection
	for _, conn := range connections {
		connSettings, err := conn.GetSettings()
		if err != nil {
			continue
		}

		if connMeta, ok := connSettings["connection"]; ok {
			if connType, ok := connMeta["type"].(string); ok && (connType == "gsm" || connType == "cdma") {
				if connUUID, ok := connMeta["uuid"].(string); ok && connUUID == uuid {
					targetConn = conn
					break
				}
			}
		}
	}

	if targetConn == nil {
		return nil, fmt.Errorf("cellular connection with UUID %s not found", uuid)
	}

	var ipv4Config CellularIPConfig
	var ipv6Config CellularIPConfig

	// Find active connection to get IP info
	activeConns, err := b.getActiveConnections()
	if err == nil && activeConns[uuid] {
		// Look for the active connection with this UUID
		nm := b.nmConn.(gonetworkmanager.NetworkManager)
		activeConnections, _ := nm.GetPropertyActiveConnections()
		for _, activeConn := range activeConnections {
			conn, _ := activeConn.GetPropertyConnection()
			if conn == nil {
				continue
			}
			connSettings, _ := conn.GetSettings()
			if connMeta, ok := connSettings["connection"]; ok {
				if connUUID, ok := connMeta["uuid"].(string); ok && connUUID == uuid {
					// Found active connection, get IP config
					ip4Config, err := activeConn.GetPropertyIP4Config()
					if err == nil && ip4Config != nil {
						var ips []string
						addresses, err := ip4Config.GetPropertyAddressData()
						if err == nil && len(addresses) > 0 {
							for _, addr := range addresses {
								ips = append(ips, fmt.Sprintf("%s/%s", addr.Address, strconv.Itoa(int(addr.Prefix))))
							}
						}

						gateway, _ := ip4Config.GetPropertyGateway()
						dnsAddrs := ""
						dns, err := ip4Config.GetPropertyNameserverData()
						if err == nil && len(dns) > 0 {
							for _, d := range dns {
								if len(dnsAddrs) > 0 {
									dnsAddrs = strings.Join([]string{dnsAddrs, d.Address}, "; ")
								} else {
									dnsAddrs = d.Address
								}
							}
						}

						ipv4Config = CellularIPConfig{
							IPs:     ips,
							Gateway: gateway,
							DNS:     dnsAddrs,
						}
					}

					ip6Config, err := activeConn.GetPropertyIP6Config()
					if err == nil && ip6Config != nil {
						var ips []string
						addresses, err := ip6Config.GetPropertyAddressData()
						if err == nil && len(addresses) > 0 {
							for _, addr := range addresses {
								ips = append(ips, fmt.Sprintf("%s/%s", addr.Address, strconv.Itoa(int(addr.Prefix))))
							}
						}

						gateway, _ := ip6Config.GetPropertyGateway()
						dnsAddrs := ""
						dns, err := ip6Config.GetPropertyNameservers()
						if err == nil && len(dns) > 0 {
							for _, d := range dns {
								if len(d) == 16 {
									ip := net.IP(d)
									if len(dnsAddrs) > 0 {
										dnsAddrs = strings.Join([]string{dnsAddrs, ip.String()}, "; ")
									} else {
										dnsAddrs = ip.String()
									}
								}
							}
						}

						ipv6Config = CellularIPConfig{
							IPs:     ips,
							Gateway: gateway,
							DNS:     dnsAddrs,
						}
					}
					break
				}
			}
		}
	}

	return &CellularNetworkInfoResponse{
		UUID:       uuid,
		IFace:      dev.Name,
		HwAddr:     dev.HwAddress,
		IMEI:       dev.IMEI,
		Operator:   dev.Operator,
		Technology: dev.Technology,
		Signal:     dev.Signal,
		IPv4:       ipv4Config,
		IPv6:       ipv6Config,
	}, nil
}

func (b *NetworkManagerBackend) ConnectCellular(uuid string) error {
	b.stateMutex.RLock()
	devices := b.state.CellularDevices
	b.stateMutex.RUnlock()

	if len(devices) == 0 {
		return fmt.Errorf("no cellular device available")
	}

	nm := b.nmConn.(gonetworkmanager.NetworkManager)

	s := b.settings
	if s == nil {
		var err error
		s, err = gonetworkmanager.NewSettings()
		if err != nil {
			return fmt.Errorf("failed to get settings: %w", err)
		}
		b.settings = s
	}

	settingsMgr := s.(gonetworkmanager.Settings)
	connections, err := settingsMgr.ListConnections()
	if err != nil {
		return fmt.Errorf("failed to get connections: %w", err)
	}

	var targetConn gonetworkmanager.Connection
	for _, conn := range connections {
		connSettings, err := conn.GetSettings()
		if err != nil {
			continue
		}

		if connMeta, ok := connSettings["connection"]; ok {
			if connUUID, ok := connMeta["uuid"].(string); ok && connUUID == uuid {
				targetConn = conn
				break
			}
		}
	}

	if targetConn == nil {
		return fmt.Errorf("connection with UUID %s not found", uuid)
	}

	// Find the cellular device to activate on
	devicesList, err := nm.GetDevices()
	if err != nil {
		return fmt.Errorf("failed to get devices: %w", err)
	}

	var targetDevice gonetworkmanager.Device
	for _, dev := range devicesList {
		devType, err := dev.GetPropertyDeviceType()
		if err != nil {
			continue
		}
		// NmDeviceTypeModem = 8
		if devType == 8 {
			targetDevice = dev
			break
		}
	}

	if targetDevice == nil {
		return fmt.Errorf("no modem device available")
	}

	_, err = nm.ActivateConnection(targetConn, targetDevice, nil)
	if err != nil {
		return fmt.Errorf("failed to activate cellular connection: %w", err)
	}

	b.updateCellularState()
	b.listCellularConnections()
	b.updatePrimaryConnection()

	if b.onStateChange != nil {
		b.onStateChange()
	}

	return nil
}

func (b *NetworkManagerBackend) DisconnectCellular() error {
	b.stateMutex.RLock()
	devices := b.state.CellularDevices
	b.stateMutex.RUnlock()

	if len(devices) == 0 {
		return fmt.Errorf("no cellular device available")
	}

	nm := b.nmConn.(gonetworkmanager.NetworkManager)
	activeConnections, err := nm.GetPropertyActiveConnections()
	if err != nil {
		return fmt.Errorf("failed to get active connections: %w", err)
	}

	for _, activeConn := range activeConnections {
		conn, err := activeConn.GetPropertyConnection()
		if err != nil || conn == nil {
			continue
		}

		connSettings, err := conn.GetSettings()
		if err != nil {
			continue
		}

		if connMeta, ok := connSettings["connection"]; ok {
			if connType, ok := connMeta["type"].(string); ok && (connType == "gsm" || connType == "cdma") {
				err := nm.DeactivateConnection(activeConn)
				if err != nil {
					return fmt.Errorf("failed to deactivate cellular connection: %w", err)
				}
				break
			}
		}
	}

	b.updateCellularState()
	b.listCellularConnections()
	b.updatePrimaryConnection()

	if b.onStateChange != nil {
		b.onStateChange()
	}

	return nil
}

func (b *NetworkManagerBackend) DisconnectCellularDevice(device string) error {
	return b.DisconnectCellular()
}

func (b *NetworkManagerBackend) ActivateCellularConnection(uuid string) error {
	return b.ConnectCellular(uuid)
}

func (b *NetworkManagerBackend) ListCellularProfiles() ([]CellularProfile, error) {
	s := b.settings
	if s == nil {
		var err error
		s, err = gonetworkmanager.NewSettings()
		if err != nil {
			return nil, fmt.Errorf("failed to get settings: %w", err)
		}
		b.settings = s
	}

	settingsMgr := s.(gonetworkmanager.Settings)
	connections, err := settingsMgr.ListConnections()
	if err != nil {
		return nil, fmt.Errorf("failed to get connections: %w", err)
	}

	profiles := make([]CellularProfile, 0)
	activeUUIDs, err := b.getActiveConnections()
	if err != nil {
		activeUUIDs = make(map[string]bool)
	}

	for _, conn := range connections {
		settings, err := conn.GetSettings()
		if err != nil {
			continue
		}

		connMeta, ok := settings["connection"]
		if !ok {
			continue
		}

		connType, _ := connMeta["type"].(string)
		if connType != "gsm" && connType != "cdma" {
			continue
		}

		connID, _ := connMeta["id"].(string)
		connUUID, _ := connMeta["uuid"].(string)

		autoconnect := true
		if ac, ok := connMeta["autoconnect"].(bool); ok {
			autoconnect = ac
		}

		apn := ""
		if gsmSettings, ok := settings["gsm"]; ok {
			if apnVal, ok := gsmSettings["apn"].(string); ok {
				apn = apnVal
			}
		}

		profile := CellularProfile{
			UUID:        connUUID,
			Name:        connID,
			APN:         apn,
			Autoconnect: autoconnect,
		}

		// Only show username if saved
		if gsmSettings, ok := settings["gsm"]; ok {
			if username, ok := gsmSettings["username"].(string); ok && username != "" {
				profile.Username = username
			}
		}

		profiles = append(profiles, profile)
		_ = activeUUIDs[connUUID] // Mark as seen
	}

	return profiles, nil
}

func (b *NetworkManagerBackend) ListActiveCellular() ([]CellularActive, error) {
	nm := b.nmConn.(gonetworkmanager.NetworkManager)
	activeConnections, err := nm.GetPropertyActiveConnections()
	if err != nil {
		return nil, fmt.Errorf("failed to get active connections: %w", err)
	}

	active := make([]CellularActive, 0)

	for _, activeConn := range activeConnections {
		conn, err := activeConn.GetPropertyConnection()
		if err != nil || conn == nil {
			continue
		}

		connSettings, err := conn.GetSettings()
		if err != nil {
			continue
		}

		connMeta, ok := connSettings["connection"]
		if !ok {
			continue
		}

		connType, _ := connMeta["type"].(string)
		if connType != "gsm" && connType != "cdma" {
			continue
		}

		connID, _ := connMeta["id"].(string)
		connUUID, _ := connMeta["uuid"].(string)

		state, _ := activeConn.GetPropertyState()
		stateStr := "unknown"
		switch state {
		case gonetworkmanager.NmActiveConnectionStateActivating:
			stateStr = "activating"
		case gonetworkmanager.NmActiveConnectionStateActivated:
			stateStr = "activated"
		case gonetworkmanager.NmActiveConnectionStateDeactivating:
			stateStr = "deactivating"
		case gonetworkmanager.NmActiveConnectionStateDeactivated:
			stateStr = "deactivated"
		}

		ipConfig, _ := activeConn.GetPropertyIP4Config()
		ip := ""
		if ipConfig != nil {
			addresses, _ := ipConfig.GetPropertyAddressData()
			if len(addresses) > 0 {
				ip = addresses[0].Address
			}
		}

		// Get device for this connection to match with ModemManager
		deviceName := ""
		if dev, err := activeConn.GetPropertyDevices(); err == nil && len(dev) > 0 {
			deviceName, _ = dev[0].GetPropertyInterface()
		}

		// Fetch cellular details from ModemManager
		operator, technology, signal := b.getModemManagerCellularDetails(deviceName)

		active = append(active, CellularActive{
			Name:       connID,
			UUID:       connUUID,
			State:      stateStr,
			IP:         ip,
			Device:     deviceName,
			Operator:   operator,
			Technology: technology,
			Signal:     signal,
		})
	}

	return active, nil
}

func (b *NetworkManagerBackend) GetCellularProfile(uuidOrName string) (*CellularProfile, error) {
	profiles, err := b.ListCellularProfiles()
	if err != nil {
		return nil, err
	}

	for _, profile := range profiles {
		if profile.UUID == uuidOrName || profile.Name == uuidOrName {
			return &profile, nil
		}
	}

	return nil, fmt.Errorf("cellular profile not found: %s", uuidOrName)
}

func (b *NetworkManagerBackend) UpdateCellularProfile(uuid string, updates map[string]any) error {
	s := b.settings
	if s == nil {
		var err error
		s, err = gonetworkmanager.NewSettings()
		if err != nil {
			return fmt.Errorf("failed to get settings: %w", err)
		}
		b.settings = s
	}

	settingsMgr := s.(gonetworkmanager.Settings)
	connections, err := settingsMgr.ListConnections()
	if err != nil {
		return fmt.Errorf("failed to get connections: %w", err)
	}

	for _, conn := range connections {
		settings, err := conn.GetSettings()
		if err != nil {
			continue
		}

		connMeta, ok := settings["connection"]
		if !ok {
			continue
		}

		connType, _ := connMeta["type"].(string)
		if connType != "gsm" && connType != "cdma" {
			continue
		}

		existingUUID, _ := connMeta["uuid"].(string)
		if existingUUID != uuid {
			continue
		}

		if name, ok := updates["name"].(string); ok && name != "" {
			connMeta["id"] = name
		}

		if autoconnect, ok := updates["autoconnect"].(bool); ok {
			connMeta["autoconnect"] = autoconnect
		}

		if apn, ok := updates["apn"].(string); ok && apn != "" {
			if gsmSettings, ok := settings["gsm"]; ok {
				gsmSettings["apn"] = apn
			}
		}

		if username, ok := updates["username"].(string); ok {
			if gsmSettings, ok := settings["gsm"]; ok {
				gsmSettings["username"] = username
			}
		}

		if password, ok := updates["password"].(string); ok && password != "" {
			if gsmSettings, ok := settings["gsm"]; ok {
				gsmSettings["password"] = password
			}
		}

		if ipv4, ok := settings["ipv4"]; ok {
			delete(ipv4, "addresses")
			delete(ipv4, "routes")
			delete(ipv4, "dns")
		}
		if ipv6, ok := settings["ipv6"]; ok {
			delete(ipv6, "addresses")
			delete(ipv6, "routes")
			delete(ipv6, "dns")
		}

		if err := conn.Update(settings); err != nil {
			return fmt.Errorf("failed to update connection: %w", err)
		}

		b.ListCellularProfiles()

		if b.onStateChange != nil {
			b.onStateChange()
		}

		return nil
	}

	return fmt.Errorf("cellular connection not found: %s", uuid)
}

func (b *NetworkManagerBackend) listCellularConnections() ([]CellularConnection, error) {
	s := b.settings
	if s == nil {
		var err error
		s, err = gonetworkmanager.NewSettings()
		if err != nil {
			return nil, fmt.Errorf("failed to get settings: %w", err)
		}
		b.settings = s
	}

	settingsMgr := s.(gonetworkmanager.Settings)
	connections, err := settingsMgr.ListConnections()
	if err != nil {
		return nil, fmt.Errorf("failed to get connections: %w", err)
	}

	cellularConns := make([]CellularConnection, 0)
	activeUUIDs, err := b.getActiveConnections()
	if err != nil {
		activeUUIDs = make(map[string]bool)
	}

	for _, connection := range connections {
		path := connection.GetPath()
		settings, err := connection.GetSettings()
		if err != nil {
			log.Errorf("unable to get settings for %s: %v", path, err)
			continue
		}

		connectionSettings := settings["connection"]
		connType, _ := connectionSettings["type"].(string)
		connID, _ := connectionSettings["id"].(string)
		connUUID, _ := connectionSettings["uuid"].(string)

		if connType == "gsm" || connType == "cdma" {
			apn := ""
			if gsmSettings, ok := settings["gsm"]; ok {
				if apnVal, ok := gsmSettings["apn"].(string); ok {
					apn = apnVal
				}
			}

			cellularConns = append(cellularConns, CellularConnection{
				Path:     path,
				ID:       connID,
				UUID:     connUUID,
				Type:     connType,
				IsActive: activeUUIDs[connUUID],
				APN:      apn,
			})
		}
	}

	b.stateMutex.Lock()
	b.state.CellularConnections = cellularConns
	b.stateMutex.Unlock()

	return cellularConns, nil
}

func (b *NetworkManagerBackend) GetSIMStatus(device string) (*CellularDevice, error) {
	devices, err := b.getModemDevices()
	if err != nil {
		return nil, err
	}

	if len(devices) == 0 {
		return nil, fmt.Errorf("no cellular devices found")
	}

	// Return first device when no specific device is requested
	if device == "" {
		return &devices[0], nil
	}

	for _, dev := range devices {
		if dev.Name == device || dev.IMEI == device {
			return &dev, nil
		}
	}

	return nil, fmt.Errorf("cellular device not found: %s", device)
}

func (b *NetworkManagerBackend) SubmitSIMPin(device string, pin string) error {
	// TODO: For actual SIM unlock, use ModemManager D-Bus:
	// org.freedesktop.ModemManager1.Sim.SendPin(pin)
	// Current approach stores PIN in connection settings for auto-unlock on activation
	s := b.settings
	if s == nil {
		var err error
		s, err = gonetworkmanager.NewSettings()
		if err != nil {
			return fmt.Errorf("failed to get settings: %w", err)
		}
		b.settings = s
	}

	settingsMgr := s.(gonetworkmanager.Settings)
	connections, err := settingsMgr.ListConnections()
	if err != nil {
		return fmt.Errorf("failed to get connections: %w", err)
	}

	// Find the first GSM connection and update it with the PIN
	for _, conn := range connections {
		connSettings, err := conn.GetSettings()
		if err != nil {
			continue
		}

		if connMeta, ok := connSettings["connection"]; ok {
			if connType, ok := connMeta["type"].(string); ok && (connType == "gsm" || connType == "cdma") {
				// Update GSM settings with PIN
				if gsmSettings, ok := connSettings["gsm"]; ok {
					gsmSettings["pin"] = pin
				} else {
					connSettings["gsm"] = map[string]any{
						"pin": pin,
					}
				}

				if err := conn.Update(connSettings); err != nil {
					return fmt.Errorf("failed to update connection with PIN: %w", err)
				}

				// Try to activate the connection
				return b.ConnectCellular(connMeta["uuid"].(string))
			}
		}
	}

	return fmt.Errorf("no cellular connection found to submit PIN")
}

func (b *NetworkManagerBackend) GetSIMPinTriesLeft(device string) (int, error) {
	// TODO: Query ModemManager D-Bus for real PIN retry count:
	// org.freedesktop.ModemManager1.Sim → RetriesLeft property
	return 3, nil
}

func (b *NetworkManagerBackend) getModemDevices() ([]CellularDevice, error) {
	return b.GetCellularDevices(), nil
}

func (b *NetworkManagerBackend) updateCellularState() {
	nm := b.nmConn.(gonetworkmanager.NetworkManager)

	// Check WWAN enabled
	wwanEnabled, _ := nm.GetPropertyWwanEnabled()

	// Get all devices
	devices, err := nm.GetDevices()
	if err != nil {
		return
	}

	cellularDevices := make([]CellularDevice, 0)
	var connectedDevice *CellularDevice

	for _, dev := range devices {
		devType, err := dev.GetPropertyDeviceType()
		if err != nil {
			continue
		}

		// NmDeviceTypeModem = 8
		if devType != 8 {
			continue
		}

		name, _ := dev.GetPropertyInterface()
		driver, _ := dev.GetPropertyDriver()
		state, _ := dev.GetPropertyState()
		ipConfig, _ := dev.GetPropertyIP4Config()

		stateStr := "unknown"
		connected := false
		switch state {
		case gonetworkmanager.NmDeviceStateUnknown:
			stateStr = "unknown"
		case gonetworkmanager.NmDeviceStateUnmanaged:
			stateStr = "unmanaged"
		case gonetworkmanager.NmDeviceStateUnavailable:
			stateStr = "unavailable"
		case gonetworkmanager.NmDeviceStateDisconnected:
			stateStr = "disconnected"
		case gonetworkmanager.NmDeviceStatePrepare:
			stateStr = "prepare"
		case gonetworkmanager.NmDeviceStateConfig:
			stateStr = "config"
		case gonetworkmanager.NmDeviceStateNeedAuth:
			stateStr = "need-auth"
		case gonetworkmanager.NmDeviceStateIpConfig:
			stateStr = "ip-config"
		case gonetworkmanager.NmDeviceStateIpCheck:
			stateStr = "ip-check"
		case gonetworkmanager.NmDeviceStateSecondaries:
			stateStr = "secondaries"
		case gonetworkmanager.NmDeviceStateActivated:
			stateStr = "activated"
			connected = true
		case gonetworkmanager.NmDeviceStateDeactivating:
			stateStr = "deactivating"
		case gonetworkmanager.NmDeviceStateFailed:
			stateStr = "failed"
		}

		ip := ""
		if ipConfig != nil {
			addresses, _ := ipConfig.GetPropertyAddressData()
			if len(addresses) > 0 {
				ip = addresses[0].Address
			}
		}

		// Try to get modem-specific info via ModemManager
		operator, technology, signal := b.getModemManagerCellularDetails(name)

		cellDev := CellularDevice{
			Name:       name,
			HwAddress:  driver, // Using driver as placeholder
			State:      stateStr,
			Connected:  connected,
			IP:         ip,
			Operator:   operator,
			Technology: technology,
			Signal:     signal,
		}

		cellularDevices = append(cellularDevices, cellDev)

		if connected {
			connectedDevice = &cellDev
		}
	}

	b.stateMutex.Lock()
	b.state.CellularEnabled = wwanEnabled
	b.state.CellularDevices = cellularDevices
	if connectedDevice != nil {
		b.state.CellularConnected = true
		b.state.CellularDevice = connectedDevice.Name
		b.state.CellularIP = connectedDevice.IP
		b.state.CellularOperator = connectedDevice.Operator
		b.state.CellularTechnology = connectedDevice.Technology
		b.state.CellularSignal = connectedDevice.Signal
	} else {
		b.state.CellularConnected = false
		b.state.CellularDevice = ""
		b.state.CellularIP = ""
		b.state.CellularOperator = ""
		b.state.CellularTechnology = ""
		b.state.CellularSignal = 0
	}
	b.stateMutex.Unlock()
}
