import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    opacity: DMSService.capsLockState ? 1 : 0

    states: [
        State {
            name: "hidden_horizontal"
            when: !DMSService.capsLockState && !isVerticalOrientation
            PropertyChanges { target: root; width: 0 }
        },
        State {
            name: "hidden_vertical"
            when: !DMSService.capsLockState && isVerticalOrientation
            PropertyChanges { target: root; height: 0 }
        }
    ]

    transitions: [
        Transition {
            NumberAnimation { properties: "width,height"; duration: Theme.shortDuration; easing.type: Theme.standardEasing }
        }
    ]

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    content: Component {
        Item {
            implicitWidth: root.widgetThickness - root.horizontalPadding * 2
            implicitHeight: root.widgetThickness - root.horizontalPadding * 2

            DankIcon {
                anchors.centerIn: parent
                name: "shift_lock"
                size: Theme.barIconSize(root.barThickness)
                color: Theme.primary
            }
        }
    }
}
