pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.ControlCenter
import "../utils/widgets.js" as WidgetUtils
import "../../../Common/GridLayout.js" as GridUtils

DankEditableGrid {
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
    signal accountsRequested
    signal editRequested
    signal closeRequested
    property bool tapToClose: false
    property var runningToplevels: []
    property bool dockEdit: false
    readonly property var editDock: {
        if (!dockEdit)
            return null;
        const layout = slotLayout;
        const col = layout.columns - 1;
        const row = layout.rows - 1;
        if (row < 0 || GridUtils.cellOccupied(layout, col, row))
            return null;
        const rect = GridUtils.slotRect(layout, col, row, 1, 1);
        return Qt.point(rect.x, rect.y);
    }

    readonly property real gridHeight: layoutHeight
    readonly property real cellWidth: (width + CcMetrics.gridGap) / columns
    readonly property CcTileSlot draggingSlot: tileRepeater.itemAt(draggingSourceIndex) as CcTileSlot

    readonly property var savedWidgets: SettingsData.controlCenterWidgets || []
    readonly property var shownIndices: savedWidgets.reduce((indices, widget, i) => WidgetUtils.isShown(widget) ? indices.concat([i]) : indices, [])

    sourceItems: shownIndices.map(i => Object.assign({}, savedWidgets[i], sizeWithHiddenTwin(i)))
    slotLayout: GridUtils.packCards(layoutItems.map(widget => Object.assign({}, widget, WidgetUtils.clampSize(widget, columns, maximumRows))), placementOrder, columns, width, CcMetrics.gridGap, cellWidth - CcMetrics.gridGap, I18n.isRtl, null, CcMetrics.gridStep, true)
    placeholderRadius: draggingSlot?.small ? Theme.fullRadius(draggingSlot.width, draggingSlot.height) : (draggingSlot?.tileItem?.bodyRadius ?? Theme.fullRadius(width, CcMetrics.tileHeight))

    onLayoutCommitted: items => model.setLayout(withHidden(items))

    function sizeWithHiddenTwin(index) {
        const widget = savedWidgets[index];
        const size = WidgetUtils.clampSize(widget, Infinity);
        if (!WidgetUtils.isUnplaced(widget))
            return size;
        for (const neighbor of [index + 1, index - 1]) {
            const twin = savedWidgets[neighbor];
            if (!twin || shownIndices.includes(neighbor) || !WidgetUtils.isUnplaced(twin))
                continue;
            const twinSize = WidgetUtils.clampSize(twin, Infinity);
            if (twinSize.w !== size.w || twinSize.h !== size.h)
                continue;
            size.w += twinSize.w;
            return size;
        }
        return size;
    }

    function savedIndex(index) {
        return shownIndices[index] ?? -1;
    }

    function withHidden(items) {
        const widgets = savedWidgets.slice();
        shownIndices.forEach((saved, i) => widgets[saved] = items[i]);
        return widgets;
    }

    DankActionButton {
        x: (root.editDock?.x ?? 0) + root.contentPadding + (root.slotLayout.colW - width) / 2
        y: (root.editDock?.y ?? 0) + root.contentPadding + (root.slotLayout.rowUnit - height) / 2
        visible: root.editDock !== null
        buttonSize: CcMetrics.footerHeight
        iconName: "edit"
        iconSize: CcMetrics.iconBoxIconSize
        iconColor: CcMetrics.tileInactiveContent
        backgroundColor: CcMetrics.tileInactiveColor
        border.width: Theme.layerOutlineWidth
        border.color: Theme.outlineMedium
        tooltipText: I18n.tr("Edit")
        onClicked: root.editRequested()
    }

    Repeater {
        id: tileRepeater

        model: root.tileModel

        CcTileSlot {
            grid: root
        }
    }
}
