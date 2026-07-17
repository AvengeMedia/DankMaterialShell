pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services

Singleton {
    id: root

    property int refCount: 0

    property bool sysupdateAvailable: false

    property var availableUpdates: []
    property var _rawUpdates: []
    property bool isChecking: false
    property bool isUpgrading: false
    property bool hasError: false
    property string errorMessage: ""
    property string errorHint: ""
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
    readonly property bool useCustomCommand: SettingsData.updaterUseCustomCommand && (SettingsData.updaterCustomCommand || "").trim().length > 0

    // Dont allow partial updates on arch, if they wanna break their system they can do it outside of DMS:
    // https://wiki.archlinux.org/title/System_maintenance#Partial_upgrades_are_unsupported
    // AUR/Flatpak packages stay ignorable — holding those cannot break the repo dependency graph.
    readonly property bool systemHoldsAllowed: !["pacman", "paru", "yay"].includes(pkgManager)

    function canIgnorePackage(pkg) {
        if (!pkg)
            return false;
        return systemHoldsAllowed || pkg.repo !== "system";
    }

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
                root._startupCheckDone = false;
            }
            Qt.callLater(() => root._maybeStartupCheck());
        }
        function onSysupdateStateUpdate(data) {
            root._applyState(data);
        }
    }

    Connections {
        target: SettingsData
        function onUpdaterCheckOnStartChanged() {
            Qt.callLater(() => root._maybeStartupCheck());
        }
        function onUpdaterAllowAURChanged() {
            root._refilter();
        }
        function onUpdaterIgnoredPackagesChanged() {
            root._refilter();
        }
        function on_HasLoadedChanged() {
            Qt.callLater(() => root._maybeStartupCheck());
        }
    }

    Component.onCompleted: {
        if (DMSService.dmsAvailable) {
            checkCapabilities();
        }
        Qt.callLater(() => root._maybeStartupCheck());
    }

    function checkCapabilities() {
        if (!DMSService.capabilities || !Array.isArray(DMSService.capabilities)) {
            sysupdateAvailable = false;
            Qt.callLater(() => root._maybeStartupCheck());
            return;
        }
        const has = DMSService.capabilities.includes("sysupdate");
        if (has && !sysupdateAvailable) {
            sysupdateAvailable = true;
            requestState();
        } else if (!has) {
            sysupdateAvailable = false;
        }
        Qt.callLater(() => root._maybeStartupCheck());
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
        backends = data.backends || [];
        const systemBackend = backends.find(b => b.repo === "system" || b.repo === "ostree");
        pkgManager = systemBackend ? systemBackend.id : (backends.length > 0 ? backends[0].id : "");
        _rawUpdates = data.packages || [];
        availableUpdates = _filterUpdates(_rawUpdates);
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
            errorHint = data.error.hint || "";
        } else {
            hasError = false;
            errorMessage = "";
            errorCode = "";
            errorHint = "";
        }
    }

    function _filterUpdates(pkgs) {
        const ignored = SettingsData.updaterIgnoredPackages || [];
        return (pkgs || []).filter(p => {
            if (!SettingsData.updaterAllowAUR && p.repo === "aur")
                return false;
            if (!canIgnorePackage(p))
                return true;
            return ignored.indexOf(p.name) === -1;
        });
    }

    function _refilter() {
        availableUpdates = _filterUpdates(_rawUpdates);
    }

    function ignorePackage(name) {
        if (!name)
            return;
        const list = (SettingsData.updaterIgnoredPackages || []).slice();
        if (list.indexOf(name) !== -1)
            return;
        list.push(name);
        SettingsData.set("updaterIgnoredPackages", list);
    }

    function unignorePackage(name) {
        if (!name)
            return;
        const list = (SettingsData.updaterIgnoredPackages || []).filter(p => p !== name);
        SettingsData.set("updaterIgnoredPackages", list);
    }

    function checkForUpdates() {
        DMSService.sysupdateRefresh(false, null);
    }

    function runUpdates(opts) {
        const params = opts || {};
        params.ignored = SettingsData.updaterIgnoredPackages || [];
        if (useCustomCommand) {
            params.customCommand = SettingsData.updaterCustomCommand.trim();
            const termArgs = (SettingsData.updaterTerminalAdditionalParams || "").trim();
            if (termArgs.length > 0) {
                params.terminalArgs = termArgs.split(/\s+/);
            }
        }
        DMSService.sysupdateUpgrade(params, null);
    }

    function cancelUpdates() {
        DMSService.sysupdateCancel(null);
    }

    function setInterval(seconds) {
        DMSService.sysupdateSetInterval(seconds, null);
    }

    property bool _startupCheckDone: false

    function _maybeStartupCheck() {
        if (refCount <= 0) {
            _startupCheckDone = false;
            return;
        }
        if (!SettingsData.updaterCheckOnStart)
            return;
        if (_startupCheckDone)
            return;
        if (!DMSService.isConnected || !sysupdateAvailable)
            return;
        _startupCheckDone = true;
        Qt.callLater(() => root.checkForUpdates());
    }

    onRefCountChanged: {
        if (refCount <= 0)
            _startupCheckDone = false;
        _syncAcquire();
        Qt.callLater(() => root._maybeStartupCheck());
    }
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
}
