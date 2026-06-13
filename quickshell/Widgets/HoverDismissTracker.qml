pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property bool enabled: false
    property var shouldDismiss: null

    signal dismissRequested

    anchors.fill: parent

    HoverHandler {
        id: hoverHandler
        enabled: root.enabled
        onHoveredChanged: {
            if (hoverHandler.hovered || !root.enabled)
                return;
            if (typeof root.shouldDismiss === "function" && !root.shouldDismiss())
                return;
            root.dismissRequested();
        }
    }

    function cancelPending() {}
}
