pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Widgets
import qs.Common
import qs.Modules.DDash
import "../../../DCommon/Widgets/MaterialShapes.js" as Shapes

ClippingRectangle {
    id: root

    property var player: null
    property string artStyle: "rounded"

    readonly property bool playing: !!root.player?.presentation?.playing
    readonly property real contentRadius: artStyle === "slanted" ? width * DashMetrics.mediaArtSoftRadiusRatio * Theme.shapeScale : radius

    readonly property real cookieMinRadius: Math.min(...Shapes.polarProfile("cookie12", 256))
    // The cookie mask rotates, so content must stay inside the largest inscribed square of the smallest cookie radius
    readonly property real contentInset: artStyle === "cookie" ? Math.ceil(width * (0.5 - cookieMinRadius / Math.SQRT2)) : 0

    radius: {
        switch (artStyle) {
        case "circle":
            return width / 2;
        case "square":
            return width * DashMetrics.mediaArtSoftRadiusRatio * Theme.shapeScale;
        case "slanted":
        case "cookie":
            return 0;
        }
        return DashMetrics.mediaInnerRadius;
    }
    color: "transparent"
    antialiasing: true
    layer.enabled: artStyle === "slanted" || artStyle === "cookie"
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: artStyle === "slanted" ? slantedShapeMask.item : cookieShapeMask.item
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    Loader {
        id: slantedShapeMask
        anchors.fill: parent
        active: root.artStyle === "slanted"
        visible: false

        sourceComponent: Item {
            layer.enabled: true

            Shape {
                id: slantedShape

                readonly property real scaleX: boundingRect.width > 0 ? root.width / boundingRect.width : 1
                readonly property real scaleY: boundingRect.height > 0 ? root.height / boundingRect.height : 1

                x: -boundingRect.x * scaleX
                y: -boundingRect.y * scaleY
                width: root.width
                height: root.height
                preferredRendererType: Shape.CurveRenderer
                transform: Scale {
                    xScale: slantedShape.scaleX
                    yScale: slantedShape.scaleY
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

    Loader {
        id: cookieShapeMask
        anchors.fill: parent
        active: root.artStyle === "cookie"
        visible: false

        sourceComponent: Item {
            layer.enabled: true

            Shape {
                id: cookieShape

                width: root.width
                height: root.height
                preferredRendererType: Shape.CurveRenderer
                transform: Rotation {
                    origin.x: cookieShape.width / 2
                    origin.y: cookieShape.height / 2
                    NumberAnimation on angle {
                        from: 0
                        to: 360
                        paused: !root.visible || !root.player?.live || !root.playing
                        duration: 20000
                        loops: Animation.Infinite
                    }
                }

                ShapePath {
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillColor: Theme.withAlpha(Theme.surface, 1)

                    PathSvg {
                        path: Shapes.buildPath("cookie12", root.width, root.height, Theme.shapeScale === 0)
                    }
                }
            }
        }
    }
}
