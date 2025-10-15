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
    readonly property var batteries: UPower.devices.values.filter(dev => dev.isLaptopBattery)

    readonly property bool usePreferred: preferredBatteryOverride && preferredBatteryOverride.length > 0

    // Main battery (for backward compatibility)
    readonly property UPowerDevice device: {
        var preferredDev
        if (usePreferred) {
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
    // Is any battery charging (at least one has changeRate > 0)
    readonly property bool isCharging: batteryAvailable && batteries.some(b => b.state === UPowerDeviceState.Charging && b.changeRate > 0)

    // Is the system plugged in (none of the batteries are discharging or empty)
    readonly property bool isPluggedIn: batteryAvailable && batteries.every(b => b.state !== UPowerDeviceState.Discharging)
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
        if (usePreferred && device && device.ready) return device.changeRate
        return batteries.length > 0 ? batteries.reduce((sum, b) => sum + b.changeRate, 0) : 0
    }

    // Aggregated battery health
    readonly property string batteryHealth: {
        if (!batteryAvailable) return "N/A"

        // If a preferred battery is selected and ready
        if (usePreferred && device && device.ready && device.healthSupported) return `${Math.round(device.healthPercentage)}%`

        // Otherwise, calculate the average health of all laptop batteries
        const validBatteries = batteries.filter(b => b.healthSupported && b.healthPercentage > 0)
        if (validBatteries.length === 0) return "N/A"

        const avgHealth = validBatteries.reduce((sum, b) => sum + b.healthPercentage, 0) / validBatteries.length
        return `${Math.round(avgHealth)}%`
    }

    readonly property real batteryEnergy: {
        if (!batteryAvailable) return 0
        if (usePreferred && device && device.ready) return device.energy
        return batteries.length > 0 ? batteries.reduce((sum, b) => sum + b.energy, 0) : 0
    }

    // Total battery capacity (Wh)
    readonly property real batteryCapacity: {
        if (!batteryAvailable) return 0
        if (usePreferred && device && device.ready) return device.energyCapacity
        return batteries.length > 0 ? batteries.reduce((sum, b) => sum + b.energyCapacity, 0) : 0
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
