pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.Common

Singleton {
    id: root

    property bool suppressSound: true
    property bool previousPluggedState: false

    readonly property var scale: 100 / SettingsData.batteryChargeLimit

    Timer {
        id: startupTimer
        interval: 500
        repeat: false
        running: true
        onTriggered: {
            root.suppressSound = false;
            DisplayService.requestSync("startup");
        }
    }

    readonly property string preferredBatteryOverride: Quickshell.env("DMS_PREFERRED_BATTERY")

    // List of laptop batteries
    readonly property var batteries: UPower.devices.values.filter(dev => dev.isLaptopBattery)

    readonly property var readyBatteries: batteries.filter(b => b.ready)
    readonly property var stateKnownBatteries: batteries.filter(b => b.ready && b.state !== UPowerDeviceState.Unknown)

    property real _lastBatteryLevel: 0
    property bool _lastIsCharging: false
    property real _lastChangeRate: 0
    property real _lastBatteryEnergy: 0
    property real _lastBatteryCapacity: 0

    readonly property bool usePreferred: preferredBatteryOverride && preferredBatteryOverride.length > 0
    readonly property UPowerDevice preferredDevice: {
        if (!usePreferred)
            return null;
        const override = preferredBatteryOverride.toLowerCase();
        return batteries.find(dev => dev.nativePath.toLowerCase().includes(override)) || null;
    }
    readonly property bool preferredDeviceKnown: preferredDevice && preferredDevice.ready && preferredDevice.state !== UPowerDeviceState.Unknown

    // Main battery (for backward compatibility)
    readonly property UPowerDevice device: {
        if (usePreferred) {
            if (preferredDeviceKnown)
                return preferredDevice;
            return stateKnownBatteries[0] || null;
        }
        return stateKnownBatteries[0] || readyBatteries[0] || batteries[0] || null;
    }
    // Whether at least one battery is available
    readonly property bool batteryAvailable: batteries.length > 0
    // Aggregated charge level (percentage)
    readonly property real batteryLevel: {
        if (!batteryAvailable)
            return 0;
        if (batteryCapacity === 0) {
            if (usePreferred && preferredDeviceKnown) {
                const val = Math.round(preferredDevice.percentage * 100 * scale);
                _lastBatteryLevel = val;
                return val;
            }
            if (usePreferred && preferredDevice)
                return _lastBatteryLevel;
            const validBatteries = stateKnownBatteries.filter(b => b.ready && b.percentage >= 0);
            if (validBatteries.length === 0)
                return _lastBatteryLevel;
            const avgPercentage = validBatteries.reduce((sum, b) => sum + b.percentage, 0) / validBatteries.length;
            const val = Math.round(avgPercentage * 100 * scale);
            _lastBatteryLevel = val;
            return val;
        }
        const energy = batteryEnergy;
        const cap = batteryCapacity;
        if (cap === 0)
            return _lastBatteryLevel;
        const val = Math.round((energy * 100) / cap * scale);
        _lastBatteryLevel = val;
        return val;
    }
    readonly property bool isCharging: {
        if (!batteryAvailable)
            return false;
        if (usePreferred && preferredDeviceKnown) {
            const preferredCharging = preferredDevice.state === UPowerDeviceState.Charging;
            _lastIsCharging = preferredCharging;
            return preferredCharging;
        }
        if (usePreferred && preferredDevice)
            return _lastIsCharging;
        const val = stateKnownBatteries.some(b => b.state === UPowerDeviceState.Charging);
        if (stateKnownBatteries.length > 0)
            _lastIsCharging = val;
        return stateKnownBatteries.length > 0 ? val : _lastIsCharging;
    }

    // Is the system plugged in (Is not running on battery)
    readonly property bool isPluggedIn: !UPower.onBattery
    readonly property bool isLowBattery: batteryAvailable && batteryLevel <= 20

    onIsPluggedInChanged: {
        if (suppressSound || !batteryAvailable) {
            previousPluggedState = isPluggedIn;
            return;
        }

        if (SettingsData.soundsEnabled && SettingsData.soundPluggedIn) {
            if (isPluggedIn && !previousPluggedState) {
                AudioService.playPowerPlugSound();
            } else if (!isPluggedIn && previousPluggedState) {
                AudioService.playPowerUnplugSound();
            }
        }

        const profileValue = BatteryService.isPluggedIn ? SettingsData.acProfileName : SettingsData.batteryProfileName;

        if (profileValue !== "") {
            const targetProfile = parseInt(profileValue);
            if (!isNaN(targetProfile) && PowerProfiles.profile !== targetProfile) {
                PowerProfiles.profile = targetProfile;
            }
        }

        DisplayService.requestSync("power-change");

        previousPluggedState = isPluggedIn;
    }

    Connections {
        target: SettingsData
        function onLowerDisplayRefreshRateOnBatteryChanged() {
            DisplayService.requestSync("setting-change");
        }

        function onActiveDisplayProfileChanged() {
            DisplayService.requestSync("profile-change");
        }

        function onActiveDisplayProfileModesChanged() {
            DisplayService.requestSync("profile-change");
        }
    }

    Connections {
        target: NiriService
        function onOutputsChanged() {
            DisplayService.requestSync("output-change");
        }
    }

    Connections {
        target: WlrOutputService
        function onStateChanged() {
            DisplayService.requestSync("output-change");
        }
    }

    // Aggregated charge/discharge rate
    readonly property real changeRate: {
        if (!batteryAvailable)
            return 0;
        if (usePreferred && preferredDeviceKnown) {
            _lastChangeRate = preferredDevice.changeRate;
            return _lastChangeRate;
        }
        if (usePreferred && preferredDevice)
            return _lastChangeRate;
        if (stateKnownBatteries.length === 0)
            return _lastChangeRate;
        const val = stateKnownBatteries.reduce((sum, b) => sum + b.changeRate, 0);
        _lastChangeRate = val;
        return val;
    }

    // Aggregated battery health
    readonly property string batteryHealth: {
        if (!batteryAvailable)
            return "N/A";

        if (usePreferred && preferredDeviceKnown && preferredDevice.healthSupported)
            return `${Math.round(preferredDevice.healthPercentage)}%`;

        const validBatteries = stateKnownBatteries.filter(b => b.ready && b.healthSupported && b.healthPercentage > 0);
        if (validBatteries.length === 0)
            return "N/A";

        const avgHealth = validBatteries.reduce((sum, b) => sum + b.healthPercentage, 0) / validBatteries.length;
        return `${Math.round(avgHealth)}%`;
    }

    readonly property real batteryEnergy: {
        if (!batteryAvailable)
            return 0;
        if (usePreferred && preferredDeviceKnown) {
            _lastBatteryEnergy = preferredDevice.energy;
            return _lastBatteryEnergy;
        }
        if (usePreferred && preferredDevice)
            return _lastBatteryEnergy;
        if (stateKnownBatteries.length === 0)
            return _lastBatteryEnergy;
        const val = stateKnownBatteries.reduce((sum, b) => sum + b.energy, 0);
        _lastBatteryEnergy = val;
        return val;
    }

    // Total battery capacity (Wh)
    readonly property real batteryCapacity: {
        if (!batteryAvailable)
            return 0;
        if (usePreferred && preferredDeviceKnown) {
            _lastBatteryCapacity = preferredDevice.energyCapacity;
            return _lastBatteryCapacity;
        }
        if (usePreferred && preferredDevice)
            return _lastBatteryCapacity;
        if (stateKnownBatteries.length === 0)
            return _lastBatteryCapacity;
        const val = stateKnownBatteries.reduce((sum, b) => sum + b.energyCapacity, 0);
        _lastBatteryCapacity = val;
        return val;
    }

    function translateBatteryState(state) {
        switch (state) {
        case UPowerDeviceState.Charging:
            return I18n.tr("Charging", "battery status");
        case UPowerDeviceState.Discharging:
            return I18n.tr("Discharging", "battery status");
        case UPowerDeviceState.Empty:
            return I18n.tr("Empty", "battery status");
        case UPowerDeviceState.FullyCharged:
            return I18n.tr("Fully Charged", "battery status");
        case UPowerDeviceState.PendingCharge:
            return I18n.tr("Pending Charge", "battery status");
        case UPowerDeviceState.PendingDischarge:
            return I18n.tr("Pending Discharge", "battery status");
        default:
            return I18n.tr("Unknown", "battery status");
        }
    }

    // Aggregated battery status
    readonly property string batteryStatus: {
        if (!batteryAvailable) {
            return I18n.tr("No battery", "battery status");
        }

        const targetBatteries = stateKnownBatteries.length > 0 ? stateKnownBatteries : batteries;

        if (isCharging && !targetBatteries.some(b => b.changeRate > 0))
            return I18n.tr("Plugged In", "battery status");

        const states = targetBatteries.map(b => b.state);
        if (states.every(s => s === states[0]))
            return translateBatteryState(states[0]);

        return isCharging ? I18n.tr("Charging", "battery status") : (isPluggedIn ? I18n.tr("Plugged In", "battery status") : I18n.tr("Discharging", "battery status"));
    }

    readonly property bool suggestPowerSaver: false

    readonly property var bluetoothDevices: {
        const bluetoothTypes = [UPowerDeviceType.BluetoothGeneric, UPowerDeviceType.Headphones, UPowerDeviceType.Headset, UPowerDeviceType.Keyboard, UPowerDeviceType.Mouse, UPowerDeviceType.Speakers];

        const btDevices = UPower.devices.values.filter(dev => dev && dev.ready && bluetoothTypes.includes(dev.type)).map(dev => {
            return {
                "name": dev.model || UPowerDeviceType.toString(dev.type),
                "percentage": Math.round(dev.percentage * 100),
                "type": dev.type
            };
        });

        return btDevices;
    }

    // Format time remaining for charge/discharge
    function formatTimeRemaining() {
        if (!batteryAvailable) {
            return "Unknown";
        }

        let totalTime = 0;
        totalTime = (isCharging) ? ((batteryCapacity - batteryEnergy) / changeRate) : (batteryEnergy / changeRate);
        const avgTime = Math.abs(totalTime * 3600);
        if (!avgTime || avgTime <= 0 || avgTime > 86400)
            return "Unknown";

        const hours = Math.floor(avgTime / 3600);
        const minutes = Math.floor((avgTime % 3600) / 60);
        return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`;
    }

    function getBatteryIcon() {
        if (!batteryAvailable) {
            return "power";
        }

        if (isCharging) {
            if (batteryLevel >= 90) {
                return "battery_charging_full";
            }
            if (batteryLevel >= 80) {
                return "battery_charging_90";
            }
            if (batteryLevel >= 60) {
                return "battery_charging_80";
            }
            if (batteryLevel >= 50) {
                return "battery_charging_60";
            }
            if (batteryLevel >= 30) {
                return "battery_charging_50";
            }
            if (batteryLevel >= 20) {
                return "battery_charging_30";
            }
            return "battery_charging_20";
        }
        if (isPluggedIn) {
            if (batteryLevel >= 90) {
                return "battery_charging_full";
            }
            if (batteryLevel >= 80) {
                return "battery_charging_90";
            }
            if (batteryLevel >= 60) {
                return "battery_charging_80";
            }
            if (batteryLevel >= 50) {
                return "battery_charging_60";
            }
            if (batteryLevel >= 30) {
                return "battery_charging_50";
            }
            if (batteryLevel >= 20) {
                return "battery_charging_30";
            }
            return "battery_charging_20";
        }
        if (batteryLevel >= 95) {
            return "battery_full";
        }
        if (batteryLevel >= 85) {
            return "battery_6_bar";
        }
        if (batteryLevel >= 70) {
            return "battery_5_bar";
        }
        if (batteryLevel >= 55) {
            return "battery_4_bar";
        }
        if (batteryLevel >= 40) {
            return "battery_3_bar";
        }
        if (batteryLevel >= 25) {
            return "battery_2_bar";
        }
        return "battery_1_bar";
    }
}
