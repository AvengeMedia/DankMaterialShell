pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland
import qs.Common

FocusScope {
    id: root

    required property WlSessionLock lock
    required property string sharedPasswordBuffer
    required property string screenName
    required property bool isLocked

    signal passwordChanged(string newPassword)
    signal unlockRequested

    Keys.onPressed: event => {
        if (videoScreensaver.active && videoScreensaver.inputEnabled) {
            videoScreensaver.dismiss();
            event.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
    }

    LockScreenContent {
        id: lockContent

        anchors.fill: parent
        demoMode: false
        passwordBuffer: root.sharedPasswordBuffer
        screenName: root.screenName
        enabled: !videoScreensaver.active
        focus: !videoScreensaver.active
        opacity: videoScreensaver.active ? 0 : 1
        onUnlockRequested: root.unlockRequested()
        onPasswordBufferChanged: {
            if (root.sharedPasswordBuffer !== passwordBuffer) {
                root.passwordChanged(passwordBuffer);
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }
    }

    VideoScreensaver {
        id: videoScreensaver
        anchors.fill: parent
        screenName: root.screenName
    }

    Component.onCompleted: forceActiveFocus()

    onIsLockedChanged: {
        if (isLocked) {
            forceActiveFocus();
            lockContent.resetLockState();
            if (SettingsData.lockScreenVideoEnabled) {
                videoScreensaver.start();
            }
            return;
        }
        lockContent.unlocking = false;
    }
}
