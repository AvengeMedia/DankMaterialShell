import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.ControlCenter
import "../utils/widgets.js" as WidgetUtils
import "../../../Common/GridLayout.js" as GridUtils

DankEditableGridSlot {
    id: root

    readonly property var widgetData: JSON.parse(json)
    readonly property var sizeSpec: WidgetUtils.sizeSpec(widgetData.id || "", grid.columns, grid.maximumRows)
    readonly property real cols: slot?.cols ?? 1
    readonly property real rows: slot?.rows ?? 1
    readonly property bool compact: cols <= 2 && rows === 1
    readonly property var tileItem: tileLoader.item

    onPressAndHold: {
        if (!editChrome.hasOptions)
            return;
        root.grid.configRequested(root.index, root.widgetData, editChrome);
    }

    onResizeRequested: (requestedWidth, requestedHeight) => {
        const step = sizeSpec.step;
        let width = GridUtils.dimension(Math.round((requestedWidth + CcMetrics.gridGap) / grid.cellWidth / step) * step, sizeSpec.minW, sizeSpec.maxW, sizeSpec.w, step);
        let height = GridUtils.dimension(Math.round((requestedHeight + CcMetrics.gridGap) / grid.cellWidth / step) * step, sizeSpec.minH, sizeSpec.maxH, sizeSpec.h, step);
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

    Connections {
        target: root.tileItem
        ignoreUnknownSignals: true

        function onExpandClicked() {
            if (root.grid.editMode)
                return;
            root.grid.expandClicked(root.widgetData);
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
        dragging: root.dragging
        resizing: root.resizing
        cornerRadius: root.tileItem?.bodyRadius ?? Theme.fullRadius(root.width, root.height)
        sizeText: root.cols + "×" + root.rows
        onResizeStarted: (px, py) => root.beginResize(px, py)
        onResizeMoved: (px, py) => root.resizeTo(px, py)
        onResizeEnded: root.finishResize()
        onResizeCanceled: root.cancelResize()
        onRemoveRequested: root.grid.removeWidget(root.index)
        onConfigRequested: anchor => root.grid.configRequested(root.index, root.widgetData, anchor)
    }
}
