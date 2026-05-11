pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

Singleton {
    id: root
    readonly property var log: Log.scoped("Proc")

    readonly property int noTimeout: -1
    property int defaultDebounceMs: 50
    property int defaultTimeoutMs: 10000
    property var _procDebouncers: ({})

    function runCommand(id, command, callback, debounceMs, timeoutMs) {
        const wait = (typeof debounceMs === "number" && debounceMs >= 0) ? debounceMs : defaultDebounceMs;
        const timeout = (typeof timeoutMs === "number") ? timeoutMs : defaultTimeoutMs;
        let procId = id ? id : Math.random();
        const isRandomId = !id;

        if (!_procDebouncers[procId]) {
            const t = debounceTimerComp.createObject(root);
            t.triggered.connect(function () {
                _launchProc(procId, isRandomId);
            });
            _procDebouncers[procId] = {
                timer: t,
                command: command,
                callback: callback,
                waitMs: wait,
                timeoutMs: timeout,
                isRandomId: isRandomId
            };
        } else {
            _procDebouncers[procId].command = command;
            _procDebouncers[procId].callback = callback;
            _procDebouncers[procId].waitMs = wait;
            _procDebouncers[procId].timeoutMs = timeout;
        }

        const entry = _procDebouncers[procId];
        entry.timer.interval = entry.waitMs;
        entry.timer.restart();
    }

    function _launchProc(id, isRandomId) {
        const entry = _procDebouncers[id];
        if (!entry)
            return;
        const proc = procComp.createObject(root, {
            command: entry.command
        });
        const timeoutTimer = debounceTimerComp.createObject(root);

        let capturedOut = "";
        let capturedErr = "";
        let exitSeen = false;
        let exitCodeValue = -1;
        let outSeen = false;
        let errSeen = false;
        let timedOut = false;

        timeoutTimer.interval = entry.timeoutMs;
        timeoutTimer.triggered.connect(function () {
            if (!exitSeen) {
                timedOut = true;
                proc.running = false;
                exitSeen = true;
                exitCodeValue = 124;
                maybeComplete();
            }
        });

        proc.stdout.streamFinished.connect(function () {
            try {
                capturedOut = proc.stdout.text || "";
            } catch (e) {
                capturedOut = "";
            }
            outSeen = true;
            maybeComplete();
        });

        proc.stderr.streamFinished.connect(function () {
            try {
                capturedErr = proc.stderr.text || "";
            } catch (e) {
                capturedErr = "";
            }
            errSeen = true;
            maybeComplete();
        });

        proc.exited.connect(function (code) {
            timeoutTimer.stop();
            exitSeen = true;
            exitCodeValue = code;
            maybeComplete();
        });

        function maybeComplete() {
            if (!exitSeen || !outSeen || !errSeen)
                return;
            timeoutTimer.stop();
            if (entry && entry.callback && typeof entry.callback === "function") {
                try {
                    const safeOutput = capturedOut !== null && capturedOut !== undefined ? capturedOut : "";
                    const safeExitCode = exitCodeValue !== null && exitCodeValue !== undefined ? exitCodeValue : -1;
                    entry.callback(safeOutput, safeExitCode);
                } catch (e) {
                    log.warn("runCommand callback error for command:", entry.command, "Error:", e);
                }
            }
            try {
                proc.destroy();
            } catch (_) {}
            try {
                timeoutTimer.destroy();
            } catch (_) {}

            if (isRandomId || entry.isRandomId) {
                Qt.callLater(function () {
                    if (_procDebouncers[id]) {
                        try {
                            _procDebouncers[id].timer.destroy();
                        } catch (_) {}
                        delete _procDebouncers[id];
                    }
                });
            }
        }

        proc.running = true;
        if (entry.timeoutMs !== noTimeout)
            timeoutTimer.start();
    }

    Component {
        id: debounceTimerComp
        Timer {
            repeat: false
        }
    }

    Component {
        id: procComp
        Process {
            running: false
            stdout: StdioCollector {}
            stderr: StdioCollector {}
        }
    }
}
