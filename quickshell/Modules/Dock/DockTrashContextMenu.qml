import QtQuick
import qs.Common
import qs.Services

DockContextMenuBase {
    id: root

    property var dockApps: null

    layerNamespace: "dms:dock-trash-context-menu"

    function showForButton(button, dockHeight, dockScreen, parentDockApps) {
        dockApps = parentDockApps || null;
        show(button, dockHeight, dockScreen);
    }

    DockTrashMenuItem {
        width: parent.width
        iconName: "folder_open"
        text: I18n.tr("Open Trash")
        onTriggered: {
            TrashService.openTrash();
            root.close();
        }
    }

    DockTrashMenuItem {
        width: parent.width
        iconName: "delete_forever"
        isDestructive: true
        enabled: !TrashService.isEmpty
        text: TrashService.isEmpty ? I18n.tr("Empty Trash") : I18n.tr("Empty Trash (%1)").arg(TrashService.count)
        onTriggered: {
            TrashService.requestEmptyTrash();
            root.close();
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
    }

    DockTrashMenuItem {
        width: parent.width
        iconName: "settings"
        text: I18n.tr("Settings")
        onTriggered: {
            SettingsSearchService.navigateToSection("dockTrash");
            PopoutService.openSettingsWithTab("dock");
            root.close();
        }
    }
}
