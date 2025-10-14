pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Common

Singleton {
    id: root

    property bool suppressSound: true
    property bool previousPluggedState: false

    Timer {
        id: startupTimer
        interval: 500
        repeat: false
        running: true
        onTriggered: root.suppressSound = false
    }

    readonly property string preferredBatteryOverride: Quickshell.env("DMS_PREFERRED_BATTERY")

    // List of laptop batteries
    property var batteries: []

    // Connections to monitor UPower devices model changes
    property var devicesConnection: Connections {
        target: UPower.devices

        function onRowsInserted() {
            Qt.callLater(root.updateBatteries)
        }
        function onRowsRemoved() {
            Qt.callLater(root.updateBatteries)
        }
        function onModelReset() {
            Qt.callLater(root.updateBatteries)
        }
        function onDataChanged() {
            Qt.callLater(root.updateBatteries)
        }
    }

    // Timer to periodically refresh battery information
    property var updateTimer: Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateBatteries()
    }

    // Update the list of available batteries
    function updateBatteries() {
        const arr = []
        const model = UPower.devices

        if (!model) {
            batteries = arr
            return
        }

        const rowCount = model.rowCount ? model.rowCount() : 0

        for (var i = 0; i < rowCount; i++) {
            const index = model.index(i, 0)
            const dev = model.data(index, 0x0100) // Qt.UserRole

            if (dev && dev.ready && dev.isLaptopBattery) {
                arr.push(dev)
            }
        }

        batteries = arr
    }

    // Main battery (for backward compatibility)
    readonly property UPowerDevice device: {
        var preferredDev
        if (preferredBatteryOverride && preferredBatteryOverride.length > 0) {
            preferredDev = batteries.find(dev => dev.nativePath.toLowerCase().includes(preferredBatteryOverride.toLowerCase()))
        }
        return preferredDev || batteries[0] || null
    }
    // Whether at least one battery is available
    readonly property bool batteryAvailable: batteries.length > 0
    // Aggregated charge level (percentage)
    readonly property real batteryLevel: {
        if (!batteryAvailable)
        return 0
        return Math.round((batteryEnergy * 100) / batteryCapacity)
    }
    readonly property bool isCharging: batteryAvailable && device.state === UPowerDeviceState.Charging && device.changeRate > 0
    readonly property bool isPluggedIn: batteryAvailable && (device.state !== UPowerDeviceState.Discharging && device.state !== UPowerDeviceState.Empty)
    readonly property bool isLowBattery: batteryAvailable && batteryLevel <= 20

    onIsPluggedInChanged: {
        if (suppressSound || !batteryAvailable) {
            previousPluggedState = isPluggedIn
            return
        }

        if (SettingsData.soundsEnabled && SettingsData.soundPluggedIn) {
            if (isPluggedIn && !previousPluggedState) {
                AudioService.playPowerPlugSound()
            } else if (!isPluggedIn && previousPluggedState) {
                AudioService.playPowerUnplugSound()
            }
        }

        previousPluggedState = isPluggedIn
    }

    // Aggregated charge/discharge rate
    readonly property real changeRate: {
        if (!batteryAvailable) return 0
        let total = 0
        for (let b of batteries)
            total += b.changeRate
        return total
    }

    // Aggregated battery health
    readonly property string batteryHealth: {
        if (!batteryAvailable) {
            return "N/A"
        }
        let sum = 0
        let count = 0
        for (let b of batteries) {
            if (b.healthSupported && b.healthPercentage > 0) {
                sum += b.healthPercentage
                count++
            }
        }
        return count > 0 ? `${Math.round(sum / count)}%` : "N/A"
    }

    readonly property real batteryEnergy: {
        if (!batteryAvailable) return 0
        let total = 0
        for (let b of batteries)
            total += b.energy
        return total
    }

    // Total battery capacity (Wh)
    readonly property real batteryCapacity: {
        if (!batteryAvailable) return 0
        let total = 0
        for (let b of batteries)
            total += b.energyCapacity
        return total
    }

    // Aggregated battery status
    readonly property string batteryStatus: {
        if (!batteryAvailable) {
            return "No Battery"
        }

        if (isCharging && !batteries.some(b => b.changeRate > 0)) return "Plugged In"

        const states = batteries.map(b => b.state)
        if (states.every(s => s === states[0])) return UPowerDeviceState.toString(states[0])

        return isCharging ? "Charging" : (isPluggedIn ? "Plugged In" : "Discharging")
    }

    readonly property bool suggestPowerSaver: batteryAvailable && isLowBattery && UPower.onBattery && (typeof PowerProfiles !== "undefined" && PowerProfiles.profile !== PowerProfile.PowerSaver)

    readonly property var bluetoothDevices: {
        const btDevices = []
        const bluetoothTypes = [UPowerDeviceType.BluetoothGeneric, UPowerDeviceType.Headphones, UPowerDeviceType.Headset, UPowerDeviceType.Keyboard, UPowerDeviceType.Mouse, UPowerDeviceType.Speakers]

        for (var i = 0; i < UPower.devices.count; i++) {
            const dev = UPower.devices.get(i)
            if (dev && dev.ready && bluetoothTypes.includes(dev.type)) {
                btDevices.push({
                                   "name": dev.model || UPowerDeviceType.toString(dev.type),
                                   "percentage": Math.round(dev.percentage),
                                   "type": dev.type
                               })
            }
        }
        return btDevices
    }

    // Format time remaining for charge/discharge
    function formatTimeRemaining() {
        if (!batteryAvailable) {
            return "Unknown"
        }

        let totalTime = 0
        totalTime = (isCharging) ? ((batteryCapacity - batteryEnergy) / changeRate) : (batteryEnergy / changeRate)
        const avgTime = Math.abs(totalTime * 3600)
        if (!avgTime || avgTime <= 0 || avgTime > 86400) return "Unknown"

        const hours = Math.floor(avgTime / 3600)
        const minutes = Math.floor((avgTime % 3600) / 60)
        return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`
    }

    function getBatteryIcon() {
        if (!batteryAvailable) {
            return "power"
        }

        if (isCharging) {
            if (batteryLevel >= 90) {
                return "battery_charging_full"
            }
            if (batteryLevel >= 80) {
                return "battery_charging_90"
            }
            if (batteryLevel >= 60) {
                return "battery_charging_80"
            }
            if (batteryLevel >= 50) {
                return "battery_charging_60"
            }
            if (batteryLevel >= 30) {
                return "battery_charging_50"
            }
            if (batteryLevel >= 20) {
                return "battery_charging_30"
            }
            return "battery_charging_20"
        }
        if (isPluggedIn) {
            if (batteryLevel >= 90) {
                return "battery_charging_full"
            }
            if (batteryLevel >= 80) {
                return "battery_charging_90"
            }
            if (batteryLevel >= 60) {
                return "battery_charging_80"
            }
            if (batteryLevel >= 50) {
                return "battery_charging_60"
            }
            if (batteryLevel >= 30) {
                return "battery_charging_50"
            }
            if (batteryLevel >= 20) {
                return "battery_charging_30"
            }
            return "battery_charging_20"
        }
        if (batteryLevel >= 95) {
            return "battery_full"
        }
        if (batteryLevel >= 85) {
            return "battery_6_bar"
        }
        if (batteryLevel >= 70) {
            return "battery_5_bar"
        }
        if (batteryLevel >= 55) {
            return "battery_4_bar"
        }
        if (batteryLevel >= 40) {
            return "battery_3_bar"
        }
        if (batteryLevel >= 25) {
            return "battery_2_bar"
        }
        return "battery_1_bar"
    }
}
