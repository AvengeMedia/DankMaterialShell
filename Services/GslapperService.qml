pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property var activeProcesses: ({})
    property var recentFailures: ({}) // Track failed videos to prevent endless restart loops
    property bool gSlapperAvailable: false
    property bool previousPerMonitorMode: false // Track mode changes

    Component.onCompleted: {
        checkGSlapperAvailability()
        // Initialize mode tracking
        previousPerMonitorMode = SessionData.perMonitorWallpaper
    }

    // Monitor SessionData for wallpaper changes to clean up processes
    Connections {
        target: SessionData

        function onWallpaperPathChanged() {
            console.log("GslapperService: Global wallpaper changed, cleaning up processes")
            // When global wallpaper changes, stop all processes if not per-monitor mode
            if (!SessionData.perMonitorWallpaper) {
                stopAllVideos()
            }
        }

        function onMonitorWallpapersChanged() {
            console.log("GslapperService: Monitor wallpapers changed, checking for cleanup")
            // Clean up processes for monitors that no longer have gs: wallpapers
            const currentWallpapers = SessionData.monitorWallpapers || {}

            for (const monitor in activeProcesses) {
                const currentWallpaper = currentWallpapers[monitor] || ""
                if (!currentWallpaper.startsWith("gs:")) {
                    console.log("GslapperService: Stopping video for monitor", monitor, "- no longer has gs: wallpaper")
                    stopVideo(monitor)
                }
            }
        }

        function onPerMonitorWallpaperChanged() {
            console.log("GslapperService: Per-monitor mode changed from", root.previousPerMonitorMode, "to", SessionData.perMonitorWallpaper)

            // When switching between per-monitor and global mode, clean up ALL processes
            // This ensures clean state transition between modes
            console.log("GslapperService: Mode transition - force cleaning all processes")
            forceCleanup()

            // Update our tracking of the current mode
            root.previousPerMonitorMode = SessionData.perMonitorWallpaper
        }
    }

    function checkGSlapperAvailability() {
        gSlapperCheck.running = true
    }

    function startVideo(monitor, videoPath, options = "") {
        stopVideo(monitor)

        // Wait a moment for processes to be fully killed
        delayTimer.interval = 500  // Wait 500ms for cleanup
        delayTimer.monitor = monitor
        delayTimer.videoPath = videoPath
        delayTimer.options = options
        delayTimer.running = true

        return true
    }

    function startVideoDelayed(monitor, videoPath, options = "") {
        if (!gSlapperAvailable) {
            console.warn("GslapperService: gSlapper not available")
            return false
        }

        // Verify video file exists
        if (!videoPath || videoPath.trim() === "") {
            console.error("GslapperService: Invalid video path provided")
            return false
        }

        // Check if this video has failed too many times recently
        const failureKey = monitor + ":" + videoPath
        if (recentFailures[failureKey] && recentFailures[failureKey] >= 3) {
            console.error("GslapperService: Video has failed too many times recently:", videoPath)
            return false
        }

        const process = processComponent.createObject(root)
        if (!process) {
            console.error("GslapperService: Failed to create gSlapper process")
            return false
        }

        // Use proper gSlapper options with background mode and proper GStreamer options
        const gstOptions = options || "no-audio loop panscan=1.0"
        // Use -s for background mode, -vs for verbose background mode, -l background for layer
        process.command = ["gslapper", "-vs", "-l", "background", "-o", gstOptions, monitor, videoPath]
        process.monitorName = monitor
        process.videoPath = videoPath
        process.startTime = Date.now()
        process.crashCount = 0

        activeProcesses[monitor] = process
        process.running = true

        console.log("GslapperService: Starting gSlapper for monitor:", monitor, "with video:", videoPath, "options:", gstOptions)
        return true
    }

    function stopVideo(monitor) {
        let hadProcess = false
        if (activeProcesses[monitor]) {
            hadProcess = true
            console.log("GslapperService: Stopping video for monitor:", monitor)
            const process = activeProcesses[monitor]

            // Force kill immediately - no graceful termination
            if (process.running) {
                process.running = false
            }

            process.destroy()
            delete activeProcesses[monitor]
            console.log("GslapperService: Cleaned up process for monitor:", monitor)
        }

        // Improved logic: Only kill other processes when necessary
        if (hadProcess) {
            if (!SessionData.perMonitorWallpaper) {
                // Global mode: Kill all gslapper processes since we're changing global wallpaper
                // This is safe because in global mode, one process handles all monitors
                console.log("GslapperService: Killing all gslapper processes (global mode change)")
                killAllGslapperProcesses.running = true
            } else if (SessionData.perMonitorWallpaper) {
                // Per-monitor mode: Only kill specifically targeted processes, don't touch others
                // Use pkill with specific monitor pattern to avoid killing other monitor processes
                console.log("GslapperService: Per-monitor mode - only stopping specific monitor process")
                // Don't kill all processes in per-monitor mode unless explicitly stopping everything
            }
        }
    }

    function stopAllVideos() {
        for (const monitor in activeProcesses) {
            stopVideo(monitor)
        }

        // Also kill any orphaned processes as a safety measure
        Qt.callLater(() => {
            console.log("GslapperService: Running safety cleanup of all gSlapper processes")
            killAllGslapperProcesses.running = true
        })
    }

    function forceCleanup() {
        console.log("GslapperService: Force cleanup requested - killing all processes")
        // Destroy all tracked processes
        for (const monitor in activeProcesses) {
            if (activeProcesses[monitor]) {
                activeProcesses[monitor].kill()
                activeProcesses[monitor].destroy()
                delete activeProcesses[monitor]
            }
        }
        activeProcesses = {}

        // Kill any remaining gSlapper processes
        killAllGslapperProcesses.running = true
    }

    function isVideoRunning(monitor) {
        return activeProcesses[monitor] && activeProcesses[monitor].running
    }

    function getRunningVideo(monitor) {
        return activeProcesses[monitor] ? activeProcesses[monitor].videoPath : ""
    }

    function getServiceStatus() {
        const status = {
            available: gSlapperAvailable,
            activeProcesses: Object.keys(activeProcesses).length,
            recentFailures: Object.keys(recentFailures).length,
            processes: {}
        }

        for (const monitor in activeProcesses) {
            const proc = activeProcesses[monitor]
            status.processes[monitor] = {
                running: proc.running,
                videoPath: proc.videoPath,
                uptime: Date.now() - proc.startTime,
                crashCount: proc.crashCount
            }
        }

        return status
    }

    function pauseVideo(monitor) {
        // gSlapper doesn't have pause/resume, so we stop for now
        stopVideo(monitor)
    }

    function resumeVideo(monitor, videoPath, options = "") {
        startVideo(monitor, videoPath, options)
    }

    Process {
        id: gSlapperCheck
        command: ["which", "gslapper"]
        running: false

        onExited: code => {
            gSlapperAvailable = (code === 0)
            if (!gSlapperAvailable) {
                console.warn("gSlapper not found - video wallpaper support disabled")
            } else {
                console.log("gSlapper found - video wallpaper support enabled")
            }
        }
    }

    Process {
        id: killAllGslapperProcesses
        command: ["pkill", "-f", "gslapper"]
        running: false

        onExited: code => {
            console.log("GslapperService: Force killed all gSlapper processes, exit code:", code)
        }
    }

    Component {
        id: processComponent

        Process {
            property string monitorName: ""
            property string videoPath: ""
            property real startTime: 0
            property int crashCount: 0
            readonly property int maxCrashCount: 2
            readonly property int minRunTime: 10000 // 10 seconds minimum run time
            readonly property int maxIdleTime: 30000 // 30 seconds max to start properly

            running: false

            onExited: code => {
                const runTime = Date.now() - startTime
                const wasCrash = (code !== 0 && runTime < minRunTime)
                const failureKey = monitorName + ":" + videoPath

                if (code !== 0) {
                    console.error("GslapperService: Process exited with code:", code, "for monitor:", monitorName, "runtime:", runTime + "ms")

                    // Track failures
                    root.recentFailures[failureKey] = (root.recentFailures[failureKey] || 0) + 1

                    if (wasCrash) {
                        crashCount++
                        console.warn("GslapperService: Detected crash #" + crashCount + " for monitor:", monitorName)

                        // Auto-restart if under crash limit and failure count is reasonable
                        if (crashCount < maxCrashCount &&
                            root.recentFailures[failureKey] < 3 &&
                            activeProcesses[monitorName] === this) {

                            console.log("GslapperService: Auto-restarting video for monitor:", monitorName, "after crash")
                            Qt.callLater(() => {
                                root.startVideo(monitorName, videoPath)
                            })
                        } else {
                            console.error("GslapperService: Too many crashes/failures for:", failureKey, "- giving up")
                        }
                    }
                } else {
                    console.log("GslapperService: Process exited normally for monitor:", monitorName)
                    // Clear failure count on successful run
                    if (runTime > minRunTime && root.recentFailures[failureKey]) {
                        delete root.recentFailures[failureKey]
                    }
                }

                // Clean up from activeProcesses when process exits
                if (activeProcesses[monitorName] === this) {
                    delete activeProcesses[monitorName]
                }

                destroy()
            }

            onRunningChanged: {
                if (running) {
                    console.log("GslapperService: Process started for monitor:", monitorName)
                } else {
                    console.log("GslapperService: Process stopped for monitor:", monitorName)
                }
            }

            stderr: StdioCollector {
                onStreamFinished: {
                    if (text && text.trim()) {
                        console.warn("GslapperService stderr [" + monitorName + "]:", text.trim())
                    }
                }
            }

            stdout: StdioCollector {
                onStreamFinished: {
                    if (text && text.trim()) {
                        console.log("GslapperService stdout [" + monitorName + "]:", text.trim())
                    }
                }
            }
        }
    }

    // Timer for delayed video startup
    Timer {
        id: delayTimer
        property string monitor: ""
        property string videoPath: ""
        property string options: ""
        interval: 500
        running: false
        repeat: false

        onTriggered: {
            startVideoDelayed(monitor, videoPath, options)
        }
    }

    // Clean up all processes when service is destroyed
    Component.onDestruction: {
        stopAllVideos()
    }
}