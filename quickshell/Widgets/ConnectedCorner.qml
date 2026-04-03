import QtQuick
import QtQuick.Shapes
import qs.Common

// ConnectedCorner — Seam-complement connector that fills the void between
// a bar's rounded corner and a popout's flush edge, creating a seamless junction.
//
// Usage: Place as a sibling to contentWrapper inside unrollCounteract (DankPopout)
// or as a sibling to dockBackground (Dock). Position using contentWrapper.x/y.
//
// barSide:   "top" | "bottom" | "left" | "right"  — which edge the bar is on
// placement: "left" | "right"                      — which lateral end of that edge
// spacing:   gap between bar surface and popout surface (storedBarSpacing, ~4px)
// connectorRadius: bar corner radius to match (frameRounding or Theme.cornerRadius)
// color:     fill color matching the popout surface

Item {
    id: root

    property string barSide: "top"
    property string placement: "left"
    property real spacing: 4
    property real connectorRadius: 12
    property color color: "transparent"

    readonly property bool isHorizontalBar: barSide === "top" || barSide === "bottom"
    readonly property bool isPlacementLeft: placement === "left"
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

    // Horizontal bar: connector is tall (bridges vertical gap), narrow (corner radius wide)
    // Vertical bar: connector is wide (bridges horizontal gap), short (corner radius tall)
    width: isHorizontalBar ? connectorRadius : (spacing + connectorRadius)
    height: isHorizontalBar ? (spacing + connectorRadius) : connectorRadius

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            strokeWidth: 0
            startX: root.pathStartX
            startY: root.pathStartY

            PathLine {
                x: root.firstLineX
                y: root.firstLineY
            }

            PathLine {
                x: root.secondLineX
                y: root.secondLineY
            }

            PathAngleArc {
                centerX: root.arcCenterX
                centerY: root.arcCenterY
                radiusX: root.width
                radiusY: root.height
                startAngle: root.arcStartAngle
                sweepAngle: root.arcSweepAngle
            }
        }
    }
}
