pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    
    property bool isIdle: false
    property int idleThresholdSeconds: 300 // 5 minutes
    property int checkInterval: 30000 // Check every 30 seconds
    
    signal idleChanged(bool idle)
    
    function checkIdleState() {
        if (idleChecker.running) return
        idleChecker.running = true
    }
    
    Timer {
        id: idleTimer
        interval: root.checkInterval
        running: true
        repeat: true
        onTriggered: root.checkIdleState()
    }
    
    Process {
        id: idleChecker
        command: ["bash", "-c", "if command -v xprintidle >/dev/null 2>&1; then echo $(( $(xprintidle) / 1000 )); elif command -v qdbus >/dev/null 2>&1; then qdbus org.freedesktop.ScreenSaver /org/freedesktop/ScreenSaver GetSessionIdleTime 2>/dev/null || echo 0; else echo 0; fi"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                const idleSeconds = parseInt(data.trim()) || 0
                const wasIdle = root.isIdle
                root.isIdle = idleSeconds >= root.idleThresholdSeconds
                
                if (wasIdle !== root.isIdle) {
                    console.log("IdleService: System idle state changed to:", root.isIdle ? "idle" : "active", "(" + idleSeconds + "s)")
                    root.idleChanged(root.isIdle)
                }
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("IdleService: Failed to check idle state, exit code:", exitCode)
            }
        }
    }
    
    Component.onCompleted: {
        console.log("IdleService: Initialized with", root.idleThresholdSeconds + "s threshold")
        checkIdleState()
    }
}