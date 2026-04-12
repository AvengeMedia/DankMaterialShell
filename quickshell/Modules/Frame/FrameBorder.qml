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
    property color borderColor: Qt.rgba(SettingsData.effectiveFrameColor.r, SettingsData.effectiveFrameColor.g, SettingsData.effectiveFrameColor.b, SettingsData.frameOpacity)

    Rectangle {
        id: borderRect

        anchors.fill: parent
        // Bake frameOpacity into the color alpha rather than using the `opacity` property
        color: root.borderColor

        layer.enabled: true
        layer.effect: MultiEffect {
            maskSource: cutoutMask
            maskEnabled: true
            maskInverted: true
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }

    Item {
        id: cutoutMask

        anchors.fill: parent
        layer.enabled: true
        visible: false

        Rectangle {
            anchors {
                fill: parent
                topMargin: root.cutoutTopInset
                bottomMargin: root.cutoutBottomInset
                leftMargin: root.cutoutLeftInset
                rightMargin: root.cutoutRightInset
            }
            radius: root.cutoutRadius
        }
    }
}
