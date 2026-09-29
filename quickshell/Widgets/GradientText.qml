import QtQuick
import QtQuick.Effects
import qs.Common

// StyledText filled with a horizontal gradient; the glyphs are the mask.
Item {
    id: root

    property alias text: mask.text
    property alias font: mask.font
    property color startColor: Theme.surfaceText
    property color endColor: Theme.primary

    implicitWidth: mask.implicitWidth
    implicitHeight: mask.implicitHeight

    StyledText {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        color: root.startColor
    }

    Rectangle {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
        }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: root.startColor
            }
            GradientStop {
                position: 1
                color: root.endColor
            }
        }
    }
}
