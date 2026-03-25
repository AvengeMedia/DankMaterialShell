pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.Common

Item {
    id: root

    anchors.fill: parent

    required property var barEdges

    readonly property real _thickness:    SettingsData.frameThickness
    readonly property real _barThickness: SettingsData.frameBarThickness
    readonly property real _rounding:     SettingsData.frameRounding

    Rectangle {
        id: borderRect

        anchors.fill: parent
        color:   SettingsData.effectiveFrameColor
        opacity: SettingsData.frameOpacity

        layer.enabled: true
        layer.effect: MultiEffect {
            maskSource:        cutoutMask
            maskEnabled:       true
            maskInverted:      true
            maskThresholdMin:  0.5
            maskSpreadAtMin:   1
        }
    }

    Item {
        id: cutoutMask

        anchors.fill: parent
        layer.enabled: true
        visible: false

        Rectangle {
            anchors {
                fill:         parent
                topMargin:    root.barEdges.includes("top")    ? root._barThickness : root._thickness
                bottomMargin: root.barEdges.includes("bottom") ? root._barThickness : root._thickness
                leftMargin:   root.barEdges.includes("left")   ? root._barThickness : root._thickness
                rightMargin:  root.barEdges.includes("right")  ? root._barThickness : root._thickness
            }
            radius: root._rounding
        }
    }
}
