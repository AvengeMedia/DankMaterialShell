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
    tags: ["workspace", "focused", "color", "custom"]
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

        WorkspaceAppearanceColorOptions {
            focusedColorOptions: root.focusedColorOptions
            occupiedColorOptions: root.occupiedColorOptions
            unfocusedColorOptions: root.unfocusedColorOptions
            urgentColorOptions: root.urgentColorOptions
            occupiedColorVisible: root.workspaceStateColorsVisible
            urgentColorVisible: root.urgentWorkspaceColorsVisible
            focusedColorModeKey: "workspaceColorMode"
            focusedCustomColorKey: "workspaceFocusedCustomColor"
            occupiedColorModeKey: "workspaceOccupiedColorMode"
            occupiedCustomColorKey: "workspaceOccupiedCustomColor"
            unfocusedColorModeKey: "workspaceUnfocusedColorMode"
            unfocusedCustomColorKey: "workspaceUnfocusedCustomColor"
            urgentColorModeKey: "workspaceUrgentColorMode"
            urgentCustomColorKey: "workspaceUrgentCustomColor"
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

        WorkspaceAppearanceBorderFields {
            visible: SettingsData.workspaceFocusedBorderEnabled
            borderColorOptions: root.borderColorOptions
            borderColorKey: "workspaceFocusedBorderColor"
            borderCustomColorKey: "workspaceFocusedBorderCustomColor"
            borderThicknessKey: "workspaceFocusedBorderThickness"
        }
    }

    Column {
        id: unfocusedTab
        width: parent.width
        spacing: Theme.spacingM
        visible: workspaceTabBar.currentIndex === 1

        StyledText {
            width: parent.width
            visible: !BarWidgetService.focusedScreenDetectionSupported
            text: I18n.tr("Separate appearance for unfocused displays is not supported on this compositor.")
            wrapMode: Text.WordWrap
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeMedium
        }

        SettingsToggleRow {
            visible: BarWidgetService.focusedScreenDetectionSupported
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
            visible: BarWidgetService.focusedScreenDetectionSupported
        }

        Column {
            id: unfocusedOptions
            width: parent.width
            spacing: Theme.spacingM
            visible: BarWidgetService.focusedScreenDetectionSupported
            enabled: SettingsData.workspaceUnfocusedMonitorSeparateAppearance
            opacity: enabled ? 1 : 0.5

            WorkspaceAppearanceColorOptions {
                focusedColorOptions: root.focusedColorOptions
                occupiedColorOptions: root.occupiedColorOptions
                unfocusedColorOptions: root.unfocusedColorOptions
                urgentColorOptions: root.urgentColorOptions
                occupiedColorVisible: root.workspaceStateColorsVisible
                urgentColorVisible: root.urgentWorkspaceColorsVisible
                extraTags: ["unfocused", "monitor", "display"]
                focusedColorModeKey: "workspaceUnfocusedMonitorColorMode"
                focusedCustomColorKey: "workspaceUnfocusedMonitorFocusedCustomColor"
                occupiedColorModeKey: "workspaceUnfocusedMonitorOccupiedColorMode"
                occupiedCustomColorKey: "workspaceUnfocusedMonitorOccupiedCustomColor"
                unfocusedColorModeKey: "workspaceUnfocusedMonitorUnfocusedColorMode"
                unfocusedCustomColorKey: "workspaceUnfocusedMonitorUnfocusedCustomColor"
                urgentColorModeKey: "workspaceUnfocusedMonitorUrgentColorMode"
                urgentCustomColorKey: "workspaceUnfocusedMonitorUrgentCustomColor"
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

            WorkspaceAppearanceBorderFields {
                visible: SettingsData.workspaceUnfocusedMonitorBorderEnabled
                borderColorOptions: root.borderColorOptions
                extraTags: ["unfocused", "monitor", "display"]
                borderColorKey: "workspaceUnfocusedMonitorBorderColor"
                borderCustomColorKey: "workspaceUnfocusedMonitorBorderCustomColor"
                borderThicknessKey: "workspaceUnfocusedMonitorBorderThickness"
            }
        }
    }
}
