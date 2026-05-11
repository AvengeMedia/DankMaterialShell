pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

Singleton {
    id: root
    readonly property var log: Log.scoped("IdleService")

    property bool enabled: true
    property bool respectInhibitors: true

    readonly property bool externalInhibitActive: DMSService.screensaverInhibited

    readonly property bool isOnBattery: BatteryService.batteryAvailable && !BatteryService.isPluggedIn
    readonly property int monitorTimeout: isOnBattery ? SettingsData.batteryMonitorTimeout : SettingsData.acMonitorTimeout
    readonly property int lockTimeout: isOnBattery ? SettingsData.batteryLockTimeout : SettingsData.acLockTimeout
    readonly property int suspendTimeout: isOnBattery ? SettingsData.batterySuspendTimeout : SettingsData.acSuspendTimeout
    readonly property int suspendBehavior: isOnBattery ? SettingsData.batterySuspendBehavior : SettingsData.acSuspendBehavior
    readonly property int postLockMonitorTimeout: isOnBattery ? SettingsData.batteryPostLockMonitorTimeout : SettingsData.acPostLockMonitorTimeout
    readonly property bool postLockMonitorActive: isShellLocked && postLockMonitorTimeout > 0

    readonly property bool mediaPlaying: MprisController.activePlayer !== null && MprisController.activePlayer.isPlaying

    onEnabledChanged: _applyMonitorEnableds()
    onPostLockMonitorActiveChanged: _applyMonitorEnableds()
    onMonitorTimeoutChanged: _rearmIdleMonitors()
    onLockTimeoutChanged: _rearmIdleMonitors()
    onSuspendTimeoutChanged: _rearmIdleMonitors()
    onPostLockMonitorTimeoutChanged: _rearmIdleMonitors()
    onIsShellLockedChanged: _rearmIdleMonitors()

    function _applyMonitorEnableds() {
        const base = enabled;
        monitorOffMonitor.enabled = base && monitorTimeout > 0 && !postLockMonitorActive;
        postLockMonitorOffMonitor.enabled = base && postLockMonitorActive;
        lockMonitor.enabled = base && lockTimeout > 0;
        suspendMonitor.enabled = base && suspendTimeout > 0;
    }

    function _rearmIdleMonitors() {
        monitorOffMonitor.enabled = false;
        postLockMonitorOffMonitor.enabled = false;
        lockMonitor.enabled = false;
        suspendMonitor.enabled = false;
        Qt.callLater(_applyMonitorEnableds);
    }

    signal lockRequested
    signal fadeToLockRequested
    signal cancelFadeToLock
    signal fadeToDpmsRequested
    signal cancelFadeToDpms
    signal requestMonitorOff
    signal requestMonitorOn
    signal requestSuspend

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

    IdleMonitor {
        id: monitorOffMonitor
        timeout: root.monitorTimeout > 0 ? root.monitorTimeout : 86400
        respectInhibitors: root.respectInhibitors
        enabled: false
        onIsIdleChanged: {
            if (isIdle) {
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
        }
    }

    IdleMonitor {
        id: postLockMonitorOffMonitor
        timeout: root.postLockMonitorTimeout > 0 ? root.postLockMonitorTimeout : 86400
        respectInhibitors: root.respectInhibitors
        enabled: false
        onIsIdleChanged: {
            if (isIdle) {
                root.requestMonitorOff();
            } else {
                root.requestMonitorOn();
            }
        }
    }

    IdleMonitor {
        id: lockMonitor
        timeout: root.lockTimeout > 0 ? root.lockTimeout : 86400
        respectInhibitors: root.respectInhibitors
        enabled: false
        onIsIdleChanged: {
            if (isIdle) {
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
        }
    }

    IdleMonitor {
        id: suspendMonitor
        timeout: root.suspendTimeout > 0 ? root.suspendTimeout : 86400
        respectInhibitors: root.respectInhibitors
        enabled: false
        onIsIdleChanged: {
            if (isIdle)
                root.requestSuspend();
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
            log.info("External idle inhibit active from:", apps || "unknown");
            SessionService.idleInhibited = true;
            SessionService.inhibitReason = "External app: " + (apps || "unknown");
        } else {
            log.info("External idle inhibit released");
            SessionService.idleInhibited = false;
            SessionService.inhibitReason = "Keep system awake";
        }
    }

    Component.onCompleted: {
        _applyMonitorEnableds();
        if (externalInhibitActive) {
            const apps = DMSService.screensaverInhibitors.map(i => i.appName).join(", ");
            SessionService.idleInhibited = true;
            SessionService.inhibitReason = "External app: " + (apps || "unknown");
        }
    }
}
