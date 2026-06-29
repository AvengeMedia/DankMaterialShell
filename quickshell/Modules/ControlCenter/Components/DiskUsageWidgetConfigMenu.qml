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
    border.color: Theme.outlineStrong
    border.width: 1

    MouseArea {
        anchors.fill: parent
    }

    Column {
        id: menuColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        spacing: 2

        DankToggle {
            width: parent.width
            text: I18n.tr("Show mount path", "toggle in control center disk usage widget to turn mount path display on or off")
            checked: root.widgetData?.showMountPath !== false
            onToggled: newChecked => {
                root.showMountPathChanged(newChecked);
            }
        }
    }
}
