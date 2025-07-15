import QtQuick
import Quickshell
import Quickshell.Services.UPower
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    // Debug mode for testing on desktop systems without batteries
    property bool debugMode: false  // Set to true to enable fake battery for testing
    
    // Debug fake battery data
    property int debugBatteryLevel: 65
    property string debugBatteryStatus: "Discharging"
    property int debugTimeRemaining: 7200  // 2 hours in seconds
    property bool debugIsCharging: false
    property int debugBatteryHealth: 88
    property string debugBatteryTechnology: "Li-ion"
    property int debugBatteryCapacity: 45000  // 45 Wh in mWh
    
    property bool batteryAvailable: debugMode || (battery.ready && battery.isLaptopBattery)
    property int batteryLevel: debugMode ? debugBatteryLevel : Math.round(battery.percentage)
    property string batteryStatus: debugMode ? debugBatteryStatus : UPowerDeviceState.toString(battery.state)
    property int timeRemaining: debugMode ? debugTimeRemaining : (battery.timeToEmpty || battery.timeToFull)
    property bool isCharging: debugMode ? debugIsCharging : (battery.state === UPowerDeviceState.Charging)
    property bool isLowBattery: debugMode ? (debugBatteryLevel <= 20) : (battery.percentage <= 20)
    property int batteryHealth: debugMode ? debugBatteryHealth : (battery.healthSupported ? Math.round(battery.healthPercentage) : 100)
    property string batteryTechnology: {
        if (debugMode) return debugBatteryTechnology
        
        // Try to get technology from any available laptop battery
        for (let i = 0; i < UPower.devices.length; i++) {
            let device = UPower.devices[i]
            if (device.isLaptopBattery && device.ready) {
                // UPower doesn't expose technology directly, but we can get it from the model
                let model = device.model || ""
                if (model.toLowerCase().includes("li-ion") || model.toLowerCase().includes("lithium")) {
                    return "Li-ion"
                } else if (model.toLowerCase().includes("li-po") || model.toLowerCase().includes("polymer")) {
                    return "Li-polymer"
                } else if (model.toLowerCase().includes("nimh")) {
                    return "NiMH"
                }
            }
        }
        return "Unknown"
    }
    property int cycleCount: 0  // UPower doesn't expose cycle count
    property int batteryCapacity: debugMode ? debugBatteryCapacity : Math.round(battery.energyCapacity * 1000)
    property var powerProfiles: availableProfiles
    property string activePowerProfile: PowerProfile.toString(PowerProfiles.profile)
    
    property var battery: UPower.displayDevice
    
    property var availableProfiles: {
        let profiles = []
        if (PowerProfiles.profile !== undefined) {
            profiles.push("power-saver")
            profiles.push("balanced")
            if (PowerProfiles.hasPerformanceProfile) {
                profiles.push("performance")
            }
        }
        return profiles
    }
    
    // Timer to simulate battery changes in debug mode
    Timer {
        id: debugTimer
        interval: 5000  // Update every 5 seconds
        running: debugMode
        repeat: true
        onTriggered: {
            // Simulate battery discharge/charge
            if (debugIsCharging) {
                debugBatteryLevel = Math.min(100, debugBatteryLevel + 1)
                if (debugBatteryLevel >= 100) {
                    debugBatteryStatus = "Full"
                    debugIsCharging = false
                }
            } else {
                debugBatteryLevel = Math.max(0, debugBatteryLevel - 1)
                if (debugBatteryLevel <= 15) {
                    debugBatteryStatus = "Charging"
                    debugIsCharging = true
                }
            }
            
            // Update time remaining
            debugTimeRemaining = debugIsCharging ? 
                Math.max(0, debugTimeRemaining - 300) :  // 5 minutes less to full
                Math.max(0, debugTimeRemaining - 300)    // 5 minutes less remaining
        }
    }
    
    function setBatteryProfile(profileName) {
        let profile = PowerProfile.Balanced
        
        if (profileName === "power-saver") {
            profile = PowerProfile.PowerSaver
        } else if (profileName === "balanced") {
            profile = PowerProfile.Balanced
        } else if (profileName === "performance") {
            if (PowerProfiles.hasPerformanceProfile) {
                profile = PowerProfile.Performance
            } else {
                console.warn("Performance profile not available")
                return
            }
        } else {
            console.warn("Invalid power profile:", profileName)
            return
        }
        
        console.log("Setting power profile to:", profileName)
        PowerProfiles.profile = profile
    }
    
    function getBatteryIcon() {
        if (!root.batteryAvailable) return "power"
        
        let level = root.batteryLevel
        let charging = root.isCharging
        
        if (charging) {
            if (level >= 90) return "battery_charging_full"
            if (level >= 60) return "battery_charging_90"
            if (level >= 30) return "battery_charging_60"
            if (level >= 20) return "battery_charging_30"
            return "battery_charging_20"
        } else {
            if (level >= 90) return "battery_full"
            if (level >= 60) return "battery_6_bar"
            if (level >= 50) return "battery_5_bar"
            if (level >= 40) return "battery_4_bar"
            if (level >= 30) return "battery_3_bar"
            if (level >= 20) return "battery_2_bar"
            if (level >= 10) return "battery_1_bar"
            return "battery_alert"
        }
    }
    
    function formatTimeRemaining() {
        if (root.timeRemaining <= 0) return "Unknown"
        
        let hours = Math.floor(root.timeRemaining / 3600)
        let minutes = Math.floor((root.timeRemaining % 3600) / 60)
        
        if (hours > 0) {
            return hours + "h " + minutes + "m"
        } else {
            return minutes + "m"
        }
    }
}