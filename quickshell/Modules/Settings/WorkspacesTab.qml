import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn

            topPadding: Theme.spacingXL
            bottomPadding: Theme.spacingXL
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                width: parent.width
                iconName: "view_module"
                title: I18n.tr("Workspace Settings")
                settingKey: "workspaceSettings"

                SettingsToggleRow {
                    settingKey: "showWorkspaceIndex"
                    tags: ["workspace", "index", "numbers", "labels"]
                    text: I18n.tr("Workspace Index Numbers")
                    description: I18n.tr("Show workspace index numbers in the top bar workspace switcher")
                    checked: SettingsData.showWorkspaceIndex
                    onToggled: checked => SettingsData.set("showWorkspaceIndex", checked)
                }

                SettingsToggleRow {
                    settingKey: "showWorkspaceName"
                    tags: ["workspace", "name", "labels"]
                    text: I18n.tr("Workspace Names")
                    description: I18n.tr("Show workspace name on horizontal bars, and first letter on vertical bars")
                    checked: SettingsData.showWorkspaceName
                    onToggled: checked => SettingsData.set("showWorkspaceName", checked)
                }

                SettingsToggleRow {
                    settingKey: "showWorkspacePadding"
                    tags: ["workspace", "padding", "minimum"]
                    text: I18n.tr("Workspace Padding")
                    description: I18n.tr("Always show a minimum of 3 workspaces, even if fewer are available")
                    checked: SettingsData.showWorkspacePadding
                    onToggled: checked => SettingsData.set("showWorkspacePadding", checked)
                }

                SettingsToggleRow {
                    settingKey: "showWorkspaceApps"
                    tags: ["workspace", "apps", "icons", "applications"]
                    text: I18n.tr("Show Workspace Apps")
                    description: I18n.tr("Display application icons in workspace indicators")
                    checked: SettingsData.showWorkspaceApps
                    visible: CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango
                    onToggled: checked => SettingsData.set("showWorkspaceApps", checked)
                }

                Item {
                    width: parent.width
                    height: maxAppsColumn.height
                    visible: SettingsData.showWorkspaceApps
                    opacity: visible ? 1 : 0

                    Column {
                        id: maxAppsColumn
                        x: Theme.spacingL
                        width: 120
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Max apps to show")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignLeft
                        }

                        DankTextField {
                            width: 100
                            height: 28
                            placeholderText: "3"
                            text: SettingsData.maxWorkspaceIcons
                            maximumLength: 2
                            font.pixelSize: Theme.fontSizeSmall
                            topPadding: Theme.spacingXS
                            bottomPadding: Theme.spacingXS
                            onEditingFinished: SettingsData.set("maxWorkspaceIcons", parseInt(text, 10))
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }
                }

                SettingsSliderRow {
                    visible: SettingsData.showWorkspaceApps
                    text: I18n.tr("Icon Size")
                    value: SettingsData.workspaceAppIconSizeOffset
                    minimum: 0
                    maximum: 10
                    unit: "px"
                    defaultValue: 0
                    onSliderValueChanged: newValue => SettingsData.set("workspaceAppIconSizeOffset", newValue)
                }

                SettingsToggleRow {
                    settingKey: "groupWorkspaceApps"
                    tags: ["workspace", "apps", "icons", "group", "grouped", "collapse"]
                    text: I18n.tr("Group Workspace Apps")
                    description: I18n.tr("Group repeated application icons in unfocused workspaces")
                    checked: SettingsData.groupWorkspaceApps
                    visible: SettingsData.showWorkspaceApps
                    onToggled: checked => SettingsData.set("groupWorkspaceApps", checked)
                }

                SettingsToggleRow {
                    settingKey: "groupActiveWorkspaceApps"
                    tags: ["workspace", "apps", "icons", "group", "grouped", "active", "focused"]
                    text: I18n.tr("Group Active Workspace")
                    description: I18n.tr("Also group repeated application icons on the active workspace")
                    checked: SettingsData.groupActiveWorkspaceApps
                    visible: SettingsData.showWorkspaceApps && SettingsData.groupWorkspaceApps
                    onToggled: checked => SettingsData.set("groupActiveWorkspaceApps", checked)
                }

                SettingsToggleRow {
                    settingKey: "workspaceActiveAppHighlightEnabled"
                    tags: ["workspace", "apps", "icons", "highlight", "active", "focused"]
                    text: I18n.tr("Highlight Active Workspace App")
                    description: I18n.tr("Highlight the currently focused app inside workspace indicators")
                    checked: SettingsData.workspaceActiveAppHighlightEnabled
                    visible: SettingsData.showWorkspaceApps
                    onToggled: checked => SettingsData.set("workspaceActiveAppHighlightEnabled", checked)
                }

                SettingsToggleRow {
                    settingKey: "workspaceFollowFocus"
                    tags: ["workspace", "focus", "follow", "monitor"]
                    text: I18n.tr("Follow Monitor Focus")
                    description: I18n.tr("Show workspaces of the currently focused monitor")
                    checked: SettingsData.workspaceFollowFocus
                    visible: CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isDwl || CompositorService.isMango || CompositorService.isSway || CompositorService.isScroll || CompositorService.isMiracle
                    onToggled: checked => SettingsData.set("workspaceFollowFocus", checked)
                }

                SettingsToggleRow {
                    settingKey: "showOccupiedWorkspacesOnly"
                    tags: ["workspace", "occupied", "active", "windows"]
                    text: I18n.tr("Show Occupied Workspaces Only")
                    description: I18n.tr("Display only workspaces that contain windows")
                    checked: SettingsData.showOccupiedWorkspacesOnly
                    visible: CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango
                    onToggled: checked => SettingsData.set("showOccupiedWorkspacesOnly", checked)
                }

                SettingsToggleRow {
                    settingKey: "reverseScrolling"
                    tags: ["workspace", "scroll", "scrolling", "reverse", "direction"]
                    text: I18n.tr("Reverse Scrolling Direction")
                    description: I18n.tr("Reverse workspace switch direction when scrolling over the bar")
                    checked: SettingsData.reverseScrolling
                    visible: CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango
                    onToggled: checked => SettingsData.set("reverseScrolling", checked)
                }

                SettingsToggleRow {
                    settingKey: "workspaceDragReorder"
                    tags: ["workspace", "drag", "reorder", "sort", "move"]
                    text: I18n.tr("Drag to Reorder")
                    description: I18n.tr("Drag workspace indicators to reorder them")
                    checked: SettingsData.workspaceDragReorder
                    visible: CompositorService.isNiri
                    onToggled: checked => SettingsData.set("workspaceDragReorder", checked)
                }

                SettingsToggleRow {
                    settingKey: "dwlShowAllTags"
                    tags: ["dwl", "tags", "workspace"]
                    text: I18n.tr("Show All Tags")
                    description: I18n.tr("Show all 9 tags instead of only occupied tags")
                    checked: SettingsData.dwlShowAllTags
                    visible: CompositorService.isDwl || CompositorService.isMango
                    onToggled: checked => SettingsData.set("dwlShowAllTags", checked)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "label"
                title: I18n.tr("Named Workspace Icons")
                settingKey: "workspaceIcons"
                visible: SettingsData.hasNamedWorkspaces()

                StyledText {
                    width: parent.width
                    text: I18n.tr("Configure icons for named workspaces. Icons take priority over numbers when both are enabled.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.outline
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: SettingsData.getNamedWorkspaces()

                    Rectangle {
                        width: parent.width
                        height: workspaceIconRow.implicitHeight + Theme.spacingM
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                        border.width: 0

                        Row {
                            id: workspaceIconRow

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.spacingM
                            anchors.rightMargin: Theme.spacingM
                            spacing: Theme.spacingM

                            StyledText {
                                text: "\"" + modelData + "\""
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                width: 150
                                elide: Text.ElideRight
                            }

                            DankIconPicker {
                                id: iconPicker
                                anchors.verticalCenter: parent.verticalCenter

                                Component.onCompleted: {
                                    var iconData = SettingsData.getWorkspaceNameIcon(modelData);
                                    if (iconData) {
                                        setIcon(iconData.value, iconData.type);
                                    }
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
                                        var iconData = SettingsData.getWorkspaceNameIcon(modelData);
                                        if (iconData) {
                                            iconPicker.setIcon(iconData.value, iconData.type);
                                        } else {
                                            iconPicker.setIcon("", "icon");
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: 28
                                height: 28
                                radius: Theme.cornerRadius
                                color: clearMouseArea.containsMouse ? Theme.errorHover : Theme.surfaceContainer
                                border.width: 0
                                anchors.verticalCenter: parent.verticalCenter

                                DankIcon {
                                    name: "close"
                                    size: 16
                                    color: clearMouseArea.containsMouse ? Theme.error : Theme.outline
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    id: clearMouseArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: SettingsData.removeWorkspaceNameIcon(modelData)
                                }
                            }

                            Item {
                                width: parent.width - 150 - 240 - 28 - Theme.spacingM * 4
                                height: 1
                            }
                        }
                    }
                }
            }
        }
    }
}
