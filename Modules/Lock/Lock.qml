pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Services

Scope {
    id: root

    property string sharedPasswordBuffer: ""
    property bool shouldLock: false
    property bool processingExternalEvent: false

    Component.onCompleted: {
        IdleService.lockComponent = this
    }

    function lock() {
        if (!processingExternalEvent && SessionData.loginctlLockIntegration && DMSService.isConnected) {
            DMSService.lockSession(response => {
                if (response.error) {
                    console.warn("Lock: Failed to call loginctl.lock:", response.error)
                    shouldLock = true
                }
            })
        } else {
            shouldLock = true
        }
    }

    function unlock() {
        if (!processingExternalEvent && SessionData.loginctlLockIntegration && DMSService.isConnected) {
            DMSService.unlockSession(response => {
                if (response.error) {
                    console.warn("Lock: Failed to call loginctl.unlock:", response.error)
                    shouldLock = false
                }
            })
        } else {
            shouldLock = false
        }
    }

    function activate() {
        lock()
    }

    Connections {
        target: SessionService

        function onSessionLocked() {
            processingExternalEvent = true
            shouldLock = true
            processingExternalEvent = false
        }

        function onSessionUnlocked() {
            processingExternalEvent = true
            shouldLock = false
            processingExternalEvent = false
        }
    }

    Connections {
        target: IdleService

        function onLockRequested() {
            lock()
        }
    }

    WlSessionLock {
        id: sessionLock

        locked: shouldLock

        WlSessionLockSurface {
            color: "transparent"

            LockSurface {
                anchors.fill: parent
                lock: sessionLock
                sharedPasswordBuffer: root.sharedPasswordBuffer
                onUnlockRequested: {
                    root.unlock()
                }
                onPasswordChanged: newPassword => {
                                       root.sharedPasswordBuffer = newPassword
                                   }
            }
        }
    }

    LockScreenDemo {
        id: demoWindow
    }

    IpcHandler {
        target: "lock"

        function lock() {
            root.lock()
        }

        function demo() {
            demoWindow.showDemo()
        }

        function isLocked(): bool {
            return sessionLock.locked
        }
    }
}
