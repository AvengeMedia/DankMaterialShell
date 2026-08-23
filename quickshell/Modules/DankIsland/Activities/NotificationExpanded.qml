pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    required property var notificationModel

    Item {
        anchors {
            fill: parent
            margins: 22
        }

        Row {
            id: header

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: 46
            spacing: Theme.spacingM

            DankCircularImage {
                anchors.verticalCenter: parent.verticalCenter
                width: 46
                height: 46
                imageSource: root.notificationModel.imageSource
                fallbackIcon: root.notificationModel.fallbackIcon
                fallbackText: root.notificationModel.fallbackText
                cacheImages: false
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 46 - closeButton.width - parent.spacing * 2
                spacing: 2

                Text {
                    width: parent.width
                    text: root.notificationModel.appName
                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.notificationModel.timeText
                    color: Theme.surfaceTextSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                id: closeButton

                anchors.verticalCenter: parent.verticalCenter
                width: 38
                height: 38
                radius: 19
                color: closeArea.containsMouse ? Theme.surfaceTextHover : "transparent"

                DankIcon {
                    anchors.centerIn: parent
                    name: "close"
                    size: 21
                    color: Theme.surfaceText
                }

                MouseArea {
                    id: closeArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.notificationModel.dismiss()
                }
            }
        }

        Column {
            anchors {
                left: parent.left
                right: parent.right
                top: header.bottom
                topMargin: Theme.spacingM
                bottom: actions.top
                bottomMargin: Theme.spacingM
            }
            spacing: Theme.spacingS

            Text {
                width: parent.width
                text: root.notificationModel.summary
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.DemiBold
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.notificationModel.body
                color: Theme.surfaceTextMedium
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 3
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }

        Row {
            id: actions

            anchors {
                right: parent.right
                bottom: parent.bottom
            }
            height: 34
            spacing: Theme.spacingS

            Rectangle {
                width: dismissLabel.implicitWidth + Theme.spacingL * 2
                height: parent.height
                radius: height / 2
                color: dismissArea.containsMouse ? Theme.surfaceTextHover : "transparent"
                border.width: 1
                border.color: Theme.withAlpha(Theme.outline, 0.5)

                Text {
                    id: dismissLabel

                    anchors.centerIn: parent
                    text: "Dismiss"
                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: dismissArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.notificationModel.dismiss()
                }
            }

            Rectangle {
                visible: root.notificationModel.hasAction
                width: actionLabel.implicitWidth + Theme.spacingL * 2
                height: parent.height
                radius: height / 2
                color: actionArea.containsMouse ? Theme.primaryContainer : Theme.primary

                Text {
                    id: actionLabel

                    anchors.centerIn: parent
                    text: root.notificationModel.actionLabel
                    color: actionArea.containsMouse ? Theme.primary : Theme.onPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: actionArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.notificationModel.activate()
                }
            }
        }
    }
}
