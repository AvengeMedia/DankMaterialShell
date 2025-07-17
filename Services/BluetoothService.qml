pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root
    
    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool discovering: adapter?.discovering ?? false

    readonly property var devices: {
        var deviceList = []
        if (!adapter) return deviceList
        
        for (var i = 0; i < adapter.devices.count; i++) {
            var dev = adapter.devices.get(i)
            if (dev && dev.ready && _isValidDevice(dev)) {
                deviceList.push({
                    address: dev.address,
                    name: dev.name || dev.deviceName,
                    paired: dev.paired,
                    connected: dev.connected,
                    iconName: _getDeviceIcon(dev),
                    type: _getDeviceType(dev),
                    batteryLevel: dev.batteryAvailable ? Math.round(dev.battery * 100) : -1,
                    batteryAvailable: dev.batteryAvailable,
                    native: dev
                })
            }
        }
        return deviceList
    }
    
    readonly property var pairedDevices: {
        return devices.filter(dev => dev.paired)
    }
    
    readonly property var availableDevices: {
        if (!discovering) return []
        var availableList = []
        
        if (Bluetooth.devices && Bluetooth.devices.values) {
            for (var device of Bluetooth.devices.values) {
                if (device && device.ready && !device.paired && _isValidDevice(device)) {
                    availableList.push({
                        address: device.address,
                        name: device.name || device.deviceName,
                        paired: false,
                        connected: false,
                        iconName: _getDeviceIcon(device),
                        type: _getDeviceType(device),
                        batteryLevel: -1,
                        batteryAvailable: false,
                        native: device
                    })
                }
            }
        }
        return availableList
    }
    
    readonly property var allDevicesWithBattery: {
        return devices.filter(dev => dev.batteryAvailable && dev.batteryLevel >= 0)
    }
    
    Component.onCompleted: {
        if (adapter && adapter.devices) {
            adapter.devices.itemAdded.connect(devicesChanged)
            adapter.devices.itemRemoved.connect(devicesChanged)
        }
        
        if (Bluetooth.devices) {
            Bluetooth.devices.itemAdded.connect(devicesChanged)
            Bluetooth.devices.itemRemoved.connect(devicesChanged)
        }
    }

    Connections {
        target: Bluetooth
        function onDefaultAdapterChanged() {
            if (adapter && adapter.devices) {
                adapter.devices.itemAdded.connect(devicesChanged)
                adapter.devices.itemRemoved.connect(devicesChanged)
            }
        }
    }
    
    function _isValidDevice(device) {
        var displayName = device.name || device.deviceName
        if (!displayName || displayName.length < 2) return false
        if (displayName.startsWith('/org/bluez') || displayName.includes('hci0')) return false
        return displayName.length >= 3
    }
    
    function _getDeviceIcon(device) {
        var name = (device.name || device.deviceName || "").toLowerCase()
        var icon = (device.icon || "").toLowerCase()
        
        if (icon.includes("headset") || icon.includes("audio") || name.includes("headphone") || 
            name.includes("airpod") || name.includes("headset") || name.includes("arctis")) return "headset"
        if (icon.includes("mouse") || name.includes("mouse")) return "mouse"
        if (icon.includes("keyboard") || name.includes("keyboard")) return "keyboard"
        if (icon.includes("phone") || name.includes("phone") || name.includes("iphone") || 
            name.includes("android") || name.includes("samsung")) return "smartphone"
        if (icon.includes("watch") || name.includes("watch")) return "watch"
        if (icon.includes("speaker") || name.includes("speaker")) return "speaker"
        if (icon.includes("display") || name.includes("tv")) return "tv"
        return "bluetooth"
    }
    
    function _getDeviceType(device) {
        var name = (device.name || device.deviceName || "").toLowerCase()
        var icon = (device.icon || "").toLowerCase()
        
        if (icon.includes("headset") || icon.includes("audio") || name.includes("headphone") || 
            name.includes("airpod") || name.includes("headset") || name.includes("arctis")) return "headset"
        if (icon.includes("mouse") || name.includes("mouse")) return "mouse"
        if (icon.includes("keyboard") || name.includes("keyboard")) return "keyboard"
        if (icon.includes("phone") || name.includes("phone") || name.includes("iphone") || 
            name.includes("android") || name.includes("samsung")) return "phone"
        if (icon.includes("watch") || name.includes("watch")) return "watch"
        if (icon.includes("speaker") || name.includes("speaker")) return "speaker"
        if (icon.includes("display") || name.includes("tv")) return "tv"
        return "bluetooth"
    }
    
    function toggleAdapter() {
        if (adapter) adapter.enabled = !adapter.enabled
    }
    
    function startScan() {
        if (adapter) adapter.discovering = true
    }
    
    function stopScan() {
        if (adapter) adapter.discovering = false
    }
    
    function connect(address) {
        var device = _findDevice(address)
        if (device) device.connect()
    }
    
    function disconnect(address) {
        var device = _findDevice(address)
        if (device) device.disconnect()
    }
    
    function pair(address) {
        var device = _findDevice(address)
        if (device) device.pair()
    }
    
    function forget(address) {
        var device = _findDevice(address)
        if (device) device.forget()
    }
    
    function toggle(address) {
        var device = _findDevice(address)
        if (device) {
            if (device.connected) device.disconnect()
            else device.connect()
        }
    }
    
    function _findDevice(address) {
        if (!adapter) return null
        return adapter.devices.values.find(d => d.address === address) || 
               (Bluetooth.devices ? Bluetooth.devices.values.find(d => d.address === address) : null)
    }
}