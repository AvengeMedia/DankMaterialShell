pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    
    property var sessions: []
    property bool loading: false

    signal onSessionsChanged()
    
    Process {
        id: tmuxProcess
        running: false
        command: ["tmux", "list-sessions", "-F", "#{session_name}|#{session_windows}|#{session_attached}"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.parseSessions(text)
                } catch (e) {
                    console.error("[TmuxService] Error parsing sessions:", e)
                    root.sessions = []
                }
                root.loading = false
            }
        }
        
        stderr: SplitParser {
            onRead: (line) => {
                if (line.trim()) {
                    console.error("[TmuxService] stderr:", line)
                }
            }
        }
        
        onExited: (code) => {
            if (code !== 0 && code !== 1) {
                console.warn("[TmuxService] Process exited with code:", code)
                root.sessions = []
            }
            root.loading = false
        }
    }
    
    function refreshSessions() {
        root.loading = true
        
        if (tmuxProcess.running) {
            tmuxProcess.running = false
        }
        
        Qt.callLater(function() {
            tmuxProcess.running = true
        })
    }
    
    function parseSessions(output) {
        var sessionList = []
        var lines = output.trim().split('\n')
        
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line.length === 0) continue
            
            var parts = line.split('|')
            if (parts.length >= 3) {
                sessionList.push({
                    name: parts[0],
                    windows: parts[1],
                    attached: parts[2] === "1"
                })
            }
        }
        
        if (sessionList.length != root.sessions.length) {
            onSessionsChanged()
        }

        root.sessions = sessionList
    }
}