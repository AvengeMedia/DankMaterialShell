pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

Item {
    id: root

    property var level: Theme.elevationLevel2
    property string direction: Theme.elevationLightDirection
    property real fallbackOffset: 4

    property color targetColor: "white"
    property real targetRadius: Theme.cornerRadius
    property real topLeftRadius: targetRadius
    property real topRightRadius: targetRadius
    property real bottomLeftRadius: targetRadius
    property real bottomRightRadius: targetRadius
    property color borderColor: "transparent"
    property real borderWidth: 0

    property real sourceX: 0
    property real sourceY: 0
    property real sourceWidth: width
    property real sourceHeight: height

    property bool shadowEnabled: Theme.elevationEnabled
    property real shadowBlurPx: level && level.blurPx !== undefined ? level.blurPx : 0
    property real shadowSpreadPx: level && level.spreadPx !== undefined ? level.spreadPx : 0
    property real shadowOffsetX: Theme.elevationOffsetXFor(level, direction, fallbackOffset)
    property real shadowOffsetY: Theme.elevationOffsetYFor(level, direction, fallbackOffset)
    property color shadowColor: Theme.elevationShadowColor(level)
    property real shadowOpacity: 1

    readonly property var _ambient: Theme.elevationAmbient(level)
    readonly property real _pad: shadowEnabled ? Math.ceil(Math.max(shadowBlurPx + shadowSpreadPx + Math.max(Math.abs(shadowOffsetX), Math.abs(shadowOffsetY)), _ambient.blurPx + _ambient.spreadPx) + 2) : 0

    ShaderEffect {
        anchors.fill: parent
        anchors.margins: -root._pad
        fragmentShader: Qt.resolvedUrl("../Shaders/qsb/elevation_rect.frag.qsb")

        property real widthPx: width
        property real heightPx: height
        property real borderWidth: root.borderWidth
        property vector4d rectPx: Qt.vector4d(root._pad + root.sourceX, root._pad + root.sourceY, root.sourceWidth, root.sourceHeight)
        property vector4d cornerRadius: Qt.vector4d(root.topLeftRadius, root.topRightRadius, root.bottomRightRadius, root.bottomLeftRadius)
        property vector4d fillColor: Qt.vector4d(root.targetColor.r, root.targetColor.g, root.targetColor.b, root.targetColor.a)
        property vector4d borderColor: Qt.vector4d(root.borderColor.r, root.borderColor.g, root.borderColor.b, root.borderColor.a)
        property vector4d shadowColor: Qt.vector4d(root.shadowColor.r, root.shadowColor.g, root.shadowColor.b, root.shadowEnabled ? root.shadowColor.a * root.shadowOpacity : 0)
        property vector4d shadowParam: Qt.vector4d(Math.max(0, root.shadowBlurPx), root.shadowSpreadPx, root.shadowOffsetX, root.shadowOffsetY)
        property vector4d ambientParam: Qt.vector4d(root._ambient.blurPx, root._ambient.spreadPx, root.shadowEnabled ? root._ambient.alpha * root.shadowOpacity : 0, 0)
    }
}
