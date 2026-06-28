pragma ComponentBehavior: Bound

import QtQuick

HoverHandler {
    id: root

    property var shouldDismiss: null

    signal dismissRequested
    // Emitted on every hover move; passive to avoid blocking overlapping MouseAreas
    signal hoverMoved(real gx, real gy)

    onPointChanged: {
        if (!enabled || !hovered)
            return;
        const gp = parent.mapToItem(null, point.position.x, point.position.y);
        hoverMoved(gp.x, gp.y);
    }
    onHoveredChanged: {
        if (hovered || !enabled)
            return;
        if (typeof shouldDismiss === "function" && !shouldDismiss())
            return;
        dismissRequested();
    }

    function cancelPending() {
    }
}
