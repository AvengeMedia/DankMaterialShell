pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root

    property bool available: false
    property bool binaryExists: false
    property bool syncing: false
    property string syncStatus: ""
    property bool fallbackFromPrecheck: false

    signal syncFinished

    function refresh() {
        detectProcess.running = true;
    }

    function sync() {
        if (!binaryExists || syncing)
            return;
        fallbackFromPrecheck = false;
        syncStatus = I18n.tr("Checking whether sudo authentication is needed...");
        syncing = true;
        sudoProbeProcess.running = true;
    }

    function launchTerminalFallback(fromPrecheck, statusText) {
        fallbackFromPrecheck = fromPrecheck;
        if (statusText)
            syncStatus = statusText;
        terminalFallbackProcess.running = true;
    }

    function withOutput(message, out, err) {
        let text = message;
        if (out !== "")
            text += "\n\n" + out;
        if (err !== "")
            text += "\n\nstderr:\n" + err;
        return text;
    }

    function finishSync() {
        syncing = false;
        syncFinished();
    }

    Process {
        id: detectProcess

        command: ["sh", "-c", "command -v dms-greeter >/dev/null 2>&1 && echo binary; grep -qs dms-greeter /etc/greetd/config.toml && echo config"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.split("\n");
                root.binaryExists = found.includes("binary");
                root.available = root.binaryExists || found.includes("config");
            }
        }
    }

    Process {
        id: sudoProbeProcess

        command: ["sudo", "-n", "true"]

        stderr: StdioCollector {
            id: sudoProbeErr
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                root.syncStatus = I18n.tr("Running greeter sync...");
                syncProcess.running = true;
                return;
            }
            let authNeeded = I18n.tr("Sync needs sudo authentication. Opening terminal so you can use password or fingerprint.");
            const err = sudoProbeErr.text.trim();
            if (err !== "")
                authNeeded += "\n\n" + err;
            root.launchTerminalFallback(true, authNeeded);
        }
    }

    Process {
        id: syncProcess

        command: ["dms-greeter", "sync", "--yes"]

        stdout: StdioCollector {
            id: syncOut
        }

        stderr: StdioCollector {
            id: syncErr
        }

        onExited: exitCode => {
            const out = syncOut.text.trim();
            const err = syncErr.text.trim();
            if (exitCode !== 0) {
                root.syncStatus = root.withOutput(I18n.tr("Sync failed in background mode. Trying terminal mode so you can authenticate interactively.") + " (exit " + exitCode + ")", out, err);
                root.launchTerminalFallback(false, "");
                return;
            }
            root.syncStatus = root.withOutput(I18n.tr("Sync completed successfully."), out, err);
            SettingsData.clearGreeterSyncPending();
            ToastService.showInfo(I18n.tr("Greeter sync complete"));
            root.finishSync();
        }
    }

    Process {
        id: terminalFallbackProcess

        command: ["dms-greeter", "sync", "--terminal", "--yes"]

        stderr: StdioCollector {
            id: terminalFallbackErr
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                const launched = root.fallbackFromPrecheck ? I18n.tr("Terminal opened. Complete authentication there; it will close automatically when done.") : I18n.tr("Terminal fallback opened. Complete authentication there; it will close automatically when done.");
                root.syncStatus = root.syncStatus ? root.syncStatus + "\n\n" + launched : launched;
                SettingsData.clearGreeterSyncPending();
                root.finishSync();
                return;
            }
            let fallback = I18n.tr("Terminal fallback failed. Install one of the supported terminal emulators or run 'dms-greeter sync' manually.") + " (exit " + exitCode + ")";
            const err = terminalFallbackErr.text.trim();
            if (err !== "")
                fallback += "\n\nstderr:\n" + err;
            root.syncStatus = root.syncStatus ? root.syncStatus + "\n\n" + fallback : fallback;
            root.finishSync();
        }
    }
}
