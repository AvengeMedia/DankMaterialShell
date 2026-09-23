pragma ComponentBehavior: Bound

import QtQuick

DragHandler {
    id: root

    required property var hostWindow
    required property var surface

    readonly property real maxFlingSpeed: 4000
    readonly property real flingProjection: 0.09
    property real startAnchorX: 0
    property real startAnchorY: 0
    property point startPointer
    property bool tracking: false
    property real velocityX: 0
    property real velocityY: 0

    function pointerPosition() {
        return root.surface.mapToGlobal(root.centroid.position.x, root.centroid.position.y);
    }

    function rememberPress() {
        root.startAnchorX = root.surface.currentVisualX + root.surface.currentVisualWidth / 2;
        root.startAnchorY = root.surface.currentVisualY + root.surface.currentVisualHeight / 2;
        root.startPointer = root.pointerPosition();
        root.velocityX = 0;
        root.velocityY = 0;
        root.tracking = true;
    }

    function beginDrag() {
        if (!root.tracking)
            root.rememberPress();
        root.hostWindow.dragging = true;
        root.hostWindow.wake();
        root.updateDrag();
    }

    function updateDrag() {
        const point = root.pointerPosition();
        root.velocityX = Math.max(-root.maxFlingSpeed, Math.min(root.maxFlingSpeed, root.centroid.velocity.x));
        root.velocityY = Math.max(-root.maxFlingSpeed, Math.min(root.maxFlingSpeed, root.centroid.velocity.y));
        root.hostWindow.anchorX = root.startAnchorX + point.x - root.startPointer.x;
        root.hostWindow.anchorY = root.startAnchorY + point.y - root.startPointer.y;
    }

    function finishDrag() {
        root.hostWindow.dragging = false;
        root.hostWindow.anchorX = root.hostWindow.clampAnchorX(root.hostWindow.anchorX + root.velocityX * root.flingProjection);
        root.hostWindow.anchorY = root.hostWindow.clampAnchorY(root.hostWindow.anchorY + root.velocityY * root.flingProjection);
        root.surface.applyTarget({
            "offsetAlong": root.surface.isVertical ? root.velocityY : root.velocityX,
            "offsetCross": root.surface.isVertical ? root.velocityX : root.velocityY
        });
        root.hostWindow.storeAnchor();
        root.hostWindow.wake();
    }

    parent: root.surface
    target: null
    acceptedButtons: Qt.LeftButton
    cursorShape: active ? Qt.ClosedHandCursor : Qt.ArrowCursor
    onActiveChanged: {
        if (active)
            root.beginDrag();
        else
            root.finishDrag();
    }
    onCentroidChanged: {
        if (!(root.centroid.pressedButtons & Qt.LeftButton)) {
            root.tracking = false;
            return;
        }
        if (!root.tracking)
            root.rememberPress();
        if (active)
            root.updateDrag();
    }
}
