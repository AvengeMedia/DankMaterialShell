import QtQuick
import QtQuick.Shapes
import qs.Common

// Concave arc connector filling the gap between a bar corner and an adjacent surface.

Item {
    id: root

    property string barSide: "top"
    property string placement: "left"
    property real spacing: 4
    property real connectorRadius: 12
    property color color: "transparent"
    property real edgeStrokeWidth: 0
    property color edgeStrokeColor: color
    property real dpr: 1

    readonly property bool isHorizontalBar: barSide === "top" || barSide === "bottom"
    readonly property bool isPlacementLeft: placement === "left"
    readonly property real _edgeStrokeWidth: Math.max(0, edgeStrokeWidth)
    readonly property string arcCorner: {
        if (barSide === "top")
            return isPlacementLeft ? "bottomLeft" : "bottomRight";
        if (barSide === "bottom")
            return isPlacementLeft ? "topLeft" : "topRight";
        if (barSide === "left")
            return isPlacementLeft ? "topRight" : "bottomRight";
        return isPlacementLeft ? "topLeft" : "bottomLeft";
    }
    readonly property real pathStartX: {
        switch (arcCorner) {
        case "topLeft":
            return width;
        case "topRight":
        case "bottomLeft":
            return 0;
        default:
            return 0;
        }
    }
    readonly property real pathStartY: {
        switch (arcCorner) {
        case "bottomRight":
            return height;
        default:
            return 0;
        }
    }
    readonly property real firstLineX: {
        switch (arcCorner) {
        case "topLeft":
        case "bottomLeft":
            return width;
        default:
            return 0;
        }
    }
    readonly property real firstLineY: {
        switch (arcCorner) {
        case "topLeft":
        case "topRight":
            return height;
        default:
            return 0;
        }
    }
    readonly property real secondLineX: {
        switch (arcCorner) {
        case "topRight":
        case "bottomLeft":
        case "bottomRight":
            return width;
        default:
            return 0;
        }
    }
    readonly property real secondLineY: {
        switch (arcCorner) {
        case "topLeft":
        case "topRight":
        case "bottomLeft":
            return height;
        default:
            return 0;
        }
    }
    readonly property real arcCenterX: arcCorner === "topRight" || arcCorner === "bottomRight" ? width : 0
    readonly property real arcCenterY: arcCorner === "bottomLeft" || arcCorner === "bottomRight" ? height : 0
    readonly property real arcStartAngle: {
        switch (arcCorner) {
        case "topLeft":
        case "topRight":
            return 90;
        case "bottomLeft":
            return 0;
        default:
            return -90;
        }
    }
    readonly property real arcSweepAngle: {
        switch (arcCorner) {
        case "topRight":
            return 90;
        default:
            return -90;
        }
    }

    width: isHorizontalBar ? connectorRadius : (spacing + connectorRadius)
    height: isHorizontalBar ? (spacing + connectorRadius) : connectorRadius

    Shape {
        x: -root._edgeStrokeWidth
        y: -root._edgeStrokeWidth
        width: root.width + root._edgeStrokeWidth * 2
        height: root.height + root._edgeStrokeWidth * 2
        asynchronous: false
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: root.dpr > 1 ? Qt.size(Math.ceil(width * root.dpr), Math.ceil(height * root.dpr)) : Qt.size(0, 0)

        ShapePath {
            fillColor: root.color
            strokeColor: root._edgeStrokeWidth > 0 ? root.edgeStrokeColor : "transparent"
            strokeWidth: root._edgeStrokeWidth * 2
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            fillRule: ShapePath.WindingFill
            startX: root.pathStartX + root._edgeStrokeWidth
            startY: root.pathStartY + root._edgeStrokeWidth

            PathLine {
                x: root.firstLineX + root._edgeStrokeWidth
                y: root.firstLineY + root._edgeStrokeWidth
            }

            PathLine {
                x: root.secondLineX + root._edgeStrokeWidth
                y: root.secondLineY + root._edgeStrokeWidth
            }

            PathAngleArc {
                centerX: root.arcCenterX + root._edgeStrokeWidth
                centerY: root.arcCenterY + root._edgeStrokeWidth
                radiusX: root.connectorRadius
                radiusY: root.connectorRadius
                startAngle: root.arcStartAngle
                sweepAngle: root.arcSweepAngle
            }
        }
    }
}
