pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

// Frame perimeter ring: the full window rectangle with a rounded-rectangle
// cutout, rendered as a signed-distance field with analytic antialiasing.
// One primitive: no full-output mask textures, no corner double-blend, crisp
// edges at any scale without an FBO.
Item {
    id: root

    anchors.fill: parent

    required property real cutoutTopInset
    required property real cutoutBottomInset
    required property real cutoutLeftInset
    required property real cutoutRightInset
    required property real cutoutRadius
    property color borderColor: Qt.rgba(SettingsData.effectiveFrameColor.r, SettingsData.effectiveFrameColor.g, SettingsData.effectiveFrameColor.b, SettingsData.frameOpacity)

    ShaderEffect {
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("../../Shaders/qsb/frame_arc.frag.qsb")

        property real widthPx: width
        property real heightPx: height
        property real cutoutRadius: root.cutoutRadius
        property vector4d cutout: Qt.vector4d(root.cutoutLeftInset, root.cutoutTopInset, root.width - root.cutoutRightInset, root.height - root.cutoutBottomInset)
        property vector4d surfaceColor: Qt.vector4d(root.borderColor.r, root.borderColor.g, root.borderColor.b, root.borderColor.a)
    }
}
