import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.ControlCenter
import "../utils/widgets.js" as WidgetUtils
import "../../../Common/GridLayout.js" as GridUtils

DEditableGridSlot {
    id: root

    readonly property var widgetData: JSON.parse(json)
    readonly property var sizeSpec: WidgetUtils.sizeSpec(widgetData, grid.columns, grid.maximumRows)
    readonly property real cols: slot?.cols ?? 1
    readonly property real rows: slot?.rows ?? 1
    readonly property bool compact: cols <= 2 && rows === 1
    readonly property bool small: WidgetUtils.isSmall(grid.layoutItems[index] ?? widgetData, rows)
    readonly property var tileItem: tileLoader.item
    // Small tiles resize from a virtual half row so growing them passes through full size first.
    property real biasH: 0
    readonly property real smallSpanLimit: (1 + CcMetrics.smallRowFraction) / 2

    passthrough: tileItem?.passthrough ?? null
    restCursor: widgetData.id === WidgetUtils.EDIT_ID ? Qt.PointingHandCursor : Qt.OpenHandCursor
    raised: dragging || resizing || (tileItem?.memberDragging ?? false)

    function reanchor(small) {
        const shift = ((small ? CcMetrics.smallRowFraction : 1) - smallSpanLimit) * grid.cellWidth;
        biasH += shift;
    }

    function spanOf(requested, bias = 0) {
        return (requested + bias + CcMetrics.gridGap) / grid.cellWidth;
    }

    onClicked: {
        if (widgetData.id === WidgetUtils.EDIT_ID)
            root.grid.editRequested();
    }

    onPressAndHold: {
        if (!editChrome.hasOptions)
            return;
        root.grid.configRequested(root.grid.savedIndex(root.index), root.widgetData, editChrome);
    }

    onResizeRequested: (requestedWidth, requestedHeight) => {
        const step = sizeSpec.step;
        const canShrink = WidgetUtils.canShrink(widgetData.id);
        if (canShrink && root.small !== (spanOf(requestedHeight, biasH) < smallSpanLimit))
            reanchor(!root.small);
        const spanW = spanOf(requestedWidth);
        const spanH = spanOf(requestedHeight, biasH);
        let width = GridUtils.dimension(Math.round(spanW / step) * step, sizeSpec.minW, sizeSpec.maxW, sizeSpec.w, step);
        let height = GridUtils.dimension(Math.round(spanH / step) * step, sizeSpec.minH, sizeSpec.maxH, sizeSpec.h, step);
        const current = WidgetUtils.clampSize(widgetData, grid.columns, grid.maximumRows);
        if (WidgetUtils.isSliderWidget(widgetData.id) && width < 2 && height < 2) {
            if (width !== current.w && sizeSpec.maxH > 1)
                height = 2;
            else
                width = Math.min(2, sizeSpec.maxW);
        }
        const changes = {};
        if (width !== current.w)
            changes.w = width;
        if (height !== current.h)
            changes.h = height;
        const small = canShrink && height === 1 && spanH < smallSpanLimit;
        if (small !== (widgetData.small === true))
            changes.small = small;
        grid.previewSize(index, changes);
    }

    CcTileLoader {
        id: tileLoader
        anchors.fill: parent
        grid: root.grid
        widgetData: root.widgetData
        savedIndex: root.grid.savedIndex(root.index)
        columns: root.cols
        rows: root.rows
        compact: root.compact
        small: root.small
    }

    CcEditChrome {
        id: editChrome

        anchors.fill: parent
        anchors.margins: -contentInset
        z: 2
        visible: root.grid.editMode
        enabled: root.interactionEnabled
        widgetData: root.widgetData
        passthrough: root.passthrough
        dragging: root.dragging
        resizing: root.resizing
        cornerRadius: root.small ? Theme.fullRadius(root.width, root.height) : (root.tileItem?.bodyRadius ?? Theme.fullRadius(root.width, root.height))
        sizeText: root.cols + "×" + (root.small ? CcMetrics.smallRowFraction : root.rows)
        onResizeStarted: (px, py) => {
            root.biasH = root.small ? (CcMetrics.smallRowFraction - 1) * root.grid.cellWidth : 0;
            root.beginResize(px, py);
        }
        onResizeMoved: (px, py) => root.resizeTo(px, py)
        onResizeEnded: root.finishResize()
        onResizeCanceled: root.cancelResize()
        onRemoveRequested: root.grid.removeWidget(root.grid.savedIndex(root.index))
        onConfigRequested: anchor => root.grid.configRequested(root.grid.savedIndex(root.index), root.widgetData, anchor)
    }
}
