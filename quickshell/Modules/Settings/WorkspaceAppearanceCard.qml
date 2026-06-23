import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
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

    function isFocusedAppearanceSection(section) {
        return ["workspaceAppearance", "workspaceColorMode", "workspaceOccupiedColorMode", "workspaceUnfocusedColorMode", "workspaceUrgentColorMode", "workspaceFocusedBorderEnabled", "workspaceFocusedBorderColor", "workspaceFocusedBorderThickness"].includes(section);
    }

    Item {
        width: parent.width
        height: workspaceTabBar.height + Theme.spacingM

        DankTabBar {
            id: workspaceTabBar
            width: parent.width
            tabHeight: 44
            showIcons: false
            model: [({
                    "text": I18n.tr("Focused Display", "workspace appearance tab")
                }), ({
                    "text": I18n.tr("Unfocused Display(s)", "workspace appearance tab")
                })]
            onTabClicked: index => currentIndex = index
            Component.onCompleted: Qt.callLater(updateIndicator)

            Connections {
                target: SettingsSearchService

                function onTargetSectionChanged() {
                    const section = SettingsSearchService.targetSection;
                    if (!section)
                        return;

                    if (section.startsWith("workspaceUnfocusedMonitor")) {
                        root.expanded = true;
                        workspaceTabBar.currentIndex = 1;
                    } else if (root.isFocusedAppearanceSection(section)) {
                        root.expanded = true;
                        workspaceTabBar.currentIndex = 0;
                    } else {
                        return;
                    }

                    Qt.callLater(workspaceTabBar.updateIndicator);
                }
            }
        }
    }

    Column {
        id: focusedTab
        width: parent.width
        spacing: Theme.spacingM
        visible: workspaceTabBar.currentIndex === 0

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
            visible: root.workspaceStateColorsVisible
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
            visible: root.urgentWorkspaceColorsVisible
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

    Column {
        id: unfocusedTab
        width: parent.width
        spacing: Theme.spacingM
        visible: workspaceTabBar.currentIndex === 1

        SettingsToggleRow {
            settingKey: "workspaceUnfocusedMonitorSeparateAppearance"
            tags: ["workspace", "unfocused", "monitor", "display", "separate", "color"]
            text: I18n.tr("Separate Appearance for Unfocused Display(s)")
            description: I18n.tr("Use different workspace colors on displays that are not focused")
            checked: SettingsData.workspaceUnfocusedMonitorSeparateAppearance
            onToggled: checked => SettingsData.set("workspaceUnfocusedMonitorSeparateAppearance", checked)
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outline
            opacity: 0.15
        }

        Column {
            id: unfocusedOptions
            width: parent.width
            spacing: Theme.spacingM
            enabled: SettingsData.workspaceUnfocusedMonitorSeparateAppearance
            opacity: enabled ? 1 : 0.5

            ColorDropdownRow {
                text: I18n.tr("Focused Color")
                settingKey: "workspaceUnfocusedMonitorColorMode"
                tags: ["workspace", "focused", "color", "custom", "unfocused", "monitor", "display"]
                options: root.focusedColorOptions
                currentMode: SettingsData.workspaceUnfocusedMonitorColorMode
                customColor: SettingsData.workspaceUnfocusedMonitorFocusedCustomColor || "#6750A4"
                onModeSelected: mode => SettingsData.set("workspaceUnfocusedMonitorColorMode", mode)
                onCustomColorSelected: selectedColor => SettingsData.set("workspaceUnfocusedMonitorFocusedCustomColor", selectedColor.toString())
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.outline
                opacity: 0.15
            }

            ColorDropdownRow {
                text: I18n.tr("Occupied Color")
                settingKey: "workspaceUnfocusedMonitorOccupiedColorMode"
                tags: ["workspace", "occupied", "color", "custom", "unfocused", "monitor", "display"]
                visible: root.workspaceStateColorsVisible
                options: root.occupiedColorOptions
                currentMode: SettingsData.workspaceUnfocusedMonitorOccupiedColorMode
                customColor: SettingsData.workspaceUnfocusedMonitorOccupiedCustomColor || "#625B71"
                onModeSelected: mode => SettingsData.set("workspaceUnfocusedMonitorOccupiedColorMode", mode)
                onCustomColorSelected: selectedColor => SettingsData.set("workspaceUnfocusedMonitorOccupiedCustomColor", selectedColor.toString())
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.outline
                opacity: 0.15
                visible: root.workspaceStateColorsVisible
            }

            ColorDropdownRow {
                text: I18n.tr("Unfocused Color")
                settingKey: "workspaceUnfocusedMonitorUnfocusedColorMode"
                tags: ["workspace", "unfocused", "color", "custom", "monitor", "display"]
                options: root.unfocusedColorOptions
                defaultColor: Theme.surfaceText
                currentMode: SettingsData.workspaceUnfocusedMonitorUnfocusedColorMode
                customColor: SettingsData.workspaceUnfocusedMonitorUnfocusedCustomColor || "#49454E"
                onModeSelected: mode => SettingsData.set("workspaceUnfocusedMonitorUnfocusedColorMode", mode)
                onCustomColorSelected: selectedColor => SettingsData.set("workspaceUnfocusedMonitorUnfocusedCustomColor", selectedColor.toString())
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.outline
                opacity: 0.15
                visible: root.urgentWorkspaceColorsVisible
            }

            ColorDropdownRow {
                text: I18n.tr("Urgent Color")
                settingKey: "workspaceUnfocusedMonitorUrgentColorMode"
                tags: ["workspace", "urgent", "color", "custom", "unfocused", "monitor", "display"]
                visible: root.urgentWorkspaceColorsVisible
                options: root.urgentColorOptions
                defaultColor: Theme.error
                currentMode: SettingsData.workspaceUnfocusedMonitorUrgentColorMode
                customColor: SettingsData.workspaceUnfocusedMonitorUrgentCustomColor || "#B3261E"
                onModeSelected: mode => SettingsData.set("workspaceUnfocusedMonitorUrgentColorMode", mode)
                onCustomColorSelected: selectedColor => SettingsData.set("workspaceUnfocusedMonitorUrgentCustomColor", selectedColor.toString())
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.outline
                opacity: 0.15
            }

            SettingsToggleRow {
                settingKey: "workspaceUnfocusedMonitorBorderEnabled"
                tags: ["workspace", "border", "outline", "focused", "ring", "unfocused", "monitor", "display"]
                text: I18n.tr("Focused Border")
                description: I18n.tr("Show an outline ring around the focused workspace indicator")
                checked: SettingsData.workspaceUnfocusedMonitorBorderEnabled
                onToggled: checked => SettingsData.set("workspaceUnfocusedMonitorBorderEnabled", checked)
            }

            Column {
                width: parent.width
                spacing: Theme.spacingS
                visible: SettingsData.workspaceUnfocusedMonitorBorderEnabled
                leftPadding: Theme.spacingM

                ColorDropdownRow {
                    width: parent.width - parent.leftPadding
                    text: I18n.tr("Border Color")
                    settingKey: "workspaceUnfocusedMonitorBorderColor"
                    tags: ["workspace", "focused", "border", "color", "custom", "unfocused", "monitor", "display"]
                    options: root.borderColorOptions
                    currentMode: SettingsData.workspaceUnfocusedMonitorBorderColor
                    customColor: SettingsData.workspaceUnfocusedMonitorBorderCustomColor || "#6750A4"
                    onModeSelected: mode => SettingsData.set("workspaceUnfocusedMonitorBorderColor", mode)
                    onCustomColorSelected: selectedColor => SettingsData.set("workspaceUnfocusedMonitorBorderCustomColor", selectedColor.toString())
                }

                SettingsSliderRow {
                    width: parent.width - parent.leftPadding
                    text: I18n.tr("Thickness")
                    value: SettingsData.workspaceUnfocusedMonitorBorderThickness
                    minimum: 1
                    maximum: 6
                    unit: "px"
                    defaultValue: 2
                    onSliderValueChanged: newValue => SettingsData.set("workspaceUnfocusedMonitorBorderThickness", newValue)
                }
            }
        }
    }
}
