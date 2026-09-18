import QtQuick
import qs.Common
import qs.Modules.ControlCenter.Widgets
import "utils/cards.js" as CardUtils

CcMenu {
    id: root

    required property string entryId
    property var tabItem: null
    property bool editMode: false
    property bool panelResizable: false
    readonly property bool hasWidgets: root.entryId === DashRegistry.fallbackId || typeof root.tabItem?.clearWidgets === "function"

    signal editRequested
    signal optionsRequested
    signal settingsRequested

    items: root.editMode ? [
        {
            "label": I18n.tr("Options", "noun, menu entry or button that opens item options"),
            "iconName": "tune",
            "visible": DashRegistry.hasOptions(root.entryId),
            "action": () => root.optionsRequested()
        },
        {
            "label": I18n.tr("Reset to default"),
            "iconName": "settings_backup_restore",
            "action": () => {
                if (root.panelResizable)
                    DashRegistry.resetPanelSize(root.entryId);
                if (root.entryId === DashRegistry.fallbackId)
                    CardUtils.resetToDefault();
                else
                    root.tabItem?.resetWidgets?.();
            }
        },
        {
            "label": I18n.tr("Clear All"),
            "iconName": "clear_all",
            "destructive": true,
            "visible": root.hasWidgets,
            "action": () => {
                if (root.entryId === DashRegistry.fallbackId)
                    CardUtils.clearAll();
                else
                    root.tabItem?.clearWidgets();
            }
        }
    ] : (root.tabItem?.menuActions ?? []).concat([
        {
            "label": I18n.tr("Edit"),
            "iconName": "edit",
            "visible": root.panelResizable || root.hasWidgets,
            "action": () => root.editRequested()
        },
        {
            "label": I18n.tr("Options"),
            "iconName": "tune",
            "visible": DashRegistry.hasOptions(root.entryId),
            "action": () => root.optionsRequested()
        },
        {
            "label": I18n.tr("Settings"),
            "iconName": "settings",
            "action": () => root.settingsRequested()
        }
    ])
}
