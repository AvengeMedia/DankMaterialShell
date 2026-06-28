pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

Item {
    id: root

    required property bool dismissEnabled
    required property bool dismissSuspended
    required property bool surfaceVisible

    property int graceInterval: 150
    property bool bodyHovered: false
    property real globalOffsetX: 0
    property real globalOffsetY: 0

    signal dismissRequested

    function cancelPending() {
        graceTimer.stop();
        hoverTracker.cancelPending();
    }

    function updateBodyHover(over) {
        bodyHovered = over;
        if (over) {
            graceTimer.stop();
        } else if (dismissEnabled && !dismissSuspended && surfaceVisible) {
            graceTimer.restart();
        }
    }

    function updateCursor(sceneX, sceneY) {
        PopoutManager.updateHoverCursor(sceneX + globalOffsetX, sceneY + globalOffsetY);
    }

    onDismissEnabledChanged: {
        if (!dismissEnabled)
            cancelPending();
    }
    onDismissSuspendedChanged: {
        if (dismissSuspended)
            graceTimer.stop();
        else if (dismissEnabled && surfaceVisible && !bodyHovered)
            graceTimer.restart();
    }
    onSurfaceVisibleChanged: {
        if (!surfaceVisible)
            cancelPending();
    }

    Timer {
        id: graceTimer
        interval: root.graceInterval
        repeat: false
        onTriggered: {
            if (!root.dismissEnabled || root.dismissSuspended || !root.surfaceVisible || root.bodyHovered)
                return;
            if (PopoutManager.cursorOverBar(PopoutManager.hoverCursorGlobalX, PopoutManager.hoverCursorGlobalY))
                return;
            root.dismissRequested();
        }
    }

    HoverDismissTracker {
        id: hoverTracker
        enabled: root.dismissEnabled && !root.dismissSuspended && root.surfaceVisible
        shouldDismiss: function () {
            return !PopoutManager.cursorOverBar(PopoutManager.hoverCursorGlobalX, PopoutManager.hoverCursorGlobalY);
        }
        onDismissRequested: root.dismissRequested()
        onHoverMoved: (gx, gy) => root.updateCursor(gx, gy)
    }
}
