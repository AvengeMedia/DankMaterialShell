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
    readonly property color dimColor: Theme.withAlpha(root.fillColor, root.hovered ? 0.6 : 0.48)
    readonly property color trackColor: {
        if (root.outlined)
            return root.hovered ? Theme.withAlpha(Theme.surfaceVariant, 0.45) : "transparent";
        return root.dimColor;
    }
    readonly property color onFillColor: {
        if (root.lowState)
            return Theme.isLightColor(Theme.error) ? Qt.rgba(0, 0, 0, 0.9) : Qt.rgba(1, 1, 1, 0.95);
        return Theme.primaryText;
    }
    readonly property color glyphColor: root.outlined ? Theme.surfaceText : root.onFillColor
    readonly property int glyphWeight: Theme.fontWeight
    readonly property string numberText: Math.round(root.level).toString()
    readonly property string signText: root.showPercentSign ? "%" : ""
    readonly property bool boltInside: root.charging && root.showBolt
    readonly property bool numberInside: !root.vertical && root.showNumber && BatteryService.batteryAvailable
    readonly property bool glyphsVisible: root.numberInside || root.boltInside
    readonly property real strokeWidth: root.outlined ? 1.5 * root.unit : 0
    readonly property real textCanvasLeft: (root.boltInside ? 8 : 1.5) * root.unit
    readonly property real textCanvasWidth: root.bodyLength - root.textCanvasLeft - 1.5 * root.unit
    readonly property real textNeed: fitMetrics.advanceWidth + signMetrics.advanceWidth
    property real fontSize: Theme.fontSizeSmall
    readonly property real baseTextSize: {
        if (!root.boltInside)
            return root.fontSize;
        return root.numberText.length >= 3 ? root.fontSize * 0.55 : root.fontSize * 0.82;
    }
    readonly property real signRatio: 0.72
    readonly property real textSize: root.baseTextSize
    readonly property real signSize: Math.max(1, root.textSize * root.signRatio)
    readonly property real textBaseline: root.height / 2 - digitInk.tightBoundingRect.y - digitInk.tightBoundingRect.height / 2
    readonly property real boltHeight: root.vertical ? 8 * root.unit : 6 * root.unit
    readonly property real boltWidth: root.boltHeight * (6 / 13)
    readonly property real bodyLength: Math.max(Math.round(25 * root.unit), Math.ceil(root.numberInside ? root.textNeed + root.textCanvasLeft + 1.5 * root.unit : 0))
    readonly property real capGap: Math.max(1, Math.round(root.unit))
    readonly property real capOffset: root.bodyLength + root.capGap
    readonly property real capBreadth: Math.max(1, Math.round(1.25 * root.unit))
    readonly property real capSpan: Math.round(6 * root.unit)

    implicitWidth: root.vertical ? Math.round(14 * root.unit) : root.capOffset + root.capBreadth
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

    StyledTextMetrics {
        id: signMetrics

        font.weight: root.glyphWeight
        font.pixelSize: Math.max(1, root.baseTextSize * root.signRatio)
        text: root.signText
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

    Rectangle {
        id: cap

        x: root.vertical ? (root.width - root.capSpan) / 2 : root.capOffset
        y: root.vertical ? 0 : (root.height - root.capSpan) / 2
        width: root.vertical ? root.capSpan : root.capBreadth
        height: root.vertical ? root.capBreadth : root.capSpan
        radius: root.capBreadth / 2
        color: root.outlined ? root.fillColor : root.dimColor
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

    Item {
        visible: root.glyphsVisible
        width: root.width
        height: root.height

        NumericText {
            id: numberGlyph

            isMonospace: false
            visible: root.numberInside
            x: root.textCanvasLeft + (root.textCanvasWidth - implicitWidth - signGlyph.implicitWidth) / 2
            y: root.textBaseline - baselineOffset
            text: root.numberText
            color: root.glyphColor
            font.weight: root.glyphWeight
            font.pixelSize: Math.max(1, root.textSize)
        }

        StyledText {
            id: signGlyph

            visible: root.numberInside && root.signText !== ""
            x: numberGlyph.x + numberGlyph.implicitWidth
            anchors.verticalCenter: numberGlyph.verticalCenter
            text: root.signText
            color: root.glyphColor
            font.weight: root.glyphWeight
            font.pixelSize: root.signSize
        }

        Bolt {
            visible: root.boltInside
            x: root.vertical ? (root.width - width) / 2 : 2 * root.unit + (6 * root.unit - width) / 2
            y: root.vertical ? (root.height - height) / 2 : 4 * root.unit
            fillColor: root.glyphColor
        }
    }
}
