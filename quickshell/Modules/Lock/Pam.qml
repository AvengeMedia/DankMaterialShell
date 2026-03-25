pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs.Common

Scope {
    id: root

    property bool lockSecured: false
    property bool unlockInProgress: false

    readonly property alias passwd: passwd
    readonly property alias fprint: fprint
    property string lockMessage
    property string state
    property string fprintState
    property string buffer

    signal flashMsg
    signal unlockRequested

    function resetAuthFlows(): void {
        passwd.abort();
        fprint.abort();
        u2f.abort();
        errorRetry.running = false;
        u2fErrorRetry.running = false;
        u2fPendingTimeout.running = false;
        passwdActiveTimeout.running = false;
        unlockRequestTimeout.running = false;
        root.u2fPending = false;
        root.u2fState = "";
        root.unlockInProgress = false;
    }

    function recoverFromAuthStall(newState: string): void {
        resetAuthFlows();
        root.state = newState;
        flashMsg();
        stateReset.restart();
        fprint.checkAvail();
        u2f.checkAvail();
    }

    function completeUnlock(): void {
        if (!root.unlockInProgress) {
            root.unlockInProgress = true;
            passwd.abort();
            fprint.abort();
            u2f.abort();
            errorRetry.running = false;
            u2fErrorRetry.running = false;
            u2fPendingTimeout.running = false;
            root.u2fPending = false;
            root.u2fState = "";
            unlockRequestTimeout.restart();
            unlockRequested();
        }
    }

    function proceedAfterPrimaryAuth(): void {
        if (SettingsData.enableU2f && SettingsData.u2fMode === "and" && u2f.available) {
            u2f.startForSecondFactor();
        } else {
            completeUnlock();
        }
    }

    function cancelU2fPending(): void {
        if (!root.u2fPending)
            return;
        u2f.abort();
        u2fErrorRetry.running = false;
        u2fPendingTimeout.running = false;
        root.u2fPending = false;
        root.u2fState = "";
        fprint.checkAvail();
    }

    FileView {
        id: dankshellConfigWatcher

        path: "/etc/pam.d/dankshell"
        printErrors: false
    }

    FileView {
        id: loginConfigWatcher

        path: "/etc/pam.d/login"
        printErrors: false
    }

    FileView {
        id: u2fConfigWatcher

        path: "/etc/pam.d/dankshell-u2f"
        printErrors: false
    }

    readonly property string bundledPasswdConfig: SettingsData.lockFaillockSupported ? "login-faillock" : "login"

    PamContext {
        id: passwd

        config: dankshellConfigWatcher.loaded ? "dankshell" : root.bundledPasswdConfig
        configDirectory: (dankshellConfigWatcher.loaded || loginConfigWatcher.loaded) ? "/etc/pam.d" : Quickshell.shellDir + "/assets/pam"

        onMessageChanged: {
            if (message.startsWith("The account is locked")) {
                root.lockMessage = message;
            } else if (root.lockMessage && message.endsWith(" left to unlock)")) {
                root.lockMessage += "\n" + message;
            } else if (root.lockMessage && message && message.length > 0) {
                root.lockMessage = "";
            }
        }

        onResponseRequiredChanged: {
            if (!responseRequired)
                return;

            respond(root.buffer);
        }

        onCompleted: res => {
            if (res === PamResult.Success) {
                if (!root.unlockInProgress) {
                    root.unlockInProgress = true;
                    fprint.abort();
                    root.unlockRequested();
                }
                return;
            }

            unlockRequestTimeout.running = false;
            root.unlockInProgress = false;
            root.u2fPending = false;
            root.u2fState = "";
            u2fPendingTimeout.running = false;
            u2f.abort();

            if (res === PamResult.Error)
                root.state = "error";
            else if (res === PamResult.MaxTries)
                root.state = "max";
            else if (res === PamResult.Failed)
                root.state = "fail";

            root.flashMsg();
            stateReset.restart();
        }
    }

    Connections {
        target: passwd

        function onActiveChanged() {
            if (passwd.active) {
                passwdActiveTimeout.restart();
            } else {
                passwdActiveTimeout.running = false;
            }
        }
    }

    PamContext {
        id: fprint

        property bool available: SettingsData.lockFingerprintReady
        property int tries
        property int errorTries

        function checkAvail(): void {
            if (!available || !SettingsData.enableFprint || !root.lockSecured) {
                abort();
                return;
            }

            tries = 0;
            errorTries = 0;
            start();
        }

        config: "fprint"
        configDirectory: Quickshell.shellDir + "/assets/pam"

        onCompleted: res => {
            if (!available)
                return;

            if (res === PamResult.Success) {
                if (!root.unlockInProgress) {
                    root.unlockInProgress = true;
                    passwd.abort();
                    root.unlockRequested();
                }
                return;
            }

            if (res === PamResult.Error) {
                root.fprintState = "error";
                errorTries++;
                if (errorTries < 5) {
                    abort();
                    errorRetry.restart();
                }
            } else if (res === PamResult.MaxTries) {
                tries++;
                if (tries < SettingsData.maxFprintTries) {
                    root.fprintState = "fail";
                    start();
                } else {
                    root.fprintState = "max";
                    abort();
                }
            }

            root.flashMsg();
            fprintStateReset.start();
        }
    }

    PamContext {
        id: u2f

        property bool available: SettingsData.lockU2fReady

        function checkAvail(): void {
            if (!available || !SettingsData.enableU2f || !root.lockSecured) {
                abort();
                return;
            }

            if (SettingsData.u2fMode === "or") {
                start();
            }
        }

        function startForSecondFactor(): void {
            if (!available || !SettingsData.enableU2f) {
                root.completeUnlock();
                return;
            }
            abort();
            root.u2fPending = true;
            root.u2fState = "";
            u2fPendingTimeout.restart();
            start();
        }

        config: u2fConfigWatcher.loaded ? "dankshell-u2f" : "u2f"
        configDirectory: u2fConfigWatcher.loaded ? "/etc/pam.d" : Quickshell.shellDir + "/assets/pam"

        onMessageChanged: {
            if (message.toLowerCase().includes("touch"))
                root.u2fState = "waiting";
        }

        onCompleted: res => {
            if (!available || root.unlockInProgress)
                return;

            if (res === PamResult.Success) {
                root.completeUnlock();
                return;
            }

            if (res === PamResult.Error || res === PamResult.MaxTries || res === PamResult.Failed) {
                abort();

                if (root.u2fPending) {
                    if (root.u2fState === "waiting") {
                        // AND mode: device was found but auth failed → back to password
                        root.u2fPending = false;
                        root.u2fState = "";
                        fprint.checkAvail();
                    } else {
                        // AND mode: no device found → keep pending, show "Insert...", retry
                        root.u2fState = "insert";
                        u2fErrorRetry.restart();
                    }
                } else {
                    // OR mode: prompt to insert key, silently retry
                    root.u2fState = "insert";
                    u2fErrorRetry.restart();
                }
            }
        }
    }

    Timer {
        id: errorRetry

        interval: 800
        onTriggered: fprint.start()
    }

    Timer {
        id: u2fErrorRetry

        interval: 800
        onTriggered: u2f.start()
    }

    Timer {
        id: u2fPendingTimeout

        interval: 30000
        onTriggered: root.cancelU2fPending()
    }

    Timer {
        id: passwdActiveTimeout

        interval: 15000
        onTriggered: {
            if (passwd.active)
                root.recoverFromAuthStall("error");
        }
    }

    Timer {
        id: unlockRequestTimeout

        interval: 8000
        onTriggered: {
            if (root.unlockInProgress)
                root.recoverFromAuthStall("error");
        }
    }

    Timer {
        id: stateReset

        interval: 4000
        onTriggered: {
            if (root.state !== "max")
                root.state = "";
        }
    }

    Timer {
        id: fprintStateReset

        interval: 4000
        onTriggered: {
            root.fprintState = "";
            fprint.errorTries = 0;
        }
    }

    onLockSecuredChanged: {
        if (lockSecured) {
            SettingsData.refreshAuthAvailability();
            root.state = "";
            root.fprintState = "";
            root.lockMessage = "";
            root.resetAuthFlows();
            fprint.checkAvail();
            u2f.checkAvail();
        } else {
            root.resetAuthFlows();
        }
    }

    Connections {
        target: SettingsData

        function onEnableFprintChanged(): void {
            fprint.checkAvail();
        }

        function onLockFingerprintReadyChanged(): void {
            fprint.checkAvail();
        }

        function onEnableU2fChanged(): void {
            u2f.checkAvail();
        }

        function onLockU2fReadyChanged(): void {
            u2f.checkAvail();
        }

        function onU2fModeChanged(): void {
            if (root.lockSecured) {
                u2f.abort();
                u2fErrorRetry.running = false;
                u2fPendingTimeout.running = false;
                unlockRequestTimeout.running = false;
                root.u2fPending = false;
                root.u2fState = "";
                u2f.checkAvail();
            }
        }
    }
}
