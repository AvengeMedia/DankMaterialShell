import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.ControlCenter
import "../utils/widgets.js" as WidgetUtils
import "../../../Common/GridLayout.js" as GridUtils

DankEditableGridSlot {
    id: root

    readonly property var widgetData: JSON.parse(json)
    readonly property var sizeSpec: WidgetUtils.sizeSpec(widgetData, grid.columns, grid.maximumRows)
    readonly property real cols: slot?.cols ?? 1
    readonly property real rows: slot?.rows ?? 1
    readonly property bool compact: cols <= 2 && rows === 1
    readonly property bool small: WidgetUtils.isSmall(grid.layoutItems[index] ?? widgetData, rows)
    readonly property var tileItem: tileLoader.item
    // Small tiles resize from a virtual half cell so growing them passes through full size first.
    property real biasW: 0
    property real biasH: 0
    readonly property real smallSpanLimit: (1 + CcMetrics.smallRowFraction) / 2

    passthrough: tileItem?.passthrough ?? null

    function reanchor(small) {
        const shift = ((small ? CcMetrics.smallRowFraction : 1) - smallSpanLimit) * grid.cellWidth;
        biasH += shift;
        if (cols === 1)
            biasW += shift;
    }

    function spanOf(requested, bias) {
        return (requested + bias + CcMetrics.gridGap) / grid.cellWidth;
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
        const spanW = spanOf(requestedWidth, biasW);
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

    Loader {
        id: tileLoader
        anchors.fill: parent
        sourceComponent: root.grid.model ? root.grid.model.componentForWidget(root.widgetData) : null
    }

    Binding {
        target: root.tileItem
        property: "widgetData"
        value: root.widgetData
        when: root.tileItem !== null
    }

    Binding {
        target: root.tileItem
        property: "widgetDef"
        value: root.grid.model?.getWidgetForId(root.widgetData.id || "") ?? null
        when: root.tileItem !== null
    }

    Binding {
        target: root.tileItem
        property: "host"
        value: root.grid
        when: root.tileItem !== null
    }

    Binding {
        target: root.tileItem
        property: "live"
        value: root.grid.live
        when: root.tileItem !== null
    }

    Binding {
        target: root.tileItem
        property: "interactive"
        value: !root.grid.editMode
        when: root.tileItem !== null
    }

    Binding {
        target: root.tileItem
        property: "columns"
        value: root.cols
        when: root.tileItem !== null
    }

    Binding {
        target: root.tileItem
        property: "rows"
        value: root.rows
        when: root.tileItem !== null
    }

    Binding {
        target: root.tileItem
        property: "compact"
        value: root.compact
        when: root.tileItem !== null
    }

    Binding {
        target: root.tileItem
        property: "small"
        value: root.small
        when: root.tileItem !== null && "small" in root.tileItem
    }

    Connections {
        target: root.tileItem
        ignoreUnknownSignals: true

        function onExpandClicked() {
            if (root.grid.editMode)
                return;
            root.grid.expandClicked(root.widgetData);
        }

        function onOptionChanged(key, value) {
            root.grid.model?.setOption(root.grid.savedIndex(root.index), key, value);
        }
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
        sizeText: (root.small && root.cols === 1 ? CcMetrics.smallRowFraction : root.cols) + "×" + (root.small ? CcMetrics.smallRowFraction : root.rows)
        onResizeStarted: (px, py) => {
            root.biasH = root.small ? (CcMetrics.smallRowFraction - 1) * root.grid.cellWidth : 0;
            root.biasW = root.small && root.cols === 1 ? root.biasH : 0;
            root.beginResize(px, py);
        }
        onResizeMoved: (px, py) => root.resizeTo(px, py)
        onResizeEnded: root.finishResize()
        onResizeCanceled: root.cancelResize()
        onRemoveRequested: root.grid.removeWidget(root.grid.savedIndex(root.index))
        onConfigRequested: anchor => root.grid.configRequested(root.grid.savedIndex(root.index), root.widgetData, anchor)
    }
}
