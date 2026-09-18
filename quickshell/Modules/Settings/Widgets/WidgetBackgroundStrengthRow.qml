import QtQuick
import qs.Common

SettingsSliderRow {
    visible: SettingsData.widgetBackgroundColor === "custom"
    tags: ["widget", "background", "color", "custom", "blend"]
    settingKey: "widgetBackgroundCustomStrength"
    text: I18n.tr("Custom blend")
    value: Math.round(SettingsData.widgetBackgroundCustomStrength * 100)
    minimum: 0
    maximum: 100
    onSliderValueChanged: newValue => SettingsData.set("widgetBackgroundCustomStrength", newValue / 100)
}
