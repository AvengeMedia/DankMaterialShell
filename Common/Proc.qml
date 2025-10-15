pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int defaultDebounceMs: 50
    property var _procDebouncers: ({}) // id -> { timer, command, callback, waitMs }

    function runCommand(id, command, callback, debounceMs) {
        const wait = (typeof debounceMs === "number" && debounceMs >= 0) ? debounceMs : defaultDebounceMs
        let procId = id ? id : Math.random()        

        if (!_procDebouncers[procId]) {
            const t = Qt.createQmlObject('import QtQuick; Timer { repeat: false }', root)
            t.triggered.connect(function() { _launchProc(procId) })
            _procDebouncers[procId] = { timer: t, command: command, callback: callback, waitMs: wait }
        } else {
            _procDebouncers[procId].command = command
            _procDebouncers[procId].callback = callback
            _procDebouncers[procId].waitMs = wait
        }

        const entry = _procDebouncers[procId]
        entry.timer.interval = entry.waitMs
        entry.timer.restart()
    }

    function _launchProc(id) {
        const entry = _procDebouncers[id]
        if (!entry) return

        const proc = Qt.createQmlObject('import Quickshell.Io; Process { running: false }', root)
        const out = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', proc)
        const err = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', proc)

        proc.stdout = out
        proc.stderr = err
        proc.command = entry.command

        let capturedOut = ""
        let exitSeen = false
        let exitCodeValue = -1

        out.streamFinished.connect(function() {
            capturedOut = out.text || ""
            maybeComplete()
        })

        proc.exited.connect(function(code) {
            exitSeen = true
            exitCodeValue = code
            maybeComplete()
        })

        function maybeComplete() {
            if (!exitSeen) return
            if (typeof entry.callback === "function") {
                try { entry.callback(capturedOut, exitCodeValue) } catch (e) { console.warn("runCommand callback error:", e) }
            }
            try { proc.destroy() } catch (_) {}
        }

        proc.running = true
    }
}
