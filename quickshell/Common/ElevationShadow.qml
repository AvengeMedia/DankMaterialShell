pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.Common

Item {
    id: root

    property var level: Theme.elevationLevel2
    property string direction: Theme.elevationLightDirection
    property real fallbackOffset: 4

    property color targetColor: "white"
    property real targetRadius: Theme.cornerRadius
    property color borderColor: "transparent"
    property real borderWidth: 0

    property bool shadowEnabled: Theme.elevationEnabled
    property real shadowBlurPx: level && level.blurPx !== undefined ? level.blurPx : 0
    property real shadowSpreadPx: level && level.spreadPx !== undefined ? level.spreadPx : 0
    property real shadowOffsetX: Theme.elevationOffsetXFor(level, direction, fallbackOffset)
    property real shadowOffsetY: Theme.elevationOffsetYFor(level, direction, fallbackOffset)
    property color shadowColor: Theme.elevationShadowColor(level)
    property real shadowOpacity: 1
    property real blurMax: Theme.elevationBlurMax

    property alias sourceRect: sourceRect

    layer.enabled: shadowEnabled

    layer.effect: MultiEffect {
        autoPaddingEnabled: true
        shadowEnabled: true
        blurEnabled: false
        maskEnabled: false
        shadowBlur: Math.max(0, Math.min(1, root.shadowBlurPx / Math.max(1, root.blurMax)))
        shadowScale: 1 + (2 * root.shadowSpreadPx) / Math.max(1, Math.min(root.width, root.height))
        shadowHorizontalOffset: root.shadowOffsetX
        shadowVerticalOffset: root.shadowOffsetY
        blurMax: root.blurMax
        shadowColor: root.shadowColor
        shadowOpacity: root.shadowOpacity
    }

    Rectangle {
        id: sourceRect
        anchors.fill: parent
        radius: root.targetRadius
        color: root.targetColor
        border.color: root.borderColor
        border.width: root.borderWidth
    }
}
