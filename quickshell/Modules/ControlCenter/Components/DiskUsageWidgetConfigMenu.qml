import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property var widgetData: null

    signal showMountPathChanged(bool show)

    width: 260
    height: menuColumn.implicitHeight + Theme.spacingS * 2
    radius: Theme.cornerRadius
    color: Theme.surfaceContainer
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.16)
    border.width: 1

    MouseArea {
        anchors.fill: parent
    }

    Column {
        id: menuColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        spacing: 2

        StyledText {
            width: parent.width
            leftPadding: Theme.spacingS
            topPadding: Theme.spacingXS
            bottomPadding: Theme.spacingXS
            text: I18n.tr("Disk Usage Widget")
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        DankToggle {
            width: parent.width
            text: I18n.tr("Show mount path")
            description: I18n.tr("Display the mount path under the widget")
            checked: root.widgetData?.showMountPath !== false
            onToggled: newChecked => {
                root.showMountPathChanged(newChecked);
            }
        }
    }
}
