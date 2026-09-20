import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.ControlCenter

DankGridEditChrome {
    id: root

    property var widgetData: ({})

    signal configRequested(var anchor)

    hasOptions: widgetData.id === "diskUsage" || widgetData.id === "brightnessSlider" || widgetData.id === "idleInhibitor" || String(widgetData.id ?? "").startsWith("plugin_")
    buttonSize: Theme.iconSize
    hitOverflow: CcMetrics.gridGap / 2
    iconSize: PopoutMetrics.chromeIconSize

    onOptionsRequested: anchor => root.configRequested(anchor)
}
