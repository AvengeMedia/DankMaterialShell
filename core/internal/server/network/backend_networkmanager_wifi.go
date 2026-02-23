package network

import (
	"bytes"
	"fmt"
	"sort"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/Wifx/gonetworkmanager/v2"
)

func (b *NetworkManagerBackend) GetWiFiEnabled() (bool, error) {
	nm := b.nmConn.(gonetworkmanager.NetworkManager)
	return nm.GetPropertyWirelessEnabled()
}

func (b *NetworkManagerBackend) SetWiFiEnabled(enabled bool) error {
	nm := b.nmConn.(gonetworkmanager.NetworkManager)
	err := nm.SetPropertyWirelessEnabled(enabled)
	if err != nil {
		return fmt.Errorf("failed to set WiFi enabled: %w", err)
	}

	b.stateMutex.Lock()
	b.state.WiFiEnabled = enabled
	b.stateMutex.Unlock()

	if b.onStateChange != nil {
		b.onStateChange()
	}

	return nil
}

func (b *NetworkManagerBackend) ScanWiFi() error {
	if b.wifiDevice == nil {
		return fmt.Errorf("no WiFi device available")
	}

	b.stateMutex.RLock()
	enabled := b.state.WiFiEnabled
	b.stateMutex.RUnlock()

	if !enabled {
		return fmt.Errorf("WiFi is disabled")
	}

	if err := b.ensureWiFiDevice(); err != nil {
		return err
	}

	w := b.wifiDev.(gonetworkmanager.DeviceWireless)
	err := w.RequestScan()
	if err != nil {
		return fmt.Errorf("scan request failed: %w", err)
	}

	_, err = b.updateWiFiNetworks()
	return err
}

func (b *NetworkManagerBackend) GetWiFiNetworkDetails(ssid string) (*NetworkInfoResponse, error) {
	if b.wifiDevice == nil {
		return nil, fmt.Errorf("no WiFi device available")
	}

	if err := b.ensureWiFiDevice(); err != nil {
		return nil, err
	}
	wifiDev := b.wifiDev

	w := wifiDev.(gonetworkmanager.DeviceWireless)
	apPaths, err := w.GetAccessPoints()
	if err != nil {
		return nil, fmt.Errorf("failed to get access points: %w", err)
	}

	s := b.settings
	if s == nil {
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

	savedSSIDs := make(map[string]bool)
	autoconnectMap := make(map[string]bool)
	for _, conn := range connections {
		connSettings, err := conn.GetSettings()
		if err != nil {
			continue
		}

		if connMeta, ok := connSettings["connection"]; ok {
			if connType, ok := connMeta["type"].(string); ok && connType == "802-11-wireless" {
				if wifiSettings, ok := connSettings["802-11-wireless"]; ok {
					if ssidBytes, ok := wifiSettings["ssid"].([]byte); ok {
						savedSSID := string(ssidBytes)
						savedSSIDs[savedSSID] = true
						autoconnect := true
						if ac, ok := connMeta["autoconnect"].(bool); ok {
							autoconnect = ac
						}
						autoconnectMap[savedSSID] = autoconnect
					}
				}
			}
		}
	}

	b.stateMutex.RLock()
	currentSSID := b.state.WiFiSSID
	currentBSSID := b.state.WiFiBSSID
	b.stateMutex.RUnlock()

	var bands []WiFiNetwork

	for _, ap := range apPaths {
		apSSID, err := ap.GetPropertySSID()
		if err != nil || apSSID != ssid {
			continue
		}

		strength, _ := ap.GetPropertyStrength()
		flags, _ := ap.GetPropertyFlags()
		wpaFlags, _ := ap.GetPropertyWPAFlags()
		rsnFlags, _ := ap.GetPropertyRSNFlags()
		freq, _ := ap.GetPropertyFrequency()
		maxBitrate, _ := ap.GetPropertyMaxBitrate()
		bssid, _ := ap.GetPropertyHWAddress()
		mode, _ := ap.GetPropertyMode()

		secured := flags != uint32(gonetworkmanager.Nm80211APFlagsNone) ||
			wpaFlags != uint32(gonetworkmanager.Nm80211APSecNone) ||
			rsnFlags != uint32(gonetworkmanager.Nm80211APSecNone)

		enterprise := (rsnFlags&uint32(gonetworkmanager.Nm80211APSecKeyMgmt8021X) != 0) ||
			(wpaFlags&uint32(gonetworkmanager.Nm80211APSecKeyMgmt8021X) != 0)

		var modeStr string
		switch mode {
		case gonetworkmanager.Nm80211ModeAdhoc:
			modeStr = "adhoc"
		case gonetworkmanager.Nm80211ModeInfra:
			modeStr = "infrastructure"
		case gonetworkmanager.Nm80211ModeAp:
			modeStr = "ap"
		default:
			modeStr = "unknown"
		}

		channel := frequencyToChannel(freq)

		network := WiFiNetwork{
			SSID:        ssid,
			BSSID:       bssid,
			Signal:      strength,
			Secured:     secured,
			Enterprise:  enterprise,
			Connected:   ssid == currentSSID && bssid == currentBSSID,
			Saved:       savedSSIDs[ssid],
			Autoconnect: autoconnectMap[ssid],
			Frequency:   freq,
			Mode:        modeStr,
			Rate:        maxBitrate / 1000,
			Channel:     channel,
		}

		bands = append(bands, network)
	}

	if len(bands) == 0 {
		return nil, fmt.Errorf("network not found: %s", ssid)
	}

	sort.Slice(bands, func(i, j int) bool {
		if bands[i].Connected && !bands[j].Connected {
			return true
		}
		if !bands[i].Connected && bands[j].Connected {
			return false
		}
		return bands[i].Signal > bands[j].Signal
	})

	return &NetworkInfoResponse{
		SSID:  ssid,
		Bands: bands,
	}, nil
}

func (b *NetworkManagerBackend) GetWiFiQRCodeContent(ssid string) (string, error) {
	conn, err := b.findConnection(ssid)
	if err != nil {
		return "", fmt.Errorf("no saved connection for `%s`: %w", ssid, err)
	}

	connSettings, err := conn.GetSettings()
	if err != nil {
		return "", fmt.Errorf("failed to get settings for `%s`: %w", ssid, err)
	}

	secSettings, ok := connSettings["802-11-wireless-security"]
	if !ok {
		return "", fmt.Errorf("network `%s` has no security settings", ssid)
	}

	keyMgmt, ok := secSettings["key-mgmt"].(string)
	if !ok {
		return "", fmt.Errorf("failed to identify security type of network `%s`", ssid)
	}

	var securityType string
	switch keyMgmt {
	case "none":
		authAlg, _ := secSettings["auth-alg"].(string)
		switch authAlg {
		case "open":
			securityType = "nopass"
		default:
			securityType = "WEP"
		}
	case "ieee8021x":
		securityType = "WEP"
	default:
		securityType = "WPA"
	}

	if securityType != "WPA" {
		return "", fmt.Errorf("QR code generation only supports WPA connections, `%s` uses %s", ssid, securityType)
	}

	secrets, err := conn.GetSecrets("802-11-wireless-security")
	if err != nil {
		return "", fmt.Errorf("failed to retrieve connection secrets for `%s`: %w", ssid, err)
	}

	secSecrets, ok := secrets["802-11-wireless-security"]
	if !ok {
		return "", fmt.Errorf("failed to retrieve password for `%s`", ssid)
	}

	psk, ok := secSecrets["psk"].(string)
	if !ok {
		return "", fmt.Errorf("failed to retrieve password for `%s`", ssid)
	}

	return FormatWiFiQRString(securityType, ssid, psk), nil
}

func (b *NetworkManagerBackend) ConnectWiFi(req ConnectionRequest) error {
	devInfo, err := b.getWifiDeviceForConnection(req.Device)
	if err != nil {
		return err
	}

	b.stateMutex.RLock()
	alreadyConnected := b.state.WiFiConnected && b.state.WiFiSSID == req.SSID
	b.stateMutex.RUnlock()

	if alreadyConnected && !req.Interactive && req.Device == "" {
		return nil
	}

	b.stateMutex.Lock()
	b.state.IsConnecting = true
	b.state.ConnectingSSID = req.SSID
	b.state.ConnectingDevice = req.Device
	b.state.LastError = ""
	b.stateMutex.Unlock()

	if b.onStateChange != nil {
		b.onStateChange()
	}

	nm := b.nmConn.(gonetworkmanager.NetworkManager)

	existingConn, err := b.findConnection(req.SSID)
	if err == nil && existingConn != nil {
		_, err := nm.ActivateConnection(existingConn, devInfo.device, nil)
		if err != nil {
			log.Warnf("[ConnectWiFi] Failed to activate existing connection: %v", err)
			b.stateMutex.Lock()
			b.state.IsConnecting = false
			b.state.ConnectingSSID = ""
			b.state.ConnectingDevice = ""
			b.state.LastError = fmt.Sprintf("failed to activate connection: %v", err)
			b.stateMutex.Unlock()
			if b.onStateChange != nil {
				b.onStateChange()
			}
			return fmt.Errorf("failed to activate connection: %w", err)
		}

		return nil
	}

	if err := b.createAndConnectWiFiOnDevice(req, devInfo); err != nil {
		log.Warnf("[ConnectWiFi] Failed to create and connect: %v", err)
		b.stateMutex.Lock()
		b.state.IsConnecting = false
		b.state.ConnectingSSID = ""
		b.state.ConnectingDevice = ""
		b.state.LastError = err.Error()
		b.stateMutex.Unlock()
		if b.onStateChange != nil {
			b.onStateChange()
		}
		return err
	}

	return nil
}

func (b *NetworkManagerBackend) DisconnectWiFi() error {
	if b.wifiDevice == nil {
		return fmt.Errorf("no WiFi device available")
	}

	dev := b.wifiDevice.(gonetworkmanager.Device)

	err := dev.Disconnect()
	if err != nil {
		return fmt.Errorf("failed to disconnect: %w", err)
	}

	b.updateWiFiState()
	b.updatePrimaryConnection()

	if b.onStateChange != nil {
		b.onStateChange()
	}

	return nil
}

func (b *NetworkManagerBackend) ForgetWiFiNetwork(ssid string) error {
	conn, err := b.findConnection(ssid)
	if err != nil {
		return fmt.Errorf("connection not found: %w", err)
	}

	b.stateMutex.RLock()
	currentSSID := b.state.WiFiSSID
	isConnected := b.state.WiFiConnected
	b.stateMutex.RUnlock()

	err = conn.Delete()
	if err != nil {
		return fmt.Errorf("failed to delete connection: %w", err)
	}

	if isConnected && currentSSID == ssid {
		b.stateMutex.Lock()
		b.state.WiFiConnected = false
		b.state.WiFiSSID = ""
		b.state.WiFiBSSID = ""
		b.state.WiFiSignal = 0
		b.state.WiFiIP = ""
		b.state.NetworkStatus = StatusDisconnected
		b.stateMutex.Unlock()
	}

	b.updateWiFiNetworks()

	if b.onStateChange != nil {
		b.onStateChange()
	}

	return nil
}

func (b *NetworkManagerBackend) IsConnectingTo(ssid string) bool {
	b.stateMutex.RLock()
	defer b.stateMutex.RUnlock()
	return b.state.IsConnecting && b.state.ConnectingSSID == ssid
}

func (b *NetworkManagerBackend) updateWiFiNetworks() ([]WiFiNetwork, error) {
	if b.wifiDevice == nil {
		return nil, fmt.Errorf("no WiFi device available")
	}

	if err := b.ensureWiFiDevice(); err != nil {
		return nil, err
	}
	wifiDev := b.wifiDev

	w := wifiDev.(gonetworkmanager.DeviceWireless)
	apPaths, err := w.GetAccessPoints()
	if err != nil {
		return nil, fmt.Errorf("failed to get access points: %w", err)
	}

	s := b.settings
	if s == nil {
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

	savedSSIDs := make(map[string]bool)
	autoconnectMap := make(map[string]bool)
	hiddenSSIDs := make(map[string]bool)
	for _, conn := range connections {
		connSettings, err := conn.GetSettings()
		if err != nil {
			continue
		}

		connMeta, ok := connSettings["connection"]
		if !ok {
			continue
		}

		connType, ok := connMeta["type"].(string)
		if !ok || connType != "802-11-wireless" {
			continue
		}

		wifiSettings, ok := connSettings["802-11-wireless"]
		if !ok {
			continue
		}

		ssidBytes, ok := wifiSettings["ssid"].([]byte)
		if !ok {
			continue
		}

		ssid := string(ssidBytes)
		savedSSIDs[ssid] = true
		autoconnect := true
		if ac, ok := connMeta["autoconnect"].(bool); ok {
			autoconnect = ac
		}
		autoconnectMap[ssid] = autoconnect

		if hidden, ok := wifiSettings["hidden"].(bool); ok && hidden {
			hiddenSSIDs[ssid] = true
		}
	}

	b.stateMutex.RLock()
	currentSSID := b.state.WiFiSSID
	wifiConnected := b.state.WiFiConnected
	wifiSignal := b.state.WiFiSignal
	wifiBSSID := b.state.WiFiBSSID
	b.stateMutex.RUnlock()

	seenSSIDs := make(map[string]*WiFiNetwork)
	networks := []WiFiNetwork{}

	for _, ap := range apPaths {
		ssid, err := ap.GetPropertySSID()
		if err != nil || ssid == "" {
			continue
		}

		if existing, exists := seenSSIDs[ssid]; exists {
			strength, _ := ap.GetPropertyStrength()
			if strength > existing.Signal {
				existing.Signal = strength
				freq, _ := ap.GetPropertyFrequency()
				existing.Frequency = freq
				bssid, _ := ap.GetPropertyHWAddress()
				existing.BSSID = bssid
			}
			continue
		}

		strength, _ := ap.GetPropertyStrength()
		flags, _ := ap.GetPropertyFlags()
		wpaFlags, _ := ap.GetPropertyWPAFlags()
		rsnFlags, _ := ap.GetPropertyRSNFlags()
		freq, _ := ap.GetPropertyFrequency()
		maxBitrate, _ := ap.GetPropertyMaxBitrate()
		bssid, _ := ap.GetPropertyHWAddress()
		mode, _ := ap.GetPropertyMode()

		secured := flags != uint32(gonetworkmanager.Nm80211APFlagsNone) ||
			wpaFlags != uint32(gonetworkmanager.Nm80211APSecNone) ||
			rsnFlags != uint32(gonetworkmanager.Nm80211APSecNone)

		enterprise := (rsnFlags&uint32(gonetworkmanager.Nm80211APSecKeyMgmt8021X) != 0) ||
			(wpaFlags&uint32(gonetworkmanager.Nm80211APSecKeyMgmt8021X) != 0)

		var modeStr string
		switch mode {
		case gonetworkmanager.Nm80211ModeAdhoc:
			modeStr = "adhoc"
		case gonetworkmanager.Nm80211ModeInfra:
			modeStr = "infrastructure"
		case gonetworkmanager.Nm80211ModeAp:
			modeStr = "ap"
		default:
			modeStr = "unknown"
		}

		channel := frequencyToChannel(freq)

		network := WiFiNetwork{
			SSID:        ssid,
			BSSID:       bssid,
			Signal:      strength,
			Secured:     secured,
			Enterprise:  enterprise,
			Connected:   ssid == currentSSID,
			Saved:       savedSSIDs[ssid],
			Autoconnect: autoconnectMap[ssid],
			Hidden:      hiddenSSIDs[ssid],
			Frequency:   freq,
			Mode:        modeStr,
			Rate:        maxBitrate / 1000,
			Channel:     channel,
		}

		seenSSIDs[ssid] = &network
		networks = append(networks, network)
	}

	if wifiConnected && currentSSID != "" {
		if _, exists := seenSSIDs[currentSSID]; !exists {
			hiddenNetwork := WiFiNetwork{
				SSID:        currentSSID,
				BSSID:       wifiBSSID,
				Signal:      wifiSignal,
				Secured:     true,
				Connected:   true,
				Saved:       savedSSIDs[currentSSID],
				Autoconnect: autoconnectMap[currentSSID],
				Hidden:      true,
				Mode:        "infrastructure",
			}
			networks = append(networks, hiddenNetwork)
		}
	}

	sortWiFiNetworks(networks)

	b.stateMutex.Lock()
	b.state.WiFiNetworks = networks
	b.stateMutex.Unlock()

	return networks, nil
}

func (b *NetworkManagerBackend) findConnection(ssid string) (gonetworkmanager.Connection, error) {
	s := b.settings
	if s == nil {
		var err error
		s, err = gonetworkmanager.NewSettings()
		if err != nil {
			return nil, err
		}
		b.settings = s
	}

	settings := s.(gonetworkmanager.Settings)
	connections, err := settings.ListConnections()
	if err != nil {
		return nil, err
	}

	ssidBytes := []byte(ssid)
	for _, conn := range connections {
		connSettings, err := conn.GetSettings()
		if err != nil {
			continue
		}

		if connMeta, ok := connSettings["connection"]; ok {
			if connType, ok := connMeta["type"].(string); ok && connType == "802-11-wireless" {
				if wifiSettings, ok := connSettings["802-11-wireless"]; ok {
					if candidateSSID, ok := wifiSettings["ssid"].([]byte); ok {
						if bytes.Equal(candidateSSID, ssidBytes) {
							return conn, nil
						}
					}
				}
			}
		}
	}

	return nil, fmt.Errorf("connection not found")
}

func (b *NetworkManagerBackend) createAndConnectWiFi(req ConnectionRequest) error {
	devInfo, err := b.getWifiDeviceForConnection(req.Device)
	if err != nil {
		return err
	}
	return b.createAndConnectWiFiOnDevice(req, devInfo)
}

func (b *NetworkManagerBackend) createAndConnectWiFiOnDevice(req ConnectionRequest, devInfo *wifiDeviceInfo) error {
	nm := b.nmConn.(gonetworkmanager.NetworkManager)
	dev := devInfo.device
	w := devInfo.wireless

	var targetAP gonetworkmanager.AccessPoint
	var flags, wpaFlags, rsnFlags uint32

	if !req.Hidden {
		apPaths, err := w.GetAccessPoints()
		if err != nil {
			return fmt.Errorf("failed to get access points: %w", err)
		}

		for _, ap := range apPaths {
			ssid, err := ap.GetPropertySSID()
			if err != nil || ssid != req.SSID {
				continue
			}
			targetAP = ap
			break
		}

		if targetAP == nil {
			return fmt.Errorf("access point not found: %s", req.SSID)
		}

		flags, _ = targetAP.GetPropertyFlags()
		wpaFlags, _ = targetAP.GetPropertyWPAFlags()
		rsnFlags, _ = targetAP.GetPropertyRSNFlags()
	}

	const KeyMgmt8021x = uint32(512)
	const KeyMgmtPsk = uint32(256)
	const KeyMgmtSae = uint32(1024)

	var isEnterprise, isPsk, isSae, secured bool

	switch {
	case req.Hidden:
		secured = req.Password != "" || req.Username != ""
		isEnterprise = req.Username != ""
		isPsk = req.Password != "" && !isEnterprise
	default:
		isEnterprise = (wpaFlags&KeyMgmt8021x) != 0 || (rsnFlags&KeyMgmt8021x) != 0
		isPsk = (wpaFlags&KeyMgmtPsk) != 0 || (rsnFlags&KeyMgmtPsk) != 0
		isSae = (wpaFlags&KeyMgmtSae) != 0 || (rsnFlags&KeyMgmtSae) != 0
		secured = flags != uint32(gonetworkmanager.Nm80211APFlagsNone) ||
			wpaFlags != uint32(gonetworkmanager.Nm80211APSecNone) ||
			rsnFlags != uint32(gonetworkmanager.Nm80211APSecNone)
	}

	if isEnterprise {
		log.Infof("[createAndConnectWiFi] Enterprise network detected (802.1x) - SSID: %s, interactive: %v",
			req.SSID, req.Interactive)
	}

	settings := make(map[string]map[string]any)

	settings["connection"] = map[string]any{
		"id":          req.SSID,
		"type":        "802-11-wireless",
		"autoconnect": true,
	}

	settings["ipv4"] = map[string]any{"method": "auto"}
	settings["ipv6"] = map[string]any{"method": "auto"}

	if secured {
		wifiSettings := map[string]any{
			"ssid":     []byte(req.SSID),
			"mode":     "infrastructure",
			"security": "802-11-wireless-security",
		}
		if req.Hidden {
			wifiSettings["hidden"] = true
		}
		settings["802-11-wireless"] = wifiSettings

		switch {
		case isEnterprise || req.Username != "":
			settings["802-11-wireless-security"] = map[string]any{
				"key-mgmt": "wpa-eap",
			}

			eapMethod := "peap"
			if req.EAPMethod != "" {
				eapMethod = req.EAPMethod
			}

			phase2Auth := "mschapv2"
			if req.Phase2Auth != "" {
				phase2Auth = req.Phase2Auth
			}

			useSystemCACerts := false
			if req.UseSystemCACerts != nil {
				useSystemCACerts = *req.UseSystemCACerts
			}

			x := map[string]any{
				"eap":             []string{eapMethod},
				"system-ca-certs": useSystemCACerts,
				"password-flags":  uint32(0),
			}

			switch eapMethod {
			case "peap", "ttls":
				x["phase2-auth"] = phase2Auth
			case "tls":
				if req.ClientCertPath != "" {
					x["client-cert"] = []byte("file://" + req.ClientCertPath)
				}
				if req.PrivateKeyPath != "" {
					x["private-key"] = []byte("file://" + req.PrivateKeyPath)
				}
			}

			if req.Username != "" {
				x["identity"] = req.Username
			}
			if req.Password != "" {
				x["password"] = req.Password
			}
			if req.AnonymousIdentity != "" {
				x["anonymous-identity"] = req.AnonymousIdentity
			}
			if req.DomainSuffixMatch != "" {
				x["domain-suffix-match"] = req.DomainSuffixMatch
			}
			if req.CACertPath != "" {
				x["ca-cert"] = []byte("file://" + req.CACertPath)
			}

			settings["802-1x"] = x

			log.Infof("[createAndConnectWiFi] WPA-EAP settings: eap=%s, phase2-auth=%s, identity=%s, interactive=%v, system-ca-certs=%v, domain-suffix-match=%q",
				eapMethod, phase2Auth, req.Username, req.Interactive, useSystemCACerts, req.DomainSuffixMatch)

		case isPsk:
			sec := map[string]any{
				"key-mgmt":  "wpa-psk",
				"psk-flags": uint32(0),
			}
			if !req.Interactive {
				sec["psk"] = req.Password
			}
			settings["802-11-wireless-security"] = sec

		case isSae:
			sec := map[string]any{
				"key-mgmt":  "sae",
				"pmf":       int32(3),
				"psk-flags": uint32(0),
			}
			if !req.Interactive {
				sec["psk"] = req.Password
			}
			settings["802-11-wireless-security"] = sec

		default:
			return fmt.Errorf("secured network but not SAE/PSK/802.1X (rsn=0x%x wpa=0x%x)", rsnFlags, wpaFlags)
		}
	} else {
		wifiSettings := map[string]any{
			"ssid": []byte(req.SSID),
			"mode": "infrastructure",
		}
		if req.Hidden {
			wifiSettings["hidden"] = true
		}
		settings["802-11-wireless"] = wifiSettings
	}

	if req.Interactive {
		s := b.settings
		if s == nil {
			var settingsErr error
			s, settingsErr = gonetworkmanager.NewSettings()
			if settingsErr != nil {
				return fmt.Errorf("failed to get settings manager: %w", settingsErr)
			}
			b.settings = s
		}

		settingsMgr := s.(gonetworkmanager.Settings)
		conn, err := settingsMgr.AddConnection(settings)
		if err != nil {
			return fmt.Errorf("failed to add connection: %w", err)
		}

		if isEnterprise {
			log.Infof("[createAndConnectWiFi] Enterprise connection added, activating (secret agent will be called)")
		}

		if req.Hidden {
			_, err = nm.ActivateConnection(conn, dev, nil)
		} else {
			_, err = nm.ActivateWirelessConnection(conn, dev, targetAP)
		}
		if err != nil {
			return fmt.Errorf("failed to activate connection: %w", err)
		}

		log.Infof("[createAndConnectWiFi] Connection activation initiated, waiting for NetworkManager state changes...")
	} else {
		var err error
		if req.Hidden {
			_, err = nm.AddAndActivateConnection(settings, dev)
		} else {
			_, err = nm.AddAndActivateWirelessConnection(settings, dev, targetAP)
		}
		if err != nil {
			return fmt.Errorf("failed to connect: %w", err)
		}
		log.Infof("[createAndConnectWiFi] Connection activation initiated, waiting for NetworkManager state changes...")
	}

	return nil
}

func (b *NetworkManagerBackend) SetWiFiAutoconnect(ssid string, autoconnect bool) error {
	conn, err := b.findConnection(ssid)
	if err != nil {
		return fmt.Errorf("connection not found: %w", err)
	}

	settings, err := conn.GetSettings()
	if err != nil {
		return fmt.Errorf("failed to get connection settings: %w", err)
	}

	if connMeta, ok := settings["connection"]; ok {
		connMeta["autoconnect"] = autoconnect
	} else {
		return fmt.Errorf("connection metadata not found")
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

	err = conn.Update(settings)
	if err != nil {
		return fmt.Errorf("failed to update connection: %w", err)
	}

	b.updateWiFiNetworks()

	if b.onStateChange != nil {
		b.onStateChange()
	}

	return nil
}

func (b *NetworkManagerBackend) ScanWiFiDevice(device string) error {
	devInfo, ok := b.wifiDevices[device]
	if !ok {
		return fmt.Errorf("WiFi device not found: %s", device)
	}

	b.stateMutex.RLock()
	enabled := b.state.WiFiEnabled
	b.stateMutex.RUnlock()

	if !enabled {
		return fmt.Errorf("WiFi is disabled")
	}

	if err := devInfo.wireless.RequestScan(); err != nil {
		return fmt.Errorf("scan request failed: %w", err)
	}

	b.updateAllWiFiDevices()
	return nil
}

func (b *NetworkManagerBackend) DisconnectWiFiDevice(device string) error {
	devInfo, ok := b.wifiDevices[device]
	if !ok {
		return fmt.Errorf("WiFi device not found: %s", device)
	}

	if err := devInfo.device.Disconnect(); err != nil {
		return fmt.Errorf("failed to disconnect: %w", err)
	}

	b.updateWiFiState()
	b.updateAllWiFiDevices()
	b.updatePrimaryConnection()

	if b.onStateChange != nil {
		b.onStateChange()
	}

	return nil
}

func (b *NetworkManagerBackend) GetWiFiDevices() []WiFiDevice {
	b.stateMutex.RLock()
	defer b.stateMutex.RUnlock()
	return append([]WiFiDevice(nil), b.state.WiFiDevices...)
}

func (b *NetworkManagerBackend) updateAllWiFiDevices() {
	s := b.settings
	if s == nil {
		var err error
		s, err = gonetworkmanager.NewSettings()
		if err != nil {
			return
		}
		b.settings = s
	}

	settingsMgr := s.(gonetworkmanager.Settings)
	connections, err := settingsMgr.ListConnections()
	if err != nil {
		return
	}

	savedSSIDs := make(map[string]bool)
	autoconnectMap := make(map[string]bool)
	hiddenSSIDs := make(map[string]bool)
	for _, conn := range connections {
		connSettings, err := conn.GetSettings()
		if err != nil {
			continue
		}

		connMeta, ok := connSettings["connection"]
		if !ok {
			continue
		}

		connType, ok := connMeta["type"].(string)
		if !ok || connType != "802-11-wireless" {
			continue
		}

		wifiSettings, ok := connSettings["802-11-wireless"]
		if !ok {
			continue
		}

		ssidBytes, ok := wifiSettings["ssid"].([]byte)
		if !ok {
			continue
		}

		ssid := string(ssidBytes)
		savedSSIDs[ssid] = true
		autoconnect := true
		if ac, ok := connMeta["autoconnect"].(bool); ok {
			autoconnect = ac
		}
		autoconnectMap[ssid] = autoconnect

		if hidden, ok := wifiSettings["hidden"].(bool); ok && hidden {
			hiddenSSIDs[ssid] = true
		}
	}

	var devices []WiFiDevice

	for name, devInfo := range b.wifiDevices {
		state, _ := devInfo.device.GetPropertyState()
		connected := state == gonetworkmanager.NmDeviceStateActivated

		var ssid, bssid, ip string
		var signal uint8

		if connected {
			if activeAP, err := devInfo.wireless.GetPropertyActiveAccessPoint(); err == nil && activeAP != nil && activeAP.GetPath() != "/" {
				ssid, _ = activeAP.GetPropertySSID()
				signal, _ = activeAP.GetPropertyStrength()
				bssid, _ = activeAP.GetPropertyHWAddress()
			}
			ip = b.getDeviceIP(devInfo.device)
		}

		stateStr := "disconnected"
		switch state {
		case gonetworkmanager.NmDeviceStateActivated:
			stateStr = "connected"
		case gonetworkmanager.NmDeviceStateConfig, gonetworkmanager.NmDeviceStateIpConfig:
			stateStr = "connecting"
		case gonetworkmanager.NmDeviceStatePrepare:
			stateStr = "preparing"
		case gonetworkmanager.NmDeviceStateDeactivating:
			stateStr = "disconnecting"
		}

		apPaths, err := devInfo.wireless.GetAccessPoints()
		var networks []WiFiNetwork
		if err == nil {
			seenSSIDs := make(map[string]*WiFiNetwork)
			for _, ap := range apPaths {
				apSSID, err := ap.GetPropertySSID()
				if err != nil || apSSID == "" {
					continue
				}

				if existing, exists := seenSSIDs[apSSID]; exists {
					strength, _ := ap.GetPropertyStrength()
					if strength > existing.Signal {
						existing.Signal = strength
						freq, _ := ap.GetPropertyFrequency()
						existing.Frequency = freq
						apBSSID, _ := ap.GetPropertyHWAddress()
						existing.BSSID = apBSSID
					}
					continue
				}

				strength, _ := ap.GetPropertyStrength()
				flags, _ := ap.GetPropertyFlags()
				wpaFlags, _ := ap.GetPropertyWPAFlags()
				rsnFlags, _ := ap.GetPropertyRSNFlags()
				freq, _ := ap.GetPropertyFrequency()
				maxBitrate, _ := ap.GetPropertyMaxBitrate()
				apBSSID, _ := ap.GetPropertyHWAddress()
				mode, _ := ap.GetPropertyMode()

				secured := flags != uint32(gonetworkmanager.Nm80211APFlagsNone) ||
					wpaFlags != uint32(gonetworkmanager.Nm80211APSecNone) ||
					rsnFlags != uint32(gonetworkmanager.Nm80211APSecNone)

				enterprise := (rsnFlags&uint32(gonetworkmanager.Nm80211APSecKeyMgmt8021X) != 0) ||
					(wpaFlags&uint32(gonetworkmanager.Nm80211APSecKeyMgmt8021X) != 0)

				var modeStr string
				switch mode {
				case gonetworkmanager.Nm80211ModeAdhoc:
					modeStr = "adhoc"
				case gonetworkmanager.Nm80211ModeInfra:
					modeStr = "infrastructure"
				case gonetworkmanager.Nm80211ModeAp:
					modeStr = "ap"
				default:
					modeStr = "unknown"
				}

				channel := frequencyToChannel(freq)

				network := WiFiNetwork{
					SSID:        apSSID,
					BSSID:       apBSSID,
					Signal:      strength,
					Secured:     secured,
					Enterprise:  enterprise,
					Connected:   connected && apSSID == ssid,
					Saved:       savedSSIDs[apSSID],
					Autoconnect: autoconnectMap[apSSID],
					Hidden:      hiddenSSIDs[apSSID],
					Frequency:   freq,
					Mode:        modeStr,
					Rate:        maxBitrate / 1000,
					Channel:     channel,
					Device:      name,
				}

				seenSSIDs[apSSID] = &network
				networks = append(networks, network)
			}

			if connected && ssid != "" {
				if _, exists := seenSSIDs[ssid]; !exists {
					hiddenNetwork := WiFiNetwork{
						SSID:        ssid,
						BSSID:       bssid,
						Signal:      signal,
						Secured:     true,
						Connected:   true,
						Saved:       savedSSIDs[ssid],
						Autoconnect: autoconnectMap[ssid],
						Hidden:      true,
						Mode:        "infrastructure",
						Device:      name,
					}
					networks = append(networks, hiddenNetwork)
				}
			}

			sortWiFiNetworks(networks)
		}

		devices = append(devices, WiFiDevice{
			Name:      name,
			HwAddress: devInfo.hwAddress,
			State:     stateStr,
			Connected: connected,
			SSID:      ssid,
			BSSID:     bssid,
			Signal:    signal,
			IP:        ip,
			Networks:  networks,
		})
	}

	sort.Slice(devices, func(i, j int) bool {
		return devices[i].Name < devices[j].Name
	})

	b.stateMutex.Lock()
	b.state.WiFiDevices = devices
	b.stateMutex.Unlock()
}

func (b *NetworkManagerBackend) getWifiDeviceForConnection(deviceName string) (*wifiDeviceInfo, error) {
	if deviceName != "" {
		devInfo, ok := b.wifiDevices[deviceName]
		if !ok {
			return nil, fmt.Errorf("WiFi device not found: %s", deviceName)
		}
		return devInfo, nil
	}

	if b.wifiDevice == nil {
		return nil, fmt.Errorf("no WiFi device available")
	}

	dev := b.wifiDevice.(gonetworkmanager.Device)
	iface, _ := dev.GetPropertyInterface()
	if devInfo, ok := b.wifiDevices[iface]; ok {
		return devInfo, nil
	}

	return nil, fmt.Errorf("no WiFi device available")
}
