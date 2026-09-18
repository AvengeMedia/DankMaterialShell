import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.ControlCenter
import "../utils/layout.js" as LayoutUtils

DankEditableGridSlot {
    id: root

    readonly property var widgetData: JSON.parse(json)
    readonly property bool isSlider: LayoutUtils.isSliderWidget(widgetData.id || "")
    readonly property int previewWidth: resizing ? grid.sizePreview.changes.width : (widgetData.width || 50)
    readonly property bool compact: LayoutUtils.isCompactWidth(previewWidth)
    readonly property var tileItem: tileLoader.item

    onPressAndHold: {
        if (!editChrome.hasOptions)
            return;
        root.grid.configRequested(root.index, root.widgetData, editChrome);
    }

    onResizeRequested: (requestedWidth, requestedHeight) => {
        const width = LayoutUtils.nearestWidgetWidth(widgetData.id, requestedWidth, grid.width, CcMetrics.gridGap);
        grid.previewSize(index, {
            "width": width
        });
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
        cornerRadius: root.isSlider ? Theme.cornerRadiusM : (root.tileItem?.bodyRadius ?? Theme.fullRadius(root.width, root.height))
        onResizeStarted: (px, py) => root.beginResize(px, py)
        onResizeMoved: (px, py) => root.resizeTo(px, py)
        onResizeEnded: root.finishResize()
        onResizeCanceled: root.cancelResize()
        onRemoveRequested: root.grid.removeWidget(root.index)
        onConfigRequested: anchor => root.grid.configRequested(root.index, root.widgetData, anchor)
    }
}
