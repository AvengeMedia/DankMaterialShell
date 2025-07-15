import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    property real cpuUsage: 0.0
    property int cpuCores: 1
    property string cpuModel: ""
    property real cpuFrequency: 0.0
    
    property var prevCpuStats: [0, 0, 0, 0, 0, 0, 0, 0]
    
    property real memoryUsage: 0.0
    property real totalMemory: 0.0
    property real usedMemory: 0.0
    property real freeMemory: 0.0
    property real availableMemory: 0.0
    property real bufferMemory: 0.0
    property real cacheMemory: 0.0
    
    property real cpuTemperature: 0.0
    
    property int cpuUpdateInterval: 3000
    property int memoryUpdateInterval: 5000
    property int temperatureUpdateInterval: 10000
    
    property bool enabledForTopBar: true
    property bool enabledForDetailedView: false

    Component.onCompleted: {
        console.log("SystemMonitorService: Starting initialization...")
        getCpuInfo()
        updateSystemStats()
        console.log("SystemMonitorService: Initialization complete")
    }
    
    Process {
        id: cpuInfoProcess
        command: ["bash", "-c", "lscpu | grep -E 'Model name|CPU\\(s\\):' | head -2"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split('\n')
                for (const line of lines) {
                    if (line.includes("Model name")) {
                        root.cpuModel = line.split(":")[1].trim()
                    } else if (line.includes("CPU(s):")) {
                        root.cpuCores = parseInt(line.split(":")[1].trim())
                    }
                }
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("CPU info check failed with exit code:", exitCode)
            }
        }
    }
    
    Process {
        id: cpuUsageProcess
        command: ["bash", "-c", "head -1 /proc/stat | awk '{print $2,$3,$4,$5,$6,$7,$8,$9}'"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    const stats = text.trim().split(" ").map(x => parseInt(x))
                    if (root.prevCpuStats[0] > 0) {
                        let diffs = []
                        for (let i = 0; i < 8; i++) {
                            diffs[i] = stats[i] - root.prevCpuStats[i]
                        }
                        
                        const totalTime = diffs.reduce((a, b) => a + b, 0)
                        const idleTime = diffs[3] + diffs[4]
                        
                        if (totalTime > 0) {
                            root.cpuUsage = Math.max(0, Math.min(100, ((totalTime - idleTime) / totalTime) * 100))
                        }
                    }
                    root.prevCpuStats = stats
                }
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("CPU usage check failed with exit code:", exitCode)
            }
        }
    }
    
    Process {
        id: memoryUsageProcess
        command: ["bash", "-c", "free -m | awk 'NR==2{printf \"%.1f %.1f %.1f %.1f\", $3*100/$2, $2, $3, $7}'"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    const parts = text.trim().split(" ")
                    root.memoryUsage = parseFloat(parts[0])
                    root.totalMemory = parseFloat(parts[1])
                    root.usedMemory = parseFloat(parts[2])
                    root.availableMemory = parseFloat(parts[3])
                    root.freeMemory = root.totalMemory - root.usedMemory
                }
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("Memory usage check failed with exit code:", exitCode)
            }
        }
    }
    
    Process {
        id: cpuFrequencyProcess
        command: ["bash", "-c", "cat /proc/cpuinfo | grep 'cpu MHz' | head -1 | awk '{print $4}'"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    root.cpuFrequency = parseFloat(text.trim())
                }
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("CPU frequency check failed with exit code:", exitCode)
            }
        }
    }
    
    Process {
        id: temperatureProcess
        command: ["bash", "-c", "if [ -f /sys/class/thermal/thermal_zone0/temp ]; then cat /sys/class/thermal/thermal_zone0/temp | awk '{print $1/1000}'; else sensors 2>/dev/null | grep 'Core 0' | awk '{print $3}' | sed 's/+//g;s/°C//g' | head -1; fi"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    root.cpuTemperature = parseFloat(text.trim())
                }
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("CPU temperature check failed with exit code:", exitCode)
            }
        }
    }
    
    Timer {
        id: cpuTimer
        interval: root.cpuUpdateInterval
        running: root.enabledForTopBar || root.enabledForDetailedView
        repeat: true
        
        onTriggered: {
            if (root.enabledForTopBar || root.enabledForDetailedView) {
                cpuUsageProcess.running = true
                cpuFrequencyProcess.running = true
            }
        }
    }
    
    Timer {
        id: memoryTimer
        interval: root.memoryUpdateInterval
        running: root.enabledForTopBar || root.enabledForDetailedView
        repeat: true
        
        onTriggered: {
            if (root.enabledForTopBar || root.enabledForDetailedView) {
                memoryUsageProcess.running = true
            }
        }
    }
    
    Timer {
        id: temperatureTimer
        interval: root.temperatureUpdateInterval
        running: root.enabledForDetailedView
        repeat: true
        
        onTriggered: {
            if (root.enabledForDetailedView) {
                temperatureProcess.running = true
            }
        }
    }
    
    function getCpuInfo() {
        cpuInfoProcess.running = true
    }
    
    function updateSystemStats() {
        if (root.enabledForTopBar || root.enabledForDetailedView) {
            cpuUsageProcess.running = true
            memoryUsageProcess.running = true
            cpuFrequencyProcess.running = true
            if (root.enabledForDetailedView) {
                temperatureProcess.running = true
            }
        }
    }
    
    function enableTopBarMonitoring(enabled) {
        root.enabledForTopBar = enabled
    }
    
    function enableDetailedMonitoring(enabled) {
        root.enabledForDetailedView = enabled
    }
    
    function getCpuUsageColor() {
        if (cpuUsage > 80) return "#e74c3c"
        if (cpuUsage > 60) return "#f39c12"
        return "#27ae60"
    }
    
    function getMemoryUsageColor() {
        if (memoryUsage > 90) return "#e74c3c"
        if (memoryUsage > 75) return "#f39c12"
        return "#3498db"
    }
    
    function formatMemory(mb) {
        if (mb >= 1024) {
            return (mb / 1024).toFixed(1) + " GB"
        }
        return mb.toFixed(0) + " MB"
    }
    
    function getTemperatureColor() {
        if (cpuTemperature > 80) return "#e74c3c"
        if (cpuTemperature > 65) return "#f39c12"
        return "#27ae60"
    }
}