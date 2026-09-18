import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property var popoutService: null
    readonly property int count: pluginData.count ?? 0
    readonly property real textSize: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)

    pillClickAction: (x, y, width, section, screen) => popoutService?.toggleDankDash("plugin_" + pluginId, x, y, width, section, screen)
    pillRightClickAction: () => pluginService?.savePluginData(pluginId, "count", count + 1)

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "counter_1"
                size: root.iconSize
                color: Theme.widgetIconColor
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.count
                font.pixelSize: root.textSize
                color: Theme.widgetTextColor
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXXS

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "counter_1"
                size: root.iconSize
                color: Theme.widgetIconColor
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.count
                font.pixelSize: root.textSize
                color: Theme.widgetTextColor
            }
        }
    }
}
