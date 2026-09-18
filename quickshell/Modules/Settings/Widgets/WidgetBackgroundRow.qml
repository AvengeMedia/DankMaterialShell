import QtQuick
import qs.Common
import qs.Modules.Settings

ColorDropdownRow {
    id: root

    readonly property var widgetBackgroundOptions: [({
                "value": "sth",
                "label": I18n.tr("Overlay", "widget background color option"),
                "previewColor": Theme.blend(Theme.surfaceContainerHigh, Theme.surfaceText, 0.24)
            }), ({
                "value": "s",
                "label": I18n.tr("Surface", "widget background color option")
            }), ({
                "value": "sc",
                "label": I18n.tr("Surface Container", "widget background color option")
            }), ({
                "value": "sch",
                "label": I18n.tr("Surface High", "widget background color option")
            }), ({
                "value": "primaryContainer",
                "label": I18n.tr("Primary Container", "widget background color option")
            }), ({
                "value": "secondaryContainer",
                "label": I18n.tr("Secondary Container", "widget background color option")
            }), ({
                "value": "tertiaryContainer",
                "label": I18n.tr("Tertiary Container", "widget background color option")
            }), ({
                "value": "custom",
                "label": I18n.tr("Custom", "widget background color option")
            })]

    tags: ["widget", "background", "color", "surface", "material"]
    settingKey: "widgetBackgroundColor"
    resetKeys: ["widgetBackgroundColor", "widgetBackgroundCustomColor"]
    text: I18n.tr("Background")
    dropdownWidth: 220
    options: root.widgetBackgroundOptions
    currentMode: SettingsData.widgetBackgroundColor
    customColor: SettingsData.widgetBackgroundCustomColor || "#6750A4"
    pickerTitle: I18n.tr("Widget Background Color")
    onModeSelected: mode => SettingsData.set("widgetBackgroundColor", mode)
    onCustomColorSelected: selectedColor => SettingsData.set("widgetBackgroundCustomColor", selectedColor.toString())
}
