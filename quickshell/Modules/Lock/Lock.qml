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

    onSharedPasswordBufferChanged: {
        if (!powerOffFadeTimer.running)
            return;
        cancelPowerOffFade();
    }

    onShouldLockChanged: {
        IdleService.isShellLocked = shouldLock;
        if (shouldLock && lockPowerOffArmed) {
            lockStateCheck.restart();
        }
    }

    Timer {
        id: lockStateCheck
        interval: 100
        repeat: false
        onTriggered: {
            if (sessionLock.locked && lockPowerOffArmed) {
                pendingLock = false;
                lockPowerOffArmed = false;
                beginPowerOff();
            }
        }
    }

    property bool lockInitiatedLocally: false
    property bool pendingLock: false
    property bool lockPowerOffArmed: false
    property bool lockWakeAllowed: false
    property bool customLockerSpawned: false
    readonly property bool powerOffOnLock: SettingsData.lockScreenPowerOffMonitorsOnLock || IdleService.lockPowerOffRequested
    property real powerOffFadeTarget: 0
    property bool powerOffFadeInstant: false

    function beginPowerOff() {
        if (!SettingsData.fadeToDpmsEnabled || SettingsData.fadeToDpmsGracePeriod <= 0) {
            applyMonitorsOff();
            return;
        }
        powerOffFadeInstant = false;
        powerOffFadeTarget = 1;
        powerOffFadeTimer.restart();
    }

    function applyMonitorsOff() {
        IdleService.monitorsOff = true;
        CompositorService.powerOffMonitors();
        lockWakeAllowed = false;
        lockWakeDebounce.restart();
        dpmsReapplyTimer.start();
    }

    function resetPowerOffFade() {
        powerOffFadeTimer.stop();
        powerOffFadeInstant = true;
        powerOffFadeTarget = 0;
    }

    function cancelPowerOffFade() {
        resetPowerOffFade();
        IdleService.lockPowerOffRequested = false;
    }

    Component.onCompleted: {
        IdleService.lockComponent = this;
        if (SettingsData.lockAtStartup)
            lock();
    }

    function notifyLockedHint(locked: bool) {
        if (!SettingsData.loginctlLockIntegration || !DMSService.isConnected)
            return;
        DMSService.setLockedHint(locked, () => {});
    }

    function notifyLoginctl(lockAction: bool) {
        if (!SettingsData.loginctlLockIntegration || !DMSService.isConnected)
            return;
        if (lockAction)
            DMSService.lockSession(() => {});
        else
            DMSService.unlockSession(() => {});
    }

    function spawnCustomLocker() {
        IdleService.lockPowerOffRequested = false;
        Quickshell.execDetached(["sh", "-c", SettingsData.customPowerActionLock]);
        // The custom locker manages its own surface; DMS never engages
        // WlSessionLock here, so isShellLocked stays false and the fade
        // overlay would never be dismissed. Hand off by dismissing it now.
        IdleService.dismissFadeToLock();
        customLockerSpawned = true;
    }

    function handleLoginctlCustomLock(): bool {
        if (!(SettingsData.customPowerActionLock?.length > 0))
            return false;
        if (!customLockerSpawned)
            spawnCustomLocker();
        return true;
    }

    function lock() {
        if (SettingsData.customPowerActionLock?.length > 0) {
            spawnCustomLocker();
            return;
        }
        if (shouldLock || pendingLock)
            return;

        lockInitiatedLocally = true;
        lockPowerOffArmed = powerOffOnLock;

        if (!SessionService.active && SessionService.loginctlAvailable && SettingsData.loginctlLockIntegration) {
            pendingLock = true;
            notifyLoginctl(true);
            return;
        }

        shouldLock = true;
        notifyLoginctl(true);
    }

    function lockAndOutputsOff() {
        IdleService.lockPowerOffRequested = true;
        if (sessionLock.locked) {
            beginPowerOff();
            return;
        }
        lockPowerOffArmed = true;
        lock();
    }

    function unlock() {
        if (!shouldLock)
            return;
        lockInitiatedLocally = false;
        notifyLoginctl(false);
        shouldLock = false;
    }

    function forceReset() {
        lockInitiatedLocally = false;
        pendingLock = false;
        shouldLock = false;
        customLockerSpawned = false;
        resetPowerOffFade();
        IdleService.lockPowerOffRequested = false;
    }

    function activate() {
        lock();
    }

    Connections {
        target: SessionService

        function onSessionLocked() {
            if (shouldLock || pendingLock)
                return;
            if (handleLoginctlCustomLock())
                return;
            if (!SessionService.active && SessionService.loginctlAvailable && SettingsData.loginctlLockIntegration) {
                pendingLock = true;
                lockInitiatedLocally = false;
                return;
            }
            lockInitiatedLocally = false;
            lockPowerOffArmed = powerOffOnLock;
            shouldLock = true;
        }

        function onSessionUnlocked() {
            customLockerSpawned = false;
            if (pendingLock) {
                pendingLock = false;
                lockInitiatedLocally = false;
                return;
            }
            if (!shouldLock || lockInitiatedLocally)
                return;
            shouldLock = false;
        }

        function onLoginctlStateChanged() {
            if (SessionService.active && pendingLock) {
                pendingLock = false;
                lockInitiatedLocally = true;
                lockPowerOffArmed = powerOffOnLock;
                shouldLock = true;
                return;
            }
            if (SessionService.locked && !shouldLock && !pendingLock) {
                if (handleLoginctlCustomLock())
                    return;
                lockInitiatedLocally = false;
                lockPowerOffArmed = powerOffOnLock;
                shouldLock = true;
            }
        }
    }

    Connections {
        target: IdleService

        function onLockRequested() {
            lock();
        }

        function onMonitorsOffChanged() {
            if (!IdleService.monitorsOff)
                root.resetPowerOffFade();
        }
    }

    Pam {
        id: sharedPam
        lockSecured: root.shouldLock
        buffer: root.sharedPasswordBuffer
        onUnlockRequested: root.unlock()
    }

    WlSessionLock {
        id: sessionLock

        locked: shouldLock

        WlSessionLockSurface {
            id: lockSurface

            property string currentScreenName: screen?.name ?? ""
            property bool isActiveScreen: {
                if (Quickshell.screens.length <= 1)
                    return true;
                return SettingsData.getFilteredScreens("lockScreen").includes(screen);
            }

            color: isActiveScreen ? "transparent" : SettingsData.lockScreenInactiveColor

            LockSurface {
                anchors.fill: parent
                visible: lockSurface.isActiveScreen
                lock: sessionLock
                pam: sharedPam
                sharedPasswordBuffer: root.sharedPasswordBuffer
                screenName: lockSurface.currentScreenName
                isLocked: shouldLock
                onUnlockRequested: root.unlock()
                onPasswordChanged: newPassword => {
                    root.sharedPasswordBuffer = newPassword;
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: root.powerOffFadeTarget
                visible: opacity > 0 || powerOffFadeTimer.running

                Behavior on opacity {
                    enabled: !root.powerOffFadeInstant
                    NumberAnimation {
                        duration: SettingsData.fadeToDpmsGracePeriod * 1000
                        easing.type: Easing.OutCubic
                    }
                }

                MouseArea {
                    property real baselineX: -1
                    property real baselineY: -1

                    anchors.fill: parent
                    enabled: powerOffFadeTimer.running
                    hoverEnabled: enabled
                    onEnabledChanged: {
                        baselineX = -1;
                        baselineY = -1;
                    }
                    onPressed: root.cancelPowerOffFade()
                    onWheel: root.cancelPowerOffFade()
                    onPositionChanged: mouse => {
                        if (baselineX < 0) {
                            baselineX = mouse.x;
                            baselineY = mouse.y;
                            return;
                        }
                        if (Math.abs(mouse.x - baselineX) < 5 && Math.abs(mouse.y - baselineY) < 5)
                            return;
                        root.cancelPowerOffFade();
                    }
                }
            }
        }
    }

    Connections {
        target: sessionLock

        function onLockedChanged() {
            notifyLockedHint(sessionLock.locked);
            if (sessionLock.locked) {
                pendingLock = false;
                if (lockPowerOffArmed && powerOffOnLock)
                    beginPowerOff();
                lockPowerOffArmed = false;
                return;
            }

            lockWakeAllowed = false;
            resetPowerOffFade();
            if (IdleService.monitorsOff && powerOffOnLock) {
                IdleService.monitorsOff = false;
                CompositorService.powerOnMonitors();
            }
            IdleService.lockPowerOffRequested = false;
        }
    }

    LockScreenDemo {
        id: demoWindow
    }

    IpcHandler {
        target: "lock"

        function lock() {
            root.lock();
        }

        function lockAndOutputsOff() {
            root.lockAndOutputsOff();
        }

        function unlock() {
            root.unlock();
        }

        function forceReset() {
            root.forceReset();
        }

        function demo() {
            demoWindow.showDemo();
        }

        function isLocked(): bool {
            return sessionLock.locked;
        }

        function status(): string {
            return JSON.stringify({
                shouldLock: root.shouldLock,
                sessionLockLocked: sessionLock.locked,
                lockInitiatedLocally: root.lockInitiatedLocally,
                pendingLock: root.pendingLock,
                loginctlLocked: SessionService.locked,
                loginctlActive: SessionService.active
            });
        }
    }

    Timer {
        id: powerOffFadeTimer
        interval: SettingsData.fadeToDpmsGracePeriod * 1000
        repeat: false
        onTriggered: root.applyMonitorsOff()
    }

    IdleMonitor {
        timeout: 1
        respectInhibitors: false
        enabled: powerOffFadeTimer.running
        onIsIdleChanged: {
            if (isIdle)
                return;
            if (!powerOffFadeTimer.running)
                return;
            root.cancelPowerOffFade();
        }
    }

    Timer {
        id: dpmsReapplyTimer
        interval: 100
        repeat: false
        onTriggered: IdleService.reapplyDpmsIfNeeded()
    }

    Timer {
        id: lockWakeDebounce
        interval: 200
        repeat: false
        onTriggered: {
            if (!sessionLock.locked)
                return;
            if (!powerOffOnLock)
                return;
            if (!IdleService.monitorsOff) {
                lockWakeAllowed = true;
                return;
            }
            if (lockWakeAllowed) {
                IdleService.monitorsOff = false;
                CompositorService.powerOnMonitors();
            } else {
                lockWakeAllowed = true;
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: sessionLock.locked
        hoverEnabled: enabled
        onPressed: lockWakeDebounce.restart()
        onPositionChanged: lockWakeDebounce.restart()
        onWheel: lockWakeDebounce.restart()
    }

    FocusScope {
        anchors.fill: parent
        focus: sessionLock.locked

        Keys.onPressed: event => {
            if (!sessionLock.locked)
                return;
            lockWakeDebounce.restart();
        }
    }
}
