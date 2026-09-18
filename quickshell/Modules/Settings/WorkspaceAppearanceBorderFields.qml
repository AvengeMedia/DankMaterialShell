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
    property var store: null

    width: parent?.width ?? 0
    spacing: Theme.spacingS
    leftPadding: Theme.spacingM

    ColorDropdownRow {
        width: parent.width - parent.leftPadding
        text: I18n.tr("Border color")
        settingKey: root.borderColorKey
        resetStore: root.store
        resetKeys: [root.borderColorKey, root.borderCustomColorKey]
        tags: ["workspace", "focused", "border", "color", "custom"].concat(root.extraTags)
        options: root.borderColorOptions
        currentMode: root.store.get(root.borderColorKey)
        customColor: root.store.get(root.borderCustomColorKey) || "#6750A4"
        onModeSelected: mode => root.store.set(root.borderColorKey, mode)
        onCustomColorSelected: selectedColor => root.store.set(root.borderCustomColorKey, selectedColor.toString())
    }

    SettingsSliderRow {
        width: parent.width - parent.leftPadding
        text: I18n.tr("Thickness")
        resetStore: root.store
        resetKeys: [root.borderThicknessKey]
        value: root.store.get(root.borderThicknessKey)
        minimum: 1
        maximum: 6
        unit: "px"
        onSliderValueChanged: newValue => root.store.set(root.borderThicknessKey, newValue)
    }
}
