import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    // Battery properties
    property bool batteryAvailable: false
    property int batteryLevel: 0
    property string batteryStatus: "Unknown"
    property int timeRemaining: 0
    property bool isCharging: false
    property bool isLowBattery: false
    property int batteryHealth: 100
    property string batteryTechnology: "Unknown"
    property int cycleCount: 0
    property int batteryCapacity: 0
    property var powerProfiles: []
    property string activePowerProfile: ""
    
    // Check if battery is available
    Process {
        id: batteryAvailabilityChecker
        command: ["bash", "-c", "ls /sys/class/power_supply/ | grep -E '^BAT' | head -1"]
        running: true
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    root.batteryAvailable = true
                    console.log("Battery found:", data.trim())
                    batteryStatusChecker.running = true
                } else {
                    root.batteryAvailable = false
                    console.log("No battery found - this appears to be a desktop system")
                }
            }
        }
    }
    
    // Battery status checker
    Process {
        id: batteryStatusChecker
        command: ["bash", "-c", "if [ -d /sys/class/power_supply/BAT0 ] || [ -d /sys/class/power_supply/BAT1 ]; then upower -i $(upower -e | grep 'BAT') | grep -E 'state|percentage|time to|energy|technology|cycle-count' || acpi -b 2>/dev/null || echo 'fallback'; else echo 'no-battery'; fi"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "no-battery") {
                    root.batteryAvailable = false
                    return
                }
                
                if (text.trim() && text.trim() !== "fallback") {
                    parseBatteryInfo(text.trim())
                } else {
                    // Fallback to simple methods
                    fallbackBatteryChecker.running = true
                }
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("Battery status check failed, trying fallback methods")
                fallbackBatteryChecker.running = true
            }
        }
    }
    
    // Fallback battery checker using /sys files
    Process {
        id: fallbackBatteryChecker
        command: ["bash", "-c", "if [ -f /sys/class/power_supply/BAT0/capacity ]; then BAT=BAT0; elif [ -f /sys/class/power_supply/BAT1/capacity ]; then BAT=BAT1; else echo 'no-battery'; exit 1; fi; echo \"percentage: $(cat /sys/class/power_supply/$BAT/capacity)%\"; echo \"state: $(cat /sys/class/power_supply/$BAT/status 2>/dev/null || echo Unknown)\"; if [ -f /sys/class/power_supply/$BAT/technology ]; then echo \"technology: $(cat /sys/class/power_supply/$BAT/technology)\"; fi; if [ -f /sys/class/power_supply/$BAT/cycle_count ]; then echo \"cycle-count: $(cat /sys/class/power_supply/$BAT/cycle_count)\"; fi"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "no-battery") {
                    parseBatteryInfo(text.trim())
                }
            }
        }
    }
    
    // Power profiles checker (for systems with power-profiles-daemon)
    Process {
        id: powerProfilesChecker
        command: ["bash", "-c", "if command -v powerprofilesctl > /dev/null; then powerprofilesctl list 2>/dev/null; else echo 'not-available'; fi"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "not-available") {
                    parsePowerProfiles(text.trim())
                }
            }
        }
    }
    
    function parseBatteryInfo(batteryText) {
        let lines = batteryText.split('\n')
        
        for (let line of lines) {
            line = line.trim().toLowerCase()
            
            if (line.includes('percentage:') || line.includes('capacity:')) {
                let match = line.match(/(\d+)%?/)
                if (match) {
                    root.batteryLevel = parseInt(match[1])
                    root.isLowBattery = root.batteryLevel <= 20
                }
            } else if (line.includes('state:') || line.includes('status:')) {
                let statusPart = line.split(':')[1]?.trim().toLowerCase() || line
                console.log("Raw battery status line:", line, "extracted status:", statusPart)
                
                if (statusPart === 'charging') {
                    root.batteryStatus = "Charging"
                    root.isCharging = true
                    console.log("Battery is charging")
                } else if (statusPart === 'discharging') {
                    root.batteryStatus = "Discharging"
                    root.isCharging = false
                    console.log("Battery is discharging")
                } else if (statusPart === 'full') {
                    root.batteryStatus = "Full"
                    root.isCharging = false
                    console.log("Battery is full")
                } else if (statusPart === 'not charging') {
                    root.batteryStatus = "Not charging"
                    root.isCharging = false
                    console.log("Battery is not charging")
                } else {
                    root.batteryStatus = statusPart.charAt(0).toUpperCase() + statusPart.slice(1) || "Unknown"
                    root.isCharging = false
                    console.log("Battery status unknown:", statusPart)
                }
            } else if (line.includes('time to')) {
                let match = line.match(/(\d+):(\d+)/)
                if (match) {
                    root.timeRemaining = parseInt(match[1]) * 60 + parseInt(match[2])
                }
            } else if (line.includes('technology:')) {
                let tech = line.split(':')[1]?.trim() || "Unknown"
                root.batteryTechnology = tech.charAt(0).toUpperCase() + tech.slice(1)
            } else if (line.includes('cycle-count:')) {
                let match = line.match(/(\d+)/)
                if (match) {
                    root.cycleCount = parseInt(match[1])
                }
            } else if (line.includes('energy-full:') || line.includes('capacity:')) {
                let match = line.match(/([\d.]+)\s*wh/i)
                if (match) {
                    root.batteryCapacity = Math.round(parseFloat(match[1]) * 1000) // Convert to mWh
                }
            }
        }
        
        console.log("Battery status updated:", root.batteryLevel + "%", root.batteryStatus)
    }
    
    function parsePowerProfiles(profileText) {
        let lines = profileText.split('\n')
        let profiles = []
        
        for (let line of lines) {
            line = line.trim()
            if (line.includes('*')) {
                // Active profile
                let profileName = line.replace('*', '').trim()
                if (profileName.includes(':')) {
                    profileName = profileName.split(':')[0].trim()
                }
                root.activePowerProfile = profileName
                profiles.push(profileName)
            } else if (line && !line.includes(':') && line.length > 0) {
                profiles.push(line)
            }
        }
        
        root.powerProfiles = profiles
        console.log("Power profiles available:", profiles, "Active:", root.activePowerProfile)
    }
    
    function setBatteryProfile(profileName) {
        if (!root.powerProfiles.includes(profileName)) {
            console.warn("Invalid power profile:", profileName)
            return
        }
        
        console.log("Setting power profile to:", profileName)
        let profileProcess = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["powerprofilesctl", "set", "${profileName}"]
                running: true
                onExited: (exitCode) => {
                    if (exitCode === 0) {
                        console.log("Power profile changed to:", "${profileName}")
                        root.activePowerProfile = "${profileName}"
                    } else {
                        console.warn("Failed to change power profile")
                    }
                }
            }
        `, root)
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
        
        let hours = Math.floor(root.timeRemaining / 60)
        let minutes = root.timeRemaining % 60
        
        if (hours > 0) {
            return hours + "h " + minutes + "m"
        } else {
            return minutes + "m"
        }
    }
    
    
    // Update timer
    Timer {
        interval: 30000
        running: root.batteryAvailable
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            batteryStatusChecker.running = true
            powerProfilesChecker.running = true
        }
    }
}