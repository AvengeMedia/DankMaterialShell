pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property real thickness: 14
    property bool vertical: false
    property bool showNumber: true
    property bool showBolt: true
    property bool outlined: false
    property bool hovered: false

    readonly property real unit: root.thickness / 14
    readonly property real level: Math.max(0, Math.min(100, BatteryService.batteryLevel))
    readonly property bool charging: BatteryService.batteryAvailable && BatteryService.isCharging
    readonly property bool lowState: BatteryService.batteryAvailable && BatteryService.isLowBattery && !BatteryService.isCharging
    readonly property color fillColor: {
        if (!BatteryService.batteryAvailable)
            return Theme.surfaceVariant;
        if (root.charging)
            return Theme.success;
        if (root.lowState)
            return Theme.error;
        return Theme.isLightColor(Theme.primary) === Theme.isLightColor(Theme.surface) ? Theme.surfaceText : Theme.primary;
    }
    readonly property color dimColor: Theme.withAlpha(root.fillColor, root.hovered ? 0.6 : 0.48)
    readonly property color trackColor: {
        if (root.outlined)
            return root.hovered ? Theme.withAlpha(Theme.surfaceVariant, 0.45) : "transparent";
        return root.dimColor;
    }
    readonly property color inkColor: {
        if (Theme.isLightColor(root.fillColor))
            return Theme.isLightColor(Theme.surface) ? Theme.surfaceText : Theme.surface;
        return Theme.isLightColor(Theme.surface) ? Theme.surface : Theme.surfaceText;
    }
    readonly property int glyphWeight: Theme.fontWeight
    readonly property string numberText: Math.round(root.level).toString()
    readonly property bool boltVisible: root.charging && root.showBolt
    readonly property bool numberInside: !root.vertical && root.showNumber && BatteryService.batteryAvailable
    readonly property real strokeWidth: root.outlined ? 1.5 * root.unit : 0
    readonly property real textCanvasLeft: 1.5 * root.unit
    readonly property real textCanvasWidth: root.bodyLength - root.textCanvasLeft - 1.5 * root.unit
    readonly property real textNeed: fitMetrics.advanceWidth
    property real fontSize: Theme.fontSizeSmall
    readonly property real baseTextSize: root.fontSize
    readonly property real textSize: root.baseTextSize
    readonly property real textBaseline: root.height / 2 - digitInk.tightBoundingRect.y - digitInk.tightBoundingRect.height / 2
    readonly property real boltBadgeSize: Math.round(9 * root.unit)
    readonly property real boltBadgeWidth: Math.round(root.boltBadgeSize * (8 / 13))
    readonly property real bodyLength: Math.max(Math.round(25 * root.unit), Math.ceil(root.numberInside ? root.textNeed + root.textCanvasLeft + 1.5 * root.unit : 0))
    readonly property real capGap: Math.max(1, Math.round(root.unit))
    readonly property real capOffset: root.bodyLength + root.capGap
    readonly property real capBreadth: Math.max(1, Math.round(1.25 * root.unit))
    readonly property real capSpan: Math.round(6 * root.unit)

    implicitWidth: root.vertical ? Math.round(14 * root.unit) : root.capOffset + (root.boltVisible ? root.boltBadgeWidth : root.capBreadth)
    implicitHeight: root.vertical ? root.capOffset + root.capBreadth : Math.round(14 * root.unit)

    StyledTextMetrics {
        id: fitMetrics

        font.weight: root.glyphWeight
        font.pixelSize: Math.max(1, root.baseTextSize)
        font.features: {
            "tnum": 1
        }
        text: root.numberText
    }

    StyledTextMetrics {
        id: digitInk

        font.weight: root.glyphWeight
        font.pixelSize: Math.max(1, root.textSize)
        text: "0"
    }

    component Bolt: Shape {
        id: bolt

        property color fillColor

        width: root.boltBadgeWidth
        height: root.boltBadgeSize
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: bolt.fillColor
            strokeColor: "transparent"
            startX: bolt.width * (1 / 3)
            startY: bolt.height
            PathLine {
                x: bolt.width * (1 / 3)
                y: bolt.height * (7.5 / 13)
            }
            PathLine {
                x: 0
                y: bolt.height * (7.5 / 13)
            }
            PathLine {
                x: bolt.width * (2 / 3)
                y: 0
            }
            PathLine {
                x: bolt.width * (2 / 3)
                y: bolt.height * (5.5 / 13)
            }
            PathLine {
                x: bolt.width
                y: bolt.height * (5.5 / 13)
            }
            PathLine {
                x: bolt.width * (1 / 3)
                y: bolt.height
            }
        }
    }

    Rectangle {
        id: cap

        x: root.vertical ? (root.width - root.capSpan) / 2 : root.capOffset
        y: root.vertical ? 0 : (root.height - root.capSpan) / 2
        width: root.vertical ? root.capSpan : root.capBreadth
        height: root.vertical ? root.capBreadth : root.capSpan
        radius: root.capBreadth / 2
        visible: root.vertical || !root.boltVisible
        color: root.outlined ? root.fillColor : root.dimColor
    }

    Rectangle {
        id: frame

        x: 0
        y: root.vertical ? root.height - root.bodyLength : 0
        width: root.vertical ? root.width : root.bodyLength
        height: root.vertical ? root.bodyLength : root.height
        radius: 4 * root.unit
        color: root.trackColor
        border.width: root.strokeWidth
        border.color: root.fillColor
    }

    ClippingRectangle {
        id: interior

        x: frame.x + root.strokeWidth
        y: frame.y + root.strokeWidth
        width: frame.width - root.strokeWidth * 2
        height: frame.height - root.strokeWidth * 2
        radius: Math.max(0, frame.radius - root.strokeWidth)
        color: "transparent"

        Rectangle {
            id: fill

            x: 0
            y: root.vertical ? parent.height - height : 0
            width: root.vertical ? parent.width : Math.round(parent.width * root.level / 100)
            height: root.vertical ? Math.round(parent.height * root.level / 100) : parent.height
            color: root.outlined ? Theme.withAlpha(root.fillColor, 0.32) : root.fillColor

            Behavior on width {
                enabled: !root.vertical
                NumberAnimation {
                    duration: Theme.mediumDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on height {
                enabled: root.vertical
                NumberAnimation {
                    duration: Theme.mediumDuration
                    easing.type: Theme.standardEasing
                }
            }
        }
    }

    component Glyphs: Item {
        id: glyphs

        property color ink

        width: root.width
        height: root.height

        NumericText {
            isMonospace: false
            visible: root.numberInside
            x: root.textCanvasLeft + (root.textCanvasWidth - implicitWidth) / 2
            y: root.textBaseline - baselineOffset
            text: root.numberText
            color: glyphs.ink
            font.weight: root.glyphWeight
            font.pixelSize: Math.max(1, root.textSize)
        }
    }

    Glyphs {
        visible: root.numberInside
        ink: Theme.surfaceText
    }

    Item {
        x: interior.x + fill.x
        y: interior.y + fill.y
        width: fill.width
        height: fill.height
        clip: true
        visible: root.numberInside && !root.outlined

        Glyphs {
            x: -parent.x
            y: -parent.y
            ink: root.inkColor
        }
    }

    Bolt {
        visible: root.boltVisible
        x: root.vertical ? (root.width - width) / 2 : root.capOffset
        y: root.vertical ? frame.y + (frame.height - height) / 2 : (root.height - height) / 2
        fillColor: Theme.surfaceText
    }
}
