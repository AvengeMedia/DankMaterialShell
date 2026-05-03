package network

import (
	"github.com/Wifx/gonetworkmanager/v2"
	"github.com/godbus/dbus/v5"
)

func (b *NetworkManagerBackend) startSignalPump() error {
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		return err
	}
	b.dbusConn = conn

	signals := make(chan *dbus.Signal, 256)
	b.signals = signals
	conn.Signal(signals)

	if err := conn.AddMatchSignal(
		dbus.WithMatchObjectPath(dbus.ObjectPath(dbusNMPath)),
		dbus.WithMatchInterface(dbusPropsInterface),
		dbus.WithMatchMember("PropertiesChanged"),
	); err != nil {
		conn.RemoveSignal(signals)
		conn.Close()
		return err
	}

	if err := conn.AddMatchSignal(
		dbus.WithMatchObjectPath(dbus.ObjectPath("/org/freedesktop/NetworkManager/Settings")),
		dbus.WithMatchInterface("org.freedesktop.NetworkManager.Settings"),
		dbus.WithMatchMember("NewConnection"),
	); err != nil {
		conn.RemoveMatchSignal(
			dbus.WithMatchObjectPath(dbus.ObjectPath(dbusNMPath)),
			dbus.WithMatchInterface(dbusPropsInterface),
			dbus.WithMatchMember("PropertiesChanged"),
		)
		conn.RemoveSignal(signals)
		conn.Close()
		return err
	}

	if err := conn.AddMatchSignal(
		dbus.WithMatchObjectPath(dbus.ObjectPath("/org/freedesktop/NetworkManager/Settings")),
		dbus.WithMatchInterface("org.freedesktop.NetworkManager.Settings"),
		dbus.WithMatchMember("ConnectionRemoved"),
	); err != nil {
		conn.RemoveMatchSignal(
			dbus.WithMatchObjectPath(dbus.ObjectPath(dbusNMPath)),
			dbus.WithMatchInterface(dbusPropsInterface),
			dbus.WithMatchMember("PropertiesChanged"),
		)
		conn.RemoveMatchSignal(
			dbus.WithMatchObjectPath(dbus.ObjectPath("/org/freedesktop/NetworkManager/Settings")),
			dbus.WithMatchInterface("org.freedesktop.NetworkManager.Settings"),
			dbus.WithMatchMember("NewConnection"),
		)
		conn.RemoveSignal(signals)
		conn.Close()
		return err
	}

	if err := conn.AddMatchSignal(
		dbus.WithMatchObjectPath(dbus.ObjectPath(dbusNMPath)),
		dbus.WithMatchInterface(dbusNMInterface),
		dbus.WithMatchMember("DeviceAdded"),
	); err != nil {
		conn.RemoveSignal(signals)
		conn.Close()
		return err
	}

	if err := conn.AddMatchSignal(
		dbus.WithMatchObjectPath(dbus.ObjectPath(dbusNMPath)),
		dbus.WithMatchInterface(dbusNMInterface),
		dbus.WithMatchMember("DeviceRemoved"),
	); err != nil {
		conn.RemoveSignal(signals)
		conn.Close()
		return err
	}

	for _, info := range b.wifiDevices {
		if err := conn.AddMatchSignal(
			dbus.WithMatchObjectPath(dbus.ObjectPath(info.device.GetPath())),
			dbus.WithMatchInterface(dbusPropsInterface),
			dbus.WithMatchMember("PropertiesChanged"),
		); err != nil {
			conn.RemoveSignal(signals)
			conn.Close()
			return err
		}
	}

	for _, info := range b.ethernetDevices {
		if err := conn.AddMatchSignal(
			dbus.WithMatchObjectPath(dbus.ObjectPath(info.device.GetPath())),
			dbus.WithMatchInterface(dbusPropsInterface),
			dbus.WithMatchMember("PropertiesChanged"),
		); err != nil {
			conn.RemoveSignal(signals)
			conn.Close()
			return err
		}
	}

	b.sigWG.Add(1)
	go func() {
		defer b.sigWG.Done()
		for {
			select {
			case <-b.stopChan:
				return
			case sig, ok := <-signals:
				if !ok {
					return
				}
				if sig == nil {
					continue
				}
				b.handleDBusSignal(sig)
			}
		}
	}()
	return nil
}

func (b *NetworkManagerBackend) stopSignalPump() {
	if b.dbusConn == nil {
		return
	}

	b.dbusConn.RemoveMatchSignal(
		dbus.WithMatchObjectPath(dbus.ObjectPath(dbusNMPath)),
		dbus.WithMatchInterface(dbusPropsInterface),
		dbus.WithMatchMember("PropertiesChanged"),
	)

	for _, info := range b.wifiDevices {
		b.dbusConn.RemoveMatchSignal(
			dbus.WithMatchObjectPath(dbus.ObjectPath(info.device.GetPath())),
			dbus.WithMatchInterface(dbusPropsInterface),
			dbus.WithMatchMember("PropertiesChanged"),
		)
	}

	for _, info := range b.ethernetDevices {
		b.dbusConn.RemoveMatchSignal(
			dbus.WithMatchObjectPath(dbus.ObjectPath(info.device.GetPath())),
			dbus.WithMatchInterface(dbusPropsInterface),
			dbus.WithMatchMember("PropertiesChanged"),
		)
	}

	if b.signals != nil {
		b.dbusConn.RemoveSignal(b.signals)
		close(b.signals)
	}

	b.sigWG.Wait()

	b.dbusConn.Close()
}

func (b *NetworkManagerBackend) handleDBusSignal(sig *dbus.Signal) {
	if sig.Name == "org.freedesktop.NetworkManager.Settings.NewConnection" ||
		sig.Name == "org.freedesktop.NetworkManager.Settings.ConnectionRemoved" {
		b.ListVPNProfiles()
		if b.onStateChange != nil {
			b.onStateChange()
		}
		return
	}

	if sig.Name == "org.freedesktop.NetworkManager.DeviceAdded" {
		if len(sig.Body) >= 1 {
			if devicePath, ok := sig.Body[0].(dbus.ObjectPath); ok {
				b.handleDeviceAdded(devicePath)
			}
		}
		return
	}

	if sig.Name == "org.freedesktop.NetworkManager.DeviceRemoved" {
		if len(sig.Body) >= 1 {
			if devicePath, ok := sig.Body[0].(dbus.ObjectPath); ok {
				b.handleDeviceRemoved(devicePath)
			}
		}
		return
	}

	if len(sig.Body) < 2 {
		return
	}

	iface, ok := sig.Body[0].(string)
	if !ok {
		return
	}

	changes, ok := sig.Body[1].(map[string]dbus.Variant)
	if !ok {
		return
	}

	switch iface {
	case dbusNMInterface:
		b.handleNetworkManagerChange(changes)

	case dbusNMDeviceInterface:
		b.handleDeviceChange(sig.Path, changes)

	case dbusNMWiredInterface:
		b.handleWiredChange(changes)

	case dbusNMWirelessInterface:
		b.handleWiFiChange(changes)

	case dbusNMAccessPointInterface:
		b.handleAccessPointChange(changes)
	}
}

func (b *NetworkManagerBackend) handleNetworkManagerChange(changes map[string]dbus.Variant) {
	var needsUpdate bool

	for key := range changes {
		switch key {
		case "PrimaryConnection", "State", "ActiveConnections":
			needsUpdate = true
		case "WirelessEnabled":
			nm := b.nmConn.(gonetworkmanager.NetworkManager)
			if enabled, err := nm.GetPropertyWirelessEnabled(); err == nil {
				b.stateMutex.Lock()
				b.state.WiFiEnabled = enabled
				b.stateMutex.Unlock()
				needsUpdate = true
			}
		case "WwanEnabled":
			nm := b.nmConn.(gonetworkmanager.NetworkManager)
			if enabled, err := nm.GetPropertyWwanEnabled(); err == nil {
				b.stateMutex.Lock()
				b.state.CellularEnabled = enabled
				b.stateMutex.Unlock()
				needsUpdate = true
			}
		default:
			continue
		}
	}

	if needsUpdate {
		b.updatePrimaryConnection()
		if _, exists := changes["State"]; exists {
			b.updateEthernetState()
			b.updateWiFiState()
			b.updateCellularState()
		}
		if _, exists := changes["ActiveConnections"]; exists {
			b.updateVPNConnectionState()
			b.ListActiveVPN()
			b.updateCellularState()
			b.listCellularConnections()
			b.ListActiveCellular()
		}
		if b.onStateChange != nil {
			b.onStateChange()
		}
	}
}

func (b *NetworkManagerBackend) handleDeviceChange(devicePath dbus.ObjectPath, changes map[string]dbus.Variant) {
	var needsUpdate bool
	var stateChanged bool
	var managedChanged bool

	for key := range changes {
		switch key {
		case "State":
			stateChanged = true
			needsUpdate = true
		case "Ip4Config":
			needsUpdate = true
		case "Managed":
			managedChanged = true
		default:
			continue
		}
	}

	if managedChanged {
		if managedVariant, ok := changes["Managed"]; ok {
			if managed, ok := managedVariant.Value().(bool); ok && managed {
				b.handleDeviceAdded(devicePath)
				return
			}
		}
	}

	if !needsUpdate {
		return
	}

	b.updateAllEthernetDevices()
	b.updateEthernetState()
	b.updateAllWiFiDevices()
	b.updateWiFiState()
	b.updateCellularState()
	if stateChanged {
		b.listEthernetConnections()
		b.listCellularConnections()
		b.updatePrimaryConnection()
	}
	if b.onStateChange != nil {
		b.onStateChange()
	}
}

func (b *NetworkManagerBackend) handleWiredChange(changes map[string]dbus.Variant) {
	var needsUpdate bool

	for key := range changes {
		switch key {
		case "Carrier", "Speed", "HwAddress":
			needsUpdate = true
		default:
			continue
		}
	}

	if !needsUpdate {
		return
	}

	b.updateAllEthernetDevices()
	b.updateEthernetState()
	b.updatePrimaryConnection()
	if b.onStateChange != nil {
		b.onStateChange()
	}
}

func (b *NetworkManagerBackend) handleWiFiChange(changes map[string]dbus.Variant) {
	var needsStateUpdate bool
	var needsNetworkUpdate bool

	for key := range changes {
		switch key {
		case "ActiveAccessPoint":
			needsStateUpdate = true
			needsNetworkUpdate = true
		case "AccessPoints":
			needsNetworkUpdate = true
		default:
			continue
		}
	}

	if needsStateUpdate {
		b.updateWiFiState()
	}
	if needsNetworkUpdate {
		b.updateWiFiNetworks()
	}
	if needsStateUpdate || needsNetworkUpdate {
		if b.onStateChange != nil {
			b.onStateChange()
		}
	}
}

func (b *NetworkManagerBackend) handleAccessPointChange(changes map[string]dbus.Variant) {
	_, hasStrength := changes["Strength"]
	if !hasStrength {
		return
	}

	b.stateMutex.RLock()
	oldSignal := b.state.WiFiSignal
	b.stateMutex.RUnlock()

	b.updateWiFiState()

	b.stateMutex.RLock()
	newSignal := b.state.WiFiSignal
	b.stateMutex.RUnlock()

	if signalChangeSignificant(oldSignal, newSignal) {
		if b.onStateChange != nil {
			b.onStateChange()
		}
	}
}

func (b *NetworkManagerBackend) handleDeviceAdded(devicePath dbus.ObjectPath) {
	dev, err := gonetworkmanager.NewDevice(devicePath)
	if err != nil {
		return
	}

	devType, err := dev.GetPropertyDeviceType()
	if err != nil {
		return
	}

	// NmDeviceTypeModem = 8
	if devType != gonetworkmanager.NmDeviceTypeEthernet && devType != gonetworkmanager.NmDeviceTypeWifi && devType != 8 {
		return
	}

	if b.dbusConn != nil {
		b.dbusConn.AddMatchSignal(
			dbus.WithMatchObjectPath(devicePath),
			dbus.WithMatchInterface(dbusPropsInterface),
			dbus.WithMatchMember("PropertiesChanged"),
		)
	}

	managed, _ := dev.GetPropertyManaged()
	if !managed {
		return
	}

	iface, err := dev.GetPropertyInterface()
	if err != nil {
		return
	}

	switch devType {
	case gonetworkmanager.NmDeviceTypeEthernet:
		w, err := gonetworkmanager.NewDeviceWired(devicePath)
		if err != nil {
			return
		}
		hwAddr, _ := w.GetPropertyHwAddress()

		b.ethernetDevices[iface] = &ethernetDeviceInfo{
			device:    dev,
			wired:     w,
			name:      iface,
			hwAddress: hwAddr,
		}

		if b.ethernetDevice == nil {
			b.ethernetDevice = dev
		}

		b.updateAllEthernetDevices()
		b.updateEthernetState()
		b.listEthernetConnections()
		b.updatePrimaryConnection()

	case gonetworkmanager.NmDeviceTypeWifi:
		w, err := gonetworkmanager.NewDeviceWireless(devicePath)
		if err != nil {
			return
		}
		hwAddr, _ := w.GetPropertyHwAddress()

		b.wifiDevices[iface] = &wifiDeviceInfo{
			device:    dev,
			wireless:  w,
			name:      iface,
			hwAddress: hwAddr,
		}

		if b.wifiDevice == nil {
			b.wifiDevice = dev
			b.wifiDev = w
		}

		b.updateAllWiFiDevices()
		b.updateWiFiState()

	case 8: // NmDeviceTypeModem
		b.updateCellularState()
		b.listCellularConnections()
		b.ListCellularProfiles()
		b.ListActiveCellular()
	}

	if b.onStateChange != nil {
		b.onStateChange()
	}
}

func (b *NetworkManagerBackend) handleDeviceRemoved(devicePath dbus.ObjectPath) {
	if b.dbusConn != nil {
		b.dbusConn.RemoveMatchSignal(
			dbus.WithMatchObjectPath(devicePath),
			dbus.WithMatchInterface(dbusPropsInterface),
			dbus.WithMatchMember("PropertiesChanged"),
		)
	}

	for iface, info := range b.ethernetDevices {
		if info.device.GetPath() == devicePath {
			delete(b.ethernetDevices, iface)

			if b.ethernetDevice != nil {
				dev := b.ethernetDevice.(gonetworkmanager.Device)
				if dev.GetPath() == devicePath {
					b.ethernetDevice = nil
					for _, remaining := range b.ethernetDevices {
						b.ethernetDevice = remaining.device
						break
					}
				}
			}

			b.updateAllEthernetDevices()
			b.updateEthernetState()
			b.listEthernetConnections()
			b.updatePrimaryConnection()

			if b.onStateChange != nil {
				b.onStateChange()
			}
			return
		}
	}

	for iface, info := range b.wifiDevices {
		if info.device.GetPath() == devicePath {
			delete(b.wifiDevices, iface)

			if b.wifiDevice != nil {
				dev := b.wifiDevice.(gonetworkmanager.Device)
				if dev.GetPath() == devicePath {
					b.wifiDevice = nil
					b.wifiDev = nil
					for _, remaining := range b.wifiDevices {
						b.wifiDevice = remaining.device
						b.wifiDev = remaining.wireless
						break
					}
				}
			}

			b.updateAllWiFiDevices()
			b.updateWiFiState()

			if b.onStateChange != nil {
				b.onStateChange()
			}
			return
		}
	}

	// If not found in ethernet/wifi maps, it may be a modem device
	b.updateCellularState()
	b.listCellularConnections()
	b.ListActiveCellular()
	if b.onStateChange != nil {
		b.onStateChange()
	}
}
