pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var expandedStates: ({})
    property var groupCollapsedStates: ({})
    property var parentModal: null
    property string editingGroupId: ""
    property string newGroupName: ""

    readonly property var allInstances: SettingsData.desktopWidgetInstances || []
    readonly property var allGroups: SettingsData.desktopWidgetGroups || []

    readonly property bool dragActive: dragGroup.active
    property alias reorderGroup: dragGroup

    SettingsReorderGroup {
        id: dragGroup

        coordinateItem: root
        onTransferred: (source, sourceIndex, target, targetIndex) => SettingsData.moveDesktopWidgetInstanceToGroup(source.model[sourceIndex].id, target.groupKey || null, targetIndex)
    }

    function storageKeyFor(sectionKey) {
        return sectionKey === "" ? "_ungrouped" : sectionKey;
    }

    function toggleCollapsed(sectionKey) {
        const key = storageKeyFor(sectionKey);
        var states = Object.assign({}, groupCollapsedStates);
        states[key] = !(states[key] ?? false);
        groupCollapsedStates = states;
    }

    function setExpanded(instanceId, expanded) {
        if (expanded === (expandedStates[instanceId] ?? false))
            return;
        var states = Object.assign({}, expandedStates);
        states[instanceId] = expanded;
        expandedStates = states;
    }

    function showWidgetBrowser() {
        widgetBrowserLoader.active = true;
        if (widgetBrowserLoader.item)
            widgetBrowserLoader.item.show();
    }

    function showDesktopPluginBrowser() {
        desktopPluginBrowserLoader.active = true;
        if (desktopPluginBrowserLoader.item)
            desktopPluginBrowserLoader.item.show();
    }

    LazyLoader {
        id: widgetBrowserLoader
        active: false

        DesktopWidgetBrowser {
            parentModal: root.parentModal
            onWidgetAdded: widgetType => {
                ToastService.showInfo(I18n.tr("Widget added"));
            }
        }
    }

    LazyLoader {
        id: desktopPluginBrowserLoader
        active: false

        PluginBrowser {
            parentModal: root.parentModal
            typeFilter: "desktop-widget"
        }
    }

    SettingsPage {
        id: mainColumn

        SettingsCard {
            settingKey: "desktopWidgetsManage"
            tags: ["desktop", "widgets", "clock", "conky"]
            width: parent.width

            SettingsRow {
                body: Column {
                    width: parent.width - Theme.spacingM * 2
                    x: Theme.spacingM
                    spacing: Theme.spacingM

                    Row {
                        spacing: Theme.spacingM

                        DankButton {
                            text: I18n.tr("Add widget")
                            iconName: "add"
                            onClicked: root.showWidgetBrowser()
                        }

                        DankButton {
                            text: I18n.tr("Browse plugins")
                            iconName: "store"
                            onClicked: root.showDesktopPluginBrowser()
                        }
                    }
                }
            }
        }

        SettingsCard {
            settingKey: "desktopWidgetGroups"
            tags: ["groups", "profiles", "layouts"]
            width: parent.width
            iconName: "folder"
            title: I18n.tr("Groups", "noun, card title for desktop widget groups")
            collapsible: true
            expanded: root.allGroups.length > 0

            SettingsRow {
                body: Column {
                    width: parent.width - Theme.spacingM * 2
                    x: Theme.spacingM
                    spacing: Theme.spacingM

                    Row {
                        spacing: Theme.spacingS
                        width: parent.width

                        DankTextField {
                            id: newGroupField
                            outlined: true
                            leftIconName: "folder"
                            labelText: I18n.tr("Name")
                            width: parent.width - addGroupBtn.width - Theme.spacingS
                            text: root.newGroupName
                            onTextChanged: root.newGroupName = text
                            onAccepted: {
                                if (!text.trim())
                                    return;
                                SettingsData.createDesktopWidgetGroup(text.trim());
                                root.newGroupName = "";
                                text = "";
                            }
                        }

                        DankButton {
                            id: addGroupBtn
                            iconName: "add"
                            text: I18n.tr("Add")
                            enabled: root.newGroupName.trim().length > 0
                            onClicked: {
                                SettingsData.createDesktopWidgetGroup(root.newGroupName.trim());
                                root.newGroupName = "";
                                newGroupField.text = "";
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        visible: root.allGroups.length > 0

                        Repeater {
                            model: root.allGroups

                            Rectangle {
                                id: groupItem
                                required property var modelData
                                required property int index

                                width: parent.width
                                height: Math.max(Theme.iconButtonSize, groupNameLoader.height + Theme.spacingS)
                                radius: Theme.cornerRadius
                                color: groupMouseArea.containsMouse ? Theme.surfaceHover : Theme.floatingWindowFieldColor

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingS
                                    anchors.rightMargin: Theme.spacingS
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: "folder"
                                        visible: !groupNameLoader.active
                                        size: Theme.iconSizeSmall
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Loader {
                                        id: groupNameLoader
                                        active: root.editingGroupId === groupItem.modelData.id
                                        width: active ? parent.width - deleteGroupBtn.width - Theme.spacingS : 0
                                        height: active && item ? item.implicitHeight : 0
                                        anchors.verticalCenter: parent.verticalCenter

                                        sourceComponent: DankTextField {
                                            outlined: true
                                            leftIconName: "folder"
                                            labelText: I18n.tr("Name")
                                            text: groupItem.modelData.name
                                            onAccepted: {
                                                if (!text.trim())
                                                    return;
                                                SettingsData.updateDesktopWidgetGroup(groupItem.modelData.id, {
                                                    name: text.trim()
                                                });
                                                root.editingGroupId = "";
                                            }
                                            onEditingFinished: {
                                                if (!text.trim())
                                                    return;
                                                SettingsData.updateDesktopWidgetGroup(groupItem.modelData.id, {
                                                    name: text.trim()
                                                });
                                                root.editingGroupId = "";
                                            }
                                            Component.onCompleted: forceActiveFocus()
                                        }
                                    }

                                    StyledText {
                                        visible: root.editingGroupId !== groupItem.modelData.id
                                        text: groupItem.modelData.name
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                        elide: Text.ElideRight
                                        width: parent.width - Theme.iconSizeSmall - deleteGroupBtn.width - Theme.spacingS * 3
                                    }

                                    DankActionButton {
                                        id: deleteGroupBtn
                                        iconName: "delete"
                                        Accessible.name: I18n.tr("Delete")
                                        backgroundColor: Theme.withAlpha(Theme.error, 0.15)
                                        iconColor: Theme.error
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: {
                                            SettingsData.removeDesktopWidgetGroup(groupItem.modelData.id);
                                            ToastService.showInfo(I18n.tr("Group removed"));
                                        }
                                    }
                                }

                                MouseArea {
                                    id: groupMouseArea
                                    anchors.fill: parent
                                    z: -1
                                    hoverEnabled: true
                                    onDoubleClicked: root.editingGroupId = groupItem.modelData.id
                                }
                            }
                        }
                    }
                }
            }
        }

        Repeater {
            id: groupsRepeater
            model: root.allGroups

            DesktopWidgetGroupSection {
                required property var modelData
                required property int index

                width: mainColumn.columnWidth
                reorderGroup: dragGroup
                groupId: modelData.id
                groupName: modelData.name
                isUngrouped: false
                showHeader: true
                collapsed: root.groupCollapsedStates[modelData.id] ?? false
                instances: root.allInstances.filter(inst => inst.group === modelData.id)
                expandedStates: root.expandedStates
                visible: instances.length > 0 || root.dragActive

                onCollapseToggled: key => root.toggleCollapsed(key)
                onExpandedToggled: (instanceId, expanded) => root.setExpanded(instanceId, expanded)
                onDuplicateRequested: instanceId => SettingsData.duplicateDesktopWidgetInstance(instanceId)
                onDeleteRequested: instanceId => {
                    SettingsData.removeDesktopWidgetInstance(instanceId);
                    ToastService.showInfo(I18n.tr("Widget removed"));
                }
            }
        }

        DesktopWidgetGroupSection {
            id: ungroupedSection

            readonly property var ungroupedInstances: root.allInstances.filter(inst => {
                if (!inst.group)
                    return true;
                return !root.allGroups.some(g => g.id === inst.group);
            })

            width: mainColumn.columnWidth
            reorderGroup: dragGroup
            groupId: null
            groupName: I18n.tr("Ungrouped", "section header for desktop widgets without a group")
            isUngrouped: true
            showHeader: root.allGroups.length > 0
            collapsed: root.groupCollapsedStates["_ungrouped"] ?? false
            instances: ungroupedInstances
            expandedStates: root.expandedStates
            visible: ungroupedInstances.length > 0 || root.dragActive

            onCollapseToggled: key => root.toggleCollapsed(key)
            onExpandedToggled: (instanceId, expanded) => root.setExpanded(instanceId, expanded)
            onDuplicateRequested: instanceId => SettingsData.duplicateDesktopWidgetInstance(instanceId)
            onDeleteRequested: instanceId => {
                SettingsData.removeDesktopWidgetInstance(instanceId);
                ToastService.showInfo(I18n.tr("Widget removed"));
            }
        }

        StyledText {
            visible: root.allInstances.length === 0
            text: I18n.tr("No widgets added. Click \"Add widget\" to get started.")
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceVariantText
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignLeft
        }

        SettingsCard {
            width: parent.width
            iconName: "info"
            title: I18n.tr("Help", "noun, card title for desktop widget usage tips")

            SettingsRow {
                body: Column {
                    width: parent.width - Theme.spacingM * 2
                    x: Theme.spacingM
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 40
                            height: 40
                            radius: Theme.fullRadius(width, height)
                            color: Theme.primarySelected

                            DankIcon {
                                anchors.centerIn: parent
                                name: "drag_pan"
                                size: Theme.iconSize
                                color: Theme.primary
                            }
                        }

                        Column {
                            spacing: Theme.spacingXXS
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 40 - Theme.spacingM

                            StyledText {
                                text: I18n.tr("Move", "verb, help item title for moving a desktop widget")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Theme.fontWeightMedium
                                color: Theme.surfaceText
                                width: parent.width
                                horizontalAlignment: Text.AlignLeft
                            }

                            StyledText {
                                text: I18n.tr("Right-click and drag anywhere on the widget")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                width: parent.width
                                horizontalAlignment: Text.AlignLeft
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 40
                            height: 40
                            radius: Theme.fullRadius(width, height)
                            color: Theme.primarySelected

                            DankIcon {
                                anchors.centerIn: parent
                                name: "open_in_full"
                                size: Theme.iconSize
                                color: Theme.primary
                            }
                        }

                        Column {
                            spacing: Theme.spacingXXS
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 40 - Theme.spacingM

                            StyledText {
                                text: I18n.tr("Resize", "verb, help item title for resizing a desktop widget")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Theme.fontWeightMedium
                                color: Theme.surfaceText
                                width: parent.width
                                horizontalAlignment: Text.AlignLeft
                            }

                            StyledText {
                                text: I18n.tr("Right-click and drag the bottom-right corner")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                width: parent.width
                                horizontalAlignment: Text.AlignLeft
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 40
                            height: 40
                            radius: Theme.fullRadius(width, height)
                            color: Theme.primarySelected

                            DankIcon {
                                anchors.centerIn: parent
                                name: "drag_indicator"
                                size: Theme.iconSize
                                color: Theme.primary
                            }
                        }

                        Column {
                            spacing: Theme.spacingXXS
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 40 - Theme.spacingM

                            StyledText {
                                text: I18n.tr("Reorder & group")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Theme.fontWeightMedium
                                color: Theme.surfaceText
                                width: parent.width
                                horizontalAlignment: Text.AlignLeft
                            }

                            StyledText {
                                text: I18n.tr("Drag a widget by its handle here to reorder it or drop it into another group")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                width: parent.width
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignLeft
                            }
                        }
                    }
                }
            }
        }
    }

    SettingsReorderPreview {
        group: dragGroup
    }
}
