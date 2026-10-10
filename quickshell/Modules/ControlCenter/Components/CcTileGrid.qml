pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.ControlCenter
import "../utils/widgets.js" as WidgetUtils
import "../../../Common/GridLayout.js" as GridUtils

DEditableGrid {
    id: root

    property var model: null
    property bool live: true
    property string screenName: ""
    property int columns: CcMetrics.gridColumns
    property real availableHeight: CcMetrics.fallbackScreenHeight - CcMetrics.maxHeightInset
    readonly property int maximumRows: CcMetrics.rowCapFor(availableHeight, cellWidth - CcMetrics.gridGap)

    signal expandClicked(var widgetData)
    signal removeWidget(int index)
    signal configRequested(int index, var widgetData, var anchor)
    signal colorPickerRequested
    signal lockRequested
    signal powerRequested
    signal settingsRequested
    signal editRequested
    signal accountsRequested
    signal closeRequested
    property bool tapToClose: false
    property var runningToplevels: []

    readonly property real gridHeight: layoutHeight
    readonly property real cellWidth: (width + CcMetrics.gridGap) / columns
    readonly property CcTileSlot draggingSlot: tileRepeater.itemAt(draggingSourceIndex) as CcTileSlot
    readonly property string hoverGroup: heldOutside && draggingSourceIndex >= 0 ? (groupAt(dragScenePoint, draggingSourceIndex)?.groupId ?? "") : ""

    readonly property var savedWidgets: SettingsData.controlCenterWidgets || []
    readonly property var groupIds: WidgetUtils.groupIds(savedWidgets)
    readonly property var shownIndices: savedWidgets.reduce((indices, widget, i) => !WidgetUtils.inFooter(widget) && !WidgetUtils.inGroup(widget, groupIds) && WidgetUtils.isShown(widget) && model?.componentForWidget(widget) ? indices.concat([i]) : indices, [])

    sourceItems: shownIndices.map(i => Object.assign({}, savedWidgets[i], sizeWithHiddenTwin(i)))
    slotLayout: GridUtils.packCards(clamped(layoutItems), placementOrder, columns, width, CcMetrics.gridGap, cellWidth - CcMetrics.gridGap, I18n.isRtl, null, CcMetrics.gridStep, true)
    gravity: true
    rowStep: CcMetrics.gridStep
    packer: items => GridUtils.packCells(clamped(items), placementOrder, columns, null, CcMetrics.gridStep, true).cells
    placeholderRadius: draggingSlot?.small ? Theme.fullRadius(draggingSlot.width, draggingSlot.height) : (draggingSlot?.tileItem?.bodyRadius ?? Theme.fullRadius(width, CcMetrics.tileHeight))

    onLayoutCommitted: items => model.setLayout(withHidden(items))

    function clamped(items) {
        return items.map(widget => Object.assign({}, widget, WidgetUtils.clampSize(widget, columns, maximumRows)));
    }

    function sizeWithHiddenTwin(index) {
        const widget = savedWidgets[index];
        const size = WidgetUtils.clampSize(widget, Infinity);
        if (!WidgetUtils.isUnplaced(widget))
            return size;
        for (const neighbor of [index + 1, index - 1]) {
            const twin = savedWidgets[neighbor];
            if (!twin || WidgetUtils.isShown(twin) || !WidgetUtils.isUnplaced(twin))
                continue;
            const twinSize = WidgetUtils.clampSize(twin, Infinity);
            if (twinSize.w !== size.w || twinSize.h !== size.h)
                continue;
            size.w += twinSize.w;
            return size;
        }
        return size;
    }

    function groupAt(scenePoint, excludeIndex) {
        for (let i = 0; i < tileRepeater.count; i++) {
            const slot = tileRepeater.itemAt(i) as CcTileSlot;
            if (i === excludeIndex || slot?.widgetData.id !== WidgetUtils.GROUP_ID)
                continue;
            if (slot.contains(slot.mapFromItem(null, scenePoint.x, scenePoint.y)))
                return slot.tileItem;
        }
        return null;
    }

    function savedIndex(index) {
        return shownIndices[index] ?? -1;
    }

    function withHidden(items) {
        const widgets = savedWidgets.slice();
        shownIndices.forEach((saved, i) => widgets[saved] = items[i]);
        return widgets;
    }

    Repeater {
        id: tileRepeater

        model: root.tileModel

        CcTileSlot {
            grid: root
        }
    }
}
