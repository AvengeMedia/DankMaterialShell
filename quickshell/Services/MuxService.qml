pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root
    readonly property var log: Log.scoped("MuxService")

    property var sessions: []
    property bool loading: false

    property bool tmuxAvailable: false
    property bool zellijAvailable: false
    readonly property bool currentMuxAvailable: muxType === "zellij" ? zellijAvailable : tmuxAvailable

    readonly property string muxType: SettingsData.muxType
    readonly property string displayName: muxType === "zellij" ? "Zellij" : "Tmux"

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
        id: tmuxCheckProcess
        command: ["which", "tmux"]
        running: false
        onExited: code => {
            root.tmuxAvailable = (code === 0);
        }
    }

    Process {
        id: zellijCheckProcess
        command: ["which", "zellij"]
        running: false
        onExited: code => {
            root.zellijAvailable = (code === 0);
        }
    }

    function checkAvailability() {
        tmuxCheckProcess.running = true;
        zellijCheckProcess.running = true;
    }

    Component.onCompleted: checkAvailability()

    Process {
        id: listProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (root.muxType === "zellij")
                        root._parseZellijSessions(text);
                    else
                        root._parseTmuxSessions(text);
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

        if (root.muxType === "zellij")
            listProcess.command = ["zellij", "list-sessions", "--no-formatting"];
        else
            listProcess.command = ["tmux", "list-sessions", "-F", "#{session_name}|#{session_windows}|#{session_attached}"];

        Qt.callLater(function () {
            listProcess.running = true;
        });
    }

    function _isSessionExcluded(name) {
        var filter = SettingsData.muxSessionFilter.trim();
        if (filter.length === 0)
            return false;
        var parts = filter.split(",");
        for (var i = 0; i < parts.length; i++) {
            var pattern = parts[i].trim();
            if (pattern.length === 0)
                continue;
            if (pattern.startsWith("/") && pattern.endsWith("/") && pattern.length > 2) {
                try {
                    var re = new RegExp(pattern.slice(1, -1));
                    if (re.test(name))
                        return true;
                } catch (e) {}
            } else {
                if (name.toLowerCase() === pattern.toLowerCase())
                    return true;
            }
        }
        return false;
    }

    function _parseTmuxSessions(output) {
        var sessionList = [];
        var lines = output.trim().split('\n');

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line.length === 0)
                continue;
            var parts = line.split('|');
            if (parts.length >= 3 && !_isSessionExcluded(parts[0])) {
                sessionList.push({
                    name: parts[0],
                    windows: parts[1],
                    attached: parts[2] === "1"
                });
            }
        }

        root.sessions = sessionList;
    }

    function _parseZellijSessions(output) {
        var sessionList = [];
        var lines = output.trim().split('\n');

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line.length === 0)
                continue;
            var exited = line.includes("(EXITED");
            var bracketIdx = line.indexOf(" [");
            var name = (bracketIdx > 0 ? line.substring(0, bracketIdx) : line).trim();

            if (!_isSessionExcluded(name)) {
                sessionList.push({
                    name: name,
                    windows: "N/A",
                    attached: !exited
                });
            }
        }

        root.sessions = sessionList;
    }

    function attachToSession(name) {
        if (SettingsData.muxUseCustomCommand && SettingsData.muxCustomCommand) {
            Quickshell.execDetached([Paths.expandTilde(SettingsData.muxCustomCommand), name]);
        } else if (root.muxType === "zellij") {
            Quickshell.execDetached(_terminalPrefix().concat(["zellij", "attach", name]));
        } else {
            Quickshell.execDetached(_terminalPrefix().concat(["tmux", "attach", "-t", name]));
        }
    }

    function createSession(name) {
        if (SettingsData.muxUseCustomCommand && SettingsData.muxCustomCommand) {
            Quickshell.execDetached([Paths.expandTilde(SettingsData.muxCustomCommand), name]);
        } else if (root.muxType === "zellij") {
            Quickshell.execDetached(_terminalPrefix().concat(["zellij", "-s", name]));
        } else {
            Quickshell.execDetached(_terminalPrefix().concat(["tmux", "new-session", "-s", name]));
        }
    }

    readonly property bool supportsRename: muxType !== "zellij"

    function renameSession(oldName, newName) {
        if (root.muxType === "zellij")
            return;
        Quickshell.execDetached(["tmux", "rename-session", "-t", oldName, newName]);
        Qt.callLater(refreshSessions);
    }

    function killSession(name) {
        if (root.muxType === "zellij") {
            Quickshell.execDetached(["zellij", "kill-session", name]);
        } else {
            Quickshell.execDetached(["tmux", "kill-session", "-t", name]);
        }
        Qt.callLater(refreshSessions);
    }
}
