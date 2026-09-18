import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real radius: 0
    property color color: "transparent"
    property string corner: "topLeft"

    readonly property real rotationAngle: {
        switch (corner) {
        case "topRight":
            return 90;
        case "bottomRight":
            return 180;
        case "bottomLeft":
            return 270;
        default:
            return 0;
        }
    }
    readonly property rect discRect: {
        const r = radius;
        switch (corner) {
        case "topRight":
            return Qt.rect(0, -r, r * 2, r * 2);
        case "bottomRight":
            return Qt.rect(0, 0, r * 2, r * 2);
        case "bottomLeft":
            return Qt.rect(-r, 0, r * 2, r * 2);
        default:
            return Qt.rect(-r, -r, r * 2, r * 2);
        }
    }

    width: Math.max(0, radius)
    height: Math.max(0, radius)
    visible: radius > 0

    Shape {
        anchors.fill: parent
        rotation: root.rotationAngle
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            strokeWidth: 0

            PathSvg {
                path: root.radius > 0 ? `M ${root.radius} 0 L ${root.radius} ${root.radius} L 0 ${root.radius} A ${root.radius} ${root.radius} 0 0 0 ${root.radius} 0 Z` : ""
            }
        }
    }
}
