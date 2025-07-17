pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root
    
    readonly property var device: UPower.displayDevice
    readonly property bool batteryAvailable: device && device.ready && device.isLaptopBattery
    readonly property int batteryLevel: batteryAvailable ? device.percentage * 100.0 : 0
    readonly property bool isCharging: batteryAvailable && device.state === UPowerDeviceState.Charging
    readonly property bool isLowBattery: batteryAvailable && batteryLevel <= 20
    readonly property string batteryHealth: batteryAvailable && device.healthSupported ? Math.round(device.healthPercentage * 100.0) + "%" : "N/A"
    readonly property real batteryCapacity: batteryAvailable && device.energyCapacity > 0 ? device.energyCapacity : 0
    
    readonly property string batteryStatus: {
        if (!batteryAvailable) return "No Battery"
        return UPowerDeviceState.toString(device.state)
    }
    
    readonly property int timeRemaining: {
        if (!batteryAvailable) return 0
        return isCharging ? (device.timeToFull || 0) : (device.timeToEmpty || 0)
    }
    
    readonly property bool suggestPowerSaver: batteryAvailable && isLowBattery && UPower.onBattery && (typeof PowerProfiles !== "undefined" && PowerProfiles.profile !== PowerProfile.PowerSaver)
    
    readonly property var bluetoothDevices: {
        var btDevices = []
        for (var i = 0; i < UPower.devices.count; i++) {
            var dev = UPower.devices.get(i)
            if (dev && dev.ready && (dev.type === UPowerDeviceType.BluetoothGeneric || 
                                   dev.type === UPowerDeviceType.Headphones ||
                                   dev.type === UPowerDeviceType.Headset ||
                                   dev.type === UPowerDeviceType.Keyboard ||
                                   dev.type === UPowerDeviceType.Mouse ||
                                   dev.type === UPowerDeviceType.Speakers)) {
                btDevices.push({
                    name: dev.model || UPowerDeviceType.toString(dev.type),
                    percentage: Math.round(dev.percentage),
                    type: dev.type
                })
            }
        }
        return btDevices
    }
    
    function formatTimeRemaining() {
        if (!batteryAvailable || timeRemaining <= 0) return "Unknown"
        
        const hours = Math.floor(timeRemaining / 3600)
        const minutes = Math.floor((timeRemaining % 3600) / 60)
        
        if (hours > 0) {
            return hours + "h " + minutes + "m"
        } else {
            return minutes + "m"
        }
    }
    
    function getBluetoothDevices() {
        return bluetoothDevices
    }
}