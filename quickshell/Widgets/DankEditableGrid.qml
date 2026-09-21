import QtQuick
import qs.Common
import "../Common/GridLayout.js" as GridUtils

Item {
    id: root

    property bool editMode: false
    property var sourceItems: []
    property var slotLayout: ({
            "slots": [],
            "totalHeight": 0
        })
    property real minimumHeight: 0
    property real contentPadding: 0
    property real placeholderRadius: Theme.cornerRadiusXL
    property bool animationsEnabled: Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
    property bool animateLayout: false
    property int draggingSourceIndex: -1
    property var dragCell: null
    property var sizePreview: null
    property var pinnedCells: null
    property real heldHeight: 0
    readonly property alias tileModel: tiles
    readonly property bool interacting: draggingSourceIndex >= 0 || sizePreview !== null
    readonly property real layoutHeight: interacting ? Math.max(heldHeight, slotLayout.totalHeight) : slotLayout.totalHeight
    readonly property int interactingIndex: draggingSourceIndex >= 0 ? draggingSourceIndex : (sizePreview?.index ?? -1)
    readonly property var placementOrder: {
        const order = sourceItems.map((item, i) => i);
        if (interactingIndex < 0)
            return order;
        order.splice(interactingIndex, 1);
        order.unshift(interactingIndex);
        return order;
    }
    readonly property var pinnedItems: pinnedCells ? GridUtils.placedItems(sourceItems, pinnedCells) : sourceItems
    readonly property var layoutItems: {
        const changes = sizePreview?.changes ?? dragCell;
        if (interactingIndex < 0 || !changes)
            return pinnedItems;
        return pinnedItems.map((item, i) => i === interactingIndex ? Object.assign({}, item, changes) : item);
    }

    signal layoutCommitted(var items)

    implicitHeight: Math.max(minimumHeight, layoutHeight) + contentPadding * 2
    height: implicitHeight

    function pin() {
        pinnedCells = slotLayout.slots.slice();
        heldHeight = slotLayout.totalHeight;
    }

    function cancelInteraction() {
        draggingSourceIndex = -1;
        dragCell = null;
        sizePreview = null;
        pinnedCells = null;
        heldHeight = 0;
    }

    function committedItems() {
        return GridUtils.placedItems(layoutItems, slotLayout.slots);
    }

    function syncTiles() {
        animateLayout = false;
        cancelInteraction();
        const seen = {};
        const keys = sourceItems.map(item => {
            const base = JSON.stringify([item.id || "", item.instanceId || ""]);
            const count = seen[base] || 0;
            seen[base] = count + 1;
            return base + "#" + count;
        });
        for (let i = tiles.count - 1; i >= 0; i--) {
            if (keys.indexOf(tiles.get(i).key) < 0)
                tiles.remove(i);
        }
        for (let p = 0; p < keys.length; p++) {
            const json = JSON.stringify(sourceItems[p]);
            let current = -1;
            for (let j = p; j < tiles.count; j++) {
                if (tiles.get(j).key !== keys[p])
                    continue;
                current = j;
                break;
            }
            if (current < 0) {
                tiles.insert(p, {
                    "key": keys[p],
                    "json": json
                });
                continue;
            }
            if (current !== p)
                tiles.move(current, p, 1);
            if (tiles.get(p).json !== json)
                tiles.setProperty(p, "json", json);
        }
    }

    function beginDrag(sourceIndex) {
        if (!editMode || interacting || !sourceItems[sourceIndex])
            return;
        pin();
        draggingSourceIndex = sourceIndex;
    }

    function updateDragTarget(x, y) {
        const slot = draggingSourceIndex >= 0 ? slotLayout.slots[draggingSourceIndex] : null;
        if (!slot)
            return;
        const cell = GridUtils.cellAt(slotLayout, x - contentPadding, y - contentPadding, slot.cols, slot.rows);
        if (dragCell && dragCell.col === cell.col && dragCell.row === cell.row)
            return;
        dragCell = cell;
    }

    function endDrag() {
        if (draggingSourceIndex < 0)
            return;
        const items = committedItems();
        const moved = pinnedCells.some((cell, i) => cell && (cell.col !== items[i].col || cell.row !== items[i].row));
        cancelInteraction();
        if (moved)
            layoutCommitted(items);
    }

    function previewSize(index, changes) {
        if (!editMode || draggingSourceIndex >= 0 || !sourceItems[index])
            return;
        if (sizePreview?.index === index && JSON.stringify(sizePreview.changes) === JSON.stringify(changes))
            return;
        if (!pinnedCells)
            pin();
        sizePreview = {
            "index": index,
            "changes": changes
        };
    }

    function commitSize() {
        const preview = sizePreview;
        if (!preview)
            return;
        const item = sourceItems[preview.index];
        const changed = item && Object.keys(preview.changes).some(key => item[key] !== preview.changes[key]);
        const items = committedItems();
        if (changed)
            layoutCommitted(items);
        cancelInteraction();
    }

    function commitChange(index, changes) {
        previewSize(index, changes);
        commitSize();
    }

    onSourceItemsChanged: syncTiles()
    onSlotLayoutChanged: {
        if (interacting)
            heldHeight = Math.max(heldHeight, slotLayout.totalHeight);
    }
    Component.onCompleted: syncTiles()
    onEditModeChanged: {
        if (!editMode)
            cancelInteraction();
    }

    Timer {
        interval: 0
        running: root.width > 0 && !root.animateLayout
        onTriggered: root.animateLayout = true
    }

    ListModel {
        id: tiles
    }

    Rectangle {
        readonly property var slot: root.draggingSourceIndex >= 0 ? (root.slotLayout.slots[root.draggingSourceIndex] ?? null) : null

        visible: slot !== null
        x: slot ? slot.x + root.contentPadding : 0
        y: slot ? slot.y + root.contentPadding : 0
        width: slot ? slot.w : 0
        height: slot ? slot.h : 0
        radius: root.placeholderRadius
        color: Theme.withAlpha(Theme.primary, Theme.stateLayerDrag)

        Behavior on x {
            enabled: root.animationsEnabled
            NumberAnimation {
                duration: Theme.expressiveDurations.expressiveFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
            }
        }

        Behavior on y {
            enabled: root.animationsEnabled
            NumberAnimation {
                duration: Theme.expressiveDurations.expressiveFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
            }
        }
    }
}
