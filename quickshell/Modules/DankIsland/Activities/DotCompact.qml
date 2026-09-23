pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    required property var controller
    property string iconName: "blur_on"

    readonly property real diameter: Math.min(width, height)

    DankIcon {
        anchors.centerIn: parent
        name: root.iconName
        size: Math.max(Theme.fontSizeSmall, Math.round(root.diameter * 0.46))
        color: Theme.primary
    }

    Rectangle {
        readonly property real badgeSize: Math.max(Theme.spacingXS, Math.round(root.diameter * 0.2))

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Math.round(root.diameter * 0.08)
        width: badgeSize
        height: badgeSize
        radius: badgeSize / 2
        color: Theme.error
        visible: root.controller.homeNotificationBadge
    }
}
