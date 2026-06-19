import QtQuick
import qs.Common
import qs.Services
import qs.Modules.ControlCenter.Components
import "../utils/layout.js" as LayoutUtils

Item {
    id: root

    property var model: null
    property var componentProvider: null
    property bool active: true

    signal removeWidget(int index)
    signal toggleWidgetSize(int index)
    signal configRequested(int index, var widgetData, var anchor)

    property var sourceWidgets: SettingsData.controlCenterWidgets || []
    property var visualOrder: []
    property int draggingSourceIndex: -1
    property var dragStartOrder: []

    readonly property real rowSpacing: Theme.spacingL
    readonly property real sliderCellHeight: 48
    readonly property real normalCellHeight: 60

    readonly property var slotLayout: LayoutUtils.computeSlots(sourceWidgets, visualOrder, width, Theme.spacingS, rowSpacing, sliderCellHeight, normalCellHeight)

    implicitHeight: slotLayout.totalHeight

    function rebuildOrder() {
        const n = (sourceWidgets || []).length;
        const arr = [];
        for (var i = 0; i < n; i++)
            arr.push(i);
        visualOrder = arr;
    }

    onSourceWidgetsChanged: rebuildOrder()
    Component.onCompleted: rebuildOrder()

    function beginDrag(sourceIndex) {
        draggingSourceIndex = sourceIndex;
        dragStartOrder = visualOrder.slice();
    }

    function sameOrder(a, b) {
        if (a.length !== b.length)
            return false;
        for (var i = 0; i < a.length; i++) {
            if (a[i] !== b[i])
                return false;
        }
        return true;
    }

    function updateDragTarget(centerX, centerY) {
        if (draggingSourceIndex < 0)
            return;
        const p = LayoutUtils.slotContainingPoint(slotLayout.slots, visualOrder, centerX, centerY);
        if (p < 0)
            return;
        const arr = visualOrder.slice();
        const d = arr.indexOf(draggingSourceIndex);
        if (d < 0 || d === p)
            return;
        arr.splice(d, 1);
        arr.splice(p, 0, draggingSourceIndex);
        visualOrder = arr;
    }

    function endDrag() {
        if (draggingSourceIndex < 0)
            return;
        draggingSourceIndex = -1;
        if (!sameOrder(visualOrder, dragStartOrder))
            commit();
    }

    function commit() {
        const widgets = sourceWidgets || [];
        const arr = visualOrder.map(i => widgets[i]);
        if (root.model)
            root.model.reorderWidgets(arr);
    }

    Repeater {
        model: root.active ? root.sourceWidgets : []

        EditModeWidgetDelegate {
            required property int index
            required property var modelData

            grid: root
            sourceIndex: index
            widgetData: modelData
            isSlider: LayoutUtils.isSliderWidget(modelData.id || "")
            widgetComponent: root.componentProvider ? root.componentProvider.componentForWidget(modelData) : null

            slotX: root.slotLayout.slots[index] ? root.slotLayout.slots[index].x : 0
            slotY: root.slotLayout.slots[index] ? root.slotLayout.slots[index].y : 0
            cellW: root.slotLayout.slots[index] ? root.slotLayout.slots[index].w : root.width
            cellH: root.slotLayout.slots[index] ? root.slotLayout.slots[index].h : root.normalCellHeight

            onRemoveWidget: idx => root.removeWidget(idx)
            onToggleWidgetSize: idx => root.toggleWidgetSize(idx)
            onConfigRequested: (idx, data, anchor) => root.configRequested(idx, data, anchor)
        }
    }
}
