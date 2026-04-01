pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.Common

Item {
    id: root

    anchors.fill: parent

    required property real cutoutTopInset
    required property real cutoutBottomInset
    required property real cutoutLeftInset
    required property real cutoutRightInset
    required property real cutoutRadius

    Rectangle {
        id: borderRect

        anchors.fill: parent
        // Bake frameOpacity into the color alpha rather than using the `opacity` property.
        // Qt Quick can skip layer.effect processing on items with opacity < 1 as an
        // optimization, causing the MultiEffect inverted mask to stop working and the
        // Rectangle to render as a plain square at low opacity values.
        color: Qt.rgba(SettingsData.effectiveFrameColor.r,
                       SettingsData.effectiveFrameColor.g,
                       SettingsData.effectiveFrameColor.b,
                       SettingsData.frameOpacity)

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
                topMargin:    root.cutoutTopInset
                bottomMargin: root.cutoutBottomInset
                leftMargin:   root.cutoutLeftInset
                rightMargin:  root.cutoutRightInset
            }
            radius: root.cutoutRadius
        }
    }
}
