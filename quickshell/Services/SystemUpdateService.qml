pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root

    property int refCount: 0

    property bool sysupdateAvailable: false

    property var availableUpdates: []
    property bool isChecking: false
    property bool isUpgrading: false
    property bool hasError: false
    property string errorMessage: ""
    property string errorCode: ""
    property var backends: []
    property string distribution: ""
    property string distributionPretty: ""
    property string pkgManager: ""
    property bool distributionSupported: false
    property var recentLog: []
    property int intervalSeconds: 1800
    property int lastCheckUnix: 0
    property int nextCheckUnix: 0

    readonly property int updateCount: availableUpdates.length
    readonly property bool helperAvailable: sysupdateAvailable && backends.length > 0

    Connections {
        target: DMSService
        function onCapabilitiesReceived() {
            root.checkCapabilities();
        }
        function onConnectionStateChanged() {
            if (DMSService.isConnected) {
                root.checkCapabilities();
            } else {
                root.sysupdateAvailable = false;
            }
        }
        function onSysupdateStateUpdate(data) {
            root._applyState(data);
        }
    }

    Component.onCompleted: {
        if (DMSService.dmsAvailable) {
            checkCapabilities();
        }
    }

    function checkCapabilities() {
        if (!DMSService.capabilities || !Array.isArray(DMSService.capabilities)) {
            sysupdateAvailable = false;
            return;
        }
        const has = DMSService.capabilities.includes("sysupdate");
        if (has && !sysupdateAvailable) {
            sysupdateAvailable = true;
            requestState();
        } else if (!has) {
            sysupdateAvailable = false;
        }
    }

    function requestState() {
        if (!DMSService.isConnected || !sysupdateAvailable) {
            return;
        }
        DMSService.sysupdateGetState(resp => {
            if (resp && resp.result) {
                _applyState(resp.result);
            }
        });
    }

    function _applyState(data) {
        if (!data) {
            return;
        }
        availableUpdates = data.packages || [];
        backends = data.backends || [];
        distribution = data.distro || "";
        distributionPretty = data.distroPretty || "";
        distributionSupported = (backends.length > 0);
        recentLog = data.recentLog || [];
        intervalSeconds = data.intervalSeconds || 1800;
        lastCheckUnix = data.lastCheckUnix || 0;
        nextCheckUnix = data.nextCheckUnix || 0;

        const phase = data.phase || "idle";
        switch (phase) {
        case "refreshing":
            isChecking = true;
            isUpgrading = false;
            break;
        case "upgrading":
            isChecking = false;
            isUpgrading = true;
            break;
        default:
            isChecking = false;
            isUpgrading = false;
        }

        if (data.error) {
            hasError = true;
            errorMessage = data.error.message || "";
            errorCode = data.error.code || "";
        } else {
            hasError = false;
            errorMessage = "";
            errorCode = "";
        }

        if (backends.length > 0) {
            const sys = backends.find(b => b.repo === "system" || b.repo === "ostree");
            pkgManager = sys ? sys.id : backends[0].id;
        } else {
            pkgManager = "";
        }
    }

    function checkForUpdates() {
        DMSService.sysupdateRefresh(false, null);
    }

    function runUpdates(opts) {
        const params = opts || {};
        if (SettingsData.updaterUseCustomCommand && SettingsData.updaterCustomCommand.length > 0) {
            _runCustomTerminalCommand();
            return;
        }
        DMSService.sysupdateUpgrade(params, null);
    }

    function cancelUpdates() {
        DMSService.sysupdateCancel(null);
    }

    function setInterval(seconds) {
        DMSService.sysupdateSetInterval(seconds, null);
    }

    function _runCustomTerminalCommand() {
        const terminal = SessionData.resolveTerminal();
        if (!terminal || terminal.length === 0) {
            ToastService.showError(I18n.tr("No terminal configured"), I18n.tr("Pick a terminal in Settings → Launcher (or set $TERMINAL)."));
            return;
        }
        const updateCommand = `${SettingsData.updaterCustomCommand} && echo -n "Updates complete! " ; echo "Press Enter to close..." && read`;
        const termClass = SettingsData.updaterTerminalAdditionalParams || "";
        var argv = [terminal];
        if (termClass.length > 0) {
            argv = argv.concat(termClass.split(" "));
        }
        argv.push("-e");
        argv.push("sh");
        argv.push("-c");
        argv.push(updateCommand);
        customRunner.command = argv;
        customRunner.running = true;
    }

    Process {
        id: customRunner
        onExited: root.checkForUpdates()
    }

    onRefCountChanged: _syncAcquire()
    onSysupdateAvailableChanged: _syncAcquire()

    property bool _acquired: false

    function _syncAcquire() {
        const want = refCount > 0 && sysupdateAvailable;
        if (want === _acquired) {
            return;
        }
        _acquired = want;
        if (want) {
            DMSService.sysupdateAcquire(null);
            return;
        }
        DMSService.sysupdateRelease(null);
    }

    IpcHandler {
        target: "systemupdater"

        function updatestatus(): string {
            if (root.isChecking) {
                return "ERROR: already checking";
            }
            if (root.backends.length === 0) {
                return "ERROR: no package manager available";
            }
            root.checkForUpdates();
            return "SUCCESS: Now checking...";
        }
    }
}
