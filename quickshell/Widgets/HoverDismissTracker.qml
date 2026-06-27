pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property bool enabled: false
    property var shouldDismiss: null

    signal dismissRequested
    // Emitted on every hover move; passive to avoid blocking overlapping MouseAreas
    signal hoverMoved(real gx, real gy)

    anchors.fill: parent

    HoverHandler {
        id: hoverHandler
        enabled: root.enabled
        onPointChanged: {
            if (!root.enabled || !hoverHandler.hovered)
                return;
            const gp = root.mapToItem(null, hoverHandler.point.position.x, hoverHandler.point.position.y);
            root.hoverMoved(gp.x, gp.y);
        }
        onHoveredChanged: {
            if (hoverHandler.hovered || !root.enabled)
                return;
            if (typeof root.shouldDismiss === "function" && !root.shouldDismiss())
                return;
            root.dismissRequested();
        }
    }

    function cancelPending() {
    }
}
