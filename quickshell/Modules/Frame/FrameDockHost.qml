pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.Dock
import qs.Services

// Renders the dock inside the frame surface in connected mode: a single DockBody
// positioned by SettingsData.dockPosition. It fills the frame and positions its own
// content via its internal anchors/geometry using hostWindow.
Item {
    id: host

    required property var frameWindow
    required property var targetScreen

    readonly property string screenName: targetScreen ? targetScreen.name : ""

    // Exposed so FrameWindow can add the dock's hover strip to its input region.
    readonly property alias dockMaskItem: dockBody.inputMaskItem

    DockBody {
        id: dockBody
        anchors.fill: parent
        hostWindow: host.frameWindow
        modelData: host.targetScreen
        contextMenu: BarWidgetService.dockContextMenu
        trashContextMenu: BarWidgetService.dockTrashContextMenu
    }
}
