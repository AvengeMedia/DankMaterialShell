package network

import (
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/errdefs"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/Wifx/gonetworkmanager/v2"
)

func (b *NetworkManagerBackend) updatePrimaryConnection() error {
	nm := b.nmConn.(gonetworkmanager.NetworkManager)

	activeConns, err := nm.GetPropertyActiveConnections()
	if err != nil {
		return err
	}

	hasActiveVPN := false
	for _, activeConn := range activeConns {
		connType, err := activeConn.GetPropertyType()
		if err != nil {
			continue
		}
		if connType == "vpn" || connType == "wireguard" {
			state, _ := activeConn.GetPropertyState()
			if state == 2 {
				hasActiveVPN = true
				break
			}
		}
	}

	if hasActiveVPN {
		b.stateMutex.Lock()
		b.state.NetworkStatus = StatusVPN
		b.stateMutex.Unlock()
		return nil
	}

	primaryConn, err := nm.GetPropertyPrimaryConnection()
	if err != nil {
		return err
	}

	if primaryConn == nil || primaryConn.GetPath() == "/" {
		b.stateMutex.Lock()
		b.state.NetworkStatus = StatusDisconnected
		b.stateMutex.Unlock()
		return nil
	}

	connType, err := primaryConn.GetPropertyType()
	if err != nil {
		return err
	}

	b.stateMutex.Lock()
	switch connType {
	case "802-3-ethernet":
		b.state.NetworkStatus = StatusEthernet
	case "802-11-wireless":
		b.state.NetworkStatus = StatusWiFi
	case "vpn", "wireguard":
		b.state.NetworkStatus = StatusVPN
	default:
		b.state.NetworkStatus = StatusDisconnected
	}
	b.stateMutex.Unlock()

	return nil
}

func (b *NetworkManagerBackend) updateEthernetState() error {
	var connectedDevice string
	var connectedIP string
	var anyConnected bool

	for name, info := range b.ethernetDevices {
		state, err := info.device.GetPropertyState()
		if err != nil {
			continue
		}

		if state == gonetworkmanager.NmDeviceStateActivated {
			anyConnected = true
			connectedDevice = name
			connectedIP = b.getDeviceIP(info.device)
			break
		}
	}

	if !anyConnected && b.ethernetDevice != nil {
		dev := b.ethernetDevice.(gonetworkmanager.Device)
		iface, _ := dev.GetPropertyInterface()
		connectedDevice = iface
	}

	b.stateMutex.Lock()
	b.state.EthernetDevice = connectedDevice
	b.state.EthernetConnected = anyConnected
	b.state.EthernetIP = connectedIP
	b.stateMutex.Unlock()

	return nil
}

func (b *NetworkManagerBackend) getDeviceStateReason(dev gonetworkmanager.Device) uint32 {
	path := dev.GetPath()
	obj := b.dbusConn.Object("org.freedesktop.NetworkManager", path)

	variant, err := obj.GetProperty(dbusNMDeviceInterface + ".StateReason")
	if err != nil {
		return 0
	}

	if stateReasonStruct, ok := variant.Value().([]any); ok && len(stateReasonStruct) >= 2 {
		if reason, ok := stateReasonStruct[1].(uint32); ok {
			return reason
		}
	}

	return 0
}

func (b *NetworkManagerBackend) classifyNMStateReason(reason uint32) string {
	switch reason {
	case NmDeviceStateReasonWrongPassword,
		NmDeviceStateReasonSupplicantTimeout,
		NmDeviceStateReasonSupplicantFailed,
		NmDeviceStateReasonSecretsRequired:
		return errdefs.ErrBadCredentials
	case NmDeviceStateReasonNoSecrets:
		return errdefs.ErrUserCanceled
	case NmDeviceStateReasonNoSsid:
		return errdefs.ErrNoSuchSSID
	case NmDeviceStateReasonDhcpClientFailed,
		NmDeviceStateReasonIpConfigUnavailable:
		return errdefs.ErrDhcpTimeout
	case NmDeviceStateReasonSupplicantDisconnect,
		NmDeviceStateReasonCarrier:
		return errdefs.ErrAssocTimeout
	default:
		return errdefs.ErrConnectionFailed
	}
}

func (b *NetworkManagerBackend) updateWiFiState() error {
	if b.wifiDevice == nil {
		return nil
	}

	dev := b.wifiDevice.(gonetworkmanager.Device)

	iface, err := dev.GetPropertyInterface()
	if err != nil {
		return err
	}

	state, err := dev.GetPropertyState()
	if err != nil {
		return err
	}

	connected := state == gonetworkmanager.NmDeviceStateActivated
	failed := state == gonetworkmanager.NmDeviceStateFailed
	disconnected := state == gonetworkmanager.NmDeviceStateDisconnected

	var ip, ssid, bssid string
	var signal uint8

	if connected {
		if err := b.ensureWiFiDevice(); err == nil && b.wifiDev != nil {
			w := b.wifiDev.(gonetworkmanager.DeviceWireless)
			activeAP, err := w.GetPropertyActiveAccessPoint()
			if err == nil && activeAP != nil && activeAP.GetPath() != "/" {
				ssid, _ = activeAP.GetPropertySSID()
				signal, _ = activeAP.GetPropertyStrength()
				bssid, _ = activeAP.GetPropertyHWAddress()
			}
		}

		ip = b.getDeviceIP(dev)
	}

	b.stateMutex.RLock()
	wasConnecting := b.state.IsConnecting
	connectingSSID := b.state.ConnectingSSID
	b.stateMutex.RUnlock()

	var reasonCode string
	if wasConnecting && connectingSSID != "" && (failed || (disconnected && !connected)) {
		reason := b.getDeviceStateReason(dev)

		if reason == NmDeviceStateReasonNewActivation || reason == 0 {
			return nil
		}

		log.Warnf("[updateWiFiState] Connection failed: SSID=%s, state=%d, reason=%d", connectingSSID, state, reason)

		reasonCode = b.classifyNMStateReason(reason)

		if reasonCode == errdefs.ErrConnectionFailed {
			b.failedMutex.RLock()
			if b.lastFailedSSID == connectingSSID {
				elapsed := time.Now().Unix() - b.lastFailedTime
				if elapsed < 5 {
					reasonCode = errdefs.ErrBadCredentials
				}
			}
			b.failedMutex.RUnlock()
		}
	}

	b.stateMutex.Lock()
	defer b.stateMutex.Unlock()

	wasConnecting = b.state.IsConnecting
	connectingSSID = b.state.ConnectingSSID

	if wasConnecting && connectingSSID != "" {
		if connected && ssid == connectingSSID {
			log.Infof("[updateWiFiState] Connection successful: %s", ssid)
			b.state.IsConnecting = false
			b.state.ConnectingSSID = ""
			b.state.LastError = ""
		} else if failed || (disconnected && !connected) {
			log.Warnf("[updateWiFiState] Connection failed: SSID=%s, state=%d", connectingSSID, state)
			b.state.IsConnecting = false
			b.state.ConnectingSSID = ""
			b.state.LastError = reasonCode

			// If user cancelled, delete the connection profile that was just created
			if reasonCode == errdefs.ErrUserCanceled {
				log.Infof("[updateWiFiState] User cancelled authentication, removing connection profile for %s", connectingSSID)
				b.stateMutex.Unlock()
				if err := b.ForgetWiFiNetwork(connectingSSID); err != nil {
					log.Warnf("[updateWiFiState] Failed to remove cancelled connection: %v", err)
				}
				b.stateMutex.Lock()
			}

			b.failedMutex.Lock()
			b.lastFailedSSID = connectingSSID
			b.lastFailedTime = time.Now().Unix()
			b.failedMutex.Unlock()
		}
	}

	b.state.WiFiDevice = iface
	b.state.WiFiConnected = connected
	b.state.WiFiIP = ip
	b.state.WiFiSSID = ssid
	b.state.WiFiBSSID = bssid
	b.state.WiFiSignal = signal

	return nil
}

func (b *NetworkManagerBackend) getDeviceIP(dev gonetworkmanager.Device) string {
	ip4Config, err := dev.GetPropertyIP4Config()
	if err != nil || ip4Config == nil {
		return ""
	}

	addresses, err := ip4Config.GetPropertyAddressData()
	if err != nil || len(addresses) == 0 {
		return ""
	}

	return addresses[0].Address
}
