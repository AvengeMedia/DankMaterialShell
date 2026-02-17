pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.I3
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
    property string nvidiaCommand: ""

    readonly property bool nativeInhibitorAvailable: {
        try {
            return typeof IdleInhibitor !== "undefined";
        } catch (e) {
            return false;
        }
    }

    property bool loginctlAvailable: false
    property bool wtypeAvailable: false
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

    signal sessionLocked
    signal sessionUnlocked
    signal sessionResumed
    signal loginctlStateChanged

    property bool stateInitialized: false

    readonly property string socketPath: Quickshell.env("DMS_SOCKET")

    Timer {
        id: sessionInitTimer
        interval: 200
        running: true
        repeat: false
        onTriggered: {
            detectElogindProcess.running = true;
            detectHibernateProcess.running = true;
            detectPrimeRunProcess.running = true;
            detectWtypeProcess.running = true;
            console.info("SessionService: Native inhibitor available:", nativeInhibitorAvailable);
            if (!SettingsData.loginctlLockIntegration) {
                console.log("SessionService: loginctl lock integration disabled by user");
                return;
            }
            if (socketPath && socketPath.length > 0) {
                checkDMSCapabilities();
            } else {
                console.log("SessionService: DMS_SOCKET not set");
            }
        }
    }

    Process {
        id: detectUwsmProcess
        running: false
        command: ["which", "uwsm"]

        onExited: function (exitCode) {
            hasUwsm = (exitCode === 0);
        }
    }

    Process {
        id: detectElogindProcess
        running: false
        command: ["sh", "-c", "ps -eo comm= | grep -E '^(elogind|elogind-daemon)$'"]

        onExited: function (exitCode) {
            console.log("SessionService: Elogind detection exited with code", exitCode);
            isElogind = (exitCode === 0);
        }
    }

    Process {
        id: detectHibernateProcess
        running: false
        command: ["grep", "-q", "disk", "/sys/power/state"]

        onExited: function (exitCode) {
            hibernateSupported = (exitCode === 0);
        }
    }

    Process {
        id: hibernateProcess
        running: false

        property string errorOutput: ""

        stderr: SplitParser {
            splitMarker: "\n"
            onRead: data => hibernateProcess.errorOutput += data.trim()
        }

        onExited: function (exitCode) {
            if (exitCode === 0) {
                errorOutput = "";
                return;
            }
            ToastService.showError("Hibernate failed", errorOutput);
            errorOutput = "";
        }
    }

    Process {
        id: detectWtypeProcess
        running: false
        command: ["which", "wtype"]
        onExited: exitCode => {
            wtypeAvailable = (exitCode === 0);
        }
    }

    Process {
        id: detectPrimeRunProcess
        running: false
        command: ["which", "prime-run"]

        onExited: function (exitCode) {
            if (exitCode === 0) {
                nvidiaCommand = "prime-run";
            } else {
                detectNvidiaOffloadProcess.running = true;
            }
        }
    }

    Process {
        id: detectNvidiaOffloadProcess
        running: false
        command: ["which", "nvidia-offload"]

        onExited: function (exitCode) {
            if (exitCode === 0) {
                nvidiaCommand = "nvidia-offload";
            }
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
                    _logout();
                }
            }
        }

        onExited: function (exitCode) {
            if (exitCode === 0) {
                return;
            }
            _logout();
        }
    }

    function escapeShellArg(arg) {
        return "'" + arg.replace(/'/g, "'\\''") + "'";
    }

    function needsShellExecution(prefix) {
        if (!prefix || prefix.length === 0)
            return false;
        return /[;&|<>()$`\\"']/.test(prefix);
    }

    function parseEnvVars(envVarsStr) {
        if (!envVarsStr || envVarsStr.trim().length === 0)
            return {};
        const envObj = {};
        const pairs = envVarsStr.trim().split(/\s+/);
        for (const pair of pairs) {
            const eqIndex = pair.indexOf("=");
            if (eqIndex > 0) {
                const key = pair.substring(0, eqIndex);
                const value = pair.substring(eqIndex + 1);
                envObj[key] = value;
            }
        }
        return envObj;
    }

    function launchDesktopEntry(desktopEntry, useNvidia) {
        let cmd = desktopEntry.command;
        if (useNvidia && nvidiaCommand)
            cmd = [nvidiaCommand].concat(cmd);

        const appId = desktopEntry.id || desktopEntry.execString || desktopEntry.exec || "";
        const override = SessionData.getAppOverride(appId);

        if (override?.extraFlags) {
            const extraArgs = override.extraFlags.trim().split(/\s+/).filter(arg => arg.length > 0);
            cmd = cmd.concat(extraArgs);
        }

        const userPrefix = SettingsData.launchPrefix?.trim() || "";
        const defaultPrefix = Quickshell.env("DMS_DEFAULT_LAUNCH_PREFIX") || "";
        const prefix = userPrefix.length > 0 ? userPrefix : defaultPrefix;
        const workDir = desktopEntry.workingDirectory || Quickshell.env("HOME");
        const cursorEnv = typeof SettingsData.getCursorEnvironment === "function" ? SettingsData.getCursorEnvironment() : {};

        const overrideEnv = override?.envVars ? parseEnvVars(override.envVars) : {};
        const finalEnv = Object.assign({}, cursorEnv, overrideEnv);

        if (desktopEntry.runInTerminal) {
            const terminal = Quickshell.env("TERMINAL") || "xterm";
            const escapedCmd = cmd.map(arg => escapeShellArg(arg)).join(" ");
            const shellCmd = prefix.length > 0 ? `${prefix} ${escapedCmd}` : escapedCmd;
            Quickshell.execDetached({
                command: [terminal, "-e", "sh", "-c", shellCmd],
                workingDirectory: workDir,
                environment: finalEnv
            });
            return;
        }

        if (prefix.length > 0 && needsShellExecution(prefix)) {
            const escapedCmd = cmd.map(arg => escapeShellArg(arg)).join(" ");
            Quickshell.execDetached({
                command: ["sh", "-c", `${prefix} ${escapedCmd}`],
                workingDirectory: workDir,
                environment: finalEnv
            });
            return;
        }

        if (prefix.length > 0)
            cmd = prefix.split(" ").concat(cmd);

        Quickshell.execDetached({
            command: cmd,
            workingDirectory: workDir,
            environment: finalEnv
        });
    }

    function launchDesktopAction(desktopEntry, action, useNvidia) {
        let cmd = action.command;
        if (useNvidia && nvidiaCommand)
            cmd = [nvidiaCommand].concat(cmd);

        const userPrefix = SettingsData.launchPrefix?.trim() || "";
        const defaultPrefix = Quickshell.env("DMS_DEFAULT_LAUNCH_PREFIX") || "";
        const prefix = userPrefix.length > 0 ? userPrefix : defaultPrefix;
        const workDir = desktopEntry.workingDirectory || Quickshell.env("HOME");
        const cursorEnv = typeof SettingsData.getCursorEnvironment === "function" ? SettingsData.getCursorEnvironment() : {};

        if (prefix.length > 0 && needsShellExecution(prefix)) {
            const escapedCmd = cmd.map(arg => escapeShellArg(arg)).join(" ");
            Quickshell.execDetached({
                command: ["sh", "-c", `${prefix} ${escapedCmd}`],
                workingDirectory: workDir,
                environment: cursorEnv
            });
            return;
        }

        if (prefix.length > 0)
            cmd = prefix.split(" ").concat(cmd);

        Quickshell.execDetached({
            command: cmd,
            workingDirectory: workDir,
            environment: cursorEnv
        });
    }

    // * Session management
    function logout() {
        if (hasUwsm) {
            uwsmLogout.running = true;
        }
        _logout();
    }

    function _logout() {
        if (SettingsData.customPowerActionLogout.length === 0) {
            if (CompositorService.isNiri) {
                NiriService.quit();
                return;
            }

            if (CompositorService.isDwl) {
                DwlService.quit();
                return;
            }

            if (CompositorService.isSway || CompositorService.isScroll || CompositorService.isMiracle) {
                try {
                    I3.dispatch("exit");
                } catch (_) {}
                return;
            }

            Hyprland.dispatch("exit");
        } else {
            Quickshell.execDetached(["sh", "-c", SettingsData.customPowerActionLogout]);
        }
    }

    function suspend() {
        if (SettingsData.customPowerActionSuspend.length === 0) {
            Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "suspend"]);
        } else {
            Quickshell.execDetached(["sh", "-c", SettingsData.customPowerActionSuspend]);
        }
    }

    function hibernate() {
        hibernateProcess.errorOutput = "";
        if (SettingsData.customPowerActionHibernate.length > 0) {
            hibernateProcess.command = ["sh", "-c", SettingsData.customPowerActionHibernate];
        } else {
            hibernateProcess.command = [isElogind ? "loginctl" : "systemctl", "hibernate"];
        }
        hibernateProcess.running = true;
    }

    function suspendThenHibernate() {
        Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "suspend-then-hibernate"]);
    }

    function suspendWithBehavior(behavior) {
        if (behavior === SettingsData.SuspendBehavior.Hibernate) {
            hibernate();
        } else if (behavior === SettingsData.SuspendBehavior.SuspendThenHibernate) {
            suspendThenHibernate();
        } else {
            suspend();
        }
    }

    function reboot() {
        if (SettingsData.customPowerActionReboot.length === 0) {
            Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "reboot"]);
        } else {
            Quickshell.execDetached(["sh", "-c", SettingsData.customPowerActionReboot]);
        }
    }

    function poweroff() {
        if (SettingsData.customPowerActionPowerOff.length === 0) {
            Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "poweroff"]);
        } else {
            Quickshell.execDetached(["sh", "-c", SettingsData.customPowerActionPowerOff]);
        }
    }

    // * Idle Inhibitor
    signal inhibitorChanged

    function enableIdleInhibit() {
        if (idleInhibited) {
            return;
        }
        console.log("SessionService: Enabling idle inhibit (native:", nativeInhibitorAvailable, ")");
        idleInhibited = true;
        inhibitorChanged();
    }

    function disableIdleInhibit() {
        if (!idleInhibited) {
            return;
        }
        console.log("SessionService: Disabling idle inhibit (native:", nativeInhibitorAvailable, ")");
        idleInhibited = false;
        inhibitorChanged();
    }

    function toggleIdleInhibit() {
        if (idleInhibited) {
            disableIdleInhibit();
        } else {
            enableIdleInhibit();
        }
    }

    function setInhibitReason(reason) {
        inhibitReason = reason;

        if (idleInhibited && !nativeInhibitorAvailable) {
            const wasActive = idleInhibited;
            idleInhibited = false;

            Qt.callLater(() => {
                if (wasActive) {
                    idleInhibited = true;
                }
            });
        }
    }

    Process {
        id: idleInhibitProcess

        command: {
            if (!idleInhibited || nativeInhibitorAvailable) {
                return ["true"];
            }

            console.log("SessionService: Starting systemd/elogind inhibit process");
            return [isElogind ? "elogind-inhibit" : "systemd-inhibit", "--what=idle", "--who=quickshell", `--why=${inhibitReason}`, "--mode=block", "sleep", "infinity"];
        }

        running: idleInhibited && !nativeInhibitorAvailable

        onRunningChanged: {
            console.log("SessionService: Inhibit process running:", running, "(native:", nativeInhibitorAvailable, ")");
        }

        onExited: function (exitCode) {
            if (idleInhibited && exitCode !== 0 && !nativeInhibitorAvailable) {
                console.warn("SessionService: Inhibitor process crashed with exit code:", exitCode);
                idleInhibited = false;
                ToastService.showWarning("Idle inhibitor failed");
            }
        }
    }

    Connections {
        target: DMSService

        function onConnectionStateChanged() {
            if (DMSService.isConnected) {
                checkDMSCapabilities();
            }
        }

        function onCapabilitiesReceived() {
            syncSleepInhibitor();
        }
    }

    Connections {
        target: DMSService
        enabled: DMSService.isConnected

        function onCapabilitiesChanged() {
            checkDMSCapabilities();
        }
    }

    Connections {
        target: SettingsData

        function onLoginctlLockIntegrationChanged() {
            if (SettingsData.loginctlLockIntegration) {
                if (socketPath && socketPath.length > 0 && loginctlAvailable) {
                    if (!stateInitialized) {
                        stateInitialized = true;
                        getLoginctlState();
                        syncLockBeforeSuspend();
                    }
                }
            } else {
                stateInitialized = false;
            }
            syncSleepInhibitor();
        }

        function onLockBeforeSuspendChanged() {
            if (SettingsData.loginctlLockIntegration) {
                syncLockBeforeSuspend();
            }
            syncSleepInhibitor();
        }
    }

    Connections {
        target: DMSService
        enabled: SettingsData.loginctlLockIntegration

        function onLoginctlStateUpdate(data) {
            updateLoginctlState(data);
        }

        function onLoginctlEvent(event) {
            handleLoginctlEvent(event);
        }
    }

    function checkDMSCapabilities() {
        if (!DMSService.isConnected) {
            return;
        }

        if (DMSService.capabilities.length === 0) {
            return;
        }

        if (DMSService.capabilities.includes("loginctl")) {
            loginctlAvailable = true;
            if (SettingsData.loginctlLockIntegration && !stateInitialized) {
                stateInitialized = true;
                getLoginctlState();
                syncLockBeforeSuspend();
            }
        } else {
            loginctlAvailable = false;
            console.log("SessionService: loginctl capability not available in DMS");
        }
    }

    function getLoginctlState() {
        if (!loginctlAvailable)
            return;
        DMSService.sendRequest("loginctl.getState", null, response => {
            if (response.result) {
                updateLoginctlState(response.result);
            }
        });
    }

    function syncLockBeforeSuspend() {
        if (!loginctlAvailable)
            return;
        DMSService.sendRequest("loginctl.setLockBeforeSuspend", {
            enabled: SettingsData.lockBeforeSuspend
        }, response => {
            if (response.error) {
                console.warn("SessionService: Failed to sync lock before suspend:", response.error);
            } else {
                console.log("SessionService: Synced lock before suspend:", SettingsData.lockBeforeSuspend);
            }
        });
    }

    function syncSleepInhibitor() {
        if (!loginctlAvailable)
            return;
        if (!DMSService.apiVersion || DMSService.apiVersion < 4)
            return;
        DMSService.sendRequest("loginctl.setSleepInhibitorEnabled", {
            enabled: SettingsData.loginctlLockIntegration && SettingsData.lockBeforeSuspend
        }, response => {
            if (response.error) {
                console.warn("SessionService: Failed to sync sleep inhibitor:", response.error);
            } else {
                console.log("SessionService: Synced sleep inhibitor:", SettingsData.loginctlLockIntegration);
            }
        });
    }

    function updateLoginctlState(state) {
        const wasLocked = locked;
        const wasSleeping = preparingForSleep;

        sessionId = state.sessionId || "";
        sessionPath = state.sessionPath || "";
        locked = state.locked || false;
        active = state.active || false;
        idleHint = state.idleHint || false;
        lockedHint = state.lockedHint || false;
        preparingForSleep = state.preparingForSleep || false;
        sessionType = state.sessionType || "";
        userName = state.userName || "";
        seat = state.seat || "";
        display = state.display || "";

        if (locked && !wasLocked) {
            sessionLocked();
        } else if (!locked && wasLocked) {
            sessionUnlocked();
        }

        if (wasSleeping && !preparingForSleep) {
            sessionResumed();
        }

        loginctlStateChanged();
    }

    function handleLoginctlEvent(event) {
        if (event.event === "Lock") {
            locked = true;
            lockedHint = true;
            sessionLocked();
        } else if (event.event === "Unlock") {
            locked = false;
            lockedHint = false;
            sessionUnlocked();
        }
    }
}
