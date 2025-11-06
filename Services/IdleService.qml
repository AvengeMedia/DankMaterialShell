pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

Singleton {
    id: root

    readonly property bool idleMonitorAvailable: {
        try {
            return typeof IdleMonitor !== "undefined"
        } catch (e) {
            return false
        }
    }

    property bool enabled: true
    property bool respectInhibitors: true
    property bool _enableGate: true

    readonly property bool isOnBattery: BatteryService.batteryAvailable && !BatteryService.isPluggedIn
    readonly property int monitorTimeout: isOnBattery ? SettingsData.batteryMonitorTimeout : SettingsData.acMonitorTimeout
    readonly property int lockTimeout: isOnBattery ? SettingsData.batteryLockTimeout : SettingsData.acLockTimeout
    readonly property int suspendTimeout: isOnBattery ? SettingsData.batterySuspendTimeout : SettingsData.acSuspendTimeout
    readonly property int suspendBehavior: isOnBattery ? SettingsData.batterySuspendBehavior : SettingsData.acSuspendBehavior

    onMonitorTimeoutChanged: _rearmIdleMonitors()
    onLockTimeoutChanged: _rearmIdleMonitors()
    onSuspendTimeoutChanged: _rearmIdleMonitors()

    function _rearmIdleMonitors() {
        _enableGate = false
        Qt.callLater(() => { _enableGate = true })
    }

    signal lockRequested()
    signal requestMonitorOff()
    signal requestMonitorOn()
    signal requestSuspend()

    property var monitorOffMonitor: null
    property var lockMonitor: null
    property var suspendMonitor: null

    function wake() {
        requestMonitorOn()
    }

    function createIdleMonitors() {
        if (!idleMonitorAvailable) {
            console.info("IdleService: IdleMonitor not available, skipping creation")
            return
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
            `

            monitorOffMonitor = Qt.createQmlObject(qmlString, root, "IdleService.MonitorOffMonitor")
            monitorOffMonitor.enabled = Qt.binding(() => root._enableGate && root.enabled && root.idleMonitorAvailable && root.monitorTimeout > 0)
            monitorOffMonitor.respectInhibitors = Qt.binding(() => root.respectInhibitors)
            monitorOffMonitor.timeout = Qt.binding(() => root.monitorTimeout)
            monitorOffMonitor.isIdleChanged.connect(function() {
                if (monitorOffMonitor.isIdle) {
                    root.requestMonitorOff()
                } else {
                    root.requestMonitorOn()
                }
            })

            lockMonitor = Qt.createQmlObject(qmlString, root, "IdleService.LockMonitor")
            lockMonitor.enabled = Qt.binding(() => root._enableGate && root.enabled && root.idleMonitorAvailable && root.lockTimeout > 0)
            lockMonitor.respectInhibitors = Qt.binding(() => root.respectInhibitors)
            lockMonitor.timeout = Qt.binding(() => root.lockTimeout)
            lockMonitor.isIdleChanged.connect(function() {
                if (lockMonitor.isIdle) {
                    root.lockRequested()
                }
            })

            suspendMonitor = Qt.createQmlObject(qmlString, root, "IdleService.SuspendMonitor")
            suspendMonitor.enabled = Qt.binding(() => root._enableGate && root.enabled && root.idleMonitorAvailable && root.suspendTimeout > 0)
            suspendMonitor.respectInhibitors = Qt.binding(() => root.respectInhibitors)
            suspendMonitor.timeout = Qt.binding(() => root.suspendTimeout)
            suspendMonitor.isIdleChanged.connect(function() {
                if (suspendMonitor.isIdle) {
                    root.requestSuspend()
                }
            })
        } catch (e) {
            console.warn("IdleService: Error creating IdleMonitors:", e)
        }
    }

    Connections {
        target: root
        function onRequestMonitorOff() {
            CompositorService.powerOffMonitors()
        }

        function onRequestMonitorOn() {
            CompositorService.powerOnMonitors()
        }

        function onRequestSuspend() {
            SessionService.suspendWithBehavior(root.suspendBehavior)
        }
    }

    Connections {
        target: SessionService
        function onPrepareForSleep() {
            if (SettingsData.lockBeforeSuspend) {
                root.lockRequested()
            }
        }
    }

    Component.onCompleted: {
        if (!idleMonitorAvailable) {
            console.warn("IdleService: IdleMonitor not available - power management disabled. This requires a newer version of Quickshell.")
        } else {
            console.info("IdleService: Initialized with idle monitoring support")
            createIdleMonitors()
        }
    }
}