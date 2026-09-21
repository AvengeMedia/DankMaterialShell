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

    readonly property real gridHeight: layoutHeight
    readonly property real cellWidth: (width + CcMetrics.gridGap) / columns
    readonly property CcTileSlot draggingSlot: tileRepeater.itemAt(draggingSourceIndex) as CcTileSlot

    sourceItems: (SettingsData.controlCenterWidgets || []).map(widget => Object.assign({}, widget, WidgetUtils.clampSize(widget, Infinity)))
    slotLayout: GridUtils.packCards(layoutItems.map(widget => Object.assign({}, widget, WidgetUtils.clampSize(widget, columns, maximumRows))), placementOrder, columns, width, CcMetrics.gridGap, cellWidth - CcMetrics.gridGap, I18n.isRtl, null, CcMetrics.gridStep)
    placeholderRadius: draggingSlot?.tileItem?.bodyRadius ?? Theme.fullRadius(width, CcMetrics.tileHeight)

    onLayoutCommitted: items => model.setLayout(items)

    function displayedItems() {
        return GridUtils.placedItems(sourceItems.map(widget => Object.assign({}, widget, {
                "w": WidgetUtils.clampSize(widget, columns).w
            })), slotLayout.slots);
    }

    Repeater {
        id: tileRepeater

        model: root.tileModel

        CcTileSlot {
            grid: root
        }
    }
}
