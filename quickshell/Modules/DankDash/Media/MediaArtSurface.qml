pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Widgets
import qs.Common
import qs.Modules.DankDash
import "../../../DankCommon/Widgets/MaterialShapes.js" as Shapes

ClippingRectangle {
    id: root

    property string artStyle: "rounded"
    readonly property real contentRadius: artStyle === "slanted" ? width * DashMetrics.mediaArtSoftRadiusRatio * Theme.shapeScale : radius

    radius: {
        switch (artStyle) {
        case "circle":
            return width / 2;
        case "square":
            return width * DashMetrics.mediaArtSoftRadiusRatio * Theme.shapeScale;
        case "slanted":
            return 0;
        }
        return DashMetrics.mediaArtRadius;
    }
    color: "transparent"
    antialiasing: true
    layer.enabled: artStyle === "slanted"
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: shapeMask.item
    }

    Loader {
        id: shapeMask
        anchors.fill: parent
        active: root.layer.enabled
        visible: false

        sourceComponent: Item {
            layer.enabled: true

            Shape {
                id: shape

                readonly property real scaleX: boundingRect.width > 0 ? root.width / boundingRect.width : 1
                readonly property real scaleY: boundingRect.height > 0 ? root.height / boundingRect.height : 1

                x: -boundingRect.x * scaleX
                y: -boundingRect.y * scaleY
                width: root.width
                height: root.height
                preferredRendererType: Shape.CurveRenderer
                transform: Scale {
                    xScale: shape.scaleX
                    yScale: shape.scaleY
                }

                ShapePath {
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillColor: Theme.withAlpha(Theme.surface, 1)

                    PathSvg {
                        path: Shapes.buildPath("slanted", root.width, root.height, Theme.shapeScale === 0)
                    }
                }
            }
        }
    }
}
