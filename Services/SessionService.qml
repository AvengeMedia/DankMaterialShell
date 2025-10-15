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
            if (!SettingsData.loginctlLockIntegration) {
                console.log("SessionService: loginctl lock integration disabled by user")
                return
            }
            if (socketPath && socketPath.length > 0) {
                checkDMSCapabilities()
            } else {
                console.log("SessionService: DMS_SOCKET not set")
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
        if (SettingsData.launchPrefix && SettingsData.launchPrefix.length > 0) {
            const launchPrefix = SettingsData.launchPrefix.trim().split(" ")
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
        if (SettingsData.launchPrefix && SettingsData.launchPrefix.length > 0) {
            const launchPrefix = SettingsData.launchPrefix.trim().split(" ")
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
        if (SettingsData.customPowerActionLogout.length === 0) {
            if (CompositorService.isNiri) {
                NiriService.quit()
                return
            }

            // Hyprland fallback
            Hyprland.dispatch("exit")
        } else {
            Quickshell.execDetached(SettingsData.customPowerActionLogout.split(" "))
        }
    }

    function suspend() {
        if (SettingsData.customPowerActionSuspend.length === 0) {
            Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "suspend"])
        } else {
            Quickshell.execDetached(SettingsData.customPowerActionSuspend.split(" "))
        }
    }

    function hibernate() {
        if (SettingsData.customPowerActionHibernate.length === 0) {
            Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "hibernate"])
        } else {
            Quickshell.execDetached(SettingsData.customPowerActionHibernate.split(" "))
        }
    }

    function reboot() {
        if (SettingsData.customPowerActionReboot.length === 0) {
            Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "reboot"])
        } else {
            Quickshell.execDetached(SettingsData.customPowerActionReboot.split(" "))
        }
    }

    function poweroff() {
        if (SettingsData.customPowerActionPowerOff.length === 0) {
            Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "poweroff"])
        } else {
            Quickshell.execDetached(SettingsData.customPowerActionPowerOff.split(" "))
        }
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

    Connections {
        target: SettingsData

        function onLoginctlLockIntegrationChanged() {
            if (SettingsData.loginctlLockIntegration) {
                if (socketPath && socketPath.length > 0 && loginctlAvailable) {
                    if (!stateInitialized) {
                        stateInitialized = true
                        getLoginctlState()
                        syncLockBeforeSuspend()
                    }
                }
            } else {
                stateInitialized = false
            }
        }

        function onLockBeforeSuspendChanged() {
            if (SettingsData.loginctlLockIntegration) {
                syncLockBeforeSuspend()
            }
        }
    }

    Connections {
        target: DMSService
        enabled: SettingsData.loginctlLockIntegration

        function onLoginctlStateUpdate(data) {
            updateLoginctlState(data)
        }

        function onLoginctlEvent(event) {
            handleLoginctlEvent(event)
        }
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
            if (SettingsData.loginctlLockIntegration && !stateInitialized) {
                stateInitialized = true
                getLoginctlState()
                syncLockBeforeSuspend()
            }
        } else {
            loginctlAvailable = false
            console.log("SessionService: loginctl capability not available in DMS")
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

    function syncLockBeforeSuspend() {
        if (!loginctlAvailable) return

        DMSService.sendRequest("loginctl.setLockBeforeSuspend", {
            enabled: SettingsData.lockBeforeSuspend
        }, response => {
            if (response.error) {
                console.warn("SessionService: Failed to sync lock before suspend:", response.error)
            } else {
                console.log("SessionService: Synced lock before suspend:", SettingsData.lockBeforeSuspend)
            }
        })
    }

    function updateLoginctlState(state) {
        const wasLocked = locked

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

        if (locked && !wasLocked) {
            sessionLocked()
        } else if (!locked && wasLocked) {
            sessionUnlocked()
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
        }
    }

}
