pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.ControlCenter
import qs.Widgets
import "../utils/widgets.js" as WidgetUtils

Item {
    id: root

    property var widgetData: ({})
    property var widgetDef: null
    property var host: null
    property bool live: true
    property bool interactive: true
    property real columns: 1.5
    property real rows: 1.5
    property bool compact: false

    readonly property Item passthrough: actionGrid
    readonly property bool editMode: host?.editMode ?? false
    readonly property var actions: WidgetUtils.enabledQuickActions(widgetData)
    readonly property real bodyRadius: Theme.cornerRadiusL
    readonly property int actionColumns: Math.max(1, Math.min(actions.length, Math.floor((width + CcMetrics.actionGap) / (CcMetrics.actionSize + CcMetrics.actionGap))))

    width: parent?.width ?? 0
    height: CcMetrics.headerHeight
    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    function trigger(id) {
        switch (id) {
        case "lock":
            host?.lockRequested();
            return;
        case "power":
            host?.powerRequested();
            return;
        case "settings":
            host?.settingsRequested();
            return;
        case "edit":
            host?.editRequested();
            return;
        }
    }

    Grid {
        id: actionGrid

        anchors.centerIn: parent
        columns: root.actionColumns
        spacing: CcMetrics.actionGap

        Repeater {
            model: root.actions

            DankActionButton {
                required property var modelData
                readonly property string actionId: modelData.id
                readonly property bool destructive: root.widgetData?.powerAccent === true && actionId === "power"
                readonly property bool editing: actionId === "edit" && root.editMode

                buttonSize: CcMetrics.actionSize
                iconSize: CcMetrics.actionIconSize
                circular: false
                iconName: WidgetUtils.quickActionIcon(actionId)
                iconColor: editing ? Theme.onPrimary : destructive ? Theme.error : Theme.onSurface
                backgroundColor: editing ? Theme.primary : Theme.foregroundColor(Theme.cardSurface)
                tooltipText: I18n.tr(WidgetUtils.quickActionLabel(actionId))
                checkable: actionId === "edit"
                checked: editing
                Accessible.checkable: checkable
                Accessible.checked: checked
                onClicked: root.trigger(actionId)
            }
        }
    }
}
