import QtQuick
import qs.Common

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
    property var visualOrder: []
    property int draggingSourceIndex: -1
    property var dragStartOrder: []
    property var sizePreview: null
    readonly property alias tileModel: tiles
    readonly property bool interacting: draggingSourceIndex >= 0 || sizePreview !== null
    readonly property var layoutItems: sizePreview ? sourceItems.map((item, i) => i === sizePreview.index ? Object.assign({}, item, sizePreview.changes) : item) : sourceItems

    signal reorderCommitted(var items)
    signal resizeCommitted(int index, var changes)

    implicitHeight: Math.max(minimumHeight, slotLayout.totalHeight) + contentPadding * 2
    height: implicitHeight

    function resetOrder() {
        visualOrder = sourceItems.map((item, i) => i);
    }

    function cancelInteraction() {
        draggingSourceIndex = -1;
        sizePreview = null;
        resetOrder();
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
        dragStartOrder = visualOrder.slice();
        draggingSourceIndex = sourceIndex;
    }

    function updateDragTarget(px, py) {
        if (draggingSourceIndex < 0)
            return;
        px -= contentPadding;
        py -= contentPadding;
        const position = visualOrder.findIndex(i => {
            const slot = slotLayout.slots[i];
            return slot && px >= slot.x && px < slot.x + slot.w && py >= slot.y && py < slot.y + slot.h;
        });
        const current = visualOrder.indexOf(draggingSourceIndex);
        if (position < 0 || current < 0 || current === position)
            return;
        const order = visualOrder.slice();
        order.splice(current, 1);
        order.splice(position, 0, draggingSourceIndex);
        visualOrder = order;
    }

    function endDrag() {
        if (draggingSourceIndex < 0)
            return;
        draggingSourceIndex = -1;
        if (visualOrder.every((value, i) => value === dragStartOrder[i]))
            return;
        reorderCommitted(visualOrder.map(i => sourceItems[i]));
    }

    function previewSize(index, changes) {
        if (!editMode || draggingSourceIndex >= 0 || !sourceItems[index])
            return;
        if (sizePreview?.index === index && JSON.stringify(sizePreview.changes) === JSON.stringify(changes))
            return;
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
        if (item && Object.keys(preview.changes).some(key => item[key] !== preview.changes[key]))
            resizeCommitted(preview.index, preview.changes);
        sizePreview = null;
    }

    onSourceItemsChanged: syncTiles()
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
