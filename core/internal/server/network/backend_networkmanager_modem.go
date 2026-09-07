package network

import (
	"github.com/godbus/dbus/v5"
)

const (
	dbusMMService              = "org.freedesktop.ModemManager1"
	dbusMMPath                 = "/org/freedesktop/ModemManager1"
	dbusMMModemInterface       = "org.freedesktop.ModemManager1.Modem"
	dbusObjectManagerInterface = "org.freedesktop.DBus.ObjectManager"
)

// NetworkManager exposes no signal strength for modems, so radio metrics come
// straight from ModemManager and are matched back to NM devices by the modem's
// primary port, which is what NM names the device after (qrtr0, cdc-wdm0) --
// not the net port carrying the traffic.
type modemInfo struct {
	primaryPort   string
	signalQuality uint32
	accessTech    string
}

func (b *NetworkManagerBackend) modemForIface(iface string, cellularDeviceCount int) (modemInfo, bool) {
	b.modemMutex.RLock()
	defer b.modemMutex.RUnlock()

	for _, info := range b.modems {
		if info.primaryPort == iface {
			return info, true
		}
	}

	// A lone modem belongs to the lone cellular device.
	if len(b.modems) == 1 && cellularDeviceCount == 1 {
		for _, info := range b.modems {
			return info, true
		}
	}

	return modemInfo{}, false
}

func (b *NetworkManagerBackend) refreshModems() {
	if b.dbusConn == nil {
		return
	}

	var objects map[dbus.ObjectPath]map[string]map[string]dbus.Variant
	obj := b.dbusConn.Object(dbusMMService, dbus.ObjectPath(dbusMMPath))
	if err := obj.Call(dbusObjectManagerInterface+".GetManagedObjects", dbus.FlagNoAutoStart).Store(&objects); err != nil {
		b.modemMutex.Lock()
		b.modems = nil
		b.modemMutex.Unlock()
		return
	}

	modems := make(map[dbus.ObjectPath]modemInfo, len(objects))
	for path, ifaces := range objects {
		props, ok := ifaces[dbusMMModemInterface]
		if !ok {
			continue
		}
		modems[path] = parseModemProps(props)
	}

	b.modemMutex.Lock()
	b.modems = modems
	b.modemMutex.Unlock()
}

func (b *NetworkManagerBackend) refreshModem(path dbus.ObjectPath) bool {
	if b.dbusConn == nil {
		return false
	}

	var props map[string]dbus.Variant
	obj := b.dbusConn.Object(dbusMMService, path)
	if err := obj.Call(dbusPropsInterface+".GetAll", 0, dbusMMModemInterface).Store(&props); err != nil {
		return false
	}

	info := parseModemProps(props)

	b.modemMutex.Lock()
	defer b.modemMutex.Unlock()
	if b.modems == nil {
		b.modems = make(map[dbus.ObjectPath]modemInfo, 1)
	}
	if prev, ok := b.modems[path]; ok && prev == info {
		return false
	}
	b.modems[path] = info
	return true
}

func parseModemProps(props map[string]dbus.Variant) modemInfo {
	info := modemInfo{}

	if v, ok := props["SignalQuality"]; ok {
		var quality struct {
			Percent uint32
			Recent  bool
		}
		// Recent=false just means cached; it is still the best reading we have.
		if err := v.Store(&quality); err == nil {
			info.signalQuality = quality.Percent
		}
	}

	if v, ok := props["AccessTechnologies"]; ok {
		if mask, ok := v.Value().(uint32); ok {
			info.accessTech = accessTechLabel(mask)
		}
	}

	if v, ok := props["PrimaryPort"]; ok {
		if port, ok := v.Value().(string); ok {
			info.primaryPort = port
		}
	}

	return info
}

// MMModemAccessTechnology, highest generation wins.
func accessTechLabel(mask uint32) string {
	switch {
	case mask&(1<<15) != 0:
		return "5G"
	case mask&(1<<14|1<<16|1<<17) != 0:
		return "LTE"
	case mask&(1<<6|1<<7|1<<8|1<<9) != 0:
		return "H"
	case mask&(1<<5|1<<11|1<<12|1<<13) != 0:
		return "3G"
	case mask&(1<<4) != 0:
		return "E"
	case mask&(1<<3) != 0:
		return "G"
	case mask&(1<<1|1<<2|1<<10) != 0:
		return "2G"
	}
	return ""
}

func (b *NetworkManagerBackend) handleModemChange(path dbus.ObjectPath, changes map[string]dbus.Variant) {
	relevant := false
	for key := range changes {
		switch key {
		case "SignalQuality", "AccessTechnologies", "PrimaryPort", "State":
			relevant = true
		}
	}
	if !relevant {
		return
	}

	if !b.refreshModem(path) {
		return
	}

	b.updateAllCellularDevices()
	if b.onStateChange != nil {
		b.onStateChange()
	}
}

func (b *NetworkManagerBackend) handleModemObjectsChange() {
	b.refreshModems()
	b.updateAllCellularDevices()
	if b.onStateChange != nil {
		b.onStateChange()
	}
}
