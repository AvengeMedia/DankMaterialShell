import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real radius: 0
    property real radiusX: radius
    property real radiusY: radius
    property color color: "transparent"
    property string corner: "topLeft"

    readonly property rect discRect: {
        const rx = radiusX;
        const ry = radiusY;
        switch (corner) {
        case "topRight":
            return Qt.rect(0, -ry, rx * 2, ry * 2);
        case "bottomRight":
            return Qt.rect(0, 0, rx * 2, ry * 2);
        case "bottomLeft":
            return Qt.rect(-rx, 0, rx * 2, ry * 2);
        default:
            return Qt.rect(-rx, -ry, rx * 2, ry * 2);
        }
    }
    readonly property string path: {
        const rx = radiusX;
        const ry = radiusY;
        if (rx <= 0 || ry <= 0)
            return "";
        switch (corner) {
        case "topRight":
            return `M 0 0 L 0 ${ry} L ${rx} ${ry} A ${rx} ${ry} 0 0 1 0 0 Z`;
        case "bottomRight":
            return `M 0 ${ry} L 0 0 L ${rx} 0 A ${rx} ${ry} 0 0 0 0 ${ry} Z`;
        case "bottomLeft":
            return `M ${rx} ${ry} L ${rx} 0 L 0 0 A ${rx} ${ry} 0 0 1 ${rx} ${ry} Z`;
        default:
            return `M ${rx} 0 L ${rx} ${ry} L 0 ${ry} A ${rx} ${ry} 0 0 0 ${rx} 0 Z`;
        }
    }

    width: Math.max(0, radiusX)
    height: Math.max(0, radiusY)
    visible: radiusX > 0 && radiusY > 0

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            strokeWidth: 0

            PathSvg {
                path: root.path
            }
        }
    }
}
