import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    // CPU properties
    property real cpuUsage: 0.0
    property int cpuCores: 1
    property string cpuModel: ""
    property real cpuFrequency: 0.0
    
    // Memory properties  
    property real memoryUsage: 0.0
    property real totalMemory: 0.0
    property real usedMemory: 0.0
    property real freeMemory: 0.0
    property real availableMemory: 0.0
    property real bufferMemory: 0.0
    property real cacheMemory: 0.0
    
    // Temperature properties
    property real cpuTemperature: 0.0
    
    // Update intervals
    property int cpuUpdateInterval: 2000
    property int memoryUpdateInterval: 3000
    property int temperatureUpdateInterval: 5000
    
    Component.onCompleted: {
        console.log("SystemMonitorService: Starting initialization...")
        getCpuInfo()
        updateSystemStats()
        console.log("SystemMonitorService: Initialization complete")
    }
    
    // Get CPU information (static)
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
    
    // CPU usage monitoring
    Process {
        id: cpuUsageProcess
        command: ["bash", "-c", "grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$3+$4+$5)} END {printf \"%.1f\", usage}'"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    root.cpuUsage = parseFloat(text.trim())
                }
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("CPU usage check failed with exit code:", exitCode)
            }
        }
    }
    
    // Memory usage monitoring
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
    
    // CPU frequency monitoring
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
    
    // CPU temperature monitoring
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
    
    // CPU monitoring timer
    Timer {
        id: cpuTimer
        interval: root.cpuUpdateInterval
        running: true
        repeat: true
        
        onTriggered: {
            cpuUsageProcess.running = true
            cpuFrequencyProcess.running = true
        }
    }
    
    // Memory monitoring timer
    Timer {
        id: memoryTimer
        interval: root.memoryUpdateInterval
        running: true
        repeat: true
        
        onTriggered: {
            memoryUsageProcess.running = true
        }
    }
    
    // Temperature monitoring timer
    Timer {
        id: temperatureTimer
        interval: root.temperatureUpdateInterval
        running: true
        repeat: true
        
        onTriggered: {
            temperatureProcess.running = true
        }
    }
    
    // Public functions
    function getCpuInfo() {
        cpuInfoProcess.running = true
    }
    
    function updateSystemStats() {
        cpuUsageProcess.running = true
        memoryUsageProcess.running = true
        cpuFrequencyProcess.running = true
        temperatureProcess.running = true
    }
    
    function getCpuUsageColor() {
        if (cpuUsage > 80) return "#e74c3c" // Red
        if (cpuUsage > 60) return "#f39c12" // Orange
        return "#27ae60" // Green
    }
    
    function getMemoryUsageColor() {
        if (memoryUsage > 90) return "#e74c3c" // Red
        if (memoryUsage > 75) return "#f39c12" // Orange
        return "#3498db" // Blue
    }
    
    function formatMemory(mb) {
        if (mb >= 1024) {
            return (mb / 1024).toFixed(1) + " GB"
        }
        return mb.toFixed(0) + " MB"
    }
    
    function getTemperatureColor() {
        if (cpuTemperature > 80) return "#e74c3c" // Red
        if (cpuTemperature > 65) return "#f39c12" // Orange
        return "#27ae60" // Green
    }
}
