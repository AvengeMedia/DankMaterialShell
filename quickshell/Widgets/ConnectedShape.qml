import QtQuick
import QtQuick.Shapes
import qs.Common

// Unified connected silhouette: body + near/far concave arcs as one ShapePath.
// Keeping the connected chrome in one path avoids sibling alignment seams.

Item {
    id: root

    property string barSide: "top"

    property real bodyWidth: 0
    property real bodyHeight: 0

    property real connectorRadius: 12
    property real startConnectorRadius: connectorRadius
    property real endConnectorRadius: connectorRadius
    property real farStartConnectorRadius: 0
    property real farEndConnectorRadius: 0

    property real surfaceRadius: 12

    property color fillColor: "transparent"

    readonly property bool _horiz: barSide === "top" || barSide === "bottom"
    readonly property real _sc: Math.max(0, startConnectorRadius)
    readonly property real _ec: Math.max(0, endConnectorRadius)
    readonly property real _fsc: Math.max(0, farStartConnectorRadius)
    readonly property real _fec: Math.max(0, farEndConnectorRadius)
    readonly property real _firstCr: barSide === "left" ? _sc : _ec
    readonly property real _secondCr: barSide === "left" ? _ec : _sc
    readonly property real _firstFarCr: barSide === "left" ? _fsc : _fec
    readonly property real _secondFarCr: barSide === "left" ? _fec : _fsc
    readonly property real _farExtent: Math.max(_fsc, _fec)
    readonly property real _sr: Math.max(0, Math.min(surfaceRadius, (_horiz ? bodyWidth : bodyHeight) / 2, (_horiz ? bodyHeight : bodyWidth) / 2))
    readonly property real _firstSr: _firstFarCr > 0 ? 0 : _sr
    readonly property real _secondSr: _secondFarCr > 0 ? 0 : _sr
    readonly property real _firstFarInset: _firstFarCr > 0 ? _firstFarCr : _firstSr
    readonly property real _secondFarInset: _secondFarCr > 0 ? _secondFarCr : _secondSr

    // Root-level aliases — PathArc/PathLine elements can't use `parent`.
    readonly property real _bw: bodyWidth
    readonly property real _bh: bodyHeight
    readonly property real _bodyLeft: _horiz ? _sc : (barSide === "right" ? _farExtent : 0)
    readonly property real _bodyRight: _bodyLeft + _bw
    readonly property real _bodyTop: _horiz ? (barSide === "bottom" ? _farExtent : 0) : _sc
    readonly property real _bodyBottom: _bodyTop + _bh
    readonly property real _totalW: _horiz ? _bw + _sc + _ec : _bw + _farExtent
    readonly property real _totalH: _horiz ? _bh + _farExtent : _bh + _sc + _ec

    width: _totalW
    height: _totalH

    readonly property real bodyX: root._bodyLeft
    readonly property real bodyY: root._bodyTop

    Shape {
        anchors.fill: parent
        asynchronous: false
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

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
                        return root._firstCr;
                    case "right":
                        return -root._firstCr;
                    default:
                        return -root._firstCr;
                    }
                }
                relativeY: {
                    switch (root.barSide) {
                    case "bottom":
                        return -root._firstCr;
                    case "left":
                        return root._firstCr;
                    case "right":
                        return -root._firstCr;
                    default:
                        return root._firstCr;
                    }
                }
                radiusX: root._firstCr
                radiusY: root._firstCr
                direction: root.barSide === "bottom" ? PathArc.Clockwise : PathArc.Counterclockwise
            }

            // Body edge to first convex corner
            PathLine {
                x: {
                    switch (root.barSide) {
                    case "left":
                        return root._bodyRight - root._firstSr;
                    case "right":
                        return root._bodyLeft + root._firstSr;
                    default:
                        return root._bodyRight;
                    }
                }
                y: {
                    switch (root.barSide) {
                    case "bottom":
                        return root._bodyTop + root._firstSr;
                    case "left":
                        return root._bodyTop;
                    case "right":
                        return root._bodyBottom;
                    default:
                        return root._bodyBottom - root._firstSr;
                    }
                }
            }

            // Convex arc 1
            PathArc {
                relativeX: {
                    switch (root.barSide) {
                    case "left":
                        return root._firstSr;
                    case "right":
                        return -root._firstSr;
                    default:
                        return -root._firstSr;
                    }
                }
                relativeY: {
                    switch (root.barSide) {
                    case "bottom":
                        return -root._firstSr;
                    case "left":
                        return root._firstSr;
                    case "right":
                        return -root._firstSr;
                    default:
                        return root._firstSr;
                    }
                }
                radiusX: root._firstSr
                radiusY: root._firstSr
                direction: root.barSide === "bottom" ? PathArc.Counterclockwise : PathArc.Clockwise
            }

            // Opposite-side connector 1
            PathLine {
                x: {
                    switch (root.barSide) {
                    case "left":
                        return root._firstFarCr > 0 ? root._bodyRight + root._firstFarCr : root._bodyRight;
                    case "right":
                        return root._firstFarCr > 0 ? root._bodyLeft - root._firstFarCr : root._bodyLeft;
                    default:
                        return root._firstFarCr > 0 ? root._bodyRight : root._bodyRight - root._firstSr;
                    }
                }
                y: {
                    switch (root.barSide) {
                    case "bottom":
                        return root._firstFarCr > 0 ? root._bodyTop - root._firstFarCr : root._bodyTop;
                    case "left":
                        return root._firstFarCr > 0 ? root._bodyTop : root._bodyTop + root._firstSr;
                    case "right":
                        return root._firstFarCr > 0 ? root._bodyBottom : root._bodyBottom - root._firstSr;
                    default:
                        return root._firstFarCr > 0 ? root._bodyBottom + root._firstFarCr : root._bodyBottom;
                    }
                }
            }

            PathArc {
                relativeX: {
                    switch (root.barSide) {
                    case "left":
                        return -root._firstFarCr;
                    case "right":
                        return root._firstFarCr;
                    default:
                        return -root._firstFarCr;
                    }
                }
                relativeY: {
                    switch (root.barSide) {
                    case "bottom":
                        return root._firstFarCr;
                    case "left":
                        return root._firstFarCr;
                    case "right":
                        return -root._firstFarCr;
                    default:
                        return -root._firstFarCr;
                    }
                }
                radiusX: root._firstFarCr
                radiusY: root._firstFarCr
                direction: root.barSide === "bottom" ? PathArc.Clockwise : PathArc.Counterclockwise
            }

            // Far edge
            PathLine {
                x: {
                    switch (root.barSide) {
                    case "left":
                        return root._bodyRight;
                    case "right":
                        return root._bodyLeft;
                    default:
                        return root._bodyLeft + root._secondFarInset;
                    }
                }
                y: {
                    switch (root.barSide) {
                    case "bottom":
                        return root._bodyTop;
                    case "left":
                        return root._bodyBottom - root._secondFarInset;
                    case "right":
                        return root._bodyTop + root._secondFarInset;
                    default:
                        return root._bodyBottom;
                    }
                }
            }

            // Opposite-side connector 2
            PathArc {
                relativeX: {
                    switch (root.barSide) {
                    case "left":
                        return root._secondFarCr;
                    case "right":
                        return -root._secondFarCr;
                    default:
                        return -root._secondFarCr;
                    }
                }
                relativeY: {
                    switch (root.barSide) {
                    case "bottom":
                        return -root._secondFarCr;
                    case "left":
                        return root._secondFarCr;
                    case "right":
                        return -root._secondFarCr;
                    default:
                        return root._secondFarCr;
                    }
                }
                radiusX: root._secondFarCr
                radiusY: root._secondFarCr
                direction: root.barSide === "bottom" ? PathArc.Clockwise : PathArc.Counterclockwise
            }

            PathLine {
                x: {
                    switch (root.barSide) {
                    case "left":
                        return root._secondFarCr > 0 ? root._bodyRight : root._bodyRight;
                    case "right":
                        return root._secondFarCr > 0 ? root._bodyLeft : root._bodyLeft;
                    default:
                        return root._secondFarCr > 0 ? root._bodyLeft : root._bodyLeft + root._secondSr;
                    }
                }
                y: {
                    switch (root.barSide) {
                    case "bottom":
                        return root._secondFarCr > 0 ? root._bodyTop : root._bodyTop;
                    case "left":
                        return root._secondFarCr > 0 ? root._bodyBottom : root._bodyBottom - root._secondSr;
                    case "right":
                        return root._secondFarCr > 0 ? root._bodyTop : root._bodyTop + root._secondSr;
                    default:
                        return root._secondFarCr > 0 ? root._bodyBottom : root._bodyBottom;
                    }
                }
            }

            // Convex arc 2
            PathArc {
                relativeX: {
                    switch (root.barSide) {
                    case "left":
                        return -root._secondSr;
                    case "right":
                        return root._secondSr;
                    default:
                        return -root._secondSr;
                    }
                }
                relativeY: {
                    switch (root.barSide) {
                    case "bottom":
                        return root._secondSr;
                    case "left":
                        return root._secondSr;
                    case "right":
                        return -root._secondSr;
                    default:
                        return -root._secondSr;
                    }
                }
                radiusX: root._secondSr
                radiusY: root._secondSr
                direction: root.barSide === "bottom" ? PathArc.Counterclockwise : PathArc.Clockwise
            }

            // Body edge to second concave arc
            PathLine {
                x: {
                    switch (root.barSide) {
                    case "left":
                        return root._bodyLeft + root._ec;
                    case "right":
                        return root._bodyRight - root._sc;
                    default:
                        return root._bodyLeft;
                    }
                }
                y: {
                    switch (root.barSide) {
                    case "bottom":
                        return root._bodyBottom - root._sc;
                    case "left":
                        return root._bodyBottom;
                    case "right":
                        return root._bodyTop;
                    default:
                        return root._bodyTop + root._sc;
                    }
                }
            }

            // Concave arc 2
            PathArc {
                relativeX: {
                    switch (root.barSide) {
                    case "left":
                        return -root._secondCr;
                    case "right":
                        return root._secondCr;
                    default:
                        return -root._secondCr;
                    }
                }
                relativeY: {
                    switch (root.barSide) {
                    case "bottom":
                        return root._secondCr;
                    case "left":
                        return root._secondCr;
                    case "right":
                        return -root._secondCr;
                    default:
                        return -root._secondCr;
                    }
                }
                radiusX: root._secondCr
                radiusY: root._secondCr
                direction: root.barSide === "bottom" ? PathArc.Clockwise : PathArc.Counterclockwise
            }
        }
    }
}
