import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Services

Item {
    id: root

    function activate() {
        loader.activeAsync = true
    }

    Component.onCompleted: {
        if (SessionService.loginctlAvailable || SessionService.sessionPath) {
            if (SessionService.locked || SessionService.lockedHint) {
                console.log("Lock: Session locked on startup")
                loader.activeAsync = true
            }
        }
    }

    Connections {
        target: IdleService
        function onLockRequested() {
            console.log("Lock: Received lock request from IdleService")
            loader.activeAsync = true
        }
    }

    Connections {
        target: SessionService

        function onSessionLocked() {
            console.log("Lock: Lock signal received -> show lock")
            loader.activeAsync = true
        }

        function onSessionUnlocked() {
            console.log("Lock: Unlock signal received -> hide lock")
            loader.active = false
        }

        function onLoginctlStateChanged() {
            if (SessionService.lockedHint && !loader.active) {
                console.log("Lock: LockedHint=true -> show lock")
                loader.activeAsync = true
            } else if (!SessionService.locked && !SessionService.lockedHint && loader.active) {
                console.log("Lock: LockedHint=false -> hide lock")
                loader.active = false
            }
        }

        function onPrepareForSleep() {
            if (SessionService.preparingForSleep && SessionData.lockBeforeSuspend) {
                console.log("Lock: PrepareForSleep -> lock before suspend")
                loader.activeAsync = true
            }
        }
    }

    LazyLoader {
        id: loader

        WlSessionLock {
            id: sessionLock

            property bool unlocked: false
            property string sharedPasswordBuffer: ""

            locked: true

            onLockedChanged: {
                if (!locked) {
                    loader.active = false
                }
            }

            LockSurface {
                id: lockSurface
                lock: sessionLock
                sharedPasswordBuffer: sessionLock.sharedPasswordBuffer
                onPasswordChanged: newPassword => {
                                       sessionLock.sharedPasswordBuffer = newPassword
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
            console.log("Lock screen requested via IPC")
            loader.activeAsync = true
        }

        function demo() {
            console.log("Lock screen DEMO mode requested via IPC")
            demoWindow.showDemo()
        }

        function isLocked(): bool {
            return SessionService.locked || loader.active
        }
    }
}
