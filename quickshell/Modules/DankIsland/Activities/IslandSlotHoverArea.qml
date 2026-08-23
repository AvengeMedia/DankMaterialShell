pragma ComponentBehavior: Bound

import QtQuick

MouseArea {
    id: root

    required property var controller
    property bool hoverCounted: false

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onEntered: {
        hoverCounted = true;
        controller.slotHoverEntered();
    }
    onExited: {
        if (!hoverCounted)
            return;
        hoverCounted = false;
        controller.slotHoverExited();
    }
    Component.onDestruction: {
        if (hoverCounted)
            controller.slotHoverExited();
    }
}
