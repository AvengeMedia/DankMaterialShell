pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.Common

// Frame perimeter ring: the full window rectangle with a rounded-rectangle
// cutout. Drawn as a single even-odd Shape so the ring is one primitive: no
// full-output mask textures, and a translucent fill never double-blends at the
// corners.
Item {
    id: root

    anchors.fill: parent

    required property real cutoutTopInset
    required property real cutoutBottomInset
    required property real cutoutLeftInset
    required property real cutoutRightInset
    required property real cutoutRadius
    property color borderColor: Qt.rgba(SettingsData.effectiveFrameColor.r, SettingsData.effectiveFrameColor.g, SettingsData.effectiveFrameColor.b, SettingsData.frameOpacity)

    // Path elements can't reference `parent`; expose cutout edges as root props.
    readonly property real _left: cutoutLeftInset
    readonly property real _top: cutoutTopInset
    readonly property real _right: width - cutoutRightInset
    readonly property real _bottom: height - cutoutBottomInset
    readonly property real _radius: Math.max(0, Math.min(cutoutRadius, (_right - _left) / 2, (_bottom - _top) / 2))

    Shape {
        anchors.fill: parent
        asynchronous: false
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {
            fillColor: root.borderColor
            strokeWidth: -1
            fillRule: ShapePath.OddEvenFill

            // Outer rectangle (window edge, square corners)
            startX: 0
            startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }

            // Inner rounded-rectangle cutout (second subpath → even-odd hole)
            PathMove { x: root._left + root._radius; y: root._top }
            PathLine { x: root._right - root._radius; y: root._top }
            PathArc { x: root._right; y: root._top + root._radius; radiusX: root._radius; radiusY: root._radius }
            PathLine { x: root._right; y: root._bottom - root._radius }
            PathArc { x: root._right - root._radius; y: root._bottom; radiusX: root._radius; radiusY: root._radius }
            PathLine { x: root._left + root._radius; y: root._bottom }
            PathArc { x: root._left; y: root._bottom - root._radius; radiusX: root._radius; radiusY: root._radius }
            PathLine { x: root._left; y: root._top + root._radius }
            PathArc { x: root._left + root._radius; y: root._top; radiusX: root._radius; radiusY: root._radius }
        }
    }
}
