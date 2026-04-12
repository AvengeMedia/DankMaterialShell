import QtQuick
import QtQuick.Shapes
import qs.Common

// Unified connected silhouette: body + concave arcs as one ShapePath.
// PathArc pattern — 4 arcs + 4 lines, no sibling alignment.

Item {
    id: root

    property string barSide: "top"

    property real bodyWidth: 0
    property real bodyHeight: 0

    property real connectorRadius: 12

    property real surfaceRadius: 12

    property color fillColor: "transparent"

    // ── Derived layout ──
    readonly property bool _horiz: barSide === "top" || barSide === "bottom"
    readonly property real _cr: Math.max(0, connectorRadius)
    readonly property real _sr: Math.max(0, Math.min(surfaceRadius, (_horiz ? bodyWidth : bodyHeight) / 2, (_horiz ? bodyHeight : bodyWidth) / 2))

    // Root-level aliases — PathArc/PathLine elements can't use `parent`.
    readonly property real _bw: bodyWidth
    readonly property real _bh: bodyHeight
    readonly property real _totalW: _horiz ? _bw + _cr * 2 : _bw
    readonly property real _totalH: _horiz ? _bh : _bh + _cr * 2

    width: _totalW
    height: _totalH

    readonly property real bodyX: _horiz ? _cr : 0
    readonly property real bodyY: _horiz ? 0 : _cr

    Shape {
        anchors.fill: parent
        asynchronous: false
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.fillColor
            strokeWidth: -1
            fillRule: ShapePath.WindingFill

            // CW path: bar edge → concave arc → body → convex arc → far edge → convex arc → body → concave arc

            startX: root.barSide === "right" ? root._totalW : 0
            startY: {
                switch (root.barSide) {
                case "bottom":
                    return root._totalH;
                case "left":
                    return root._totalH;
                case "right":
                    return 0;
                default:
                    return 0;
                }
            }

            // Bar edge
            PathLine {
                x: {
                    switch (root.barSide) {
                    case "left":
                        return 0;
                    case "right":
                        return root._totalW;
                    default:
                        return root._totalW;
                    }
                }
                y: {
                    switch (root.barSide) {
                    case "bottom":
                        return root._totalH;
                    case "left":
                        return 0;
                    case "right":
                        return root._totalH;
                    default:
                        return 0;
                    }
                }
            }

            // Concave arc 1
            PathArc {
                relativeX: {
                    switch (root.barSide) {
                    case "left":
                        return root._cr;
                    case "right":
                        return -root._cr;
                    default:
                        return -root._cr;
                    }
                }
                relativeY: {
                    switch (root.barSide) {
                    case "bottom":
                        return -root._cr;
                    case "left":
                        return root._cr;
                    case "right":
                        return -root._cr;
                    default:
                        return root._cr;
                    }
                }
                radiusX: root._cr
                radiusY: root._cr
                direction: root.barSide === "bottom" ? PathArc.Clockwise : PathArc.Counterclockwise
            }

            // Body edge to first convex corner
            PathLine {
                x: {
                    switch (root.barSide) {
                    case "left":
                        return root._bw - root._sr;
                    case "right":
                        return root._sr;
                    default:
                        return root._totalW - root._cr;
                    }
                }
                y: {
                    switch (root.barSide) {
                    case "bottom":
                        return root._sr;
                    case "left":
                        return root._cr;
                    case "right":
                        return root._cr + root._bh;
                    default:
                        return root._totalH - root._sr;
                    }
                }
            }

            // Convex arc 1
            PathArc {
                relativeX: {
                    switch (root.barSide) {
                    case "left":
                        return root._sr;
                    case "right":
                        return -root._sr;
                    default:
                        return -root._sr;
                    }
                }
                relativeY: {
                    switch (root.barSide) {
                    case "bottom":
                        return -root._sr;
                    case "left":
                        return root._sr;
                    case "right":
                        return -root._sr;
                    default:
                        return root._sr;
                    }
                }
                radiusX: root._sr
                radiusY: root._sr
                direction: root.barSide === "bottom" ? PathArc.Counterclockwise : PathArc.Clockwise
            }

            // Far edge
            PathLine {
                x: {
                    switch (root.barSide) {
                    case "left":
                        return root._bw;
                    case "right":
                        return 0;
                    default:
                        return root._cr + root._sr;
                    }
                }
                y: {
                    switch (root.barSide) {
                    case "bottom":
                        return 0;
                    case "left":
                        return root._cr + root._bh - root._sr;
                    case "right":
                        return root._cr + root._sr;
                    default:
                        return root._totalH;
                    }
                }
            }

            // Convex arc 2
            PathArc {
                relativeX: {
                    switch (root.barSide) {
                    case "left":
                        return -root._sr;
                    case "right":
                        return root._sr;
                    default:
                        return -root._sr;
                    }
                }
                relativeY: {
                    switch (root.barSide) {
                    case "bottom":
                        return root._sr;
                    case "left":
                        return root._sr;
                    case "right":
                        return -root._sr;
                    default:
                        return -root._sr;
                    }
                }
                radiusX: root._sr
                radiusY: root._sr
                direction: root.barSide === "bottom" ? PathArc.Counterclockwise : PathArc.Clockwise
            }

            // Body edge to second concave arc
            PathLine {
                x: {
                    switch (root.barSide) {
                    case "left":
                        return root._cr;
                    case "right":
                        return root._bw - root._cr;
                    default:
                        return root._cr;
                    }
                }
                y: {
                    switch (root.barSide) {
                    case "bottom":
                        return root._totalH - root._cr;
                    case "left":
                        return root._cr + root._bh;
                    case "right":
                        return root._cr;
                    default:
                        return root._cr;
                    }
                }
            }

            // Concave arc 2
            PathArc {
                relativeX: {
                    switch (root.barSide) {
                    case "left":
                        return -root._cr;
                    case "right":
                        return root._cr;
                    default:
                        return -root._cr;
                    }
                }
                relativeY: {
                    switch (root.barSide) {
                    case "bottom":
                        return root._cr;
                    case "left":
                        return root._cr;
                    case "right":
                        return -root._cr;
                    default:
                        return -root._cr;
                    }
                }
                radiusX: root._cr
                radiusY: root._cr
                direction: root.barSide === "bottom" ? PathArc.Clockwise : PathArc.Counterclockwise
            }
        }
    }
}
