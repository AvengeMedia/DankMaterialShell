import QtQuick
import Quickshell
import Quickshell.Bluetooth
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    property bool bluetoothEnabled: false
    property bool bluetoothAvailable: false
    readonly property list<BluetoothDevice> bluetoothDevices: []
    readonly property list<BluetoothDevice> availableDevices: []
    property bool scanning: false
    property bool discoverable: false
    
    property var connectingDevices: ({})
    
    Component.onCompleted: {
        refreshBluetoothState()
        updateDevices()
    }
    
    Connections {
        target: Bluetooth
        
        function onDefaultAdapterChanged() {
            console.log("BluetoothService: Default adapter changed")
            refreshBluetoothState()
            updateDevices()
        }
    }
    
    Connections {
        target: Bluetooth.defaultAdapter
        
        function onEnabledChanged() {
            refreshBluetoothState()
            updateDevices()
        }
        
        function onDiscoveringChanged() {
            refreshBluetoothState()
            updateDevices()
        }
    }
    
    Connections {
        target: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices : null
        
        function onModelReset() {
            updateDevices()
        }
        
        function onItemAdded() {
            updateDevices()
        }
        
        function onItemRemoved() {
            updateDevices()
        }
    }
    
    Connections {
        target: Bluetooth.devices
        
        function onModelReset() {
            updateDevices()
        }
        
        function onItemAdded() {
            updateDevices()
        }
        
        function onItemRemoved() {
            updateDevices()
        }
    }
    
    function refreshBluetoothState() {
        root.bluetoothAvailable = Bluetooth.defaultAdapter !== null
        root.bluetoothEnabled = Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
        root.scanning = Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.discovering : false
        root.discoverable = Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.discoverable : false
    }
    
    function updateDevices() {
        if (!Bluetooth.defaultAdapter) {
            clearDeviceList(root.bluetoothDevices)
            clearDeviceList(root.availableDevices)
            root.bluetoothDevices = []
            root.availableDevices = []
            return
        }
        
        let newPairedDevices = []
        let newAvailableDevices = []
        let allNativeDevices = []
        
        let adapterDevices = Bluetooth.defaultAdapter.devices
        if (adapterDevices.values) {
            allNativeDevices = allNativeDevices.concat(adapterDevices.values)
        }
        
        if (Bluetooth.devices.values) {
            for (let device of Bluetooth.devices.values) {
                if (!allNativeDevices.some(d => d.address === device.address)) {
                    allNativeDevices.push(device)
                }
            }
        }
        
        for (let device of allNativeDevices) {
            if (!device) continue
            
            let deviceType = getDeviceType(device.name || device.deviceName, device.icon)
            let displayName = device.name || device.deviceName
            
            if (!displayName || displayName.startsWith('/org/bluez') || displayName.includes('hci0') || displayName.length < 2) {
                continue
            }
            
            if (device.paired) {
                let existingDevice = findDeviceInList(root.bluetoothDevices, device.address)
                if (existingDevice) {
                    updateDeviceData(existingDevice, device, deviceType, displayName)
                    newPairedDevices.push(existingDevice)
                } else {
                    let newDevice = createBluetoothDevice(device, deviceType, displayName)
                    newPairedDevices.push(newDevice)
                }
            } else {
                if (Bluetooth.defaultAdapter.discovering && isDeviceDiscoverable(device)) {
                    let existingDevice = findDeviceInList(root.availableDevices, device.address)
                    if (existingDevice) {
                        updateDeviceData(existingDevice, device, deviceType, displayName)
                        newAvailableDevices.push(existingDevice)
                    } else {
                        let newDevice = createBluetoothDevice(device, deviceType, displayName)
                        newAvailableDevices.push(newDevice)
                    }
                }
            }
        }
        
        cleanupOldDevices(root.bluetoothDevices, newPairedDevices)
        cleanupOldDevices(root.availableDevices, newAvailableDevices)
        
        console.log("BluetoothService: Found", newPairedDevices.length, "paired devices and", newAvailableDevices.length, "available devices")
        
        root.bluetoothDevices = newPairedDevices
        root.availableDevices = newAvailableDevices
    }
    
    function createBluetoothDevice(nativeDevice, deviceType, displayName) {
        return deviceComponent.createObject(root, {
            mac: nativeDevice.address,
            name: displayName,
            type: deviceType,
            paired: nativeDevice.paired,
            connected: nativeDevice.connected,
            battery: nativeDevice.batteryAvailable ? Math.round(nativeDevice.battery * 100) : -1,
            signalStrength: nativeDevice.connected ? "excellent" : "unknown",
            canPair: !nativeDevice.paired,
            nativeDevice: nativeDevice,
            connecting: false,
            connectionFailed: false
        })
    }
    
    function updateDeviceData(deviceObj, nativeDevice, deviceType, displayName) {
        deviceObj.name = displayName
        deviceObj.type = deviceType
        deviceObj.paired = nativeDevice.paired
        
        // If device connected state changed, clear connecting/failed states
        if (deviceObj.connected !== nativeDevice.connected) {
            deviceObj.connecting = false
            deviceObj.connectionFailed = false
        }
        
        deviceObj.connected = nativeDevice.connected
        deviceObj.battery = nativeDevice.batteryAvailable ? Math.round(nativeDevice.battery * 100) : -1
        deviceObj.signalStrength = nativeDevice.connected ? "excellent" : "unknown"
        deviceObj.canPair = !nativeDevice.paired
        deviceObj.nativeDevice = nativeDevice
    }
    
    function findDeviceInList(deviceList, address) {
        for (let device of deviceList) {
            if (device.mac === address) {
                return device
            }
        }
        return null
    }
    
    function cleanupOldDevices(oldList, newList) {
        for (let oldDevice of oldList) {
            if (!newList.includes(oldDevice)) {
                oldDevice.destroy()
            }
        }
    }
    
    function clearDeviceList(deviceList) {
        for (let device of deviceList) {
            device.destroy()
        }
    }
    
    function isDeviceDiscoverable(device) {
        let displayName = device.name || device.deviceName
        if (!displayName || displayName.length < 2) return false
        
        if (displayName.startsWith('/org/bluez') || displayName.includes('hci0')) return false
        
        let nameLower = displayName.toLowerCase()
        
        if (nameLower.match(/^[0-9a-f]{2}[:-][0-9a-f]{2}[:-][0-9a-f]{2}/)) {
            return false
        }
        
        if (displayName.length < 3) return false
        
        if (nameLower.includes('iphone') || nameLower.includes('ipad') || 
            nameLower.includes('airpods') || nameLower.includes('samsung') ||
            nameLower.includes('galaxy') || nameLower.includes('pixel') ||
            nameLower.includes('headphone') || nameLower.includes('speaker') ||
            nameLower.includes('mouse') || nameLower.includes('keyboard') ||
            nameLower.includes('watch') || nameLower.includes('buds') ||
            nameLower.includes('android')) {
            return true
        }
        
        return displayName.length >= 4 && !displayName.match(/^[A-Z0-9_-]+$/)
    }
    
    function getDeviceType(name, icon) {
        if (!name && !icon) return "bluetooth"
        
        let nameLower = (name || "").toLowerCase()
        let iconLower = (icon || "").toLowerCase()
        
        if (iconLower.includes("audio") || iconLower.includes("headset") || iconLower.includes("headphone") ||
            nameLower.includes("headphone") || nameLower.includes("airpod") || nameLower.includes("headset") || 
            nameLower.includes("arctis") || nameLower.includes("audio")) return "headset"
        else if (iconLower.includes("input-mouse") || nameLower.includes("mouse")) return "mouse"
        else if (iconLower.includes("input-keyboard") || nameLower.includes("keyboard")) return "keyboard"
        else if (iconLower.includes("phone") || nameLower.includes("phone") || nameLower.includes("iphone") || 
                 nameLower.includes("samsung") || nameLower.includes("android")) return "phone"
        else if (iconLower.includes("watch") || nameLower.includes("watch")) return "watch"
        else if (iconLower.includes("audio-speakers") || nameLower.includes("speaker")) return "speaker"
        else if (iconLower.includes("video-display") || nameLower.includes("tv") || nameLower.includes("display")) return "tv"
        
        return "bluetooth"
    }
    
    function startDiscovery() {
        if (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled) {
            Bluetooth.defaultAdapter.discovering = true
            updateDevices()
        }
    }
    
    function stopDiscovery() {
        if (Bluetooth.defaultAdapter) {
            Bluetooth.defaultAdapter.discovering = false
            updateDevices()
        }
    }
    
    function pairDevice(mac) {
        console.log("Pairing device:", mac)
        let device = findDeviceByMac(mac)
        if (device) {
            device.pair()
        }
    }
    
    function connectDevice(mac) {
        console.log("Connecting to device:", mac)
        let device = findDeviceByMac(mac)
        if (device) {
            device.connect()
        }
    }
    
    function removeDevice(mac) {
        console.log("Removing device:", mac)
        let device = findDeviceByMac(mac)
        if (device) {
            device.forget()
        }
    }
    
    function toggleBluetoothDevice(mac) {
        let typedDevice = findDeviceInList(root.bluetoothDevices, mac)
        if (!typedDevice) {
            typedDevice = findDeviceInList(root.availableDevices, mac)
        }
        
        if (typedDevice && typedDevice.nativeDevice) {
            if (typedDevice.connected) {
                console.log("Disconnecting device:", mac)
                typedDevice.connecting = false
                typedDevice.connectionFailed = false
                typedDevice.nativeDevice.connected = false
            } else {
                console.log("Connecting to device:", mac)
                typedDevice.connecting = true
                typedDevice.connectionFailed = false
                
                // Set a timeout to handle connection failure
                Qt.callLater(() => {
                    connectionTimeout.deviceMac = mac
                    connectionTimeout.start()
                })
                
                typedDevice.nativeDevice.connected = true
            }
        }
    }
    
    function toggleBluetooth() {
        if (Bluetooth.defaultAdapter) {
            Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
        }
    }
    
    function findDeviceByMac(mac) {
        let typedDevice = findDeviceInList(root.bluetoothDevices, mac)
        if (typedDevice && typedDevice.nativeDevice) {
            return typedDevice.nativeDevice
        }
        
        typedDevice = findDeviceInList(root.availableDevices, mac)
        if (typedDevice && typedDevice.nativeDevice) {
            return typedDevice.nativeDevice
        }
        
        if (Bluetooth.defaultAdapter) {
            let adapterDevices = Bluetooth.defaultAdapter.devices
            if (adapterDevices.values) {
                for (let device of adapterDevices.values) {
                    if (device && device.address === mac) {
                        return device
                    }
                }
            }
        }
        
        if (Bluetooth.devices.values) {
            for (let device of Bluetooth.devices.values) {
                if (device && device.address === mac) {
                    return device
                }
            }
        }
        return null
    }
    
    
    Timer {
        id: bluetoothMonitorTimer
        interval: 2000
        running: false
        repeat: true
        onTriggered: {
            updateDevices()
        }
    }
    
    function enableMonitoring(enabled) {
        bluetoothMonitorTimer.running = enabled
        if (enabled) {
            refreshBluetoothState()
            updateDevices()
        }
    }
    
    Timer {
        id: bluetoothStateRefreshTimer
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            refreshBluetoothState()
        }
    }
    
    Timer {
        id: connectionTimeout
        interval: 10000  // 10 second timeout
        running: false
        repeat: false
        
        property string deviceMac: ""
        
        onTriggered: {
            if (deviceMac) {
                let typedDevice = findDeviceInList(root.bluetoothDevices, deviceMac)
                if (!typedDevice) {
                    typedDevice = findDeviceInList(root.availableDevices, deviceMac)
                }
                
                if (typedDevice && typedDevice.connecting && !typedDevice.connected) {
                    console.log("Connection timeout for device:", deviceMac)
                    typedDevice.connecting = false
                    typedDevice.connectionFailed = true
                    
                    // Clear failure state after 3 seconds
                    Qt.callLater(() => {
                        clearFailureTimer.deviceMac = deviceMac
                        clearFailureTimer.start()
                    })
                }
                deviceMac = ""
            }
        }
    }
    
    Timer {
        id: clearFailureTimer
        interval: 3000
        running: false
        repeat: false
        
        property string deviceMac: ""
        
        onTriggered: {
            if (deviceMac) {
                let typedDevice = findDeviceInList(root.bluetoothDevices, deviceMac)
                if (!typedDevice) {
                    typedDevice = findDeviceInList(root.availableDevices, deviceMac)
                }
                
                if (typedDevice) {
                    typedDevice.connectionFailed = false
                }
                deviceMac = ""
            }
        }
    }
    
    component BluetoothDevice: QtObject {
        required property string mac
        required property string name
        required property string type
        required property bool paired
        required property bool connected
        required property int battery
        required property string signalStrength
        required property bool canPair
        required property var nativeDevice  // Reference to native Quickshell device
        
        property bool connecting: false
        property bool connectionFailed: false
        
        readonly property string displayName: name
        readonly property bool batteryAvailable: battery >= 0
        readonly property string connectionStatus: {
            if (connecting) return "Connecting..."
            if (connectionFailed) return "Connection Failed"
            if (connected) return "Connected"
            return "Disconnected"
        }
    }
    
    Component {
        id: deviceComponent
        BluetoothDevice {}
    }
}