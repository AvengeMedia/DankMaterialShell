import QtQuick
import qs.Common
import qs.Widgets
import "../../Common/QmlUtils.js" as QmlUtils

Column {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    property int defaultValue: 0
    property int value: defaultValue
    property int minimum: 0
    property int maximum: 100
    property string leftIcon: ""
    property string rightIcon: ""
    property string unit: ""

    width: parent.width
    spacing: Theme.spacingS

    function loadValue() {
        const settings = QmlUtils.findSettings(root.parent);
        if (settings && settings.pluginService) {
            value = settings.loadValue(settingKey, defaultValue);
        }
    }

    Component.onCompleted: {
        loadValue();
    }

    onValueChanged: {
        const settings = QmlUtils.findSettings(root.parent);
        if (settings) {
            settings.saveValue(settingKey, value);
        }
    }

    StyledText {
        text: root.label
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        text: root.description
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        width: parent.width
        wrapMode: Text.WordWrap
        visible: root.description !== ""
    }

    DankSlider {
        width: parent.width
        value: root.value
        minimum: root.minimum
        maximum: root.maximum
        leftIcon: root.leftIcon
        rightIcon: root.rightIcon
        unit: root.unit
        wheelEnabled: false
        thumbOutlineColor: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
        onSliderValueChanged: newValue => {
            root.value = newValue;
        }
    }
}
