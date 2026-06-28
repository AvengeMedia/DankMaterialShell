pragma ComponentBehavior: Bound

import QtQuick

HoverHandler {
    id: root

    required property var controller
    property bool trackingEnabled: false

    enabled: trackingEnabled

    onTrackingEnabledChanged: {
        if (!trackingEnabled)
            controller.updateBodyHover(false);
    }

    onHoveredChanged: controller.updateBodyHover(hovered)
    onPointChanged: {
        if (!hovered)
            return;
        const gp = parent.mapToItem(null, point.position.x, point.position.y);
        controller.updateCursor(gp.x, gp.y);
    }
}
