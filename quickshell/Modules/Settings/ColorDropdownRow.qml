pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Column {
    id: root

    property string text: ""
    property string description: ""
    property string settingKey: ""
    property string tab: ""
    property var tags: []
    property var options: []
    property string currentMode: "default"
    property color customColor: "#6750A4"
    property string pickerTitle: text
    property int dropdownWidth: 230
    property color defaultColor: Theme.primary

    readonly property var optionColorMap: {
        var map = {};
        for (var i = 0; i < options.length; i++)
            map[options[i].label] = root.colorForValue(options[i].value);
        return map;
    }

    function colorForValue(value) {
        switch (value) {
        case "custom":
            return root.customColor;
        case "none":
            return "transparent";
        case "default":
            return root.defaultColor;
        default:
            return Theme.roleColor(value);
        }
    }

    signal modeSelected(string mode)
    signal customColorSelected(color selectedColor)

    width: parent?.width ?? 0
    spacing: Theme.spacingS

    function optionLabels() {
        return options.map(option => option.label);
    }

    function optionLabel(value) {
        for (var i = 0; i < options.length; i++) {
            if (options[i].value === value)
                return options[i].label;
        }
        return options.length > 0 ? options[0].label : "";
    }

    function optionValue(label) {
        for (var i = 0; i < options.length; i++) {
            if (options[i].label === label)
                return options[i].value;
        }
        return options.length > 0 ? options[0].value : "default";
    }

    function openCustomColorPicker() {
        PopoutService.colorPickerModal.selectedColor = root.customColor;
        PopoutService.colorPickerModal.pickerTitle = root.pickerTitle;
        PopoutService.colorPickerModal.onColorSelectedCallback = function (selectedColor) {
            root.customColorSelected(selectedColor);
            root.modeSelected("custom");
        };
        PopoutService.colorPickerModal.show();
    }

    SettingsDropdownRow {
        text: root.text
        description: root.description
        tab: root.tab
        settingKey: root.settingKey
        tags: root.tags
        options: root.optionLabels()
        optionColorMap: root.optionColorMap
        currentValue: root.optionLabel(root.currentMode)
        dropdownWidth: root.dropdownWidth
        onValueChanged: value => root.modeSelected(root.optionValue(value))
    }

    Item {
        width: parent.width
        height: root.currentMode === "custom" ? customChip.height : 0
        opacity: root.currentMode === "custom" ? 1 : 0
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        Rectangle {
            id: customChip

            width: parent.width
            height: 56
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                spacing: Theme.spacingM

                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    color: root.customColor
                    border.color: Theme.outline
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    DankIcon {
                        anchors.centerIn: parent
                        name: "colorize"
                        size: 16
                        color: (root.customColor.r * 0.299 + root.customColor.g * 0.587 + root.customColor.b * 0.114) > 0.5 ? "#000000" : "#ffffff"
                    }
                }

                Column {
                    width: parent.width - 36 - editIcon.width - Theme.spacingM * 2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    StyledText {
                        text: I18n.tr("Custom Color")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        width: parent.width
                        horizontalAlignment: Text.AlignLeft
                    }

                    StyledText {
                        text: root.customColor.toString()
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        width: parent.width
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignLeft
                    }
                }

                DankIcon {
                    id: editIcon
                    name: "edit"
                    size: Theme.iconSizeSmall
                    color: Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StateLayer {
                stateColor: Theme.surfaceText
                onClicked: root.openCustomColorPicker()
            }
        }
    }
}
