import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets

DesktopWidgetInstanceSettings {
    id: root

    readonly property bool analog: cfg.style === "analog"

    SettingsDropdownRow {
        text: I18n.tr("Clock style")
        options: [I18n.tr("Digital"), I18n.tr("Analog"), I18n.tr("Stacked", "desktop clock style option")]
        currentValue: {
            switch (root.cfg.style) {
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
        visible: root.analog
    }

    SettingsToggleRow {
        visible: root.analog
        text: I18n.tr("Show hour numbers")
        checked: root.cfg.showAnalogNumbers ?? false
        onToggled: checked => root.updateConfig("showAnalogNumbers", checked)
    }

    SettingsDivider {
        visible: root.analog
    }

    SettingsToggleRow {
        visible: root.analog
        text: I18n.tr("Show seconds")
        checked: root.cfg.showAnalogSeconds ?? true
        onToggled: checked => root.updateConfig("showAnalogSeconds", checked)
    }

    SettingsDivider {
        visible: !root.analog
    }

    SettingsToggleRow {
        visible: !root.analog
        text: I18n.tr("Show seconds")
        checked: root.cfg.showDigitalSeconds ?? false
        onToggled: checked => root.updateConfig("showDigitalSeconds", checked)
    }

    SettingsDivider {}

    SettingsToggleRow {
        text: I18n.tr("Show date")
        checked: root.cfg.showDate ?? true
        onToggled: checked => root.updateConfig("showDate", checked)
    }
}
