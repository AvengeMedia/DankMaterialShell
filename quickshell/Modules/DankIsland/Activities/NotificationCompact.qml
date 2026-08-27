pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    required property var notificationModel
    required property var controller
    property bool dense: false
    property real iconSize: 36

    readonly property string headerText: root.notificationModel.appName + (root.notificationModel.timeText ? " · " + root.notificationModel.timeText : "")
    readonly property string summaryText: root.dense && root.notificationModel.appName ? root.notificationModel.appName + " · " + root.notificationModel.summary : root.notificationModel.summary
    readonly property real measuredWidth: Theme.spacingS * 3 + root.iconSize + Theme.spacingXS + Math.max(root.dense ? 0 : headerLabel.implicitWidth, summaryLabel.implicitWidth)

    function pushMeasuredWidth() {
        root.controller.setNotificationContentWidth(root.measuredWidth);
    }

    onMeasuredWidthChanged: root.pushMeasuredWidth()
    Component.onCompleted: root.pushMeasuredWidth()

    Row {
        anchors {
            fill: parent
            leftMargin: Theme.spacingS
            rightMargin: Theme.spacingS
        }
        spacing: Theme.spacingS

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
            width: parent.width - root.iconSize - parent.spacing
            spacing: 1

            StyledText {
                id: headerLabel

                width: parent.width
                visible: !root.dense
                text: root.headerText
                color: Theme.surfaceTextSecondary
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }

            StyledText {
                id: summaryLabel

                width: parent.width
                text: root.summaryText
                color: Theme.surfaceText
                font.pixelSize: root.dense ? Theme.fontSizeSmall : Theme.fontSizeMedium
                font.weight: Font.DemiBold
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }
        }
    }
}
