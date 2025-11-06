import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property bool editMode: false
    property var widgetData: null
    property int widgetIndex: -1
    property bool isSlider: false
    property Component widgetComponent: null
    property real gridCellWidth: 100
    property real gridCellHeight: 60
    property int gridColumns: 4
    property var gridLayout: null

    z: dragArea.drag.active ? 10000 : 1

    signal widgetMoved(int fromIndex, int toIndex)
    signal removeWidget(int index)
    signal toggleWidgetSize(int index)

    width: {
        const widgetWidth = widgetData?.width || 50
        if (widgetWidth <= 25) return gridCellWidth
        else if (widgetWidth <= 50) return gridCellWidth * 2
        else if (widgetWidth <= 75) return gridCellWidth * 3
        else return gridCellWidth * 4
    }
    height: isSlider ? 16 : gridCellHeight

    Rectangle {
        id: dragIndicator
        anchors.fill: parent
        color: "transparent"
        border.color: Theme.primary
        border.width: dragArea.drag.active ? 2 : 0
        radius: Theme.cornerRadius
        opacity: dragArea.drag.active ? 0.8 : 1.0
        z: dragArea.drag.active ? 10000 : 1

        Behavior on border.width {
            NumberAnimation { duration: 150 }
        }
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
    }

    Loader {
        id: widgetLoader
        anchors.fill: parent
        sourceComponent: widgetComponent
        property var widgetData: root.widgetData
        property int widgetIndex: root.widgetIndex
        property int globalWidgetIndex: root.widgetIndex
        property int widgetWidth: root.widgetData?.width || 50


        MouseArea {
            id: editModeBlocker
            anchors.fill: parent
            enabled: root.editMode
            acceptedButtons: Qt.AllButtons
            onPressed: function(mouse) { mouse.accepted = true }
            onWheel: function(wheel) { wheel.accepted = true }
            z: 100
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: editMode
        cursorShape: editMode ? Qt.OpenHandCursor : Qt.PointingHandCursor
        drag.target: editMode ? root : null
        drag.axis: Drag.XAndYAxis
        drag.smoothed: true

        onPressed: function(mouse) {
            if (editMode) {
                cursorShape = Qt.ClosedHandCursor
                if (root.gridLayout && root.gridLayout.moveToTop) {
                    root.gridLayout.moveToTop(root)
                }
            }
        }

        onReleased: function(mouse) {
            if (editMode) {
                cursorShape = Qt.OpenHandCursor
                root.snapToGrid()
            }
        }
    }

    Drag.active: dragArea.drag.active
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2

    function swapIndices(i, j) {
        if (i === j) return;
        const arr = SettingsData.controlCenterWidgets;
        if (!arr || i < 0 || j < 0 || i >= arr.length || j >= arr.length) return;

        const copy = arr.slice();
        const tmp = copy[i];
        copy[i] = copy[j];
        copy[j] = tmp;

        SettingsData.set("controlCenterWidgets", copy);
    }

    function snapToGrid() {
        if (!editMode || !gridLayout) return

        const globalPos = root.mapToItem(gridLayout, 0, 0)
        const cellWidth = gridLayout.width / gridColumns
        const cellHeight = gridCellHeight + Theme.spacingS

        const centerX = globalPos.x + (root.width / 2)
        const centerY = globalPos.y + (root.height / 2)

        let targetCol = Math.max(0, Math.floor(centerX / cellWidth))
        let targetRow = Math.max(0, Math.floor(centerY / cellHeight))

        targetCol = Math.min(targetCol, gridColumns - 1)

        const newIndex = findBestInsertionIndex(targetRow, targetCol)

        if (newIndex !== widgetIndex && newIndex >= 0 && newIndex < (SettingsData.controlCenterWidgets?.length || 0)) {
            swapIndices(widgetIndex, newIndex)
        }
    }

    function findBestInsertionIndex(targetRow, targetCol) {
        const widgets = SettingsData.controlCenterWidgets || [];
        const n = widgets.length;
        if (!n || widgetIndex < 0 || widgetIndex >= n) return -1;

        function spanFor(width) {
            const w = width ?? 50;
            if (w <= 25) return 1;
            if (w <= 50) return 2;
            if (w <= 75) return 3;
            return 4;
        }

        const cols = gridColumns || 4;

        let row = 0, col = 0;
        let draggedOrigKey = null;

        const pos = [];

        for (let i = 0; i < n; i++) {
            const span = Math.min(spanFor(widgets[i].width), cols);

            if (col + span > cols) {
                row++;
                col = 0;
            }

            const startCol = col;
            const centerKey = row * cols + (startCol + (span - 1) / 2);

            if (i === widgetIndex) {
                draggedOrigKey = centerKey;
            } else {
                pos.push({ index: i, row, startCol, span, centerKey });
            }

            col += span;
            if (col >= cols) {
                row++;
                col = 0;
            }
        }

        if (pos.length === 0) return -1;

        const centerColCoord = targetCol + 0.5;
        const targetKey = targetRow * cols + centerColCoord;

        for (let k = 0; k < pos.length; k++) {
            const p = pos[k];
            if (p.row === targetRow && centerColCoord >= p.startCol && centerColCoord < (p.startCol + p.span)) {
                return p.index;
            }
        }

        let lo = 0, hi = pos.length - 1;
        if (targetKey <= pos[0].centerKey) return pos[0].index;
        if (targetKey >= pos[hi].centerKey) return pos[hi].index;

        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            const mk = pos[mid].centerKey;
            if (targetKey < mk) hi = mid - 1;
            else if (targetKey > mk) lo = mid + 1;
            else return pos[mid].index;
        }
        const movingUp = (draggedOrigKey != null) ? (targetKey < draggedOrigKey) : false;
        return (movingUp ? pos[lo].index : pos[hi].index);
    }

    Rectangle {
        width: 16
        height: 16
        radius: 8
        color: Theme.error
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: -4
        visible: editMode
        z: 10

        DankIcon {
            anchors.centerIn: parent
            name: "close"
            size: 12
            color: Theme.primaryText
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: removeWidget(widgetIndex)
        }
    }

    SizeControls {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: -6
        visible: editMode
        z: 10
        currentSize: root.widgetData?.width || 50
        isSlider: root.isSlider
        widgetIndex: root.widgetIndex
        onSizeChanged: (newSize) => {
            var widgets = SettingsData.controlCenterWidgets.slice()
            if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                widgets[widgetIndex].width = newSize
                SettingsData.set("controlCenterWidgets", widgets)
            }
        }
    }

    Rectangle {
        id: dragHandle
        width: 16
        height: 12
        radius: 2
        color: Theme.primary
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 4
        visible: editMode
        z: 15
        opacity: dragArea.drag.active ? 1.0 : 0.7

        DankIcon {
            anchors.centerIn: parent
            name: "drag_indicator"
            size: 10
            color: Theme.primaryText
        }

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: editMode ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
        radius: Theme.cornerRadius
        border.color: "transparent"
        border.width: 0
        z: -1

        Behavior on color {
            ColorAnimation { duration: Theme.shortDuration }
        }
    }
}