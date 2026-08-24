pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services

MouseArea {
    id: root

    property bool scrollEnabled: true
    property string xBehavior: "column"
    property string yBehavior: "workspace"
    property string screenName: ""
    property real touchpadAccumulatorX: 0
    property real touchpadAccumulatorY: 0
    property real mouseAccumulatorX: 0
    property real mouseAccumulatorY: 0
    property bool actionInProgress: false

    signal workspaceSwitchRequested(int direction)

    acceptedButtons: Qt.NoButton

    Timer {
        id: cooldownTimer
        interval: 100
        onTriggered: root.actionInProgress = false
    }

    function handleScrollAction(behavior, direction) {
        switch (behavior) {
        case "workspace":
            workspaceSwitchRequested(direction);
            return true;
        case "column":
            if (!CompositorService.isNiri)
                return false;
            if (direction > 0)
                NiriService.moveColumnRight(screenName);
            else
                NiriService.moveColumnLeft(screenName);
            return true;
        default:
            return false;
        }
    }

    function fire(accumulated, behavior) {
        const reverse = SettingsData.reverseScrolling ? -1 : 1;
        const direction = accumulated * reverse < 0 ? 1 : -1;
        if (!handleScrollAction(behavior, direction))
            return;
        actionInProgress = true;
        cooldownTimer.restart();
    }

    function accumulateX(isTouchpad, delta, behavior) {
        if (isTouchpad) {
            touchpadAccumulatorX += delta;
            if (Math.abs(touchpadAccumulatorX) < 500)
                return;
            fire(touchpadAccumulatorX, behavior);
            touchpadAccumulatorX = 0;
            return;
        }
        mouseAccumulatorX += delta;
        if (Math.abs(mouseAccumulatorX) < 120)
            return;
        fire(mouseAccumulatorX, behavior);
        mouseAccumulatorX = 0;
    }

    function accumulateY(isTouchpad, delta, behavior) {
        if (isTouchpad) {
            touchpadAccumulatorY += delta;
            if (Math.abs(touchpadAccumulatorY) < 500)
                return;
            fire(touchpadAccumulatorY, behavior);
            touchpadAccumulatorY = 0;
            return;
        }
        mouseAccumulatorY += delta;
        if (Math.abs(mouseAccumulatorY) < 120)
            return;
        fire(mouseAccumulatorY, behavior);
        mouseAccumulatorY = 0;
    }

    function processWheel(wheel) {
        wheel.accepted = false;
        if (!scrollEnabled || actionInProgress)
            return;

        const deltaY = wheel.angleDelta.y;
        const deltaX = wheel.angleDelta.x;
        const isTouchpadY = wheel.pixelDelta && wheel.pixelDelta.y !== 0;
        const isTouchpadX = wheel.pixelDelta && wheel.pixelDelta.x !== 0;

        if (CompositorService.isNiri && xBehavior !== "none" && Math.abs(deltaX) > Math.abs(deltaY)) {
            accumulateX(isTouchpadX, deltaX, xBehavior);
            return;
        }
        if (yBehavior === "none")
            return;
        accumulateY(isTouchpadY, deltaY, yBehavior);
    }

    onWheel: wheel => processWheel(wheel)
}
