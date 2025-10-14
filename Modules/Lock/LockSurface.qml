pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common

Rectangle {
    id: root

    required property WlSessionLock lock
    required property string sharedPasswordBuffer

    signal passwordChanged(string newPassword)
    signal unlockRequested()

    color: "transparent"

    LockScreenContent {
        anchors.fill: parent
        demoMode: false
        passwordBuffer: root.sharedPasswordBuffer
        screenName: ""
        onUnlockRequested: root.unlockRequested()
        onPasswordBufferChanged: {
            if (root.sharedPasswordBuffer !== passwordBuffer) {
                root.passwordChanged(passwordBuffer)
            }
        }
    }
}
