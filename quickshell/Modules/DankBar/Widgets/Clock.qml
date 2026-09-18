import QtQuick
import qs.Common
import qs.Modules.DankBar
import qs.Modules.Plugins
import qs.Widgets

BasePill {
    id: root

    property var widgetData: null
    property var surfaceContext: null
    property bool compactMode: false
    signal clockClicked

    onClicked: clockClicked()

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? root.contentThickness : clock.implicitWidth
            implicitHeight: root.isVerticalOrientation ? clock.implicitHeight : root.contentThickness

            Binding {
                target: root
                property: "splitOffset"
                value: clock.split ? root.horizontalPadding + clock.splitOffset : 0
            }

            ClockContent {
                id: clock
                anchors.centerIn: parent
                vertical: root.isVerticalOrientation
                segmented: root.surfaceContext?.kind !== "dock" && BarMetrics.widgetStyle(root.barConfig) === "segments" && !root.noBackground
                displayMode: SettingsData.widgetOption("clock", root.widgetData, "clockCompactMode") ? "time" : "both"
                dateFirst: root.widgetData?.clockDateOrder === "dateFirst"
                fontSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                availableWidth: root.widgetThickness
                textColor: root.contentColor
                dateColor: vertical ? Theme.primary : root.contentColor
            }
        }
    }
}
