import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    property var processes: []
    property bool isUpdating: false
    property int processUpdateInterval: 3000
    
    property bool monitoringEnabled: false
    
    property int totalMemoryKB: 0
    property int usedMemoryKB: 0
    property int totalSwapKB: 0
    property int usedSwapKB: 0
    property int cpuCount: 1
    property real totalCpuUsage: 0.0
    property bool systemInfoAvailable: false
    
    property var cpuHistory: []
    property var memoryHistory: []
    property var networkHistory: ({rx: [], tx: []})
    property var diskHistory: ({read: [], write: []})
    property int historySize: 60
    
    property var perCoreCpuUsage: []
    
    property real networkRxRate: 0
    property real networkTxRate: 0
    property var lastNetworkStats: null
    
    property real diskReadRate: 0
    property real diskWriteRate: 0
    property var lastDiskStats: null
    
    property string sortBy: "cpu"
    property bool sortDescending: true
    property int maxProcesses: 20
    
    Component.onCompleted: {
        console.log("ProcessMonitorService: Starting initialization...")
        updateProcessList()
        console.log("ProcessMonitorService: Initialization complete")
    }
    
    Timer {
        id: testTimer
        interval: 3000
        running: false
        repeat: false
        onTriggered: {
            console.log("ProcessMonitorService: Starting test monitoring...")
            enableMonitoring(true)
            stopTestTimer.start()
        }
    }
    
    Timer {
        id: stopTestTimer
        interval: 8000
        running: false
        repeat: false
        onTriggered: {
            console.log("ProcessMonitorService: Stopping test monitoring...")
            enableMonitoring(false)
        }
    }
    
    Process {
        id: systemInfoProcess
        command: ["bash", "-c", "cat /proc/meminfo; echo '---CPU---'; nproc; echo '---CPUSTAT---'; grep '^cpu' /proc/stat | head -" + (root.cpuCount + 1)]
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
    
    Process {
        id: networkStatsProcess
        command: ["bash", "-c", "cat /proc/net/dev | grep -E '(wlan|eth|enp|wlp|ens|eno)' | awk '{print $1,$2,$10}' | sed 's/:/ /'"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    parseNetworkStats(text.trim())
                }
            }
        }
    }
    
    Process {
        id: diskStatsProcess
        command: ["bash", "-c", "cat /proc/diskstats | grep -E ' (sd[a-z]+|nvme[0-9]+n[0-9]+|vd[a-z]+) ' | grep -v 'p[0-9]' | awk '{print $3,$6,$10}'"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    parseDiskStats(text.trim())
                }
            }
        }
    }
    
    Process {
        id: processListProcess
        command: ["bash", "-c", "ps axo pid,ppid,pcpu,pmem,rss,comm,cmd --sort=-pcpu | head -" + (root.maxProcesses + 1)]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    const lines = text.trim().split('\n')
                    const newProcesses = []
                    
                    for (let i = 1; i < lines.length; i++) {
                        const line = lines[i].trim()
                        if (!line) continue
                        
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
    
    Timer {
        id: processTimer
        interval: root.processUpdateInterval
        running: root.monitoringEnabled
        repeat: true
        
        onTriggered: {
            if (root.monitoringEnabled) {
                updateSystemInfo()
                updateProcessList()
                updateNetworkStats()
                updateDiskStats()
            }
        }
    }
    
    function updateSystemInfo() {
        if (!systemInfoProcess.running && root.monitoringEnabled) {
            systemInfoProcess.running = true
        }
    }
    
    function enableMonitoring(enabled) {
        console.log("ProcessMonitorService: Monitoring", enabled ? "enabled" : "disabled")
        root.monitoringEnabled = enabled
        if (enabled) {
            root.cpuHistory = []
            root.memoryHistory = []
            root.networkHistory = ({rx: [], tx: []})
            root.diskHistory = ({read: [], write: []})
            updateSystemInfo()
            updateProcessList()
            updateNetworkStats()
            updateDiskStats()
        }
    }
    
    function updateNetworkStats() {
        if (!networkStatsProcess.running && root.monitoringEnabled) {
            networkStatsProcess.running = true
        }
    }
    
    function updateDiskStats() {
        if (!diskStatsProcess.running && root.monitoringEnabled) {
            diskStatsProcess.running = true
        }
    }
    
    function updateProcessList() {
        if (!root.isUpdating && root.monitoringEnabled) {
            root.isUpdating = true
            
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
        const cmd = command.toLowerCase()
        if (cmd.includes("firefox") || cmd.includes("chrome") || cmd.includes("browser")) return "web"
        if (cmd.includes("code") || cmd.includes("editor") || cmd.includes("vim")) return "code"
        if (cmd.includes("terminal") || cmd.includes("bash") || cmd.includes("zsh")) return "terminal"
        if (cmd.includes("music") || cmd.includes("audio") || cmd.includes("spotify")) return "music_note"
        if (cmd.includes("video") || cmd.includes("vlc") || cmd.includes("mpv")) return "play_circle"
        if (cmd.includes("systemd") || cmd.includes("kernel") || cmd.includes("kthread")) return "settings"
        return "memory"
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
        const coreUsages = []
        let memFree = 0
        let memBuffers = 0
        let memCached = 0
        
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
                } else if (line.startsWith('MemFree:')) {
                    memFree = parseInt(line.split(/\s+/)[1])
                } else if (line.startsWith('Buffers:')) {
                    memBuffers = parseInt(line.split(/\s+/)[1])
                } else if (line.startsWith('Cached:')) {
                    memCached = parseInt(line.split(/\s+/)[1])
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
                } else if (line.match(/^cpu\d+/)) {
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
                        const usage = total > 0 ? (used / total) * 100 : 0
                        coreUsages.push(usage)
                    }
                }
            }
        }
        
        // Calculate used memory as total minus free minus buffers minus cached
        root.usedMemoryKB = root.totalMemoryKB - memFree - memBuffers - memCached
        
        // Update per-core usage
        root.perCoreCpuUsage = coreUsages
        
        // Update history
        addToHistory(root.cpuHistory, root.totalCpuUsage)
        const memoryPercent = root.totalMemoryKB > 0 ? (root.usedMemoryKB / root.totalMemoryKB) * 100 : 0
        addToHistory(root.memoryHistory, memoryPercent)
        
        // console.log("ProcessMonitorService: Updated - CPU:", root.totalCpuUsage.toFixed(1) + "%", "Memory:", memoryPercent.toFixed(1) + "%", "History length:", root.cpuHistory.length)
        
        root.systemInfoAvailable = true
    }
    
    function parseNetworkStats(text) {
        const lines = text.split('\n')
        let totalRx = 0
        let totalTx = 0
        
        for (const line of lines) {
            const parts = line.trim().split(/\s+/)
            if (parts.length >= 3) {
                const rx = parseInt(parts[1])
                const tx = parseInt(parts[2])
                if (!isNaN(rx) && !isNaN(tx)) {
                    totalRx += rx
                    totalTx += tx
                }
            }
        }
        
        if (root.lastNetworkStats) {
            const timeDiff = root.processUpdateInterval / 1000
            root.networkRxRate = Math.max(0, (totalRx - root.lastNetworkStats.rx) / timeDiff)
            root.networkTxRate = Math.max(0, (totalTx - root.lastNetworkStats.tx) / timeDiff)
            
            addToHistory(root.networkHistory.rx, root.networkRxRate / 1024)
            addToHistory(root.networkHistory.tx, root.networkTxRate / 1024)
        }
        
        root.lastNetworkStats = { rx: totalRx, tx: totalTx }
    }
    
    function parseDiskStats(text) {
        const lines = text.split('\n')
        let totalRead = 0
        let totalWrite = 0
        
        for (const line of lines) {
            const parts = line.trim().split(/\s+/)
            if (parts.length >= 3) {
                const readSectors = parseInt(parts[1])
                const writeSectors = parseInt(parts[2])
                if (!isNaN(readSectors) && !isNaN(writeSectors)) {
                    totalRead += readSectors * 512
                    totalWrite += writeSectors * 512
                }
            }
        }
        
        if (root.lastDiskStats) {
            const timeDiff = root.processUpdateInterval / 1000
            root.diskReadRate = Math.max(0, (totalRead - root.lastDiskStats.read) / timeDiff)
            root.diskWriteRate = Math.max(0, (totalWrite - root.lastDiskStats.write) / timeDiff)
            
            addToHistory(root.diskHistory.read, root.diskReadRate / (1024 * 1024))
            addToHistory(root.diskHistory.write, root.diskWriteRate / (1024 * 1024))
        }
        
        root.lastDiskStats = { read: totalRead, write: totalWrite }
    }
    
    function addToHistory(array, value) {
        array.push(value)
        if (array.length > root.historySize) {
            array.shift()
        }
    }
}