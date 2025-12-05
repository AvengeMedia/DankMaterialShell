import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

BasePill {
    id: root

    property bool isActive: false

    content: Component {
        Item {
            implicitWidth: root.widgetThickness - root.horizontalPadding * 2
            implicitHeight: root.widgetThickness - root.horizontalPadding * 2

            DankIcon {
                anchors.centerIn: parent
                name: "power_settings_new"
                size: Theme.barIconSize(root.barThickness)
                color: Theme.widgetIconColor
            }
        }
    }
}