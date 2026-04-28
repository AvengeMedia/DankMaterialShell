pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland

Rectangle {
    id: root

    required property WlSessionLock lock
    required property var pam
    required property string sharedPasswordBuffer
    required property string screenName
    required property bool isLocked

    signal passwordChanged(string newPassword)
    signal unlockRequested

    color: "transparent"

    LockScreenContent {
        id: lockContent

        anchors.fill: parent
        demoMode: false
        pam: root.pam
        passwordBuffer: root.sharedPasswordBuffer
        screenName: root.screenName
        onUnlockRequested: root.unlockRequested()
        onPasswordBufferChanged: {
            if (root.sharedPasswordBuffer !== passwordBuffer) {
                root.passwordChanged(passwordBuffer);
            }
        }
    }

    onIsLockedChanged: {
        if (isLocked) {
            lockContent.resetLockState();
            return;
        }
        lockContent.unlocking = false;
    }
}
