import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Settings.Widgets

Rectangle {
    id: root

    property string label: ""
    property string iconName: ""
    property color tone: Theme.primary

    height: Theme.iconSize
    width: content.implicitWidth + Theme.spacingS * 2
    radius: Theme.cornerRadiusS
    color: SettingsMetrics.controlColor
    border.color: Theme.outlineVariant
    border.width: Theme.outlineWidth

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.spacingXXS

        DIcon {
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
