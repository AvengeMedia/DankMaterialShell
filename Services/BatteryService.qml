pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
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

    MediaPlayer {
        id: powerPlugSound
        source: Qt.resolvedUrl("../assets/sounds/plasma/power-plug.ogg")
        audioOutput: AudioOutput {
            volume: 1.0
        }
    }

    MediaPlayer {
        id: powerUnplugSound
        source: Qt.resolvedUrl("../assets/sounds/plasma/power-unplug.ogg")
        audioOutput: AudioOutput {
            volume: 1.0
        }
    }

    readonly property string preferredBatteryOverride: Quickshell.env("DMS_PREFERRED_BATTERY")

    readonly property UPowerDevice device: {
        var preferredDev
        if (preferredBatteryOverride && preferredBatteryOverride.length > 0) {
            preferredDev = UPower.devices.values.find(dev => dev.nativePath.toLowerCase().includes(preferredBatteryOverride.toLowerCase()))
        }
        return preferredDev || UPower.devices.values.find(dev => dev.isLaptopBattery) || null
    }
    readonly property bool batteryAvailable: device && device.ready
    readonly property real batteryLevel: batteryAvailable ? Math.round(device.percentage * 100) : 0
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
                powerPlugSound.play()
            } else if (!isPluggedIn && previousPluggedState) {
                powerUnplugSound.play()
            }
        }

        previousPluggedState = isPluggedIn
    }
    readonly property string batteryHealth: {
        if (!batteryAvailable) {
            return "N/A"
        }

        if (device.healthSupported && device.healthPercentage > 0) {
            return `${Math.round(device.healthPercentage)}%`
        }

        return "N/A"
    }
    readonly property real batteryCapacity: batteryAvailable && device.energyCapacity > 0 ? device.energyCapacity : 0
    readonly property string batteryStatus: {
        if (!batteryAvailable) {
            return "No Battery"
        }

        if (device.state === UPowerDeviceState.Charging && device.changeRate <= 0) {
            return "Plugged In"
        }

        return UPowerDeviceState.toString(device.state)
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

    function formatTimeRemaining() {
        if (!batteryAvailable) {
            return "Unknown"
        }

        const timeSeconds = isCharging ? device.timeToFull : device.timeToEmpty

        if (!timeSeconds || timeSeconds <= 0 || timeSeconds > 86400) {
            return "Unknown"
        }

        const hours = Math.floor(timeSeconds / 3600)
        const minutes = Math.floor((timeSeconds % 3600) / 60)

        if (hours > 0) {
            return `${hours}h ${minutes}m`
        }

        return `${minutes}m`
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
