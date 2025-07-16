pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Io

Singleton {
    id: root
    
    property bool batteryAvailable: UPower.displayDevice?.isLaptopBattery ?? false
    property int batteryLevel: batteryAvailable ? Math.round(UPower.displayDevice.percentage * 100) : 0
    property string batteryStatus: {
        if (!batteryAvailable) return "No Battery"
        if (UPower.displayDevice.state === UPowerDeviceState.Charging) return "Charging"
        if (UPower.displayDevice.state === UPowerDeviceState.Discharging) return "Discharging"
        if (UPower.displayDevice.state === UPowerDeviceState.FullyCharged) return "Full"
        if (UPower.displayDevice.state === UPowerDeviceState.Empty) return "Empty"
        if (UPower.displayDevice.state === UPowerDeviceState.PendingCharge) return "Pending Charge"
        if (UPower.displayDevice.state === UPowerDeviceState.PendingDischarge) return "Pending Discharge"
        return "Unknown"
    }
    property int timeRemaining: {
        if (!batteryAvailable) return 0
        return UPower.onBattery ? (UPower.displayDevice.timeToEmpty || 0) : (UPower.displayDevice.timeToFull || 0)
    }
    property bool isCharging: batteryAvailable && (UPower.displayDevice.state === UPowerDeviceState.Charging || (!UPower.onBattery && batteryLevel < 100))
    property bool isLowBattery: batteryAvailable && batteryLevel <= 20
    
    property int batteryHealth: batteryAvailable && UPower.displayDevice.healthSupported ? Math.round(UPower.displayDevice.healthPercentage * 100) : 100
    property string batteryTechnology: batteryAvailable ? "Li-ion" : "N/A"
    property int batteryCapacity: batteryAvailable ? Math.round(UPower.displayDevice.energyCapacity * 1000) : 0
    
    property var powerProfiles: {
        if (!powerProfilesAvailable || typeof PowerProfiles === "undefined") {
            return ["power-saver", "balanced", "performance"]
        }
        
        let profiles = [
            PowerProfile.PowerSaver,
            PowerProfile.Balanced,
            PowerProfile.Performance
        ].filter(profile => {
            if (profile === PowerProfile.Performance && !PowerProfiles.hasPerformanceProfile) {
                return false
            }
            return true
        })
        
        return profiles.map(profile => {
            switch(profile) {
                case PowerProfile.PowerSaver: return "power-saver"
                case PowerProfile.Performance: return "performance"
                case PowerProfile.Balanced:
                default: return "balanced"
            }
        })
    }
    property string activePowerProfile: {
        if (powerProfilesAvailable && typeof PowerProfiles !== "undefined") {
            try {
                switch(PowerProfiles.profile) {
                    case PowerProfile.PowerSaver: return "power-saver"
                    case PowerProfile.Performance: return "performance"
                    default: return "balanced"
                }
            } catch (error) {
                return "balanced"
            }
        }
        return "balanced"
    }
    property bool powerProfilesAvailable: false
    property string powerProfilesError: powerProfilesAvailable ? "" : "Power profiles daemon not available. Install and enable power-profiles-daemon."
    property bool suggestPowerSaver: batteryAvailable && isLowBattery && UPower.onBattery && activePowerProfile !== "power-saver"
    
    Process {
        id: checkPowerProfilesDaemon
        command: ["bash", "-c", "systemctl is-active power-profiles-daemon || pgrep -x power-profiles-daemon > /dev/null"]
        running: false
        
        onExited: (exitCode) => {
            powerProfilesAvailable = (exitCode === 0)
        }
    }


    Connections {
        target: UPower
        function onOnBatteryChanged() {
            batteryAvailableChanged()
            isChargingChanged()
        }
    }
    
    Connections {
        target: typeof PowerProfiles !== "undefined" ? PowerProfiles : null
        function onProfileChanged() {
            activePowerProfileChanged()
        }
    }
    
    Connections {
        target: UPower.displayDevice
        function onPercentageChanged() {
            batteryLevelChanged()
            isLowBatteryChanged()
        }
        function onStateChanged() {
            batteryStatusChanged()
            isChargingChanged()
        }
        function onTimeToEmptyChanged() {
            timeRemainingChanged()
        }
        function onTimeToFullChanged() {
            timeRemainingChanged()
        }
        function onReadyChanged() {
            batteryAvailableChanged()
        }
        function onIsLaptopBatteryChanged() {
            batteryAvailableChanged()
        }
        function onEnergyChanged() {
            batteryCapacityChanged()
        }
        function onEnergyCapacityChanged() {
            batteryCapacityChanged()
        }
        function onHealthPercentageChanged() {
            batteryHealthChanged()
        }
    }

    Component.onCompleted: {
        checkPowerProfilesDaemon.running = true
    }
    
    signal showErrorMessage(string message)
    
    function setBatteryProfile(profileName) {
        console.log("Setting power profile to:", profileName)
        
        if (!powerProfilesAvailable) {
            console.warn("Power profiles daemon not available")
            showErrorMessage("power-profiles-daemon not available")
            return
        }
        
        try {
            switch(profileName) {
                case "power-saver":
                    PowerProfiles.profile = PowerProfile.PowerSaver
                    break
                case "balanced":
                    PowerProfiles.profile = PowerProfile.Balanced
                    break
                case "performance":
                    PowerProfiles.profile = PowerProfile.Performance
                    break
                default:
                    console.warn("Unknown profile:", profileName)
                    return
            }
            console.log("Power profile set successfully to:", PowerProfiles.profile)
        } catch (error) {
            console.error("Failed to set power profile:", error)
            showErrorMessage("power-profiles-daemon not available")
        }
    }
    
    function getBatteryIcon() {
        if (!batteryAvailable) {
            switch(activePowerProfile) {
                case "power-saver": return "energy_savings_leaf"
                case "performance": return "rocket_launch"
                default: return "balance"
            }
        }
        
        const level = batteryLevel
        const charging = isCharging
        
        if (charging) {
            if (level >= 90) return "battery_charging_full"
            if (level >= 80) return "battery_charging_90"
            if (level >= 60) return "battery_charging_80"
            if (level >= 50) return "battery_charging_60"
            if (level >= 30) return "battery_charging_50"
            if (level >= 20) return "battery_charging_30"
            return "battery_charging_20"
        } else {
            if (level >= 95) return "battery_full"
            if (level >= 85) return "battery_6_bar"
            if (level >= 70) return "battery_5_bar"
            if (level >= 55) return "battery_4_bar"
            if (level >= 40) return "battery_3_bar"
            if (level >= 25) return "battery_2_bar"
            if (level >= 10) return "battery_1_bar"
            return "battery_alert"
        }
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
}