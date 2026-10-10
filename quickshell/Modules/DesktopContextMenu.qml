import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DContextMenu {
    id: root

    layerNamespace: "dms:desktop-context-menu"
    keyboardNavigable: true
    menuItems: [
        {
            type: "item",
            icon: "add",
            text: I18n.tr("Add widget"),
            action: () => DesktopWidgetRegistry.startEditing(root.targetScreen, true)
        },
        {
            type: "item",
            icon: "edit",
            text: I18n.tr("Edit widgets"),
            action: () => DesktopWidgetRegistry.startEditing(root.targetScreen, false)
        },
        {
            type: "separator"
        },
        {
            type: "item",
            icon: "wallpaper",
            text: I18n.tr("Wallpaper & colors"),
            action: () => PopoutService.openSettingsWithTab("personalization")
        },
        {
            type: "item",
            icon: "widgets",
            text: I18n.tr("Desktop widgets"),
            action: () => PopoutService.openSettingsWithTab("desktop_widgets")
        },
        {
            type: "item",
            icon: "monitor",
            text: I18n.tr("Displays"),
            action: () => PopoutService.openSettingsWithTab("displays")
        }
    ]

    onBackdropRightClicked: (x, y) => open(targetScreen, x, y, false)
}
