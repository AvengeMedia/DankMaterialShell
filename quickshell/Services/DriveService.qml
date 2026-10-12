pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

// Physical drives from the core's drives.list, polled only while something holds a Ref.
Singleton {
    id: root
    readonly property var log: Log.scoped("DriveService")

    property int refCount: 0

    // Drive objects as documented for drives.list
    property var drives: []
    // Absolute path of smartctl, empty when smartmontools is missing
    property string smartctlPath: ""
    // Shell command that installs smartmontools, empty when unknown
    property string installCommand: ""
    property bool loaded: false
    // True while a full SMART report is running
    readonly property bool reporting: reportProcess.running
    readonly property string reportDevice: reporting ? reportProcess.device : ""

    readonly property bool polling: refCount > 0 && DMSService.isConnected && DMSService.capabilities.includes("drives")

    property bool _errorLogged: false

    function refresh() {
        DMSService.sendRequest("drives.list", null, response => {
            // The last reply may arrive after the final Ref went away
            if (!root.polling)
                return;
            if (response.error || !response.result) {
                if (!root._errorLogged)
                    root.log.warn("drives.list failed:", response.error || "empty result");
                root._errorLogged = true;
                return;
            }
            root._errorLogged = false;
            root.drives = response.result.drives || [];
            root.smartctlPath = response.result.smartctl || "";
            root.installCommand = response.result.installCommand || "";
            root.loaded = true;
        });
    }

    // Runs `pkexec smartctl -x --json` and calls done(exitCode, stdout, stderr).
    // Exit 126 means the user dismissed the password prompt. smartctl also uses
    // nonzero bits for warnings, so stdout is worth parsing whatever the code.
    // A request for the drive already being read takes over its callback
    // instead of starting a second pkexec; another drive's request is refused
    // (the UI disables that button).
    function fullReport(drive, done) {
        if (!smartctlPath)
            return false;
        if (reportProcess.running) {
            if (reportProcess.device !== drive.device)
                return false;
            reportProcess.done = done;
            return true;
        }
        reportProcess.device = drive.device;
        reportProcess.done = done;
        reportProcess.command = ["pkexec", smartctlPath, "-x", "--json", drive.device];
        reportProcess.running = true;
        return true;
    }

    // Runs the install command in the configured terminal and waits for Enter
    function install() {
        if (!installCommand)
            return;
        Quickshell.execDetached([SessionData.resolveTerminal() || "xterm", "-e", "sh", "-c", installCommand + "; read -r _"]);
    }

    onPollingChanged: {
        if (polling)
            return;
        drives = [];
        smartctlPath = "";
        installCommand = "";
        loaded = false;
        _errorLogged = false;
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.polling
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: reportProcess
        property var done: null
        property string device: ""
        running: false

        stdout: StdioCollector {
            id: reportOut
        }

        stderr: StdioCollector {
            id: reportErr
        }

        onExited: exitCode => {
            if (exitCode === 126)
                root.log.info("SMART report cancelled at the auth prompt");
            const cb = done;
            done = null;
            if (cb)
                cb(exitCode, reportOut.text, reportErr.text.trim());
        }
    }
}
