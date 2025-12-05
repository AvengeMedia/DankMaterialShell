pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property string tab: ""
    property var tags: []
    property string settingKey: ""

    property string text: ""
    property string description: ""
    property alias value: slider.value
    property alias minimum: slider.minimum
    property alias maximum: slider.maximum
    property alias unit: slider.unit
    property alias wheelEnabled: slider.wheelEnabled
    property alias thumbOutlineColor: slider.thumbOutlineColor
    property int defaultValue: -1

    signal sliderValueChanged(int newValue)

    width: parent?.width ?? 0
    height: headerRow.height + Theme.spacingXS + slider.height

    Column {
        id: contentColumn
        width: parent.width - Theme.spacingM * 2
        x: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXS

        Row {
            id: headerRow
            width: parent.width
            height: labelColumn.height
            spacing: Theme.spacingS

            Column {
                id: labelColumn
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS
                width: parent.width - resetButtonContainer.width - Theme.spacingS

                StyledText {
                    text: root.text
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    visible: root.text !== ""
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

            Item {
                id: resetButtonContainer
                width: root.defaultValue >= 0 ? 36 : 0
                height: 36
                anchors.verticalCenter: parent.verticalCenter

                DankActionButton {
                    id: resetButton
                    anchors.centerIn: parent
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
