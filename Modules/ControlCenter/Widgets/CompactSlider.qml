import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string iconName: ""
    property color iconColor: Theme.surfaceText
    property string labelText: ""
    property real value: 0.0
    property real maximumValue: 1.0
    property real minimumValue: 0.0
    property bool enabled: true

    signal sliderValueChanged(real value)

    width: parent ? parent.width : 200
    height: 60
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 0
    opacity: enabled ? 1.0 : 0.6

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacingM
        anchors.right: sliderContainer.left
        anchors.rightMargin: Theme.spacingS
        spacing: Theme.spacingS

        DankIcon {
            name: root.iconName
            size: Theme.iconSize
            color: root.iconColor
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: root.labelText
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Rectangle {
        id: sliderContainer
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: Theme.spacingM
        width: 120
        height: parent.height - Theme.spacingS * 2

        DankSlider {
            anchors.centerIn: parent
            width: parent.width
            enabled: root.enabled
            minimum: Math.round(root.minimumValue * 100)
            maximum: Math.round(root.maximumValue * 100)
            value: Math.round(root.value * 100)
            onSliderValueChanged: root.sliderValueChanged(newValue / 100.0)
        }
    }
}