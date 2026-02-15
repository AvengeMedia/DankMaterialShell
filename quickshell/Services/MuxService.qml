pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property var sessions: []
    property bool loading: false

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
        var name = terminal.split("/").pop()
        if (terminalFlags[name] !== undefined)
            return terminalFlags[name]
        return ["-e"]
    }

    function _terminalPrefix() {
        return [SettingsData.muxTerminal].concat(getTerminalFlag(SettingsData.muxTerminal))
    }

    Process {
        id: listProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (root.muxType === "zellij")
                        root._parseZellijSessions(text)
                    else
                        root._parseTmuxSessions(text)
                } catch (e) {
                    console.error("[MuxService] Error parsing sessions:", e)
                    root.sessions = []
                }
                root.loading = false
            }
        }

        stderr: SplitParser {
            onRead: (line) => {
                if (line.trim())
                    console.error("[MuxService] stderr:", line)
            }
        }

        onExited: (code) => {
            if (code !== 0 && code !== 1) {
                console.warn("[MuxService] Process exited with code:", code)
                root.sessions = []
            }
            root.loading = false
        }
    }

    function refreshSessions() {
        root.loading = true

        if (listProcess.running)
            listProcess.running = false

        if (root.muxType === "zellij")
            listProcess.command = ["zellij", "list-sessions", "--no-formatting"]
        else
            listProcess.command = ["tmux", "list-sessions", "-F", "#{session_name}|#{session_windows}|#{session_attached}"]

        Qt.callLater(function () {
            listProcess.running = true
        })
    }

    function _parseTmuxSessions(output) {
        var sessionList = []
        var lines = output.trim().split('\n')

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line.length === 0)
                continue

            var parts = line.split('|')
            if (parts.length >= 3) {
                sessionList.push({
                    name: parts[0],
                    windows: parts[1],
                    attached: parts[2] === "1"
                })
            }
        }

        if (sessionList.length !== root.sessions.length)
            sessionsChanged()

        root.sessions = sessionList
    }

    function _parseZellijSessions(output) {
        var sessionList = []
        var lines = output.trim().split('\n')

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line.length === 0)
                continue

            var exited = line.includes("(EXITED")
            var bracketIdx = line.indexOf(" [")
            var name = bracketIdx > 0 ? line.substring(0, bracketIdx) : line

            sessionList.push({
                name: name.trim(),
                windows: "N/A",
                attached: !exited
            })
        }

        if (sessionList.length !== root.sessions.length)
            sessionsChanged()

        root.sessions = sessionList
    }

    function attachToSession(name) {
        if (SettingsData.muxUseCustomCommand && SettingsData.muxCustomCommand) {
            Quickshell.execDetached([SettingsData.muxCustomCommand, name])
        } else if (root.muxType === "zellij") {
            Quickshell.execDetached(_terminalPrefix().concat(["zellij", "attach", name]))
        } else {
            Quickshell.execDetached(_terminalPrefix().concat(["tmux", "attach", "-t", name]))
        }
    }

    function createSession(name) {
        if (SettingsData.muxUseCustomCommand && SettingsData.muxCustomCommand) {
            Quickshell.execDetached([SettingsData.muxCustomCommand, name])
        } else if (root.muxType === "zellij") {
            Quickshell.execDetached(_terminalPrefix().concat(["zellij", "-s", name]))
        } else {
            Quickshell.execDetached(_terminalPrefix().concat(["tmux", "new-session", "-s", name]))
        }
    }

    readonly property bool supportsRename: muxType !== "zellij"

    function renameSession(oldName, newName) {
        if (root.muxType === "zellij")
            return
        Quickshell.execDetached(["tmux", "rename-session", "-t", oldName, newName])
        Qt.callLater(refreshSessions)
    }

    function killSession(name) {
        if (root.muxType === "zellij") {
            Quickshell.execDetached(["zellij", "kill-session", name])
        } else {
            Quickshell.execDetached(["tmux", "kill-session", "-t", name])
        }
        Qt.callLater(refreshSessions)
    }
}
