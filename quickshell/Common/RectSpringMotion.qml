pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    property bool enabled: true
    property bool reducedMotion: false
    property bool running: false
    property real stiffness: 220
    property real damping: 23
    property real mass: 1
    property real positionEpsilon: 0.035
    property real velocityEpsilon: 0.035
    property real maximumFrameTime: 1 / 30
    property real integrationStep: 1 / 240

    property rect value: Qt.rect(0, 0, 1, 1)
    property rect target: value
    property vector4d velocity: Qt.vector4d(0, 0, 0, 0)

    readonly property real timeConstantMs: 2000 * mass / Math.max(1, damping)
    property int settleDurationMs: 0

    function snapTo(rect, initialVelocity) {
        target = rect;
        velocity = initialVelocity ?? Qt.vector4d(0, 0, 0, 0);
        value = rect;
        running = false;
    }

    function retarget(rect) {
        if (!enabled || reducedMotion) {
            snapTo(rect);
            return;
        }
        target = rect;
        if (isSettled(value, velocity)) {
            snapTo(rect);
            return;
        }
        const distance = Math.max(Math.abs(target.x - value.x), Math.abs(target.y - value.y), Math.abs(target.width - value.width), Math.abs(target.height - value.height));
        const speed = Math.max(Math.abs(velocity.x), Math.abs(velocity.y), Math.abs(velocity.z), Math.abs(velocity.w));
        const amplitude = distance + speed * timeConstantMs / 1000;
        settleDurationMs = Math.round(Math.max(timeConstantMs * 3, timeConstantMs * Math.log(Math.max(amplitude, positionEpsilon) / positionEpsilon)));
        running = true;
    }

    function isSettled(rect, speed) {
        return Math.abs(target.x - rect.x) <= positionEpsilon && Math.abs(target.y - rect.y) <= positionEpsilon && Math.abs(target.width - rect.width) <= positionEpsilon && Math.abs(target.height - rect.height) <= positionEpsilon && Math.abs(speed.x) <= velocityEpsilon && Math.abs(speed.y) <= velocityEpsilon && Math.abs(speed.z) <= velocityEpsilon && Math.abs(speed.w) <= velocityEpsilon;
    }

    function advance(rawFrameTime) {
        if (!enabled || !running || reducedMotion)
            return;
        const frameTime = Math.min(Math.max(rawFrameTime, 0), maximumFrameTime);
        if (frameTime <= 0)
            return;

        const inverseMass = 1 / Math.max(0.001, mass);
        const stableStep = 1 / Math.max(1, damping * inverseMass, Math.sqrt(stiffness * inverseMass));
        const steps = Math.max(1, Math.ceil(frameTime / Math.min(integrationStep, stableStep)));
        const step = frameTime / steps;
        let x = value.x;
        let y = value.y;
        let w = value.width;
        let h = value.height;
        let vx = velocity.x;
        let vy = velocity.y;
        let vw = velocity.z;
        let vh = velocity.w;

        for (let i = 0; i < steps; i++) {
            vx += (stiffness * (target.x - x) - damping * vx) * inverseMass * step;
            vy += (stiffness * (target.y - y) - damping * vy) * inverseMass * step;
            vw += (stiffness * (target.width - w) - damping * vw) * inverseMass * step;
            vh += (stiffness * (target.height - h) - damping * vh) * inverseMass * step;
            x += vx * step;
            y += vy * step;
            w += vw * step;
            h += vh * step;
        }

        const next = Qt.rect(x, y, Math.max(1, w), Math.max(1, h));
        const speed = Qt.vector4d(vx, vy, w < 1 ? 0 : vw, h < 1 ? 0 : vh);
        if (isSettled(next, speed)) {
            snapTo(target);
            return;
        }
        velocity = speed;
        value = next;
    }

    onReducedMotionChanged: {
        if (reducedMotion)
            snapTo(target);
    }

    onEnabledChanged: {
        if (!enabled)
            snapTo(target);
    }

    property FrameAnimation driver: FrameAnimation {
        running: root.enabled && root.running && !root.reducedMotion
        onTriggered: root.advance(frameTime)
    }
}
