import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

BasePill {
    id: root

    property bool isActive: false

    signal colorPickerRequested()

    content: Component {
        Item {
            implicitWidth: root.widgetThickness - root.horizontalPadding * 2
            implicitHeight: root.widgetThickness - root.horizontalPadding * 2

            DankIcon {
                anchors.centerIn: parent
                name: "palette"
                size: Theme.barIconSize(root.barThickness, -4)
                color: root.isActive ? Theme.primary : Theme.surfaceText
            }
        }
    }

    MouseArea {
        z: 1
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            root.colorPickerRequested()
        }
    }
}
