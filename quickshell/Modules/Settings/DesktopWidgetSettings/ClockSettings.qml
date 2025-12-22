pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Settings.Widgets

Column {
    id: root

    property string instanceId: ""
    property var instanceData: null

    readonly property var cfg: instanceData?.config ?? {}

    function updateConfig(key, value) {
        if (!instanceId)
            return;
        var updates = {};
        updates[key] = value;
        SettingsData.updateDesktopWidgetInstanceConfig(instanceId, updates);
    }

    width: parent?.width ?? 400
    spacing: 0

    SettingsDropdownRow {
        text: I18n.tr("Clock Style")
        options: [I18n.tr("Digital"), I18n.tr("Analog"), I18n.tr("Stacked")]
        currentValue: {
            switch (cfg.style) {
            case "analog":
                return I18n.tr("Analog");
            case "stacked":
                return I18n.tr("Stacked");
            default:
                return I18n.tr("Digital");
            }
        }
        onValueChanged: value => {
            switch (value) {
            case I18n.tr("Analog"):
                root.updateConfig("style", "analog");
                return;
            case I18n.tr("Stacked"):
                root.updateConfig("style", "stacked");
                return;
            default:
                root.updateConfig("style", "digital");
            }
        }
    }

    SettingsDivider {
        visible: cfg.style === "analog"
    }

    SettingsToggleRow {
        visible: cfg.style === "analog"
        text: I18n.tr("Show Hour Numbers")
        checked: cfg.showAnalogNumbers ?? false
        onToggled: checked => root.updateConfig("showAnalogNumbers", checked)
    }

    SettingsDivider {
        visible: cfg.style === "analog"
    }

    SettingsToggleRow {
        visible: cfg.style === "analog"
        text: I18n.tr("Show Seconds")
        checked: cfg.showAnalogSeconds ?? true
        onToggled: checked => root.updateConfig("showAnalogSeconds", checked)
    }

    SettingsDivider {}

    SettingsToggleRow {
        text: I18n.tr("Show Date")
        checked: cfg.showDate ?? true
        onToggled: checked => root.updateConfig("showDate", checked)
    }

    SettingsDivider {}

    SettingsSliderRow {
        text: I18n.tr("Transparency")
        minimum: 0
        maximum: 100
        value: Math.round((cfg.transparency ?? 0.8) * 100)
        unit: "%"
        onSliderValueChanged: newValue => root.updateConfig("transparency", newValue / 100)
    }

    SettingsDivider {}

    SettingsColorPicker {
        colorMode: cfg.colorMode ?? "primary"
        customColor: cfg.customColor ?? "#ffffff"
        onColorModeSelected: mode => root.updateConfig("colorMode", mode)
        onCustomColorSelected: selectedColor => root.updateConfig("customColor", selectedColor.toString())
    }

    SettingsDivider {}

    SettingsDisplayPicker {
        displayPreferences: cfg.displayPreferences ?? ["all"]
        onPreferencesChanged: prefs => root.updateConfig("displayPreferences", prefs)
    }

    SettingsDivider {}

    Item {
        width: parent.width
        height: resetRow.height + Theme.spacingM * 2

        Row {
            id: resetRow
            x: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingM

            DankButton {
                text: I18n.tr("Reset Position")
                backgroundColor: Theme.surfaceHover
                textColor: Theme.surfaceText
                buttonHeight: 36
                onClicked: {
                    if (!root.instanceId)
                        return;
                    SettingsData.updateDesktopWidgetInstance(root.instanceId, {
                        positions: {}
                    });
                }
            }

            DankButton {
                text: I18n.tr("Reset Size")
                backgroundColor: Theme.surfaceHover
                textColor: Theme.surfaceText
                buttonHeight: 36
                onClicked: {
                    if (!root.instanceId)
                        return;
                    SettingsData.updateDesktopWidgetInstance(root.instanceId, {
                        positions: {}
                    });
                }
            }
        }
    }
}
