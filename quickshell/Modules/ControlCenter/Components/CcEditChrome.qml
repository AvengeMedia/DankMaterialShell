import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.ControlCenter

DankGridEditChrome {
    id: root

    property var widgetData: ({})

    signal configRequested(var anchor)

    hasOptions: widgetData.id === "diskUsage" || widgetData.id === "brightnessSlider" || widgetData.id === "idleInhibitor" || String(widgetData.id ?? "").startsWith("plugin_")
    horizontalResize: true
    cornerRadius: Theme.fullRadius(width, CcMetrics.tileHeight)
    buttonSize: Theme.iconSize
    iconSize: PopoutMetrics.chromeIconSize

    onOptionsRequested: anchor => root.configRequested(anchor)
}
