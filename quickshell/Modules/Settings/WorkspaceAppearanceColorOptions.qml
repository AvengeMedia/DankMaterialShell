pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

Column {
    id: root

    property var focusedColorOptions: []
    property var occupiedColorOptions: []
    property var unfocusedColorOptions: []
    property var urgentColorOptions: []

    property bool occupiedColorVisible: true
    property bool urgentColorVisible: true

    property string focusedColorModeKey: ""
    property string focusedCustomColorKey: ""
    property string occupiedColorModeKey: ""
    property string occupiedCustomColorKey: ""
    property string unfocusedColorModeKey: ""
    property string unfocusedCustomColorKey: ""
    property string urgentColorModeKey: ""
    property string urgentCustomColorKey: ""

    property var extraTags: []

    width: parent?.width ?? 0
    spacing: Theme.spacingM

    ColorDropdownRow {
        text: I18n.tr("Focused Color")
        settingKey: root.focusedColorModeKey
        tags: ["workspace", "focused", "color", "custom"].concat(root.extraTags)
        options: root.focusedColorOptions
        currentMode: SettingsData[root.focusedColorModeKey]
        customColor: SettingsData[root.focusedCustomColorKey] || "#6750A4"
        onModeSelected: mode => SettingsData.set(root.focusedColorModeKey, mode)
        onCustomColorSelected: selectedColor => SettingsData.set(root.focusedCustomColorKey, selectedColor.toString())
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.15
    }

    ColorDropdownRow {
        text: I18n.tr("Occupied Color")
        settingKey: root.occupiedColorModeKey
        tags: ["workspace", "occupied", "color", "custom"].concat(root.extraTags)
        visible: root.occupiedColorVisible
        options: root.occupiedColorOptions
        currentMode: SettingsData[root.occupiedColorModeKey]
        customColor: SettingsData[root.occupiedCustomColorKey] || "#625B71"
        onModeSelected: mode => SettingsData.set(root.occupiedColorModeKey, mode)
        onCustomColorSelected: selectedColor => SettingsData.set(root.occupiedCustomColorKey, selectedColor.toString())
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.15
        visible: root.occupiedColorVisible
    }

    ColorDropdownRow {
        text: I18n.tr("Unfocused Color")
        settingKey: root.unfocusedColorModeKey
        tags: ["workspace", "unfocused", "color", "custom"].concat(root.extraTags)
        options: root.unfocusedColorOptions
        defaultColor: Theme.surfaceText
        currentMode: SettingsData[root.unfocusedColorModeKey]
        customColor: SettingsData[root.unfocusedCustomColorKey] || "#49454E"
        onModeSelected: mode => SettingsData.set(root.unfocusedColorModeKey, mode)
        onCustomColorSelected: selectedColor => SettingsData.set(root.unfocusedCustomColorKey, selectedColor.toString())
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.15
        visible: root.urgentColorVisible
    }

    ColorDropdownRow {
        text: I18n.tr("Urgent Color")
        settingKey: root.urgentColorModeKey
        tags: ["workspace", "urgent", "color", "custom"].concat(root.extraTags)
        visible: root.urgentColorVisible
        options: root.urgentColorOptions
        defaultColor: Theme.error
        currentMode: SettingsData[root.urgentColorModeKey]
        customColor: SettingsData[root.urgentCustomColorKey] || "#B3261E"
        onModeSelected: mode => SettingsData.set(root.urgentColorModeKey, mode)
        onCustomColorSelected: selectedColor => SettingsData.set(root.urgentCustomColorKey, selectedColor.toString())
    }
}
