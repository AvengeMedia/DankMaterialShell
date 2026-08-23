pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property bool hovered: false
    property bool outlined: false

    readonly property real thickness: 14
    readonly property real bodyWidth: 30
    readonly property real level: Math.max(0, Math.min(100, BatteryService.batteryLevel))
    readonly property bool charging: BatteryService.batteryAvailable && BatteryService.isCharging
    readonly property bool lowState: BatteryService.batteryAvailable && BatteryService.isLowBattery && !BatteryService.isCharging
    readonly property color fillColor: root.lowState ? Theme.error : Theme.primary
    readonly property color onFillColor: {
        const c = root.fillColor;
        const lum = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
        return lum > 0.5 ? Qt.rgba(0, 0, 0, 0.9) : Qt.rgba(1, 1, 1, 0.95);
    }
    readonly property string numberText: Math.round(root.level).toString()
    readonly property int glyphSize: Math.round(root.thickness * 0.62)
    readonly property int boltSize: Math.round(root.thickness * 0.7)
    readonly property real nubBreadth: Math.round(root.thickness * 0.16)
    readonly property real nubSpan: Math.round(root.thickness * 0.46)

    width: root.bodyWidth + root.nubBreadth
    height: root.thickness

    component PillGlyphs: Row {
        id: glyphs

        property color glyphColor

        spacing: 2

        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.charging
            name: "bolt"
            size: root.boltSize
            color: glyphs.glyphColor
        }

        StyledText {
            id: numberGlyph

            anchors.verticalCenter: parent.verticalCenter
            // Digits have no descenders; sink by half the descent to optically center.
            anchors.verticalCenterOffset: Math.round(digitMetrics.descent / 2)
            text: root.numberText
            color: glyphs.glyphColor
            font.pixelSize: root.glyphSize
            font.weight: Font.Bold
        }

        FontMetrics {
            id: digitMetrics

            font: numberGlyph.font
        }
    }

    Rectangle {
        id: body

        anchors.left: parent.left
        width: root.bodyWidth
        height: root.thickness
        radius: Math.round(Math.min(width, height) * 0.34)
        color: root.outlined ? (root.hovered ? Theme.withAlpha(Theme.surfaceVariant, 0.45) : "transparent") : (root.hovered ? Theme.surfaceVariant : Theme.withAlpha(Theme.surfaceVariant, 0.9))
        border.width: root.outlined ? 1.2 : 0
        border.color: root.fillColor

        Rectangle {
            id: fill

            anchors {
                left: parent.left
                bottom: parent.bottom
                top: parent.top
                leftMargin: body.border.width
                bottomMargin: body.border.width
                topMargin: body.border.width
            }
            width: Math.round((body.width - body.border.width * 2) * root.level / 100)
            radius: Math.max(0, body.radius - body.border.width)
            color: root.outlined ? Theme.withAlpha(root.fillColor, 0.32) : root.fillColor

            Behavior on width {
                NumberAnimation {
                    duration: Theme.mediumDuration
                    easing.type: Theme.standardEasing
                }
            }
        }

        PillGlyphs {
            anchors.centerIn: parent
            glyphColor: Theme.surfaceText
        }

        Item {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: fill.width
            clip: true
            visible: !root.outlined

            Item {
                width: body.width
                height: body.height

                PillGlyphs {
                    anchors.centerIn: parent
                    glyphColor: root.onFillColor
                }
            }
        }
    }

    Rectangle {
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        width: root.nubBreadth
        height: root.nubSpan
        radius: Math.round(root.nubBreadth * 0.35)
        color: root.outlined ? root.fillColor : Theme.withAlpha(Theme.surfaceVariant, 0.9)
    }
}
