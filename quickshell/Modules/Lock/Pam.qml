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
    readonly property alias u2f: u2f
    property string lockMessage
    property string state
    property string fprintState
    property string u2fState
    property bool u2fPending: false
    property string buffer

    signal flashMsg
    signal unlockRequested

    function completeUnlock(): void {
        if (!unlockInProgress) {
            unlockInProgress = true;
            passwd.abort();
            fprint.abort();
            u2f.abort();
            errorRetry.running = false;
            u2fErrorRetry.running = false;
            u2fPendingTimeout.running = false;
            u2fPending = false;
            u2fState = "";
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
        if (!u2fPending)
            return;
        u2f.abort();
        u2fErrorRetry.running = false;
        u2fPendingTimeout.running = false;
        u2fPending = false;
        u2fState = "";
        fprint.checkAvail();
    }

    FileView {
        id: dankshellConfigWatcher

        path: "/etc/pam.d/dankshell"
        printErrors: false
    }

    FileView {
        id: u2fConfigWatcher

        path: "/etc/pam.d/dankshell-u2f"
        printErrors: false
    }

    PamContext {
        id: passwd

        config: dankshellConfigWatcher.loaded ? "dankshell" : "login"
        configDirectory: dankshellConfigWatcher.loaded ? "/etc/pam.d" : Quickshell.shellDir + "/assets/pam"

        onMessageChanged: {
            if (message.startsWith("The account is locked"))
                root.lockMessage = message;
            else if (root.lockMessage && message.endsWith(" left to unlock)"))
                root.lockMessage += "\n" + message;
        }

        onResponseRequiredChanged: {
            if (!responseRequired)
                return;

            respond(root.buffer);
        }

        onCompleted: res => {
            if (res === PamResult.Success) {
                if (!root.unlockInProgress) {
                    fprint.abort();
                    root.proceedAfterPrimaryAuth();
                }
                return;
            }

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

    PamContext {
        id: fprint

        property bool available
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
                    passwd.abort();
                    root.proceedAfterPrimaryAuth();
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

        property bool available

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

    Process {
        id: availProc

        command: ["sh", "-c", "fprintd-list $USER"]
        onExited: code => {
            fprint.available = code === 0;
            fprint.checkAvail();
        }
    }

    Process {
        id: u2fAvailProc

        command: ["sh", "-c", "(test -f /usr/lib/security/pam_u2f.so || test -f /usr/lib64/security/pam_u2f.so) && test -f \"$HOME/.config/Yubico/u2f_keys\""]
        onExited: code => {
            u2f.available = code === 0;
            u2f.checkAvail();
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
            availProc.running = true;
            u2fAvailProc.running = true;
            root.state = "";
            root.fprintState = "";
            root.u2fState = "";
            root.u2fPending = false;
            root.lockMessage = "";
            root.unlockInProgress = false;
        } else {
            fprint.abort();
            passwd.abort();
            u2f.abort();
            errorRetry.running = false;
            u2fErrorRetry.running = false;
            u2fPendingTimeout.running = false;
            root.u2fPending = false;
            root.u2fState = "";
            root.unlockInProgress = false;
        }
    }

    Connections {
        target: SettingsData

        function onEnableFprintChanged(): void {
            fprint.checkAvail();
        }

        function onEnableU2fChanged(): void {
            u2f.checkAvail();
        }

        function onU2fModeChanged(): void {
            if (root.lockSecured) {
                u2f.abort();
                u2fErrorRetry.running = false;
                u2fPendingTimeout.running = false;
                root.u2fPending = false;
                root.u2fState = "";
                u2f.checkAvail();
            }
        }
    }
}
