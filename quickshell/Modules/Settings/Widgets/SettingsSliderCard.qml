pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    property string tab: ""
    property var tags: []

    property string title: ""
    property string description: ""
    property string iconName: ""
    property alias value: slider.value
    property alias minimum: slider.minimum
    property alias maximum: slider.maximum
    property alias unit: slider.unit
    property int defaultValue: -1

    signal sliderValueChanged(int newValue)

    width: parent?.width ?? 0
    height: Theme.spacingL * 2 + contentColumn.height
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

    Column {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacingL
        anchors.rightMargin: Theme.spacingL
        spacing: Theme.spacingS

        Row {
            width: parent.width
            spacing: Theme.spacingM

            DankIcon {
                id: headerIcon
                name: root.iconName
                size: Theme.iconSize
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
                visible: root.iconName !== ""
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS
                width: parent.width - headerIcon.width - (root.defaultValue >= 0 ? resetButton.width + Theme.spacingS : 0) - Theme.spacingM

                StyledText {
                    text: root.title
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    visible: root.title !== ""
                }

                StyledText {
                    text: root.description
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    width: parent.width
                    visible: root.description !== ""
                }
            }

            DankActionButton {
                id: resetButton
                anchors.verticalCenter: parent.verticalCenter
                buttonSize: 36
                iconName: "restart_alt"
                iconSize: 20
                visible: root.defaultValue >= 0 && slider.value !== root.defaultValue
                backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                iconColor: Theme.surfaceVariantText
                onClicked: {
                    slider.value = root.defaultValue;
                    root.sliderValueChanged(root.defaultValue);
                }
            }
        }

        DankSlider {
            id: slider
            width: parent.width
            height: 32
            showValue: true
            wheelEnabled: false
            thumbOutlineColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
            onSliderValueChanged: newValue => root.sliderValueChanged(newValue)
        }
    }
}
