pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "../Common/MuxBackends.js" as MuxBackends

Singleton {
    id: root
    readonly property var log: Log.scoped("MuxService")

    property var sessions: []
    property bool loading: false
    property bool currentMuxAvailable: false

    readonly property string muxType: SettingsData.muxType
    readonly property var backend: MuxBackends.BACKENDS[muxType] ?? MuxBackends.BACKENDS.tmux
    readonly property string displayName: backend.displayName
    readonly property bool supportsRename: !!backend.rename

    readonly property var terminalFlags: ({
            "ghostty": ["-e"],
            "kitty": ["-e"],
            "alacritty": ["-e"],
            "foot": [],
            "wezterm": ["start", "--"],
            "gnome-terminal": ["--"],
            "xterm": ["-e"],
            "konsole": ["-e"],
            "st": ["-e"],
            "terminator": ["-e"],
            "xfce4-terminal": ["-e"]
        })

    function getTerminalFlag(terminal) {
        return terminalFlags[terminal] ?? ["-e"];
    }

    readonly property string terminal: SessionData.resolveTerminal() || "ghostty"

    function _terminalPrefix() {
        return [terminal].concat(getTerminalFlag(terminal));
    }

    Process {
        id: availabilityCheck
        command: ["sh", "-c", "command -v " + root.backend.list[0]]
        running: false
        onExited: code => {
            root.currentMuxAvailable = (code === 0);
        }
    }

    // Restart so a backend switch mid-check never inherits the old binary's result
    function checkAvailability() {
        if (availabilityCheck.running)
            availabilityCheck.running = false;
        Qt.callLater(function () {
            availabilityCheck.running = true;
        });
    }

    onBackendChanged: checkAvailability()
    Component.onCompleted: checkAvailability()

    Process {
        id: listProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.sessions = root.backend.parse(text).filter(session => !root._isSessionExcluded(session.name));
                } catch (e) {
                    log.error("Error parsing sessions:", e);
                    root.sessions = [];
                }
                root.loading = false;
            }
        }

        stderr: SplitParser {
            onRead: line => {
                if (line.trim())
                    log.error("stderr:", line);
            }
        }

        onExited: code => {
            if (code !== 0 && code !== 1) {
                log.warn("Process exited with code:", code);
                root.sessions = [];
            }
            root.loading = false;
        }
    }

    function refreshSessions() {
        if (!root.currentMuxAvailable) {
            root.sessions = [];
            return;
        }

        root.loading = true;

        if (listProcess.running)
            listProcess.running = false;

        listProcess.command = root.backend.list;
        Qt.callLater(function () {
            listProcess.running = true;
        });
    }

    function _isSessionExcluded(name) {
        return MuxBackends.isSessionExcluded(name, SettingsData.muxSessionFilter);
    }

    function _runInTerminal(name, argv) {
        if (SettingsData.muxUseCustomCommand && SettingsData.muxCustomCommand) {
            Quickshell.execDetached([Paths.expandTilde(SettingsData.muxCustomCommand), name]);
            return;
        }
        Quickshell.execDetached(_terminalPrefix().concat(argv));
    }

    function attachToSession(name) {
        _runInTerminal(name, root.backend.attach(name));
    }

    function createSession(name) {
        _runInTerminal(name, root.backend.create(name));
    }

    function renameSession(oldName, newName) {
        if (!root.supportsRename)
            return;
        Quickshell.execDetached(root.backend.rename(oldName, newName));
        Qt.callLater(refreshSessions);
    }

    function killSession(name) {
        Quickshell.execDetached(root.backend.kill(name));
        Qt.callLater(refreshSessions);
    }
}
