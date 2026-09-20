pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings
import qs.Modules.Settings.Widgets

Column {
    id: root

    property var page: null

    readonly property bool showApps: page.value("showWorkspaceApps")
    readonly property var indicatorStyleValues: ["pills", "lines", "cards"]

    width: parent?.width ?? 0
    spacing: Theme.spacingL

    SettingsCard {
        title: I18n.tr("General")
        settingKey: "workspaceSettings"

        SettingsButtonGroupRow {
            resetStore: root.page
            resetKeys: ["workspaceIndicatorStyle"]
            tags: ["workspace", "style", "lines", "cards", "pills"]
            text: I18n.tr("Style")
            model: [I18n.tr("Pills", "workspace indicator style"), I18n.tr("Lines", "workspace indicator style"), I18n.tr("Cards", "workspace indicator style")]
            currentIndex: Math.max(0, root.indicatorStyleValues.indexOf(root.page.value("workspaceIndicatorStyle")))
            onSelectionChanged: (index, selected) => {
                if (selected)
                    root.page.set("workspaceIndicatorStyle", root.indicatorStyleValues[index]);
            }
        }

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["showWorkspaceIndex"]
            text: I18n.tr("Index numbers")
            checked: root.page.value("showWorkspaceIndex")
            onToggled: checked => root.page.set("showWorkspaceIndex", checked)
        }

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["showWorkspaceName"]
            text: I18n.tr("Names", "toggle to show workspace names")
            checked: root.page.value("showWorkspaceName")
            onToggled: checked => root.page.set("showWorkspaceName", checked)
        }

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["showWorkspaceApps"]
            text: I18n.tr("Show apps")
            visible: CompositorService.supportsWorkspaces
            enabled: !CompositorService.isAqueous || (AqueousService.available && Quickshell.env("DMS_FORCE_EXTWS") !== "1")
            checked: root.showApps
            onToggled: checked => root.page.set("showWorkspaceApps", checked)
        }

        SettingsSliderRow {
            resetStore: root.page
            resetKeys: ["maxWorkspaceIcons"]
            enabled: root.showApps
            text: I18n.tr("Max apps to show")
            unit: ""
            value: root.page.value("maxWorkspaceIcons")
            minimum: 1
            maximum: 10
            onSliderValueChanged: newValue => root.page.set("maxWorkspaceIcons", newValue)
        }

        SettingsSliderRow {
            resetStore: root.page
            resetKeys: ["workspaceAppIconSizeOffset"]
            enabled: root.showApps
            text: I18n.tr("Icon size")
            value: root.page.value("workspaceAppIconSizeOffset")
            minimum: 0
            maximum: 10
            unit: "px"
            onSliderValueChanged: newValue => root.page.set("workspaceAppIconSizeOffset", newValue)
        }

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["showOccupiedWorkspacesOnly"]
            text: I18n.tr("Show occupied only")
            visible: CompositorService.supportsWorkspaces
            enabled: !CompositorService.isAqueous || (AqueousService.available && Quickshell.env("DMS_FORCE_EXTWS") !== "1")
            checked: root.page.value("showOccupiedWorkspacesOnly")
            onToggled: checked => root.page.set("showOccupiedWorkspacesOnly", checked)
        }

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["showSpecialWorkspaces"]
            text: I18n.tr("Show scratchpads")
            description: I18n.tr("Special workspaces appear last; click to show or hide")
            visible: CompositorService.isHyprland
            checked: root.page.value("showSpecialWorkspaces")
            onToggled: checked => root.page.set("showSpecialWorkspaces", checked)
        }
    }

    WorkspaceAppearanceCard {
        store: root.page.store
    }

    SettingsCard {
        title: I18n.tr("Advanced")
        settingKey: "workspaceAdvanced"
        collapsible: true
        expanded: false

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["showWorkspacePadding"]
            text: I18n.tr("Minimum workspaces")
            description: CompositorService.supportsPersistentWorkspaces ? I18n.tr("Workspaces up to the count are always shown and can be opened") : I18n.tr("Empty placeholders fill the switcher up to the count")
            checked: root.page.value("showWorkspacePadding")
            onToggled: checked => root.page.set("showWorkspacePadding", checked)
        }

        SettingsSliderRow {
            resetStore: root.page
            resetKeys: ["workspacePaddingCount"]
            enabled: root.page.value("showWorkspacePadding")
            text: I18n.tr("Workspace count")
            unit: ""
            value: root.page.value("workspacePaddingCount")
            minimum: 2
            maximum: 10
            onSliderValueChanged: newValue => root.page.set("workspacePaddingCount", newValue)
        }

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["groupWorkspaceApps"]
            enabled: root.showApps
            text: I18n.tr("Group apps")
            checked: root.page.value("groupWorkspaceApps")
            onToggled: checked => root.page.set("groupWorkspaceApps", checked)
        }

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["groupActiveWorkspaceApps"]
            enabled: root.showApps && root.page.value("groupWorkspaceApps")
            text: I18n.tr("Group on active workspace")
            checked: root.page.value("groupActiveWorkspaceApps")
            onToggled: checked => root.page.set("groupActiveWorkspaceApps", checked)
        }

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["workspaceActiveAppHighlightEnabled"]
            enabled: root.showApps
            text: I18n.tr("Highlight focused app")
            checked: root.page.value("workspaceActiveAppHighlightEnabled")
            onToggled: checked => root.page.set("workspaceActiveAppHighlightEnabled", checked)
        }

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["workspaceFollowFocus"]
            text: I18n.tr("Follow display focus")
            visible: CompositorService.supportsWorkspaceFollowFocus
            checked: root.page.value("workspaceFollowFocus")
            onToggled: checked => root.page.set("workspaceFollowFocus", checked)
        }

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["reverseScrolling"]
            text: I18n.tr("Reverse scroll direction")
            visible: CompositorService.supportsWorkspaces
            checked: root.page.value("reverseScrolling")
            onToggled: checked => root.page.set("reverseScrolling", checked)
        }

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["workspaceDragReorder"]
            text: I18n.tr("Drag to reorder")
            visible: CompositorService.isNiri
            checked: root.page.value("workspaceDragReorder")
            onToggled: checked => root.page.set("workspaceDragReorder", checked)
        }

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["dwlShowAllTags"]
            text: I18n.tr("Show all tags")
            visible: CompositorService.isMango
            checked: root.page.value("dwlShowAllTags")
            onToggled: checked => root.page.set("dwlShowAllTags", checked)
        }
    }
}
