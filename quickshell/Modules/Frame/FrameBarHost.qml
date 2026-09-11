pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.DankBar
import qs.Services

// Renders the bar(s) inside the frame surface in connected mode: one DankBarBody per
// active bar edge, positioned in the frame's cutout band. Reuses the existing DankBar
// item (per bar config) as rootWindow so colour-picker, overview loader and widget
// models are shared with the standalone path.
Item {
    id: host

    required property var frameWindow
    required property var targetScreen

    readonly property string screenName: targetScreen ? targetScreen.name : ""

    // Vertical edges first so horizontal bars paint over the corners; row 0 touches the screen edge.
    readonly property var barSlots: {
        SettingsData.barConfigs;
        const out = [];
        for (const edge of ["left", "right", "top", "bottom"]) {
            const configs = SettingsData.getFrameHostedBarConfigsForEdge(host.targetScreen, edge);
            configs.forEach((bc, row) => out.push({
                    "barId": bc.id,
                    "edge": edge,
                    "row": row,
                    "rowCount": configs.length
                }));
        }
        return out;
    }

    Repeater {
        model: host.barSlots

        delegate: Item {
            id: slot

            required property var modelData

            readonly property string edge: modelData.edge
            readonly property string barId: modelData.barId
            readonly property var dankBarItem: BarWidgetService.dankBarItems[modelData.barId] ?? null
            readonly property var slotBarConfig: dankBarItem?.barConfig ?? SettingsData.getBarConfig(modelData.barId)
            readonly property int edgeInset: {
                switch (edge) {
                case "left":
                    return host.frameWindow.cutoutLeftInset;
                case "right":
                    return host.frameWindow.cutoutRightInset;
                case "bottom":
                    return host.frameWindow.cutoutBottomInset;
                default:
                    return host.frameWindow.cutoutTopInset;
                }
            }
            readonly property int rowThickness: Math.floor(edgeInset / Math.max(1, modelData.rowCount))
            readonly property int rowOffset: modelData.row * rowThickness

            // Slots span the full edge like standalone windows; DankBarContent applies the adjacency insets itself.
            x: {
                switch (edge) {
                case "left":
                    return rowOffset;
                case "right":
                    return host.frameWindow._windowRegionWidth - rowOffset - rowThickness;
                default:
                    return 0;
                }
            }
            y: {
                switch (edge) {
                case "top":
                    return rowOffset;
                case "bottom":
                    return host.frameWindow._windowRegionHeight - rowOffset - rowThickness;
                default:
                    return 0;
                }
            }
            width: (edge === "left" || edge === "right") ? rowThickness : host.frameWindow._windowRegionWidth
            height: (edge === "top" || edge === "bottom") ? rowThickness : host.frameWindow._windowRegionHeight

            Loader {
                anchors.fill: parent
                active: slot.dankBarItem !== null && slot.slotBarConfig !== null

                sourceComponent: DankBarBody {
                    hostWindow: host.frameWindow
                    modelData: host.targetScreen
                    rootWindow: slot.dankBarItem
                    barConfig: slot.slotBarConfig
                    leftWidgetsModel: slot.dankBarItem?.leftWidgetsModel ?? null
                    centerWidgetsModel: slot.dankBarItem?.centerWidgetsModel ?? null
                    rightWidgetsModel: slot.dankBarItem?.rightWidgetsModel ?? null

                    Component.onCompleted: BarWidgetService.registerFrameBar(host.screenName, slot.barId, this)
                    Component.onDestruction: BarWidgetService.unregisterFrameBar(host.screenName, slot.barId, this)
                }
            }
        }
    }
}
