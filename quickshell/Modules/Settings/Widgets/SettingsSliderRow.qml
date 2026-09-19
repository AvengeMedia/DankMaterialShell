import QtQuick
import qs.Common
import qs.Widgets

SettingsRow {
    id: root

    property string text: ""
    property string description: ""
    property string minimumLabel: ""
    property real value: 0
    property alias minimum: slider.minimum
    property alias maximum: slider.maximum
    property alias step: slider.step
    property alias showStops: slider.showStops
    property alias unit: slider.unit
    property alias decimals: slider.decimals
    property alias thumbOutlineColor: slider.thumbOutlineColor
    property alias size: slider.size

    readonly property bool atMinimum: minimumLabel !== "" && slider.value === slider.minimum
    readonly property int stepAmount: Math.max(1, step)

    signal sliderValueChanged(int newValue)
    signal sliderDragFinished(int finalValue)

    function nudge(direction) {
        const next = Math.max(minimum, Math.min(maximum, slider.value + direction * stepAmount));
        if (next === slider.value)
            return;
        slider.value = next;
        sliderValueChanged(next);
        sliderDragFinished(next);
    }

    function resync() {
        slider.value = Math.round(value);
    }

    title: text
    subtitle: description
    onValueChanged: resync()

    StyledText {
        text: root.minimumLabel
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        visible: root.atMinimum
        anchors.verticalCenter: parent.verticalCenter
    }

    body: Row {
        width: parent.width
        spacing: Theme.spacingS

        DankActionButton {
            buttonSize: Theme.iconButtonSize
            iconName: "remove"
            Accessible.name: I18n.tr("Decrease", "verb, minus button next to a settings slider")
            iconSize: Theme.iconSizeMedium
            iconColor: Theme.surfaceVariantText
            enabled: root.enabled && slider.value > slider.minimum
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.nudge(-1)
        }

        DankSlider {
            id: slider
            Accessible.name: root.text
            Accessible.description: root.description
            size: "s"
            width: parent.width - (Theme.iconButtonSize + parent.spacing) * 2
            anchors.verticalCenter: parent.verticalCenter
            enabled: root.enabled
            showValue: !root.atMinimum
            wheelEnabled: root.wheelEnabled
            Component.onCompleted: value = Math.round(root.value)
            onSliderValueChanged: newValue => root.sliderValueChanged(newValue)
            onSliderDragFinished: finalValue => root.sliderDragFinished(finalValue)
        }

        DankActionButton {
            buttonSize: Theme.iconButtonSize
            iconName: "add"
            Accessible.name: I18n.tr("Increase", "verb, plus button next to a settings slider")
            iconSize: Theme.iconSizeMedium
            iconColor: Theme.surfaceVariantText
            enabled: root.enabled && slider.value < slider.maximum
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.nudge(1)
        }
    }
}
