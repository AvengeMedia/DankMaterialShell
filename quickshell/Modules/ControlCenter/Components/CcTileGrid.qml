pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.ControlCenter
import "../utils/layout.js" as LayoutUtils

DankEditableGrid {
    id: root

    property var model: null
    property bool live: true
    property string screenName: ""

    signal expandClicked(var widgetData)
    signal removeWidget(int index)
    signal configRequested(int index, var widgetData, var anchor)
    signal colorPickerRequested

    readonly property real gridHeight: slotLayout.totalHeight
    readonly property CcTileSlot draggingSlot: tileRepeater.itemAt(draggingSourceIndex) as CcTileSlot

    sourceItems: SettingsData.controlCenterWidgets || []
    slotLayout: LayoutUtils.computeSlots(layoutItems, visualOrder, width, CcMetrics.gridGap, CcMetrics.gridGap, CcMetrics.sliderRowHeight, CcMetrics.tileHeight, I18n.isRtl)
    placeholderRadius: LayoutUtils.isSliderWidget(sourceItems[draggingSourceIndex]?.id ?? "") ? Theme.cornerRadiusM : (draggingSlot?.tileItem?.bodyRadius ?? Theme.fullRadius(width, CcMetrics.tileHeight))

    onReorderCommitted: items => model.reorderWidgets(items)
    onResizeCommitted: (index, changes) => model.setWidgetWidth(index, changes.width)

    Repeater {
        id: tileRepeater

        model: root.tileModel

        CcTileSlot {
            grid: root
        }
    }
}
