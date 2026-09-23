import QtQuick
import QtTest
import "../Modules/DankIsland"

Item {
    width: 800
    height: 600

    QtObject {
        id: host
        property real anchorX: 300
        property real anchorY: 250
        property real hitPadding: 0
        property bool dragging: false
        function wake() {}
        function storeAnchor() {}
        function clampAnchorX(x) { return x; }
        function clampAnchorY(y) { return y; }
    }

    Item {
        id: surface
        anchors.fill: parent
        property real initialOffset: 80
        property bool isVertical: false
        property real currentVisualX: host.anchorX - 50 + initialOffset
        property real currentVisualY: host.anchorY - 25
        property real currentVisualWidth: 100
        property real currentVisualHeight: 50
        property var seed: null
        function applyTarget(velocity) { seed = velocity; }
    }

    MouseArea {
        id: slot
        parent: surface
        x: surface.currentVisualX
        y: surface.currentVisualY
        width: surface.currentVisualWidth
        height: surface.currentVisualHeight
        property int clicks: 0
        onClicked: clicks++
    }

    IslandFreeDragArea {
        id: drag
        hostWindow: host
        surface: surface
    }

    TestCase {
        name: "IslandFreeDrag"
        when: windowShown

        function init() {
            host.anchorX = 300;
            host.anchorY = 250;
            host.dragging = false;
            surface.initialOffset = 0;
            slot.clicks = 0;
        }

        function test_compact_slot_click() {
            mouseClick(slot, 50, 25);
            compare(slot.clicks, 1);
        }

        function test_first_drag_starts_from_visible_face() {
            surface.initialOffset = 80;
            mousePress(slot, 50, 25);
            mouseMove(slot, 75, 25);
            verify(host.dragging);
            compare(host.anchorX, 405, "drag must preserve the grab offset from the visible centre");
            surface.initialOffset = 0;
            mouseRelease(slot, 50, 25);
            compare(slot.clicks, 0);
        }

        function test_fling_axes_data() {
            return [{ tag: "horizontal", vertical: false }, { tag: "vertical", vertical: true }];
        }

        function test_fling_axes(data) {
            surface.isVertical = data.vertical;
            drag.velocityX = 300;
            drag.velocityY = -100;
            drag.finishDrag();
            compare(surface.seed.offsetAlong, data.vertical ? -100 : 300);
            compare(surface.seed.offsetCross, data.vertical ? 300 : -100);
            compare(host.anchorX, 327);
            compare(host.anchorY, 241);
        }
    }
}
