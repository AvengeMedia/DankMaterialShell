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

    Timer {
        id: startupTimer
        interval: 500
        repeat: false
        running: true
        onTriggered: {
            root.suppressSound = false;
            root.applyPowerProfile();
        }
    }

    Connections {
        target: typeof PowerProfiles !== "undefined" ? PowerProfiles : null
        function onHasPerformanceProfileChanged() {
            root.applyPowerProfile();
        }
    }

    function applyPowerProfile() {
        if (!batteryAvailable)
            return;
        const profileValue = isPluggedIn ? SettingsData.acProfileName : SettingsData.batteryProfileName;
        if (profileValue === "")
            return;
        const targetProfile = parseInt(profileValue);
        if (isNaN(targetProfile) || PowerProfiles.profile === targetProfile)
            return;
        PowerProfileWatcher.applyProfile(targetProfile);
    }

    readonly property string preferredBatteryOverride: Quickshell.env("DMS_PREFERRED_BATTERY")

    // List of laptop batteries
    readonly property var batteries: UPower.devices.values.filter(dev => dev.isLaptopBattery)

    readonly property var readyBatteries: batteries.filter(b => b.ready)
    readonly property var stateKnownBatteries: batteries.filter(b => b.ready && b.state !== UPowerDeviceState.Unknown)
    readonly property var chargeBatteries: readyBatteries.filter(b => root._hasUsableCharge(b))
    readonly property var energyBatteries: readyBatteries.filter(b => b.energyCapacity > 0)

    property real _lastBatteryLevel: 0
    property bool _lastIsCharging: false
    property real _lastChangeRate: 0
    property real _lastBatteryEnergy: 0
    property real _lastBatteryCapacity: 0

    // UPower: 0 means unset. State can be Unknown with a valid Percentage, or Unknown with 0.
    function _hasUsableCharge(dev) {
        if (!dev || !dev.ready)
            return false;
        if (dev.percentage > 0)
            return true;
        return dev.energy > 0 && dev.energyCapacity > 0;
    }

    function _chargePercent(dev) {
        if (!dev)
            return 0;
        if (dev.percentage > 0)
            return Math.min(100, Math.round(dev.percentage * 100));
        if (dev.energy > 0 && dev.energyCapacity > 0)
            return Math.min(100, Math.round((dev.energy * 100) / dev.energyCapacity));
        return 0;
    }

    function _liveChargePercent() {
        if (usePreferred && preferredDevice) {
            if (_hasUsableCharge(preferredDevice))
                return _chargePercent(preferredDevice);
            return 0;
        }

        if (batteries.length > 1 && _hasUsableCharge(UPower.displayDevice))
            return _chargePercent(UPower.displayDevice);

        if (chargeBatteries.length === 1)
            return _chargePercent(chargeBatteries[0]);

        if (chargeBatteries.length > 1) {
            const energyPacks = chargeBatteries.filter(b => b.energy > 0 && b.energyCapacity > 0);
            if (energyPacks.length === chargeBatteries.length) {
                const energy = energyPacks.reduce((sum, b) => sum + b.energy, 0);
                const cap = energyPacks.reduce((sum, b) => sum + b.energyCapacity, 0);
                if (cap > 0)
                    return Math.min(100, Math.round((energy * 100) / cap));
            }

            return Math.min(100, Math.round(chargeBatteries.reduce((sum, b) => sum + _chargePercent(b), 0) / chargeBatteries.length));
        }

        if (_hasUsableCharge(UPower.displayDevice))
            return _chargePercent(UPower.displayDevice);

        return 0;
    }

    function _liveEnergy() {
        if (usePreferred && preferredDevice) {
            if (preferredDeviceReady && preferredDevice.energy > 0)
                return preferredDevice.energy;
            return 0;
        }
        const packs = energyBatteries.filter(b => b.energy > 0);
        if (packs.length === 0)
            return 0;
        return packs.reduce((sum, b) => sum + b.energy, 0);
    }

    function _liveCapacity() {
        if (usePreferred && preferredDevice) {
            if (preferredDeviceReady && preferredDevice.energyCapacity > 0)
                return preferredDevice.energyCapacity;
            return 0;
        }
        if (energyBatteries.length === 0)
            return 0;
        return energyBatteries.reduce((sum, b) => sum + b.energyCapacity, 0);
    }

    readonly property bool usePreferred: preferredBatteryOverride && preferredBatteryOverride.length > 0
    readonly property UPowerDevice preferredDevice: {
        if (!usePreferred)
            return null;
        const override = preferredBatteryOverride.toLowerCase();
        return batteries.find(dev => dev.nativePath.toLowerCase().includes(override)) || null;
    }
    readonly property bool preferredDeviceReady: preferredDevice && preferredDevice.ready
    readonly property bool preferredDeviceKnown: preferredDeviceReady && preferredDevice.state !== UPowerDeviceState.Unknown
    readonly property bool _hasKnownChargingState: {
        if (!batteryAvailable)
            return false;
        if (usePreferred)
            return preferredDeviceKnown;
        return stateKnownBatteries.length > 0;
    }
    readonly property bool _currentIsCharging: {
        if (!batteryAvailable)
            return false;
        if (usePreferred && preferredDeviceKnown)
            return preferredDevice.state === UPowerDeviceState.Charging;
        if (usePreferred)
            return false;
        return stateKnownBatteries.some(b => b.state === UPowerDeviceState.Charging);
    }

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
    readonly property real batteryLevel: {
        if (!batteryAvailable)
            return 0;
        const live = _liveChargePercent();
        return live > 0 ? live : _lastBatteryLevel;
    }
    readonly property bool isCharging: _hasKnownChargingState ? _currentIsCharging : _lastIsCharging

    // Is the system plugged in (Is not running on battery)
    readonly property bool isPluggedIn: !UPower.onBattery
    readonly property bool hasBatteryReading: batteryAvailable && batteryLevel > 0
    readonly property bool isLowBattery: hasBatteryReading && batteryLevel <= SettingsData.batteryLowThreshold
    readonly property bool isCriticalBattery: hasBatteryReading && batteryLevel <= SettingsData.batteryCriticalThreshold
    readonly property color levelCautionColor: "#FFC107"
    readonly property color levelCriticalColor: "#F44336"
    readonly property color levelColor: {
        if (isCharging)
            return Theme.success;
        if (isCriticalBattery)
            return levelCriticalColor;
        if (isLowBattery)
            return Theme.warning;
        if (batteryLevel <= SettingsData.batteryLowThreshold * 2)
            return levelCautionColor;
        return Theme.success;
    }

    property bool _hasNotifiedLowBattery: false
    property bool _hasNotifiedCriticalBattery: false
    property bool _hasNotifiedChargeLimit: false

    function _syncLastIsCharging() {
        if (_hasKnownChargingState)
            _lastIsCharging = _currentIsCharging;
    }

    on_HasKnownChargingStateChanged: _syncLastIsCharging()
    on_CurrentIsChargingChanged: _syncLastIsCharging()

    Component.onCompleted: {
        _syncLastIsCharging();
        if (batteryLevel > 0)
            _lastBatteryLevel = batteryLevel;
        if (batteryEnergy > 0)
            _lastBatteryEnergy = batteryEnergy;
        if (batteryCapacity > 0)
            _lastBatteryCapacity = batteryCapacity;
    }

    // urgency: "critical" (red), "warning" (orange/important), or "info"
    function sendAlert(title, message, urgency, icon, notificationType) {
        if (notificationType === 1) {
            const dbusUrgency = urgency === "critical" ? "critical" : (urgency === "warning" ? "normal" : "low");
            Quickshell.execDetached(["notify-send", "-u", dbusUrgency, "-a", "DMS", "-i", icon, title, message]);
        } else if (urgency === "critical") {
            ToastService.showError(title, message, "", icon);
        } else if (urgency === "warning") {
            ToastService.showWarning(title, message, "", icon);
        } else {
            ToastService.showInfo(title, message, "", icon);
        }
    }

    onBatteryLevelChanged: {
        if (batteryLevel > 0)
            _lastBatteryLevel = batteryLevel;

        if (isCharging && batteryLevel >= SettingsData.batteryChargeLimit) {
            if (!_hasNotifiedChargeLimit && SettingsData.batteryNotifyChargeLimit) {
                _hasNotifiedChargeLimit = true;
                sendAlert(I18n.tr("Charge Limit Reached"), I18n.tr("Battery has charged to your set limit of %1%").arg(SettingsData.batteryChargeLimit), "info", "material:battery_profile", SettingsData.batteryChargeLimitNotificationType);
            }
        } else if (!isCharging || batteryLevel < SettingsData.batteryChargeLimit - 2) {
            _hasNotifiedChargeLimit = false;
        }

        if (isCharging) {
            _hasNotifiedLowBattery = false;
            _hasNotifiedCriticalBattery = false;
            return;
        }

        // Critical battery check (higher priority)
        if (isCriticalBattery) {
            if (!_hasNotifiedCriticalBattery && SettingsData.batteryNotifyCritical) {
                _hasNotifiedCriticalBattery = true;
                sendAlert(I18n.tr("Critical Battery"), I18n.tr("Battery is at %1% - Connect charger immediately!").arg(batteryLevel), "critical", "material:battery_alert", SettingsData.batteryCriticalNotificationType);
            }
            return;
        }

        if (batteryLevel > SettingsData.batteryCriticalThreshold) {
            _hasNotifiedCriticalBattery = false;
        }

        // Low battery check
        if (isLowBattery) {
            if (!_hasNotifiedLowBattery && SettingsData.batteryNotifyLow) {
                _hasNotifiedLowBattery = true;
                sendAlert(I18n.tr("Low Battery"), I18n.tr("Battery is at %1% - Consider charging soon").arg(batteryLevel), "warning", "material:battery_0_bar", SettingsData.batteryLowNotificationType);
            }

            if (SettingsData.batteryAutoPowerSaver && PowerProfileWatcher.available) {
                if (PowerProfileWatcher.currentProfile !== PowerProfile.PowerSaver) {
                    PowerProfileWatcher.applyProfile(PowerProfile.PowerSaver);
                }
            }
        }

        if (batteryLevel > SettingsData.batteryLowThreshold) {
            _hasNotifiedLowBattery = false;
        }
    }

    onIsChargingChanged: {
        // Reset average when switching states
        _smoothedChangeRate = (_hasKnownChargingState && changeRate > 0) ? changeRate : 0;
        _lastRateSampleTime = _smoothedChangeRate > 0 ? Date.now() : 0;

        if (isCharging) {
            _hasNotifiedLowBattery = false;
            _hasNotifiedCriticalBattery = false;
        } else {
            _hasNotifiedChargeLimit = false;
        }
    }

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

        applyPowerProfile();

        if (isPluggedIn) {
            const dismissLow = SettingsData.batteryLowNotificationType === 1 && SettingsData.notificationTimeoutNormal === 0;
            const dismissCritical = SettingsData.batteryCriticalNotificationType === 1 && SettingsData.notificationTimeoutCritical === 0;

            if (dismissLow || dismissCritical) {
                const lowSummary = I18n.tr("Low Battery");
                const criticalSummary = I18n.tr("Critical Battery");

                for (const w of NotificationService.visibleNotifications) {
                    if (!w || !w.notification)
                        continue;

                    const summary = w.notification.summary;

                    if ((dismissLow && summary === lowSummary) || (dismissCritical && summary === criticalSummary)) {
                        NotificationService.dismissNotification(w);
                    }
                }
            }
        }

        previousPluggedState = isPluggedIn;
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

    // Aggregated charge/discharge rate, signed: positive while charging,
    // negative while draining the battery, zero when idle/fully charged.
    readonly property real signedChangeRate: {
        if (!batteryAvailable)
            return 0;
        const rate = Math.abs(changeRate);
        if (!isFinite(rate) || rate < 0.05)
            return 0;
        return isCharging ? rate : -rate;
    }

    // Compact signed wattage for bar widgets, e.g. "+45W" / "-8.4W".
    // Returns an empty string when there is nothing meaningful to show.
    // compact drops the decimal entirely (used by vertical bars).
    function formatPowerRate(compact) {
        const rate = signedChangeRate;
        if (rate === 0)
            return "";
        const magnitude = Math.abs(rate);
        const value = (compact || magnitude >= 10) ? Math.round(magnitude).toString() : magnitude.toFixed(1);
        return `${rate > 0 ? "+" : "-"}${value}W`;
    }

    // A time-weighted exponential moving average based on the aggregated charge/discharge rate
    property real _smoothedChangeRate: 0
    property real _lastRateSampleTime: 0
    readonly property real _rateSmoothingHalfLife: 90 // in seconds

    function _updateSmoothedRate() {
        if (!_hasKnownChargingState || changeRate <= 0)
            return;

        const now = Date.now();
        if (_smoothedChangeRate <= 0 || _lastRateSampleTime <= 0) {
            _smoothedChangeRate = changeRate;
            _lastRateSampleTime = now;
            return;
        }

        const dt = (now - _lastRateSampleTime) / 1000;
        _lastRateSampleTime = now;
        if (dt <= 0)
            return;

        const tau = _rateSmoothingHalfLife / Math.LN2;
        const alpha = 1 - Math.exp(-dt / tau);
        _smoothedChangeRate += alpha * (changeRate - _smoothedChangeRate);
    }

    onChangeRateChanged: _updateSmoothedRate()
    onBatteryAvailableChanged: if (!batteryAvailable) {
        _smoothedChangeRate = 0;
        _lastRateSampleTime = 0;
    }

    // Aggregated battery health
    readonly property string batteryHealth: {
        if (!batteryAvailable)
            return "N/A";

        if (usePreferred && preferredDeviceReady && preferredDevice.healthSupported)
            return `${Math.round(preferredDevice.healthPercentage)}%`;

        const validBatteries = readyBatteries.filter(b => b.healthSupported && b.healthPercentage > 0);
        if (validBatteries.length === 0)
            return "N/A";

        const avgHealth = validBatteries.reduce((sum, b) => sum + b.healthPercentage, 0) / validBatteries.length;
        return `${Math.round(avgHealth)}%`;
    }

    readonly property real batteryEnergy: {
        if (!batteryAvailable)
            return 0;
        const live = _liveEnergy();
        return live > 0 ? live : _lastBatteryEnergy;
    }

    onBatteryEnergyChanged: {
        if (batteryEnergy > 0)
            _lastBatteryEnergy = batteryEnergy;
    }

    readonly property real batteryCapacity: {
        if (!batteryAvailable)
            return 0;
        const live = _liveCapacity();
        return live > 0 ? live : _lastBatteryCapacity;
    }

    onBatteryCapacityChanged: {
        if (batteryCapacity > 0)
            _lastBatteryCapacity = batteryCapacity;
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

    readonly property string batteryStatus: {
        if (!batteryAvailable)
            return I18n.tr("No battery", "battery status");

        if (stateKnownBatteries.length === 0) {
            if (isCharging)
                return I18n.tr("Charging", "battery status");
            return isPluggedIn ? I18n.tr("Plugged In", "battery status") : I18n.tr("Discharging", "battery status");
        }

        if (isCharging && !stateKnownBatteries.some(b => b.changeRate > 0))
            return I18n.tr("Plugged In", "battery status");

        const states = stateKnownBatteries.map(b => b.state);
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

    function estimatedSeconds() {
        if (!batteryAvailable)
            return 0;

        const rate = _smoothedChangeRate > 0 ? _smoothedChangeRate : changeRate;
        const totalTime = (isCharging) ? ((batteryCapacity - batteryEnergy) / rate) : (batteryEnergy / rate);
        const seconds = Math.abs(totalTime * 3600);
        if (!seconds || seconds <= 0 || seconds > 86400)
            return 0;
        return seconds;
    }

    // Format time remaining for charge/discharge
    function formatTimeRemaining() {
        const seconds = estimatedSeconds();
        if (!seconds)
            return "Unknown";

        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`;
    }

    function formatEstimatedTime() {
        const seconds = estimatedSeconds();
        if (!seconds)
            return "";

        const target = new Date(Date.now() + seconds * 1000);
        const use24Hour = SettingsData.use24HourClock !== false;
        return target.toLocaleTimeString(Qt.locale(), use24Hour ? "HH:mm" : "h:mm AP");
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
