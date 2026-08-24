pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property string iconName: "volume_up"
    property color iconColor: Theme.surfaceText
    property color iconHoverColor: Theme.primary
    property real iconSize: Theme.iconSize
    property bool iconInteractive: false
    property int value: 0
    property int minimum: 0
    property int maximum: 100
    property string unit: "%"
    property string displayText: ""
    property bool sliderEnabled: true
    property color thumbOutlineColor: Theme.surfaceContainer
    property real horizontalPadding: -1

    readonly property bool containsMouse: iconArea.containsMouse || levelSlider.containsMouse
    readonly property bool showValueColumn: SettingsData.osdAlwaysShowValue
    readonly property alias isDragging: levelSlider.isDragging
    readonly property real effectiveHorizontalPadding: root.horizontalPadding >= 0 ? root.horizontalPadding : Math.max(Theme.spacingS, Math.round((height - root.iconSize) / 2))

    signal sliderValueChanged(int newValue)
    signal iconClicked
    signal hoverChanged(bool hovered)

    onContainsMouseChanged: root.hoverChanged(root.containsMouse)

    height: 40

    Item {
        id: iconSlot

        width: root.iconSize
        height: root.iconSize
        anchors {
            left: parent.left
            leftMargin: root.effectiveHorizontalPadding
            verticalCenter: parent.verticalCenter
        }

        DankIcon {
            anchors.centerIn: parent
            name: root.iconName
            size: root.iconSize
            color: iconArea.containsMouse && root.iconInteractive ? root.iconHoverColor : root.iconColor
        }

        MouseArea {
            id: iconArea

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: root.iconInteractive ? Qt.LeftButton : Qt.NoButton
            cursorShape: root.iconInteractive ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (root.iconInteractive)
                    root.iconClicked();
            }
        }
    }

    DankSlider {
        id: levelSlider

        anchors {
            left: iconSlot.right
            leftMargin: Theme.spacingS
            right: valueSlot.left
            rightMargin: root.showValueColumn ? Theme.spacingS : root.effectiveHorizontalPadding
            verticalCenter: parent.verticalCenter
        }
        height: 40
        minimum: root.minimum
        maximum: Math.max(root.minimum + 1, root.maximum)
        enabled: root.sliderEnabled
        showValue: false
        unit: root.unit
        thumbOutlineColor: root.thumbOutlineColor
        valueOverride: root.value
        onSliderValueChanged: newValue => root.sliderValueChanged(newValue)

        Binding on value {
            value: root.value
            when: !levelSlider.isDragging
        }
    }

    Item {
        id: valueSlot

        anchors {
            right: parent.right
            rightMargin: root.showValueColumn ? root.effectiveHorizontalPadding : 0
            top: parent.top
            bottom: parent.bottom
        }
        width: root.showValueColumn ? valueLabel.reservedWidth : 0
        visible: root.showValueColumn

        NumericText {
            id: valueLabel

            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
            }
            text: root.displayText.length > 0 ? root.displayText : (Math.round(root.value) + root.unit)
            reserveText: {
                const samples = [root.minimum, root.maximum, root.value];
                let widest = Math.round(root.maximum) + root.unit;
                for (let i = 0; i < samples.length; i++) {
                    const candidate = Math.round(samples[i]) + root.unit;
                    if (candidate.length > widest.length)
                        widest = candidate;
                }
                return widest;
            }
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }
    }
}
