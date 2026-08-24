pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    required property var systemModel

    Column {
        anchors {
            fill: parent
            margins: Theme.spacingXL
        }
        spacing: Theme.spacingL

        Row {
            width: parent.width
            spacing: Theme.spacingM

            Rectangle {
                width: 48
                height: 48
                radius: 18
                color: Theme.primaryContainer

                DankIcon {
                    anchors.centerIn: parent
                    name: root.systemModel.iconName
                    size: 27
                    color: Theme.primary
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.systemModel.volumeActivity
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.systemModel.toggleMute()
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 48 - valueText.width - parent.spacing * 2
                spacing: Theme.spacingXXS

                StyledText {
                    text: root.systemModel.title
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                }

                StyledText {
                    text: root.systemModel.volumeActivity ? I18n.tr("Click the icon to mute", "island volume face: hint under the title") : I18n.tr("Display brightness control", "island brightness face: hint under the title")
                    color: Theme.surfaceTextSecondary
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            StyledText {
                id: valueText

                anchors.verticalCenter: parent.verticalCenter
                text: root.systemModel.displayValue
                color: Theme.primary
                font.pixelSize: 28
                font.weight: Font.DemiBold
            }
        }

        DankSlider {
            id: levelSlider

            width: parent.width
            height: 40
            minimum: root.systemModel.minimum
            maximum: Math.max(root.systemModel.minimum + 1, Math.round(root.systemModel.maximum))
            enabled: root.systemModel.available
            showValue: false
            unit: root.systemModel.unit
            thumbOutlineColor: Theme.surfaceContainerHigh
            valueOverride: Math.round(root.systemModel.value)
            onSliderValueChanged: newValue => root.systemModel.setRatio(newValue / maximum)

            Binding on value {
                value: Math.round(root.systemModel.value)
                when: !levelSlider.isDragging
            }
        }
    }
}
