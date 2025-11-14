import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DankOSD {
    id: root

    osdWidth: Theme.iconSize + Theme.spacingS * 2
    osdHeight: Theme.iconSize + Theme.spacingS * 2
    autoHideInterval: 2000
    enableMouseInteraction: false

    property bool lastCapsLockState: false

    Connections {
        target: DMSService

        function onCapsLockStateChanged() {
            if (lastCapsLockState !== DMSService.capsLockState) {
                root.show()
            }
            lastCapsLockState = DMSService.capsLockState
        }
    }

    Component.onCompleted: {
        lastCapsLockState = DMSService.capsLockState
    }

    content: DankIcon {
        anchors.centerIn: parent
        name: DMSService.capsLockState ? "shift_lock" : "shift_lock_off"
        size: Theme.iconSize
        color: Theme.primary
    }
}
