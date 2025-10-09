pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Common

Singleton {
    id: root

    property bool hasUwsm: false
    property bool isElogind: false
    property bool hibernateSupported: false
    property bool inhibitorAvailable: true
    property bool idleInhibited: false
    property string inhibitReason: "Keep system awake"
    property bool hasPrimeRun: false

    readonly property bool nativeInhibitorAvailable: {
        try {
            return typeof IdleInhibitor !== "undefined"
        } catch (e) {
            return false
        }
    }

    property bool loginctlAvailable: false
    property string sessionId: ""
    property string sessionPath: ""
    property bool locked: false
    property bool active: false
    property bool idleHint: false
    property bool lockedHint: false
    property bool preparingForSleep: false
    property string sessionType: ""
    property string userName: ""
    property string seat: ""
    property string display: ""

    signal sessionLocked()
    signal sessionUnlocked()
    signal prepareForSleep()
    signal loginctlStateChanged()

    property bool subscriptionConnected: false
    property bool stateInitialized: false

    readonly property string socketPath: Quickshell.env("DMS_SOCKET")

    Timer {
        id: sessionInitTimer
        interval: 200
        running: true
        repeat: false
        onTriggered: {
            detectElogindProcess.running = true
            detectHibernateProcess.running = true
            detectPrimeRunProcess.running = true
            console.log("SessionService: Native inhibitor available:", nativeInhibitorAvailable)
            if (socketPath && socketPath.length > 0) {
                checkDMSCapabilities()
            } else {
                console.log("SessionService: DMS_SOCKET not set, using fallback")
                initFallbackLoginctl()
            }
        }
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

    Process {
        id: detectHibernateProcess
        running: false
        command: ["grep", "-q", "disk", "/sys/power/state"]

        onExited: function (exitCode) {
            hibernateSupported = (exitCode === 0)
        }
    }

    Process {
        id: detectPrimeRunProcess
        running: false
        command: ["which", "prime-run"]

        onExited: function (exitCode) {
            hasPrimeRun = (exitCode === 0)
        }
    }

    Process {
        id: uwsmLogout
        command: ["uwsm", "stop"]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim().toLowerCase().includes("not running")) {
                    _logout()
                }
            }
        }

        onExited: function (exitCode) {
            if (exitCode === 0) {
                return
            }
            _logout()
        }
    }

    // * Apps
    function launchDesktopEntry(desktopEntry, usePrimeRun) {
        let cmd = desktopEntry.command
        if (usePrimeRun && hasPrimeRun) {
            cmd = ["prime-run"].concat(cmd)
        }
        if (SessionData.launchPrefix && SessionData.launchPrefix.length > 0) {
            const launchPrefix = SessionData.launchPrefix.trim().split(" ")
            cmd = launchPrefix.concat(cmd)
        }

        Quickshell.execDetached({
            command: cmd,
            workingDirectory: desktopEntry.workingDirectory || Quickshell.env("HOME"),
        });
    }

    function launchDesktopAction(desktopEntry, action, usePrimeRun) {
        let cmd = action.command
        if (usePrimeRun && hasPrimeRun) {
            cmd = ["prime-run"].concat(cmd)
        }
        if (SessionData.launchPrefix && SessionData.launchPrefix.length > 0) {
            const launchPrefix = SessionData.launchPrefix.trim().split(" ")
            cmd = launchPrefix.concat(cmd)
        }

        Quickshell.execDetached({
            command: cmd,
            workingDirectory: desktopEntry.workingDirectory || Quickshell.env("HOME"),
        });
    }

    // * Session management
    function logout() {
        if (hasUwsm) {
            uwsmLogout.running = true
        }
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

    function hibernate() {
        Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "hibernate"])
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
        if (idleInhibited) {
            return
        }
        console.log("SessionService: Enabling idle inhibit (native:", nativeInhibitorAvailable, ")")
        idleInhibited = true
        inhibitorChanged()
    }

    function disableIdleInhibit() {
        if (!idleInhibited) {
            return
        }
        console.log("SessionService: Disabling idle inhibit (native:", nativeInhibitorAvailable, ")")
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

        if (idleInhibited && !nativeInhibitorAvailable) {
            const wasActive = idleInhibited
            idleInhibited = false

            Qt.callLater(() => {
                             if (wasActive) {
                                 idleInhibited = true
                             }
                         })
        }
    }

    Process {
        id: idleInhibitProcess

        command: {
            if (!idleInhibited || nativeInhibitorAvailable) {
                return ["true"]
            }

            console.log("SessionService: Starting systemd/elogind inhibit process")
            return [isElogind ? "elogind-inhibit" : "systemd-inhibit", "--what=idle", "--who=quickshell", `--why=${inhibitReason}`, "--mode=block", "sleep", "infinity"]
        }

        running: idleInhibited && !nativeInhibitorAvailable

        onRunningChanged: {
            console.log("SessionService: Inhibit process running:", running, "(native:", nativeInhibitorAvailable, ")")
        }

        onExited: function (exitCode) {
            if (idleInhibited && exitCode !== 0 && !nativeInhibitorAvailable) {
                console.warn("SessionService: Inhibitor process crashed with exit code:", exitCode)
                idleInhibited = false
                ToastService.showWarning("Idle inhibitor failed")
            }
        }
    }

    Connections {
        target: DMSService

        function onConnectionStateChanged() {
            if (DMSService.isConnected) {
                checkDMSCapabilities()
            }
        }
    }

    Connections {
        target: DMSService
        enabled: DMSService.isConnected

        function onCapabilitiesChanged() {
            checkDMSCapabilities()
        }
    }

    DankSocket {
        id: subscriptionSocket
        path: root.socketPath
        connected: loginctlAvailable

        onConnectionStateChanged: {
            root.subscriptionConnected = connected
        }

        parser: SplitParser {
            onRead: line => {
                if (!line || line.length === 0) {
                    return
                }

                try {
                    const response = JSON.parse(line)

                    if (response.capabilities) {
                        Qt.callLater(() => sendSubscribeRequest())
                        return
                    }

                    if (response.result && response.result.type === "loginctl_event") {
                        handleLoginctlEvent(response.result)
                    } else if (response.result && response.result.type === "state_changed" && response.result.data) {
                        updateLoginctlState(response.result.data)
                    }
                } catch (e) {
                    console.warn("SessionService: Failed to parse subscription response:", line, e)
                }
            }
        }
    }

    function sendSubscribeRequest() {
        subscriptionSocket.send({
            "id": 2,
            "method": "loginctl.subscribe"
        })
    }

    function checkDMSCapabilities() {
        if (!DMSService.isConnected) {
            return
        }

        if (DMSService.capabilities.length === 0) {
            return
        }

        if (DMSService.capabilities.includes("loginctl")) {
            loginctlAvailable = true
            if (!stateInitialized) {
                stateInitialized = true
                getLoginctlState()
                subscriptionSocket.connected = true
            }
        } else {
            console.log("SessionService: loginctl capability not available in DMS, using fallback")
            initFallbackLoginctl()
        }
    }

    function getLoginctlState() {
        if (!loginctlAvailable) return

        DMSService.sendRequest("loginctl.getState", null, response => {
            if (response.result) {
                updateLoginctlState(response.result)
            }
        })
    }

    function updateLoginctlState(state) {
        sessionId = state.sessionId || ""
        sessionPath = state.sessionPath || ""
        locked = state.locked || false
        active = state.active || false
        idleHint = state.idleHint || false
        lockedHint = state.lockedHint || false
        sessionType = state.sessionType || ""
        userName = state.userName || ""
        seat = state.seat || ""
        display = state.display || ""

        const wasPreparing = preparingForSleep
        preparingForSleep = state.preparingForSleep || false

        if (preparingForSleep && !wasPreparing) {
            prepareForSleep()
        }

        loginctlStateChanged()
    }

    function handleLoginctlEvent(event) {
        if (event.event === "Lock") {
            locked = true
            lockedHint = true
            sessionLocked()
        } else if (event.event === "Unlock") {
            locked = false
            lockedHint = false
            sessionUnlocked()
        } else if (event.event === "PrepareForSleep") {
            preparingForSleep = event.data?.sleeping || false
            if (preparingForSleep) {
                prepareForSleep()
            }
        }
    }

    function initFallbackLoginctl() {
        getSessionPathFallback.running = true
    }

    Process {
        id: getSessionPathFallback
        command: ["gdbus", "call", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1", "--method", "org.freedesktop.login1.Manager.GetSession", Quickshell.env("XDG_SESSION_ID") || "self"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/objectpath '([^']+)'/)
                if (match) {
                    sessionPath = match[1]
                    console.log("SessionService: Found session path (fallback):", sessionPath)
                    checkCurrentLockStateFallback.running = true
                    lockStateMonitorFallback.running = true
                }
            }
        }
    }

    Process {
        id: checkCurrentLockStateFallback
        command: sessionPath ? ["gdbus", "call", "--system", "--dest", "org.freedesktop.login1", "--object-path", sessionPath, "--method", "org.freedesktop.DBus.Properties.Get", "org.freedesktop.login1.Session", "LockedHint"] : []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.includes("true")) {
                    locked = true
                    lockedHint = true
                    sessionLocked()
                }
            }
        }
    }

    Process {
        id: lockStateMonitorFallback
        command: sessionPath ? ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"] : []
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (sessionPath && line.includes(sessionPath)) {
                    if (line.includes("org.freedesktop.login1.Session.Lock")) {
                        locked = true
                        lockedHint = true
                        sessionLocked()
                    } else if (line.includes("org.freedesktop.login1.Session.Unlock")) {
                        locked = false
                        lockedHint = false
                        sessionUnlocked()
                    } else if (line.includes("LockedHint") && line.includes("true")) {
                        locked = true
                        lockedHint = true
                        loginctlStateChanged()
                    } else if (line.includes("LockedHint") && line.includes("false")) {
                        locked = false
                        lockedHint = false
                        loginctlStateChanged()
                    }
                }
                if (line.includes("PrepareForSleep") && line.includes("true") && SessionData.lockBeforeSuspend) {
                    preparingForSleep = true
                    prepareForSleep()
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("SessionService: gdbus monitor fallback failed, exit code:", exitCode)
            }
        }
    }

    Process {
        id: lockSessionFallback
        command: ["loginctl", "lock-session"]
        running: false
    }

}
