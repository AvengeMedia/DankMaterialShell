pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    required property var notificationModel
    property bool dense: false
    property real iconSize: 36

    Row {
        anchors {
            fill: parent
            leftMargin: Theme.spacingS
            rightMargin: Theme.spacingS
        }
        spacing: Theme.spacingS

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: root.notificationModel.critical ? 3 : 0
            height: Math.max(12, parent.height - Theme.spacingS)
            radius: 1.5
            color: Theme.error
            visible: root.notificationModel.critical
        }

        DankCircularImage {
            anchors.verticalCenter: parent.verticalCenter
            width: root.iconSize
            height: width
            imageSource: root.notificationModel.imageSource
            fallbackIcon: root.notificationModel.fallbackIcon
            fallbackText: root.notificationModel.fallbackText
            cacheImages: false
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - root.iconSize - parent.spacing - (root.notificationModel.critical ? 3 + parent.spacing : 0)
            spacing: 1

            // A dense pill keeps one line, so the app name folds into the summary.
            Text {
                width: parent.width
                visible: !root.dense
                text: root.notificationModel.appName + (root.notificationModel.timeText ? " · " + root.notificationModel.timeText : "")
                color: Theme.surfaceTextSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.dense && root.notificationModel.appName ? root.notificationModel.appName + " · " + root.notificationModel.summary : root.notificationModel.summary
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: root.dense ? Theme.fontSizeSmall : Theme.fontSizeMedium
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }
    }
}
