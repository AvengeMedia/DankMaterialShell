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
    property real currentOffsetX: 0
    property real currentOffsetY: 8
    property real currentTopLeftRadius: 21
    property real currentTopRightRadius: 21
    property real currentBottomLeftRadius: 21
    property real currentBottomRightRadius: 21

    property real targetWidth: currentWidth
    property real targetHeight: currentHeight
    property real targetOffsetX: currentOffsetX
    property real targetOffsetY: currentOffsetY
    property real targetTopLeftRadius: currentTopLeftRadius
    property real targetTopRightRadius: currentTopRightRadius
    property real targetBottomLeftRadius: currentBottomLeftRadius
    property real targetBottomRightRadius: currentBottomRightRadius

    property real velocityWidth: 0
    property real velocityHeight: 0
    property real velocityOffsetX: 0
    property real velocityOffsetY: 0
    property real velocityTopLeftRadius: 0
    property real velocityTopRightRadius: 0
    property real velocityBottomLeftRadius: 0
    property real velocityBottomRightRadius: 0

    function matchesTarget(target) {
        return targetWidth === target.width && targetHeight === target.height && targetOffsetX === target.offsetX && targetOffsetY === target.offsetY && targetTopLeftRadius === target.topLeftRadius && targetTopRightRadius === target.topRightRadius && targetBottomLeftRadius === target.bottomLeftRadius && targetBottomRightRadius === target.bottomRightRadius;
    }

    function setTarget(target) {
        if (matchesTarget(target))
            return;
        targetWidth = target.width;
        targetHeight = target.height;
        targetOffsetX = target.offsetX;
        targetOffsetY = target.offsetY;
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
        targetOffsetX = target.offsetX;
        targetOffsetY = target.offsetY;
        targetTopLeftRadius = target.topLeftRadius;
        targetTopRightRadius = target.topRightRadius;
        targetBottomLeftRadius = target.bottomLeftRadius;
        targetBottomRightRadius = target.bottomRightRadius;

        currentWidth = target.width;
        currentHeight = target.height;
        currentOffsetX = target.offsetX;
        currentOffsetY = target.offsetY;
        currentTopLeftRadius = target.topLeftRadius;
        currentTopRightRadius = target.topRightRadius;
        currentBottomLeftRadius = target.bottomLeftRadius;
        currentBottomRightRadius = target.bottomRightRadius;

        velocityWidth = 0;
        velocityHeight = 0;
        velocityOffsetX = 0;
        velocityOffsetY = 0;
        velocityTopLeftRadius = 0;
        velocityTopRightRadius = 0;
        velocityBottomLeftRadius = 0;
        velocityBottomRightRadius = 0;
        running = false;
    }

    function isSettled() {
        const positionSettled = Math.abs(targetWidth - currentWidth) <= positionEpsilon && Math.abs(targetHeight - currentHeight) <= positionEpsilon && Math.abs(targetOffsetX - currentOffsetX) <= positionEpsilon && Math.abs(targetOffsetY - currentOffsetY) <= positionEpsilon && Math.abs(targetTopLeftRadius - currentTopLeftRadius) <= positionEpsilon && Math.abs(targetTopRightRadius - currentTopRightRadius) <= positionEpsilon && Math.abs(targetBottomLeftRadius - currentBottomLeftRadius) <= positionEpsilon && Math.abs(targetBottomRightRadius - currentBottomRightRadius) <= positionEpsilon;
        const velocitySettled = Math.abs(velocityWidth) <= velocityEpsilon && Math.abs(velocityHeight) <= velocityEpsilon && Math.abs(velocityOffsetX) <= velocityEpsilon && Math.abs(velocityOffsetY) <= velocityEpsilon && Math.abs(velocityTopLeftRadius) <= velocityEpsilon && Math.abs(velocityTopRightRadius) <= velocityEpsilon && Math.abs(velocityBottomLeftRadius) <= velocityEpsilon && Math.abs(velocityBottomRightRadius) <= velocityEpsilon;
        return positionSettled && velocitySettled;
    }

    function settle() {
        currentWidth = targetWidth;
        currentHeight = targetHeight;
        currentOffsetX = targetOffsetX;
        currentOffsetY = targetOffsetY;
        currentTopLeftRadius = targetTopLeftRadius;
        currentTopRightRadius = targetTopRightRadius;
        currentBottomLeftRadius = targetBottomLeftRadius;
        currentBottomRightRadius = targetBottomRightRadius;

        velocityWidth = 0;
        velocityHeight = 0;
        velocityOffsetX = 0;
        velocityOffsetY = 0;
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
            velocityOffsetX += (stiffness * (targetOffsetX - currentOffsetX) - damping * velocityOffsetX) * inverseMass * step;
            velocityOffsetY += (stiffness * (targetOffsetY - currentOffsetY) - damping * velocityOffsetY) * inverseMass * step;
            velocityTopLeftRadius += (stiffness * (targetTopLeftRadius - currentTopLeftRadius) - damping * velocityTopLeftRadius) * inverseMass * step;
            velocityTopRightRadius += (stiffness * (targetTopRightRadius - currentTopRightRadius) - damping * velocityTopRightRadius) * inverseMass * step;
            velocityBottomLeftRadius += (stiffness * (targetBottomLeftRadius - currentBottomLeftRadius) - damping * velocityBottomLeftRadius) * inverseMass * step;
            velocityBottomRightRadius += (stiffness * (targetBottomRightRadius - currentBottomRightRadius) - damping * velocityBottomRightRadius) * inverseMass * step;

            currentWidth += velocityWidth * step;
            currentHeight += velocityHeight * step;
            currentOffsetX += velocityOffsetX * step;
            currentOffsetY += velocityOffsetY * step;
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
