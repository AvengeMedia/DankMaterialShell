pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.Common

Item {
    id: root

    required property string barEdge      // "top" | "bottom" | "left" | "right" | ""
    required property real   barThickness

    anchors.fill: parent

    readonly property real _thickness: SettingsData.frameThickness
    readonly property real _rounding:  SettingsData.frameRounding

    Rectangle {
        id: borderRect

        anchors.fill: parent
        color:   SettingsData.frameColor
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
                topMargin:    root.barEdge === "top"    ? root.barThickness : root._thickness
                bottomMargin: root.barEdge === "bottom" ? root.barThickness : root._thickness
                leftMargin:   root.barEdge === "left"   ? root.barThickness : root._thickness
                rightMargin:  root.barEdge === "right"  ? root.barThickness : root._thickness
            }
            radius: root._rounding
        }
    }
}
