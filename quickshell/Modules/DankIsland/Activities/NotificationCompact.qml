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
    readonly property real criticalWidth: root.notificationModel.critical ? 3 + Theme.spacingS : 0
    readonly property real measuredWidth: Theme.spacingS * 3 + root.criticalWidth + root.iconSize + Math.max(root.dense ? 0 : headerMetrics.width, summaryMetrics.width)

    function pushMeasuredWidth() {
        root.controller.setNotificationContentWidth(root.measuredWidth);
    }

    onMeasuredWidthChanged: root.pushMeasuredWidth()
    Component.onCompleted: root.pushMeasuredWidth()

    StyledTextMetrics {
        id: headerMetrics

        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Medium
        text: root.headerText
    }

    StyledTextMetrics {
        id: summaryMetrics

        font.pixelSize: root.dense ? Theme.fontSizeSmall : Theme.fontSizeMedium
        font.weight: Font.DemiBold
        text: root.summaryText
    }

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
            width: parent.width - root.iconSize - parent.spacing - root.criticalWidth
            spacing: 1

            StyledText {
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
