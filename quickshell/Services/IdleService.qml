pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common

Singleton {
    id: root

    readonly property bool idleMonitorAvailable: {
        try {
            return typeof IdleMonitor !== "undefined";
        } catch (e) {
            return false;
        }
    }

    readonly property bool idleInhibitorAvailable: {
        try {
            return typeof IdleInhibitor !== "undefined";
        } catch (e) {
            return false;
        }
    }

    property bool enabled: true
    property bool respectInhibitors: true
    property bool _enableGate: true

    readonly property bool externalInhibitActive: DMSService.screensaverInhibited

    readonly property bool isOnBattery: BatteryService.batteryAvailable && !BatteryService.isPluggedIn
    readonly property int monitorTimeout: isOnBattery ? SettingsData.batteryMonitorTimeout : SettingsData.acMonitorTimeout
    readonly property int lockTimeout: isOnBattery ? SettingsData.batteryLockTimeout : SettingsData.acLockTimeout
    readonly property int suspendTimeout: isOnBattery ? SettingsData.batterySuspendTimeout : SettingsData.acSuspendTimeout
    readonly property int suspendBehavior: isOnBattery ? SettingsData.batterySuspendBehavior : SettingsData.acSuspendBehavior
    readonly property int postLockMonitorTimeout: isOnBattery ? SettingsData.batteryPostLockMonitorTimeout : SettingsData.acPostLockMonitorTimeout
    readonly property bool postLockMonitorActive: isShellLocked && postLockMonitorTimeout > 0

    readonly property bool mediaPlaying: MprisController.activePlayer !== null && MprisController.activePlayer.isPlaying

    onMonitorTimeoutChanged: _rearmIdleMonitors()
    onLockTimeoutChanged: _rearmIdleMonitors()
    onSuspendTimeoutChanged: _rearmIdleMonitors()
    onPostLockMonitorTimeoutChanged: _rearmIdleMonitors()
    onIsShellLockedChanged: _rearmIdleMonitors()

    function _rearmIdleMonitors() {
        _enableGate = false;
        Qt.callLater(() => {
            _enableGate = true;
        });
    }

    signal lockRequested
    signal fadeToLockRequested
    signal cancelFadeToLock
    signal fadeToDpmsRequested
    signal cancelFadeToDpms
    signal requestMonitorOff
    signal requestMonitorOn
    signal requestSuspend

    property var monitorOffMonitor: null
    property var postLockMonitorOffMonitor: null
    property var lockMonitor: null
    property var suspendMonitor: null
    property var lockComponent: null
    property bool monitorsOff: false
    property bool isShellLocked: false

    function wake() {
        requestMonitorOn();
    }

    function reapplyDpmsIfNeeded() {
        if (monitorsOff)
            CompositorService.powerOffMonitors();
    }

    function createIdleMonitors() {
        if (!idleMonitorAvailable) {
            console.info("IdleService: IdleMonitor not available, skipping creation");
            return;
        }

        try {
            const qmlString = `
                import QtQuick
                import Quickshell.Wayland

                IdleMonitor {
                    enabled: false
                    respectInhibitors: true
                    timeout: 0
                }
            `;

            monitorOffMonitor = Qt.createQmlObject(qmlString, root, "IdleService.MonitorOffMonitor");
            monitorOffMonitor.timeout = Qt.binding(() => root.monitorTimeout > 0 ? root.monitorTimeout : 86400);
            monitorOffMonitor.respectInhibitors = Qt.binding(() => root.respectInhibitors);
            monitorOffMonitor.enabled = Qt.binding(() => root._enableGate && root.enabled && root.idleMonitorAvailable && root.monitorTimeout > 0 && !root.postLockMonitorActive);
            monitorOffMonitor.isIdleChanged.connect(function () {
                if (monitorOffMonitor.isIdle) {
                    if (SettingsData.fadeToDpmsEnabled) {
                        root.fadeToDpmsRequested();
                    } else {
                        root.requestMonitorOff();
                    }
                } else {
                    if (SettingsData.fadeToDpmsEnabled) {
                        root.cancelFadeToDpms();
                    }
                    root.requestMonitorOn();
                }
            });

            postLockMonitorOffMonitor = Qt.createQmlObject(qmlString, root, "IdleService.PostLockMonitorOffMonitor");
            postLockMonitorOffMonitor.timeout = Qt.binding(() => root.postLockMonitorTimeout > 0 ? root.postLockMonitorTimeout : 86400);
            postLockMonitorOffMonitor.respectInhibitors = Qt.binding(() => root.respectInhibitors);
            postLockMonitorOffMonitor.enabled = Qt.binding(() => root._enableGate && root.enabled && root.idleMonitorAvailable && root.postLockMonitorActive);
            postLockMonitorOffMonitor.isIdleChanged.connect(function () {
                if (postLockMonitorOffMonitor.isIdle) {
                    root.requestMonitorOff();
                } else {
                    root.requestMonitorOn();
                }
            });

            lockMonitor = Qt.createQmlObject(qmlString, root, "IdleService.LockMonitor");
            lockMonitor.timeout = Qt.binding(() => root.lockTimeout > 0 ? root.lockTimeout : 86400);
            lockMonitor.respectInhibitors = Qt.binding(() => root.respectInhibitors);
            lockMonitor.enabled = Qt.binding(() => root._enableGate && root.enabled && root.idleMonitorAvailable && root.lockTimeout > 0);
            lockMonitor.isIdleChanged.connect(function () {
                if (lockMonitor.isIdle) {
                    if (SettingsData.fadeToLockEnabled) {
                        root.fadeToLockRequested();
                    } else {
                        root.lockRequested();
                    }
                } else {
                    if (SettingsData.fadeToLockEnabled) {
                        root.cancelFadeToLock();
                    }
                }
            });

            suspendMonitor = Qt.createQmlObject(qmlString, root, "IdleService.SuspendMonitor");
            suspendMonitor.timeout = Qt.binding(() => root.suspendTimeout > 0 ? root.suspendTimeout : 86400);
            suspendMonitor.respectInhibitors = Qt.binding(() => root.respectInhibitors);
            suspendMonitor.enabled = Qt.binding(() => root._enableGate && root.enabled && root.idleMonitorAvailable && root.suspendTimeout > 0);
            suspendMonitor.isIdleChanged.connect(function () {
                if (suspendMonitor.isIdle) {
                    root.requestSuspend();
                }
            });
        } catch (e) {
            console.warn("IdleService: Error creating IdleMonitors:", e);
        }
    }

    Connections {
        target: root
        function onRequestMonitorOff() {
            monitorsOff = true;
            CompositorService.powerOffMonitors();
        }

        function onRequestMonitorOn() {
            monitorsOff = false;
            CompositorService.powerOnMonitors();
        }

        function onRequestSuspend() {
            SessionService.suspendWithBehavior(root.suspendBehavior);
        }
    }

    onExternalInhibitActiveChanged: {
        if (externalInhibitActive) {
            const apps = DMSService.screensaverInhibitors.map(i => i.appName).join(", ");
            console.info("IdleService: External idle inhibit active from:", apps || "unknown");
            SessionService.idleInhibited = true;
            SessionService.inhibitReason = "External app: " + (apps || "unknown");
        } else {
            console.info("IdleService: External idle inhibit released");
            SessionService.idleInhibited = false;
            SessionService.inhibitReason = "Keep system awake";
        }
    }

    Component.onCompleted: {
        if (!idleMonitorAvailable) {
            console.warn("IdleService: IdleMonitor not available - power management disabled. This requires a newer version of Quickshell.");
        } else {
            console.info("IdleService: Initialized with idle monitoring support");
            createIdleMonitors();
        }

        if (externalInhibitActive) {
            const apps = DMSService.screensaverInhibitors.map(i => i.appName).join(", ");
            SessionService.idleInhibited = true;
            SessionService.inhibitReason = "External app: " + (apps || "unknown");
        }
    }
}
