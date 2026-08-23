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
    property bool showPercentSign: false
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
        return root.lowState ? Theme.error : Theme.primary;
    }
    readonly property color trackColor: {
        if (root.outlined)
            return root.hovered ? Theme.withAlpha(Theme.surfaceVariant, 0.45) : "transparent";
        return Theme.withAlpha(Theme.surfaceText, root.hovered ? 0.42 : 0.28);
    }
    readonly property color onFillColor: Theme.isLightColor(root.fillColor) ? Qt.rgba(0, 0, 0, 0.9) : Qt.rgba(1, 1, 1, 0.95)
    readonly property string numberText: Math.round(root.level) + (root.showPercentSign ? "%" : "")
    readonly property bool boltInside: root.charging && root.showBolt
    readonly property bool numberInside: !root.vertical && root.showNumber && BatteryService.batteryAvailable
    readonly property bool glyphsVisible: root.numberInside || root.boltInside
    readonly property real strokeWidth: root.outlined ? 1.5 * root.unit : 0
    readonly property real textCanvasLeft: (root.boltInside ? 8 : 2) * root.unit
    readonly property real textCanvasWidth: (root.boltInside ? 12 : 18) * root.unit
    readonly property real baseTextSize: {
        if (!root.boltInside)
            return 10 * root.unit;
        return root.numberText.length >= 3 ? 6 * root.unit : 9 * root.unit;
    }
    readonly property real textNudge: {
        if (!root.boltInside)
            return 1.5 * root.unit;
        return root.numberText.length >= 3 ? 1 * root.unit : 1.25 * root.unit;
    }
    readonly property real textSize: Math.min(root.baseTextSize, root.baseTextSize * root.textCanvasWidth / Math.max(1, fitMetrics.advanceWidth))
    readonly property real textBaseline: 2 * root.unit + (10 * root.unit + root.textSize) / 2 - root.textNudge
    readonly property real boltHeight: root.vertical ? 8 * root.unit : 6 * root.unit
    readonly property real boltWidth: root.boltHeight * (6 / 13)
    readonly property real bodyLength: Math.round(22 * root.unit)
    readonly property real capOffset: Math.round(22.5 * root.unit)
    readonly property real capBreadth: Math.max(1, Math.round(1.5 * root.unit))
    readonly property real capSpan: Math.round(8 * root.unit)

    implicitWidth: root.vertical ? Math.round(14 * root.unit) : root.capOffset + root.capBreadth
    implicitHeight: root.vertical ? root.capOffset + root.capBreadth : Math.round(14 * root.unit)

    StyledTextMetrics {
        id: fitMetrics

        font.pixelSize: Math.max(1, root.baseTextSize)
        font.weight: Font.Bold
        isMonospace: true
        text: root.numberText
    }

    component Bolt: Shape {
        id: bolt

        property color fillColor

        width: root.boltWidth
        height: root.boltHeight
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

    component Glyphs: Item {
        id: glyphs

        property color glyphColor

        width: root.width
        height: root.height

        StyledText {
            id: numberGlyph

            visible: root.numberInside
            x: root.textCanvasLeft + (root.textCanvasWidth - implicitWidth) / 2
            y: root.textBaseline - baselineOffset
            text: root.numberText
            color: glyphs.glyphColor
            isMonospace: true
            font.pixelSize: Math.max(1, root.textSize)
            font.weight: Font.Bold
        }

        Bolt {
            visible: root.boltInside
            x: root.vertical ? (root.width - width) / 2 : 2 * root.unit + (6 * root.unit - width) / 2
            y: root.vertical ? (root.height - height) / 2 : 4 * root.unit
            fillColor: glyphs.glyphColor
        }
    }

    Rectangle {
        id: cap

        x: root.vertical ? (root.width - root.capSpan) / 2 : root.capOffset
        y: root.vertical ? 0 : (root.height - root.capSpan) / 2
        width: root.vertical ? root.capSpan : root.capBreadth
        height: root.vertical ? root.capBreadth : root.capSpan
        topLeftRadius: root.vertical ? root.unit : 0
        topRightRadius: root.unit
        bottomRightRadius: root.vertical ? 0 : root.unit
        color: root.fillColor
    }

    Rectangle {
        id: frame

        x: 0
        y: root.vertical ? root.height - root.bodyLength : 0
        width: root.vertical ? root.width : root.bodyLength
        height: root.vertical ? root.bodyLength : root.height
        topLeftRadius: root.vertical ? 3 * root.unit : 4 * root.unit
        topRightRadius: 3 * root.unit
        bottomLeftRadius: 4 * root.unit
        bottomRightRadius: root.vertical ? 4 * root.unit : 3 * root.unit
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
        topLeftRadius: Math.max(0, frame.topLeftRadius - root.strokeWidth)
        topRightRadius: Math.max(0, frame.topRightRadius - root.strokeWidth)
        bottomLeftRadius: Math.max(0, frame.bottomLeftRadius - root.strokeWidth)
        bottomRightRadius: Math.max(0, frame.bottomRightRadius - root.strokeWidth)
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

    Glyphs {
        visible: root.glyphsVisible
        glyphColor: Theme.surfaceText
    }

    Item {
        x: interior.x + fill.x
        y: interior.y + fill.y
        width: fill.width
        height: fill.height
        clip: true
        visible: root.glyphsVisible && !root.outlined

        Glyphs {
            x: -parent.x
            y: -parent.y
            glyphColor: root.onFillColor
        }
    }
}
