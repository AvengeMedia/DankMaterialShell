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
    
    // Sorting options
    property string sortBy: "cpu" // "cpu", "memory", "name", "pid"
    property bool sortDescending: true
    property int maxProcesses: 20
    
    Component.onCompleted: {
        console.log("ProcessMonitorService: Starting initialization...")
        updateProcessList()
        console.log("ProcessMonitorService: Initialization complete")
    }
    
    // Process monitoring with ps command
    Process {
        id: processListProcess
        command: ["bash", "-c", "ps axo pid,ppid,pcpu,pmem,comm,cmd --sort=-pcpu | head -" + (root.maxProcesses + 1)]
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
                        
                        // Parse ps output: PID PPID %CPU %MEM COMMAND CMD
                        const parts = line.split(/\s+/)
                        if (parts.length >= 6) {
                            const pid = parseInt(parts[0])
                            const ppid = parseInt(parts[1])
                            const cpu = parseFloat(parts[2])
                            const memory = parseFloat(parts[3])
                            const command = parts[4]
                            const fullCmd = parts.slice(5).join(' ')
                            
                            newProcesses.push({
                                pid: pid,
                                ppid: ppid,
                                cpu: cpu,
                                memory: memory,
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
    
    // Process monitoring timer
    Timer {
        id: processTimer
        interval: root.processUpdateInterval
        running: true
        repeat: true
        
        onTriggered: {
            updateProcessList()
        }
    }
    
    // Public functions
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
            
            processListProcess.command = ["bash", "-c", "ps axo pid,ppid,pcpu,pmem,comm,cmd " + sortOption + " | head -" + (root.maxProcesses + 1)]
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
    
    function formatMemoryUsage(memory) {
        return memory.toFixed(1) + "%"
    }
}