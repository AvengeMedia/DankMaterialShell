import QtQuick
import qs.Common
import qs.Services
import qs.Modules.Settings.Widgets

SettingsCard {
    id: root

    iconName: "palette"
    title: I18n.tr("Workspace Appearance")
    settingKey: "workspaceAppearance"
    collapsible: true
    expanded: false

    readonly property var focusedColorOptions: [({
                "value": "default",
                "label": I18n.tr("Primary", "workspace color option")
            }), ({
                "value": "primaryContainer",
                "label": I18n.tr("Primary Container", "workspace color option")
            }), ({
                "value": "secondary",
                "label": I18n.tr("Secondary", "workspace color option")
            }), ({
                "value": "secondaryContainer",
                "label": I18n.tr("Secondary Container", "workspace color option")
            }), ({
                "value": "tertiary",
                "label": I18n.tr("Tertiary", "workspace color option")
            }), ({
                "value": "tertiaryContainer",
                "label": I18n.tr("Tertiary Container", "workspace color option")
            }), ({
                "value": "s",
                "label": I18n.tr("Surface", "workspace color option")
            }), ({
                "value": "sc",
                "label": I18n.tr("Surface Container", "workspace color option")
            }), ({
                "value": "sch",
                "label": I18n.tr("Surface High", "workspace color option")
            }), ({
                "value": "schh",
                "label": I18n.tr("Surface Highest", "workspace color option")
            }), ({
                "value": "none",
                "label": I18n.tr("None", "workspace color option")
            }), ({
                "value": "custom",
                "label": I18n.tr("Custom", "workspace color option")
            })]

    readonly property var occupiedColorOptions: [({
                "value": "none",
                "label": I18n.tr("None", "workspace color option")
            }), ({
                "value": "primary",
                "label": I18n.tr("Primary", "workspace color option")
            }), ({
                "value": "primaryContainer",
                "label": I18n.tr("Primary Container", "workspace color option")
            }), ({
                "value": "sec",
                "label": I18n.tr("Secondary", "workspace color option")
            }), ({
                "value": "secondaryContainer",
                "label": I18n.tr("Secondary Container", "workspace color option")
            }), ({
                "value": "tertiary",
                "label": I18n.tr("Tertiary", "workspace color option")
            }), ({
                "value": "tertiaryContainer",
                "label": I18n.tr("Tertiary Container", "workspace color option")
            }), ({
                "value": "s",
                "label": I18n.tr("Surface", "workspace color option")
            }), ({
                "value": "sc",
                "label": I18n.tr("Surface Container", "workspace color option")
            }), ({
                "value": "sch",
                "label": I18n.tr("Surface High", "workspace color option")
            }), ({
                "value": "schh",
                "label": I18n.tr("Surface Highest", "workspace color option")
            }), ({
                "value": "custom",
                "label": I18n.tr("Custom", "workspace color option")
            })]

    readonly property var unfocusedColorOptions: [({
                "value": "default",
                "label": I18n.tr("Default", "workspace color option")
            }), ({
                "value": "surfaceText",
                "label": I18n.tr("Surface Text", "workspace color option")
            }), ({
                "value": "primary",
                "label": I18n.tr("Primary", "workspace color option")
            }), ({
                "value": "secondary",
                "label": I18n.tr("Secondary", "workspace color option")
            }), ({
                "value": "tertiary",
                "label": I18n.tr("Tertiary", "workspace color option")
            }), ({
                "value": "s",
                "label": I18n.tr("Surface", "workspace color option")
            }), ({
                "value": "sc",
                "label": I18n.tr("Surface Container", "workspace color option")
            }), ({
                "value": "sch",
                "label": I18n.tr("Surface High", "workspace color option")
            }), ({
                "value": "schh",
                "label": I18n.tr("Surface Highest", "workspace color option")
            }), ({
                "value": "custom",
                "label": I18n.tr("Custom", "workspace color option")
            })]

    readonly property var urgentColorOptions: [({
                "value": "default",
                "label": I18n.tr("Error", "workspace color option")
            }), ({
                "value": "primary",
                "label": I18n.tr("Primary", "workspace color option")
            }), ({
                "value": "primaryContainer",
                "label": I18n.tr("Primary Container", "workspace color option")
            }), ({
                "value": "secondary",
                "label": I18n.tr("Secondary", "workspace color option")
            }), ({
                "value": "secondaryContainer",
                "label": I18n.tr("Secondary Container", "workspace color option")
            }), ({
                "value": "tertiary",
                "label": I18n.tr("Tertiary", "workspace color option")
            }), ({
                "value": "tertiaryContainer",
                "label": I18n.tr("Tertiary Container", "workspace color option")
            }), ({
                "value": "s",
                "label": I18n.tr("Surface", "workspace color option")
            }), ({
                "value": "sc",
                "label": I18n.tr("Surface Container", "workspace color option")
            }), ({
                "value": "sch",
                "label": I18n.tr("Surface High", "workspace color option")
            }), ({
                "value": "custom",
                "label": I18n.tr("Custom", "workspace color option")
            })]

    readonly property var borderColorOptions: [({
                "value": "surfaceText",
                "label": I18n.tr("Surface Text", "workspace color option")
            }), ({
                "value": "primary",
                "label": I18n.tr("Primary", "workspace color option")
            }), ({
                "value": "primaryContainer",
                "label": I18n.tr("Primary Container", "workspace color option")
            }), ({
                "value": "secondary",
                "label": I18n.tr("Secondary", "workspace color option")
            }), ({
                "value": "secondaryContainer",
                "label": I18n.tr("Secondary Container", "workspace color option")
            }), ({
                "value": "tertiary",
                "label": I18n.tr("Tertiary", "workspace color option")
            }), ({
                "value": "tertiaryContainer",
                "label": I18n.tr("Tertiary Container", "workspace color option")
            }), ({
                "value": "custom",
                "label": I18n.tr("Custom", "workspace color option")
            })]

    readonly property bool workspaceStateColorsVisible: CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango
    readonly property bool urgentWorkspaceColorsVisible: workspaceStateColorsVisible || CompositorService.isSway || CompositorService.isScroll || CompositorService.isMiracle

    ColorDropdownRow {
        text: I18n.tr("Focused Color")
        settingKey: "workspaceColorMode"
        tags: ["workspace", "focused", "color", "custom"]
        options: root.focusedColorOptions
        currentMode: SettingsData.workspaceColorMode
        customColor: SettingsData.workspaceFocusedCustomColor || "#6750A4"
        onModeSelected: mode => SettingsData.set("workspaceColorMode", mode)
        onCustomColorSelected: selectedColor => SettingsData.set("workspaceFocusedCustomColor", selectedColor.toString())
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.15
    }

    ColorDropdownRow {
        text: I18n.tr("Occupied Color")
        settingKey: "workspaceOccupiedColorMode"
        tags: ["workspace", "occupied", "color", "custom"]
        visible: root.workspaceStateColorsVisible
        options: root.occupiedColorOptions
        currentMode: SettingsData.workspaceOccupiedColorMode
        customColor: SettingsData.workspaceOccupiedCustomColor || "#625B71"
        onModeSelected: mode => SettingsData.set("workspaceOccupiedColorMode", mode)
        onCustomColorSelected: selectedColor => SettingsData.set("workspaceOccupiedCustomColor", selectedColor.toString())
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.15
        visible: CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango
    }

    ColorDropdownRow {
        text: I18n.tr("Unfocused Color")
        settingKey: "workspaceUnfocusedColorMode"
        tags: ["workspace", "unfocused", "color", "custom"]
        options: root.unfocusedColorOptions
        defaultColor: Theme.surfaceText
        currentMode: SettingsData.workspaceUnfocusedColorMode
        customColor: SettingsData.workspaceUnfocusedCustomColor || "#49454E"
        onModeSelected: mode => SettingsData.set("workspaceUnfocusedColorMode", mode)
        onCustomColorSelected: selectedColor => SettingsData.set("workspaceUnfocusedCustomColor", selectedColor.toString())
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.15
        visible: CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango || CompositorService.isSway || CompositorService.isScroll || CompositorService.isMiracle
    }

    ColorDropdownRow {
        text: I18n.tr("Urgent Color")
        settingKey: "workspaceUrgentColorMode"
        tags: ["workspace", "urgent", "color", "custom"]
        visible: root.urgentWorkspaceColorsVisible
        options: root.urgentColorOptions
        defaultColor: Theme.error
        currentMode: SettingsData.workspaceUrgentColorMode
        customColor: SettingsData.workspaceUrgentCustomColor || "#B3261E"
        onModeSelected: mode => SettingsData.set("workspaceUrgentColorMode", mode)
        onCustomColorSelected: selectedColor => SettingsData.set("workspaceUrgentCustomColor", selectedColor.toString())
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.15
    }

    SettingsToggleRow {
        settingKey: "workspaceFocusedBorderEnabled"
        tags: ["workspace", "border", "outline", "focused", "ring"]
        text: I18n.tr("Focused Border")
        description: I18n.tr("Show an outline ring around the focused workspace indicator")
        checked: SettingsData.workspaceFocusedBorderEnabled
        onToggled: checked => SettingsData.set("workspaceFocusedBorderEnabled", checked)
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: SettingsData.workspaceFocusedBorderEnabled
        leftPadding: Theme.spacingM

        ColorDropdownRow {
            width: parent.width - parent.leftPadding
            text: I18n.tr("Border Color")
            settingKey: "workspaceFocusedBorderColor"
            tags: ["workspace", "focused", "border", "color", "custom"]
            options: root.borderColorOptions
            currentMode: SettingsData.workspaceFocusedBorderColor
            customColor: SettingsData.workspaceFocusedBorderCustomColor || "#6750A4"
            onModeSelected: mode => SettingsData.set("workspaceFocusedBorderColor", mode)
            onCustomColorSelected: selectedColor => SettingsData.set("workspaceFocusedBorderCustomColor", selectedColor.toString())
        }

        SettingsSliderRow {
            width: parent.width - parent.leftPadding
            text: I18n.tr("Thickness")
            value: SettingsData.workspaceFocusedBorderThickness
            minimum: 1
            maximum: 6
            unit: "px"
            defaultValue: 2
            onSliderValueChanged: newValue => SettingsData.set("workspaceFocusedBorderThickness", newValue)
        }
    }
}
