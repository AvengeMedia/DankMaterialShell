pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Common

Singleton {
    id: root

    property bool hasUwsm: false
    property bool isElogind: false
    property bool inhibitorAvailable: true
    property bool idleInhibited: false
    property string inhibitReason: "Keep system awake"

    Component.onCompleted: {
        detectElogindProcess.running = true
    }

    Process {
        id: detectUwsmProcess
        running: false
        command: ["which", "uwsm"]

        onExited: function (exitCode) {
            hasUwsm = (exitCode === 0)
        }
    }

    Process {
        id: detectElogindProcess
        running: false
        command: ["sh", "-c", "ps -eo comm= | grep -E '^(elogind|elogind-daemon)$'"]

        onExited: function (exitCode) {
            console.log("SessionService: Elogind detection exited with code", exitCode)
            isElogind = (exitCode === 0)
        }
    }

    // ! TODO - hacky because uwsm doesnt behave as expected
    // uwsm idk, always passes the is-active check even if it's not a session
    // It reutrns exit code 0 when uwsm stop fails
    // They have flaws in their system, so we need to be hacky to just try it and
    // detect random text
    Process {
        id: uwsmLogout
        command: ["uwsm", "stop"]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim().toLowerCase().includes("not running")) {
                    _logout()
                }
            }
        }

        onExited: function(exitCode) {
            if (exitCode === 0) {
                return
            }
            _logout()
        }
    }

    function logout() {
        if (hasUwsm)
            uwsmLogout.running = true
        _logout()
    }

    function _logout() {
        if (CompositorService.isNiri) {
            NiriService.quit()
            return
        }

        // Hyprland fallback
        Hyprland.dispatch("exit")
    }

    function suspend() {
        Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "suspend"])
    }

    function reboot() {
        Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "reboot"])
    }

    function poweroff() {
        Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "poweroff"])
    }

    // * Idle Inhibitor
    signal inhibitorChanged

    function enableIdleInhibit() {
        if (idleInhibited)
            return
        idleInhibited = true
        inhibitorChanged()
    }

    function disableIdleInhibit() {
        if (!idleInhibited)
            return
        idleInhibited = false
        inhibitorChanged()
    }

    function toggleIdleInhibit() {
        if (idleInhibited) {
            disableIdleInhibit()
        } else {
            enableIdleInhibit()
        }
    }

    function setInhibitReason(reason) {
        inhibitReason = reason

        if (idleInhibited) {
            const wasActive = idleInhibited
            idleInhibited = false

            Qt.callLater(() => {
                             if (wasActive)
                             idleInhibited = true
                         })
        }
    }

    Process {
        id: idleInhibitProcess

        command: {
            if (!idleInhibited) {
                return ["true"]
            }

            return [isElogind ? "elogind-inhibit" : "systemd-inhibit", "--what=idle", "--who=quickshell", "--why="
                    + inhibitReason, "--mode=block", "sleep", "infinity"]
        }

        running: idleInhibited

        onExited: function (exitCode) {
            if (idleInhibited && exitCode !== 0) {
                console.warn("SessionService: Inhibitor process crashed with exit code:",
                             exitCode)
                idleInhibited = false
                ToastService.showWarning("Idle inhibitor failed")
            }
        }
    }

    IpcHandler {
        function toggle(): string {
            root.toggleIdleInhibit()
            return root.idleInhibited ? "Idle inhibit enabled" : "Idle inhibit disabled"
        }

        function enable(): string {
            root.enableIdleInhibit()
            return "Idle inhibit enabled"
        }

        function disable(): string {
            root.disableIdleInhibit()
            return "Idle inhibit disabled"
        }

        function status(): string {
            return root.idleInhibited ? "Idle inhibit is enabled" : "Idle inhibit is disabled"
        }

        function reason(newReason: string): string {
            if (!newReason) {
                return "Current reason: " + root.inhibitReason
            }

            root.setInhibitReason(newReason)
            return "Inhibit reason set to: " + newReason
        }

        target: "inhibit"
    }
}
