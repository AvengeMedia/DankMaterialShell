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

    width: parent?.width ?? 0
    spacing: Theme.spacingL

    SettingsCard {
        title: I18n.tr("General")
        settingKey: "workspaceSettings"

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
    }

    WorkspaceAppearanceCard {
        store: root.page.store
    }

    SettingsCard {
        title: I18n.tr("Icons")
        settingKey: "workspaceIcons"
        visible: NiriService.hasNamedWorkspaces()

        Repeater {
            model: NiriService.getNamedWorkspaces()

            SettingsRow {
                required property string modelData

                title: modelData

                DankIconPicker {
                    id: iconPicker
                    anchors.verticalCenter: parent.verticalCenter

                    Component.onCompleted: {
                        const iconData = SettingsData.getWorkspaceNameIcon(modelData);
                        if (iconData)
                            setIcon(iconData.value, iconData.type);
                    }

                    onIconSelected: (iconName, iconType) => {
                        SettingsData.setWorkspaceNameIcon(modelData, {
                            "type": iconType,
                            "value": iconName
                        });
                        setIcon(iconName, iconType);
                    }

                    Connections {
                        target: SettingsData
                        function onWorkspaceIconsUpdated() {
                            const iconData = SettingsData.getWorkspaceNameIcon(modelData);
                            if (iconData) {
                                iconPicker.setIcon(iconData.value, iconData.type);
                                return;
                            }
                            iconPicker.setIcon("", "icon");
                        }
                    }
                }

                DankActionButton {
                    buttonSize: Theme.iconButtonSize
                    iconName: "close"
                    Accessible.name: I18n.tr("Remove")
                    iconSize: Theme.iconSizeMedium
                    iconColor: Theme.error
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: SettingsData.removeWorkspaceNameIcon(modelData)
                }
            }
        }
    }

    SettingsCard {
        title: I18n.tr("Advanced")
        settingKey: "workspaceAdvanced"
        collapsible: true
        expanded: false

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["showWorkspacePadding"]
            text: I18n.tr("Padding")
            checked: root.page.value("showWorkspacePadding")
            onToggled: checked => root.page.set("showWorkspacePadding", checked)
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
