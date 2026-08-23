pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    required property var systemModel

    Column {
        anchors {
            fill: parent
            margins: 24
        }
        spacing: Theme.spacingL

        Row {
            width: parent.width
            spacing: Theme.spacingM

            Rectangle {
                width: 48
                height: 48
                radius: 18
                color: Theme.primaryContainer

                DankIcon {
                    anchors.centerIn: parent
                    name: root.systemModel.iconName
                    size: 27
                    color: Theme.primary
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.systemModel.volumeActivity
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.systemModel.toggleMute()
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 48 - valueText.width - parent.spacing * 2
                spacing: 2

                Text {
                    text: root.systemModel.title
                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                }

                Text {
                    text: root.systemModel.volumeActivity ? "Click the icon to mute" : "Display level"
                    color: Theme.surfaceTextSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Text {
                id: valueText

                anchors.verticalCenter: parent.verticalCenter
                text: root.systemModel.displayValue
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 28
                font.weight: Font.DemiBold
            }
        }

        Item {
            id: slider

            width: parent.width
            height: 40

            Rectangle {
                id: track

                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 12
                radius: 6
                color: Theme.withAlpha(Theme.surfaceText, 0.14)

                Rectangle {
                    width: parent.width * root.systemModel.ratio
                    height: parent.height
                    radius: parent.radius
                    color: Theme.primary
                }

                Rectangle {
                    x: Math.max(0, Math.min(parent.width - width, parent.width * root.systemModel.ratio - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    radius: 11
                    color: Theme.primary
                    border.width: 3
                    border.color: Theme.surfaceContainerHigh
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.systemModel.available
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                function updateValue(mouse) {
                    root.systemModel.setRatio(mouse.x / width);
                }

                onPressed: mouse => updateValue(mouse)
                onPositionChanged: mouse => {
                    if (pressed)
                        updateValue(mouse);
                }
            }
        }
    }
}
