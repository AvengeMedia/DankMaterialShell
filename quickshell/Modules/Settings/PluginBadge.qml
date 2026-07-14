import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string label: ""
    property string iconName: ""
    property color tone: Theme.primary
    property bool onImage: false

    height: 20
    width: content.implicitWidth + Theme.spacingS * 2
    radius: height / 2
    color: onImage ? Theme.withAlpha(Theme.surfaceContainerHigh, 0.92) : Theme.withAlpha(tone, 0.12)
    border.color: Theme.withAlpha(tone, onImage ? 0.5 : 0.35)
    border.width: 1

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.spacingXXS

        DankIcon {
            name: root.iconName
            size: 11
            color: root.tone
            visible: root.iconName.length > 0
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: root.label
            font.pixelSize: Theme.fontSizeSmall - 2
            font.weight: Font.Medium
            color: root.tone
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
