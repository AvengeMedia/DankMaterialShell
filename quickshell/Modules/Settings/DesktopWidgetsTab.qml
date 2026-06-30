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

    property bool dragActive: false
    property string dragInstanceId: ""
    property string dragSourceKey: ""
    property int dragSourceIndex: -1
    property var dragWidgetData: null
    property bool dragTargetValid: false
    property string dragTargetKey: ""
    property int dragTargetIndex: -1
    property bool proxyVisible: false
    property real proxyX: 0
    property real proxyY: 0

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

    function hitTestSection(sec, gy) {
        const top = sec.mapToItem(root, 0, 0).y;
        if (gy < top || gy > top + sec.height)
            return false;
        root.dragTargetValid = true;
        root.dragTargetKey = sec.sectionKey;
        root.dragTargetIndex = sec.insertionIndexForGlobalY(gy);
        return true;
    }

    function updateDropTarget(gc) {
        for (var i = 0; i < groupsRepeater.count; i++) {
            const sec = groupsRepeater.itemAt(i);
            if (sec && sec.visible && hitTestSection(sec, gc.y))
                return;
        }
        if (ungroupedSection.visible && hitTestSection(ungroupedSection, gc.y))
            return;
        root.dragTargetValid = false;
        root.dragTargetKey = "";
        root.dragTargetIndex = -1;
    }

    function handleDragStarted(instanceId, groupId, index, widgetData, gc) {
        root.dragActive = true;
        root.dragInstanceId = instanceId;
        root.dragSourceKey = groupId ? groupId : "";
        root.dragSourceIndex = index;
        root.dragWidgetData = widgetData;
        root.dragTargetValid = false;
        root.dragTargetKey = root.dragSourceKey;
        root.dragTargetIndex = index;
        root.proxyX = gc.x;
        root.proxyY = gc.y;
        root.proxyVisible = true;
    }

    function handleDragMoved(gc) {
        if (!root.dragActive)
            return;
        root.proxyX = gc.x;
        root.proxyY = gc.y;
        updateDropTarget(gc);
    }

    function handleDragEnded() {
        if (!root.dragActive)
            return;
        if (root.dragTargetValid) {
            var idx = root.dragTargetIndex;
            if (root.dragTargetKey === root.dragSourceKey && idx > root.dragSourceIndex)
                idx -= 1;
            SettingsData.moveDesktopWidgetInstanceToGroup(root.dragInstanceId, root.dragTargetKey === "" ? null : root.dragTargetKey, idx);
        }
        root.dragActive = false;
        root.dragInstanceId = "";
        root.dragSourceKey = "";
        root.dragSourceIndex = -1;
        root.dragWidgetData = null;
        root.dragTargetValid = false;
        root.dragTargetKey = "";
        root.dragTargetIndex = -1;
        root.proxyVisible = false;
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

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            topPadding: 4
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                width: parent.width
                iconName: "widgets"
                title: I18n.tr("Desktop Widgets")

                Column {
                    width: parent.width - Theme.spacingM * 2
                    x: Theme.spacingM
                    spacing: Theme.spacingM

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Add and configure widgets that appear on your desktop")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignLeft
                    }

                    Row {
                        spacing: Theme.spacingM

                        DankButton {
                            text: I18n.tr("Add Widget")
                            iconName: "add"
                            onClicked: root.showWidgetBrowser()
                        }

                        DankButton {
                            text: I18n.tr("Browse Plugins")
                            iconName: "store"
                            onClicked: root.showDesktopPluginBrowser()
                        }
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "folder"
                title: I18n.tr("Groups")
                collapsible: true
                expanded: root.allGroups.length > 0

                Column {
                    width: parent.width - Theme.spacingM * 2
                    x: Theme.spacingM
                    spacing: Theme.spacingM

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Organize widgets into collapsible groups")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignLeft
                    }

                    Row {
                        spacing: Theme.spacingS
                        width: parent.width

                        DankTextField {
                            id: newGroupField
                            width: parent.width - addGroupBtn.width - Theme.spacingS
                            placeholderText: I18n.tr("New group name...")
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
                                height: 40
                                radius: Theme.cornerRadius
                                color: groupMouseArea.containsMouse ? Theme.surfaceHover : Theme.surfaceContainer

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingS
                                    anchors.rightMargin: Theme.spacingS
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: "folder"
                                        size: Theme.iconSizeSmall
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Loader {
                                        active: root.editingGroupId === groupItem.modelData.id
                                        width: active ? parent.width - Theme.iconSizeSmall - deleteGroupBtn.width - Theme.spacingS * 3 : 0
                                        height: active ? 32 : 0
                                        anchors.verticalCenter: parent.verticalCenter

                                        sourceComponent: DankTextField {
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

            Repeater {
                id: groupsRepeater
                model: root.allGroups

                DesktopWidgetGroupSection {
                    required property var modelData
                    required property int index

                    width: mainColumn.width
                    coordinator: root
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
                    onDragStarted: (instanceId, groupId, index, widgetData, globalCenter) => root.handleDragStarted(instanceId, groupId, index, widgetData, globalCenter)
                    onDragMoved: globalCenter => root.handleDragMoved(globalCenter)
                    onDragEnded: root.handleDragEnded()
                }
            }

            DesktopWidgetGroupSection {
                id: ungroupedSection

                readonly property var ungroupedInstances: root.allInstances.filter(inst => {
                    if (!inst.group)
                        return true;
                    return !root.allGroups.some(g => g.id === inst.group);
                })

                width: mainColumn.width
                coordinator: root
                groupId: null
                groupName: I18n.tr("Ungrouped")
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
                onDragStarted: (instanceId, groupId, index, widgetData, globalCenter) => root.handleDragStarted(instanceId, groupId, index, widgetData, globalCenter)
                onDragMoved: globalCenter => root.handleDragMoved(globalCenter)
                onDragEnded: root.handleDragEnded()
            }

            StyledText {
                visible: root.allInstances.length === 0
                text: I18n.tr("No widgets added. Click \"Add Widget\" to get started.")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignLeft
            }

            SettingsCard {
                width: parent.width
                iconName: "info"
                title: I18n.tr("Help")

                Column {
                    width: parent.width - Theme.spacingM * 2
                    x: Theme.spacingM
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            color: Theme.primarySelected

                            DankIcon {
                                anchors.centerIn: parent
                                name: "drag_pan"
                                size: Theme.iconSize
                                color: Theme.primary
                            }
                        }

                        Column {
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 40 - Theme.spacingM

                            StyledText {
                                text: I18n.tr("Move Widget")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
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
                            radius: 20
                            color: Theme.primarySelected

                            DankIcon {
                                anchors.centerIn: parent
                                name: "open_in_full"
                                size: Theme.iconSize
                                color: Theme.primary
                            }
                        }

                        Column {
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 40 - Theme.spacingM

                            StyledText {
                                text: I18n.tr("Resize Widget")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
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
                            radius: 20
                            color: Theme.primarySelected

                            DankIcon {
                                anchors.centerIn: parent
                                name: "drag_indicator"
                                size: Theme.iconSize
                                color: Theme.primary
                            }
                        }

                        Column {
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 40 - Theme.spacingM

                            StyledText {
                                text: I18n.tr("Reorder & Group")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
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

    Item {
        id: dragProxy

        visible: root.proxyVisible
        x: root.proxyX - width / 2
        y: root.proxyY - height / 2
        width: proxyContent.implicitWidth + Theme.spacingM * 2
        height: 40
        z: 9999

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius + 4
            color: Theme.secondaryContainer
            border.color: Theme.primary
            border.width: 2
            opacity: 0.95

            Row {
                id: proxyContent
                anchors.centerIn: parent
                spacing: Theme.spacingS

                DankIcon {
                    name: (root.dragWidgetData && root.dragWidgetData.icon) ? root.dragWidgetData.icon : "widgets"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: (root.dragWidgetData && root.dragWidgetData.name) ? root.dragWidgetData.name : ""
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
