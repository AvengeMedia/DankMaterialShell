pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    property bool enabled: true
    property bool running: false
    property bool reducedMotion: false

    property real stiffness: 560
    property real damping: 37
    property real mass: 1
    property real positionEpsilon: 0.035
    property real velocityEpsilon: 0.035
    property real maximumFrameTime: 1 / 30
    property real integrationStep: 1 / 240
    readonly property real timeConstantMs: reducedMotion ? 0 : 2000 * mass / Math.max(1, damping)

    property real currentWidth: 176
    property real currentHeight: 42
    property real currentOffsetAlong: 0
    property real currentOffsetCross: 8
    property real currentTopLeftRadius: 21
    property real currentTopRightRadius: 21
    property real currentBottomLeftRadius: 21
    property real currentBottomRightRadius: 21

    property real targetWidth: currentWidth
    property real targetHeight: currentHeight
    property real targetOffsetAlong: currentOffsetAlong
    property real targetOffsetCross: currentOffsetCross
    property real targetTopLeftRadius: currentTopLeftRadius
    property real targetTopRightRadius: currentTopRightRadius
    property real targetBottomLeftRadius: currentBottomLeftRadius
    property real targetBottomRightRadius: currentBottomRightRadius

    property real velocityWidth: 0
    property real velocityHeight: 0
    property real velocityOffsetAlong: 0
    property real velocityOffsetCross: 0
    property real velocityTopLeftRadius: 0
    property real velocityTopRightRadius: 0
    property real velocityBottomLeftRadius: 0
    property real velocityBottomRightRadius: 0

    function matchesTarget(target) {
        return targetWidth === target.width && targetHeight === target.height && targetOffsetAlong === target.offsetAlong && targetOffsetCross === target.offsetCross && targetTopLeftRadius === target.topLeftRadius && targetTopRightRadius === target.topRightRadius && targetBottomLeftRadius === target.bottomLeftRadius && targetBottomRightRadius === target.bottomRightRadius;
    }

    function setTarget(target) {
        if (matchesTarget(target))
            return;
        targetWidth = target.width;
        targetHeight = target.height;
        targetOffsetAlong = target.offsetAlong;
        targetOffsetCross = target.offsetCross;
        targetTopLeftRadius = target.topLeftRadius;
        targetTopRightRadius = target.topRightRadius;
        targetBottomLeftRadius = target.bottomLeftRadius;
        targetBottomRightRadius = target.bottomRightRadius;

        if (reducedMotion) {
            settle();
            return;
        }

        if (!isSettled())
            running = true;
    }

    function snapTo(target) {
        targetWidth = target.width;
        targetHeight = target.height;
        targetOffsetAlong = target.offsetAlong;
        targetOffsetCross = target.offsetCross;
        targetTopLeftRadius = target.topLeftRadius;
        targetTopRightRadius = target.topRightRadius;
        targetBottomLeftRadius = target.bottomLeftRadius;
        targetBottomRightRadius = target.bottomRightRadius;

        currentWidth = target.width;
        currentHeight = target.height;
        currentOffsetAlong = target.offsetAlong;
        currentOffsetCross = target.offsetCross;
        currentTopLeftRadius = target.topLeftRadius;
        currentTopRightRadius = target.topRightRadius;
        currentBottomLeftRadius = target.bottomLeftRadius;
        currentBottomRightRadius = target.bottomRightRadius;

        velocityWidth = 0;
        velocityHeight = 0;
        velocityOffsetAlong = 0;
        velocityOffsetCross = 0;
        velocityTopLeftRadius = 0;
        velocityTopRightRadius = 0;
        velocityBottomLeftRadius = 0;
        velocityBottomRightRadius = 0;
        running = false;
    }

    function isSettled() {
        const positionSettled = Math.abs(targetWidth - currentWidth) <= positionEpsilon && Math.abs(targetHeight - currentHeight) <= positionEpsilon && Math.abs(targetOffsetAlong - currentOffsetAlong) <= positionEpsilon && Math.abs(targetOffsetCross - currentOffsetCross) <= positionEpsilon && Math.abs(targetTopLeftRadius - currentTopLeftRadius) <= positionEpsilon && Math.abs(targetTopRightRadius - currentTopRightRadius) <= positionEpsilon && Math.abs(targetBottomLeftRadius - currentBottomLeftRadius) <= positionEpsilon && Math.abs(targetBottomRightRadius - currentBottomRightRadius) <= positionEpsilon;
        const velocitySettled = Math.abs(velocityWidth) <= velocityEpsilon && Math.abs(velocityHeight) <= velocityEpsilon && Math.abs(velocityOffsetAlong) <= velocityEpsilon && Math.abs(velocityOffsetCross) <= velocityEpsilon && Math.abs(velocityTopLeftRadius) <= velocityEpsilon && Math.abs(velocityTopRightRadius) <= velocityEpsilon && Math.abs(velocityBottomLeftRadius) <= velocityEpsilon && Math.abs(velocityBottomRightRadius) <= velocityEpsilon;
        return positionSettled && velocitySettled;
    }

    function settle() {
        currentWidth = targetWidth;
        currentHeight = targetHeight;
        currentOffsetAlong = targetOffsetAlong;
        currentOffsetCross = targetOffsetCross;
        currentTopLeftRadius = targetTopLeftRadius;
        currentTopRightRadius = targetTopRightRadius;
        currentBottomLeftRadius = targetBottomLeftRadius;
        currentBottomRightRadius = targetBottomRightRadius;

        velocityWidth = 0;
        velocityHeight = 0;
        velocityOffsetAlong = 0;
        velocityOffsetCross = 0;
        velocityTopLeftRadius = 0;
        velocityTopRightRadius = 0;
        velocityBottomLeftRadius = 0;
        velocityBottomRightRadius = 0;
        running = false;
    }

    function advance(rawFrameTime) {
        if (!enabled || !running || reducedMotion)
            return;

        const frameTime = Math.min(Math.max(rawFrameTime, 0), maximumFrameTime);
        if (frameTime <= 0)
            return;

        const steps = Math.max(1, Math.ceil(frameTime / integrationStep));
        const step = frameTime / steps;
        const inverseMass = 1 / Math.max(0.001, mass);

        for (let i = 0; i < steps; i++) {
            velocityWidth += (stiffness * (targetWidth - currentWidth) - damping * velocityWidth) * inverseMass * step;
            velocityHeight += (stiffness * (targetHeight - currentHeight) - damping * velocityHeight) * inverseMass * step;
            velocityOffsetAlong += (stiffness * (targetOffsetAlong - currentOffsetAlong) - damping * velocityOffsetAlong) * inverseMass * step;
            velocityOffsetCross += (stiffness * (targetOffsetCross - currentOffsetCross) - damping * velocityOffsetCross) * inverseMass * step;
            velocityTopLeftRadius += (stiffness * (targetTopLeftRadius - currentTopLeftRadius) - damping * velocityTopLeftRadius) * inverseMass * step;
            velocityTopRightRadius += (stiffness * (targetTopRightRadius - currentTopRightRadius) - damping * velocityTopRightRadius) * inverseMass * step;
            velocityBottomLeftRadius += (stiffness * (targetBottomLeftRadius - currentBottomLeftRadius) - damping * velocityBottomLeftRadius) * inverseMass * step;
            velocityBottomRightRadius += (stiffness * (targetBottomRightRadius - currentBottomRightRadius) - damping * velocityBottomRightRadius) * inverseMass * step;

            currentWidth += velocityWidth * step;
            currentHeight += velocityHeight * step;
            currentOffsetAlong += velocityOffsetAlong * step;
            currentOffsetCross += velocityOffsetCross * step;
            currentTopLeftRadius += velocityTopLeftRadius * step;
            currentTopRightRadius += velocityTopRightRadius * step;
            currentBottomLeftRadius += velocityBottomLeftRadius * step;
            currentBottomRightRadius += velocityBottomRightRadius * step;
        }

        if (isSettled())
            settle();
    }

    onReducedMotionChanged: {
        if (reducedMotion)
            settle();
    }

    property FrameAnimation frameAnimation: FrameAnimation {
        running: root.enabled && root.running && !root.reducedMotion
        onTriggered: root.advance(frameTime)
    }
}
