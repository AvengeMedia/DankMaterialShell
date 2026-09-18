import QtQuick
import qs.Common

SettingsButtonGroupRow {
    tags: ["widget", "text", "style", "colorful", "default", "accent", "neutral"]
    settingKey: "widgetColorMode"
    text: I18n.tr("Text style")
    model: [I18n.tr("Default", "widget style option"), I18n.tr("Colorful", "widget style option")]
    currentIndex: SettingsData.widgetColorMode === "colorful" ? 1 : 0
    onSelectionChanged: (index, selected) => {
        if (!selected)
            return;
        SettingsData.set("widgetColorMode", index === 1 ? "colorful" : "default");
    }
}
