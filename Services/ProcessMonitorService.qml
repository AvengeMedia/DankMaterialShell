import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    // Process list properties
    property var processes: []
    property bool isUpdating: false
    property int processUpdateInterval: 3000
    
    // System information properties
    property int totalMemoryKB: 0
    property int usedMemoryKB: 0
    property int totalSwapKB: 0
    property int usedSwapKB: 0
    property int cpuCount: 1
    property real totalCpuUsage: 0.0
    property bool systemInfoAvailable: false
    
    // Sorting options
    property string sortBy: "cpu" // "cpu", "memory", "name", "pid"
    property bool sortDescending: true
    property int maxProcesses: 20
    
    Component.onCompleted: {
        console.log("ProcessMonitorService: Starting initialization...")
        updateProcessList()
        console.log("ProcessMonitorService: Initialization complete")
    }
    
    // System information monitoring
    Process {
        id: systemInfoProcess
        command: ["bash", "-c", "cat /proc/meminfo; echo '---CPU---'; nproc; echo '---CPUSTAT---'; grep '^cpu ' /proc/stat"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    parseSystemInfo(text.trim())
                }
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("System info check failed with exit code:", exitCode)
                root.systemInfoAvailable = false
            }
        }
    }
    
    // Process monitoring with ps command
    Process {
        id: processListProcess
        command: ["bash", "-c", "ps axo pid,ppid,pcpu,pmem,rss,comm,cmd --sort=-pcpu | head -" + (root.maxProcesses + 1)]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    const lines = text.trim().split('\n')
                    const newProcesses = []
                    
                    // Skip header line
                    for (let i = 1; i < lines.length; i++) {
                        const line = lines[i].trim()
                        if (!line) continue
                        
                        // Parse ps output: PID PPID %CPU %MEM RSS COMMAND CMD
                        const parts = line.split(/\s+/)
                        if (parts.length >= 7) {
                            const pid = parseInt(parts[0])
                            const ppid = parseInt(parts[1])
                            const cpu = parseFloat(parts[2])
                            const memoryPercent = parseFloat(parts[3])
                            const memoryKB = parseInt(parts[4])
                            const command = parts[5]
                            const fullCmd = parts.slice(6).join(' ')
                            
                            newProcesses.push({
                                pid: pid,
                                ppid: ppid,
                                cpu: cpu,
                                memoryPercent: memoryPercent,
                                memoryKB: memoryKB,
                                command: command,
                                fullCommand: fullCmd,
                                displayName: command.length > 15 ? command.substring(0, 15) + "..." : command
                            })
                        }
                    }
                    
                    root.processes = newProcesses
                    root.isUpdating = false
                }
            }
        }
        
        onExited: (exitCode) => {
            root.isUpdating = false
            if (exitCode !== 0) {
                console.warn("Process list check failed with exit code:", exitCode)
            }
        }
    }
    
    // System and process monitoring timer
    Timer {
        id: processTimer
        interval: root.processUpdateInterval
        running: true
        repeat: true
        
        onTriggered: {
            updateSystemInfo()
            updateProcessList()
        }
    }
    
    // Public functions
    function updateSystemInfo() {
        if (!systemInfoProcess.running) {
            systemInfoProcess.running = true
        }
    }
    
    function updateProcessList() {
        if (!root.isUpdating) {
            root.isUpdating = true
            
            // Update sort command based on current sort option
            let sortOption = ""
            switch (root.sortBy) {
                case "cpu":
                    sortOption = sortDescending ? "--sort=-pcpu" : "--sort=+pcpu"
                    break
                case "memory":
                    sortOption = sortDescending ? "--sort=-pmem" : "--sort=+pmem"
                    break
                case "name":
                    sortOption = sortDescending ? "--sort=-comm" : "--sort=+comm"
                    break
                case "pid":
                    sortOption = sortDescending ? "--sort=-pid" : "--sort=+pid"
                    break
                default:
                    sortOption = "--sort=-pcpu"
            }
            
            processListProcess.command = ["bash", "-c", "ps axo pid,ppid,pcpu,pmem,rss,comm,cmd " + sortOption + " | head -" + (root.maxProcesses + 1)]
            processListProcess.running = true
        }
    }
    
    function setSortBy(newSortBy) {
        if (newSortBy !== root.sortBy) {
            root.sortBy = newSortBy
            updateProcessList()
        }
    }
    
    function toggleSortOrder() {
        root.sortDescending = !root.sortDescending
        updateProcessList()
    }
    
    function killProcess(pid) {
        if (pid > 0) {
            const killCmd = ["bash", "-c", "kill " + pid]
            const killProcess = Qt.createQmlObject(`
                import QtQuick
                import Quickshell.Io
                Process {
                    command: ${JSON.stringify(killCmd)}
                    running: true
                    onExited: (exitCode) => {
                        if (exitCode === 0) {
                            console.log("Process killed successfully:", ${pid})
                        } else {
                            console.warn("Failed to kill process:", ${pid}, "exit code:", exitCode)
                        }
                        destroy()
                    }
                }
            `, root)
        }
    }
    
    function getProcessIcon(command) {
        // Return appropriate Material Design icon for common processes
        const cmd = command.toLowerCase()
        if (cmd.includes("firefox") || cmd.includes("chrome") || cmd.includes("browser")) return "web"
        if (cmd.includes("code") || cmd.includes("editor") || cmd.includes("vim")) return "code"
        if (cmd.includes("terminal") || cmd.includes("bash") || cmd.includes("zsh")) return "terminal"
        if (cmd.includes("music") || cmd.includes("audio") || cmd.includes("spotify")) return "music_note"
        if (cmd.includes("video") || cmd.includes("vlc") || cmd.includes("mpv")) return "play_circle"
        if (cmd.includes("systemd") || cmd.includes("kernel") || cmd.includes("kthread")) return "settings"
        return "memory" // Default process icon
    }
    
    function formatCpuUsage(cpu) {
        return cpu.toFixed(1) + "%"
    }
    
    function formatMemoryUsage(memoryKB) {
        if (memoryKB < 1024) {
            return memoryKB.toFixed(0) + " KB"
        } else if (memoryKB < 1024 * 1024) {
            return (memoryKB / 1024).toFixed(1) + " MB"
        } else {
            return (memoryKB / (1024 * 1024)).toFixed(1) + " GB"
        }
    }
    
    function formatSystemMemory(memoryKB) {
        if (memoryKB < 1024 * 1024) {
            return (memoryKB / 1024).toFixed(0) + " MB"
        } else {
            return (memoryKB / (1024 * 1024)).toFixed(1) + " GB"
        }
    }
    
    function parseSystemInfo(text) {
        const lines = text.split('\n')
        let section = 'memory'
        
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim()
            
            if (line === '---CPU---') {
                section = 'cpucount'
                continue
            } else if (line === '---CPUSTAT---') {
                section = 'cpustat'
                continue
            }
            
            if (section === 'memory') {
                if (line.startsWith('MemTotal:')) {
                    root.totalMemoryKB = parseInt(line.split(/\s+/)[1])
                } else if (line.startsWith('MemAvailable:')) {
                    const availableKB = parseInt(line.split(/\s+/)[1])
                    root.usedMemoryKB = root.totalMemoryKB - availableKB
                } else if (line.startsWith('SwapTotal:')) {
                    root.totalSwapKB = parseInt(line.split(/\s+/)[1])
                } else if (line.startsWith('SwapFree:')) {
                    const freeSwapKB = parseInt(line.split(/\s+/)[1])
                    root.usedSwapKB = root.totalSwapKB - freeSwapKB
                }
            } else if (section === 'cpucount') {
                const count = parseInt(line)
                if (!isNaN(count)) {
                    root.cpuCount = count
                }
            } else if (section === 'cpustat') {
                if (line.startsWith('cpu ')) {
                    const parts = line.split(/\s+/)
                    if (parts.length >= 8) {
                        const user = parseInt(parts[1])
                        const nice = parseInt(parts[2])
                        const system = parseInt(parts[3])
                        const idle = parseInt(parts[4])
                        const iowait = parseInt(parts[5])
                        const irq = parseInt(parts[6])
                        const softirq = parseInt(parts[7])
                        
                        const total = user + nice + system + idle + iowait + irq + softirq
                        const used = total - idle - iowait
                        root.totalCpuUsage = total > 0 ? (used / total) * 100 : 0
                    }
                }
            }
        }
        
        root.systemInfoAvailable = true
    }
}