import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    // Debug mode for testing (disabled for now)
    property bool debugMode: false
    
    // Battery properties - using shell command method (native UPower API commented out due to issues)
    property bool batteryAvailable: systemBatteryPercentage > 0
    property int batteryLevel: systemBatteryPercentage
    property string batteryStatus: {
        return systemBatteryState === "charging" ? "Charging" : 
               systemBatteryState === "discharging" ? "Discharging" :
               systemBatteryState === "fully-charged" ? "Full" :
               systemBatteryState === "empty" ? "Empty" : "Unknown"
    }
    property int timeRemaining: 0  // Not implemented for shell fallback
    property bool isCharging: systemBatteryState === "charging"
    property bool isLowBattery: systemBatteryPercentage <= 20
    
    /* Native UPower API (commented out - not working correctly, returns 1% instead of actual values)
    property bool batteryAvailable: (UPower.displayDevice && UPower.displayDevice.ready && UPower.displayDevice.percentage > 0) || systemBatteryPercentage > 0
    property int batteryLevel: {
        if (UPower.displayDevice && UPower.displayDevice.ready && UPower.displayDevice.percentage > 0) {
            return Math.round(UPower.displayDevice.percentage)
        }
        return systemBatteryPercentage
    }
    property string batteryStatus: {
        if (UPower.displayDevice && UPower.displayDevice.ready) {
            switch(UPower.displayDevice.state) {
                case UPowerDeviceState.Charging: return "Charging"
                case UPowerDeviceState.Discharging: return "Discharging"
                case UPowerDeviceState.FullyCharged: return "Full"
                case UPowerDeviceState.Empty: return "Empty"
                case UPowerDeviceState.PendingCharge: return "Pending Charge"
                case UPowerDeviceState.PendingDischarge: return "Pending Discharge"
                case UPowerDeviceState.Unknown: 
                default: return "Unknown"
            }
        }
        return systemBatteryState === "charging" ? "Charging" : 
               systemBatteryState === "discharging" ? "Discharging" :
               systemBatteryState === "fully-charged" ? "Full" :
               systemBatteryState === "empty" ? "Empty" : "Unknown"
    }
    property int timeRemaining: (UPower.displayDevice && UPower.displayDevice.ready) ? (UPower.displayDevice.timeToEmpty || UPower.displayDevice.timeToFull || 0) : 0
    property bool isCharging: {
        if (UPower.displayDevice && UPower.displayDevice.ready) {
            return UPower.displayDevice.state === UPowerDeviceState.Charging
        }
        return systemBatteryState === "charging"
    }
    property bool isLowBattery: {
        if (UPower.displayDevice && UPower.displayDevice.ready) {
            return UPower.displayDevice.percentage <= 20
        }
        return systemBatteryPercentage <= 20
    }
    */
    property int batteryHealth: 100  // Default fallback
    property string batteryTechnology: "Li-ion"  // Default fallback
    property int cycleCount: 0  // Not implemented for shell fallback
    property int batteryCapacity: 45000  // Default fallback
    property var powerProfiles: availableProfiles
    property string activePowerProfile: "balanced"  // Default fallback
    
    // System battery info from shell command (primary source)
    property int systemBatteryPercentage: 100  // Default value, will be updated by shell command
    property string systemBatteryState: "charging"  // Default value, will be updated by shell command
    
    // Shell command fallback for battery info
    Process {
        id: batteryProcess
        running: false
        command: ["upower", "-i", "/org/freedesktop/UPower/devices/battery_BAT1"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    let output = text.trim()
                    let percentageMatch = output.match(/percentage:\s*(\d+)%/)
                    let stateMatch = output.match(/state:\s*(\w+)/)
                    
                    if (percentageMatch) {
                        root.systemBatteryPercentage = parseInt(percentageMatch[1])
                        console.log("Battery percentage updated to:", root.systemBatteryPercentage)
                    }
                    if (stateMatch) {
                        root.systemBatteryState = stateMatch[1]
                        console.log("Battery state updated to:", root.systemBatteryState)
                    }
                }
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("Battery process failed with exit code:", exitCode)
            }
        }
    }
    
    
    // Timer to periodically check battery status
    Timer {
        interval: 5000  // Check every 5 seconds
        running: true
        repeat: true
        onTriggered: {
            batteryProcess.running = true
        }
    }
    
    Component.onCompleted: {
        // Initial battery check
        batteryProcess.running = true
        // Get current power profile
        getCurrentProfile()
        console.log("BatteryService initialized with shell command approach")
    }
    
    property var availableProfiles: {
        // Try to use power-profiles-daemon via shell command
        return ["power-saver", "balanced", "performance"]
    }
    
    function setBatteryProfile(profileName) {
        console.log("Setting power profile to:", profileName)
        powerProfileProcess.command = ["powerprofilesctl", "set", profileName]
        powerProfileProcess.running = true
    }
    
    // Process to set power profile
    Process {
        id: powerProfileProcess
        running: false
        
        onExited: (exitCode) => {
            if (exitCode === 0) {
                console.log("Power profile set successfully")
                // Update current profile
                getCurrentProfile()
            } else {
                console.warn("Failed to set power profile, exit code:", exitCode)
            }
        }
    }
    
    // Process to get current power profile
    Process {
        id: getCurrentProfileProcess
        running: false
        command: ["powerprofilesctl", "get"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    root.activePowerProfile = text.trim()
                    console.log("Current power profile:", root.activePowerProfile)
                }
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("Failed to get current power profile, exit code:", exitCode)
            }
        }
    }
    
    function getCurrentProfile() {
        getCurrentProfileProcess.running = true
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