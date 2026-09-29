import QtQuick
import qs.Common
import qs.Widgets
import "../utils/widgets.js" as WidgetUtils
import qs.Modules.ControlCenter

DankGridEditChrome {
    id: root

    property var widgetData: ({})

    signal configRequested(var anchor)

    hasOptions: WidgetUtils.hasOptions(widgetData.id)
    removable: !WidgetUtils.isPinned(widgetData.id)
    buttonSize: Theme.iconSize
    hitOverflow: CcMetrics.gridGap / 2
    iconSize: PopoutMetrics.chromeIconSize

    onOptionsRequested: anchor => root.configRequested(anchor)
}
