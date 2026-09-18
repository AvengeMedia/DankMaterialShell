import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string label: ""
    property string iconName: ""
    property color tone: Theme.primary
    property bool onImage: false

    height: Theme.iconSize
    width: content.implicitWidth + Theme.spacingS * 2
    radius: Theme.cornerRadiusS
    color: Theme.chipSurface
    border.color: Theme.outlineVariant
    border.width: Theme.outlineWidth

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.spacingXXS

        DankIcon {
            name: root.iconName
            size: Theme.iconSizeSmall
            color: root.tone
            visible: root.iconName.length > 0
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: root.label
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightMedium
            color: root.tone
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
