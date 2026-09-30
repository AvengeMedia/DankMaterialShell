import QtQuick
import qs.Modules.ControlCenter
import "../utils/widgets.js" as WidgetUtils

CcTile {
    id: root

    readonly property string action: widgetData?.id ?? ""

    toggle: false
    iconName: widgetDef?.icon ?? ""
    title: widgetDef?.text ?? ""
    restIconColor: CcMetrics.actionIconColor(action)

    onClicked: WidgetUtils.triggerButton(host, action)
}
