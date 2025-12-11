import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string iconName: ""
    property string text: ""

    signal pressed()

    height: 34
    radius: Theme.cornerRadius
    color: mouseArea.containsMouse ? Qt.rgba(
                                        Theme.primary.r,
                                        Theme.primary.g,
                                        Theme.primary.b,
                                        0.12) : Qt.rgba(
                                        Theme.surfaceVariant.r,
                                        Theme.surfaceVariant.g,
                                        Theme.surfaceVariant.b,
                                        0.5)

    Row {
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        DankIcon {
            name: root.iconName
            size: Theme.fontSizeSmall
            color: mouseArea.containsMouse ? Theme.primary : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        Typography {
            text: root.text
            style: Typography.Style.Button
            color: mouseArea.containsMouse ? Theme.primary : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: root.pressed()
    }
}
