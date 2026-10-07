.pragma library

// Qt Wayland sends scroll phases only for the finger axis source; pixelDelta also comes with wheels from Qt 6.12 (qtbase d19bd66b4)
const Kind = Object.freeze({
    none: "none",
    touchpad: "touchpad",
    wheel: "wheel",
    highResWheel: "highResWheel"
});

function isTouchpad(wheel) {
    if (wheel.phase === Qt.NoScrollPhase)
        return false;
    return wheel.pixelDelta.x !== 0 || wheel.pixelDelta.y !== 0;
}

function verticalKind(wheel) {
    if (isTouchpad(wheel))
        return Kind.touchpad;
    const angle = wheel.angleDelta.y;
    if (angle === 0)
        return Kind.none;
    return angle % 120 === 0 ? Kind.wheel : Kind.highResWheel;
}

function anyAxisDelta(wheel) {
    const point = isTouchpad(wheel) ? wheel.pixelDelta : wheel.angleDelta;
    return point.x || point.y;
}
