pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

QtObject {
    id: root

    property bool enabled: true
    property bool reducedMotion: false
    readonly property bool systemReducedMotion: typeof SettingsData !== "undefined" && SettingsData.reduceMotion === true
    readonly property bool effectiveReducedMotion: reducedMotion || systemReducedMotion

    property real stiffness: 100
    property real damping: 16
    property real mass: 1
    property real positionEpsilon: 0.01
    property real velocityEpsilon: 0.01
    property real maximumFrameTime: 1 / 30
    property real integrationStep: 1 / 240

    property real value: 0
    property real target: value
    property real velocity: 0

    property bool _running: false
    readonly property bool running: _running
    readonly property bool settled: !_running
    readonly property real timeConstantMs: effectiveReducedMotion ? 0 : 2000 * mass / Math.max(1, damping)
    property int settleDurationMs: 0

    function isSettled() {
        return Math.abs(target - value) <= positionEpsilon && Math.abs(velocity) <= velocityEpsilon;
    }

    function snapTo(v) {
        target = v;
        value = v;
        velocity = 0;
        _running = false;
    }

    function retarget(v) {
        if (!enabled || effectiveReducedMotion) {
            snapTo(v);
            return;
        }
        if (target === v && !_running)
            return;
        target = v;
        const tau = timeConstantMs;
        const distance = Math.abs(target - value);
        settleDurationMs = tau > 0 ? Math.round(Math.max(tau * 3, tau * Math.log(Math.max(distance, positionEpsilon) / positionEpsilon))) : 0;
        if (!isSettled())
            _running = true;
    }

    function advance(rawFrameTime) {
        if (!enabled || !_running || effectiveReducedMotion)
            return;

        const frameTime = Math.min(Math.max(rawFrameTime, 0), maximumFrameTime);
        if (frameTime <= 0)
            return;

        const steps = Math.max(1, Math.ceil(frameTime / integrationStep));
        const step = frameTime / steps;
        const inverseMass = 1 / Math.max(0.001, mass);

        for (let i = 0; i < steps; i++) {
            velocity += (stiffness * (target - value) - damping * velocity) * inverseMass * step;
            value += velocity * step;
        }

        if (isSettled()) {
            value = target;
            velocity = 0;
            _running = false;
        }
    }

    onEffectiveReducedMotionChanged: {
        if (effectiveReducedMotion)
            snapTo(target);
    }

    onEnabledChanged: {
        if (!enabled) {
            snapTo(target);
            return;
        }
        retarget(target);
    }

    property FrameAnimation driver: FrameAnimation {
        running: root.enabled && root._running && !root.effectiveReducedMotion
        onTriggered: root.advance(frameTime)
    }
}
