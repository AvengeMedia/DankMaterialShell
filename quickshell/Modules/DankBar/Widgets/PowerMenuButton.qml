import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

BasePill {
    id: root

    property bool isActive: false

    content: Component {
        Item {
            implicitWidth: icon.width
            implicitHeight: root.widgetThickness - root.horizontalPadding * 2

            DankIcon {
                id: icon
                anchors.centerIn: parent
                name: "power_settings_new"
                size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                color: Theme.widgetIconColor
            }
        }
    }
}
