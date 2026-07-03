pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets

Column {
    id: root

    property var borderColorOptions: []
    property string borderColorKey: ""
    property string borderCustomColorKey: ""
    property string borderThicknessKey: ""
    property var extraTags: []

    width: parent?.width ?? 0
    spacing: Theme.spacingS
    leftPadding: Theme.spacingM

    ColorDropdownRow {
        width: parent.width - parent.leftPadding
        text: I18n.tr("Border Color")
        settingKey: root.borderColorKey
        tags: ["workspace", "focused", "border", "color", "custom"].concat(root.extraTags)
        options: root.borderColorOptions
        currentMode: SettingsData[root.borderColorKey]
        customColor: SettingsData[root.borderCustomColorKey] || "#6750A4"
        onModeSelected: mode => SettingsData.set(root.borderColorKey, mode)
        onCustomColorSelected: selectedColor => SettingsData.set(root.borderCustomColorKey, selectedColor.toString())
    }

    SettingsSliderRow {
        width: parent.width - parent.leftPadding
        text: I18n.tr("Thickness")
        value: SettingsData[root.borderThicknessKey]
        minimum: 1
        maximum: 6
        unit: "px"
        defaultValue: 2
        onSliderValueChanged: newValue => SettingsData.set(root.borderThicknessKey, newValue)
    }
}
