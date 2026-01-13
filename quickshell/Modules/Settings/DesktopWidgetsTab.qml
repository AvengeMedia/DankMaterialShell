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
                                    hoverEnabled: true
                                    onDoubleClicked: root.editingGroupId = groupItem.modelData.id
                                }
                            }
                        }
                    }
                }
            }

            Repeater {
                model: root.allGroups

                Column {
                    id: groupSection
                    required property var modelData
                    required property int index

                    readonly property string groupId: modelData.id
                    readonly property var groupInstances: root.allInstances.filter(inst => inst.group === groupId)

                    width: mainColumn.width
                    spacing: Theme.spacingM
                    visible: groupInstances.length > 0

                    Rectangle {
                        width: parent.width
                        height: 44
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainer

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingM
                            anchors.rightMargin: Theme.spacingM
                            spacing: Theme.spacingS

                            DankIcon {
                                name: (root.groupCollapsedStates[groupSection.groupId] ?? false) ? "expand_more" : "expand_less"
                                size: Theme.iconSize
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            DankIcon {
                                name: "folder"
                                size: Theme.iconSize
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: groupSection.modelData.name
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: "(" + groupSection.groupInstances.length + ")"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var states = Object.assign({}, root.groupCollapsedStates);
                                states[groupSection.groupId] = !(states[groupSection.groupId] ?? false);
                                root.groupCollapsedStates = states;
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: !(root.groupCollapsedStates[groupSection.groupId] ?? false)
                        leftPadding: Theme.spacingM

                        Repeater {
                            model: ScriptModel {
                                objectProp: "id"
                                values: groupSection.groupInstances
                            }

                            Item {
                                id: groupDelegateItem
                                required property var modelData
                                required property int index

                                property bool held: groupDragArea.pressed
                                property real originalY: y

                                readonly property string instanceIdRef: modelData.id
                                readonly property var liveInstanceData: {
                                    const instances = root.allInstances;
                                    return instances.find(inst => inst.id === instanceIdRef) ?? modelData;
                                }

                                width: groupSection.width - Theme.spacingM
                                height: groupCard.height
                                z: held ? 2 : 1

                                DesktopWidgetInstanceCard {
                                    id: groupCard
                                    width: parent.width
                                    headerLeftPadding: 20
                                    instanceData: groupDelegateItem.liveInstanceData
                                    isExpanded: root.expandedStates[groupDelegateItem.instanceIdRef] ?? false

                                    onExpandedChanged: {
                                        if (expanded === (root.expandedStates[groupDelegateItem.instanceIdRef] ?? false))
                                            return;
                                        var states = Object.assign({}, root.expandedStates);
                                        states[groupDelegateItem.instanceIdRef] = expanded;
                                        root.expandedStates = states;
                                    }

                                    onDuplicateRequested: SettingsData.duplicateDesktopWidgetInstance(groupDelegateItem.instanceIdRef)

                                    onDeleteRequested: {
                                        SettingsData.removeDesktopWidgetInstance(groupDelegateItem.instanceIdRef);
                                        ToastService.showInfo(I18n.tr("Widget removed"));
                                    }
                                }

                                MouseArea {
                                    id: groupDragArea
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    width: 40
                                    height: 50
                                    hoverEnabled: true
                                    cursorShape: Qt.SizeVerCursor
                                    drag.target: groupDelegateItem.held ? groupDelegateItem : undefined
                                    drag.axis: Drag.YAxis
                                    preventStealing: true

                                    onPressed: {
                                        groupDelegateItem.z = 2;
                                        groupDelegateItem.originalY = groupDelegateItem.y;
                                    }
                                    onReleased: {
                                        groupDelegateItem.z = 1;
                                        if (!drag.active) {
                                            groupDelegateItem.y = groupDelegateItem.originalY;
                                            return;
                                        }
                                        const spacing = Theme.spacingM;
                                        const itemH = groupDelegateItem.height + spacing;
                                        var newIndex = Math.round(groupDelegateItem.y / itemH);
                                        newIndex = Math.max(0, Math.min(newIndex, groupSection.groupInstances.length - 1));
                                        if (newIndex !== groupDelegateItem.index)
                                            SettingsData.reorderDesktopWidgetInstanceInGroup(groupDelegateItem.instanceIdRef, groupSection.groupId, newIndex);
                                        groupDelegateItem.y = groupDelegateItem.originalY;
                                    }
                                }

                                DankIcon {
                                    x: Theme.spacingL - 2
                                    y: Theme.spacingL + (Theme.iconSize / 2) - (size / 2)
                                    name: "drag_indicator"
                                    size: 18
                                    color: Theme.outline
                                    opacity: groupDragArea.containsMouse || groupDragArea.pressed ? 1 : 0.5
                                }

                                Behavior on y {
                                    enabled: !groupDragArea.pressed && !groupDragArea.drag.active
                                    NumberAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Column {
                id: ungroupedSection
                width: parent.width
                spacing: Theme.spacingM
                visible: ungroupedInstances.length > 0

                readonly property var ungroupedInstances: root.allInstances.filter(inst => {
                    if (!inst.group)
                        return true;
                    return !root.allGroups.some(g => g.id === inst.group);
                })

                Rectangle {
                    width: parent.width
                    height: 44
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainer
                    visible: root.allGroups.length > 0

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        DankIcon {
                            name: (root.groupCollapsedStates["_ungrouped"] ?? false) ? "expand_more" : "expand_less"
                            size: Theme.iconSize
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        DankIcon {
                            name: "widgets"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Ungrouped")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "(" + ungroupedSection.ungroupedInstances.length + ")"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var states = Object.assign({}, root.groupCollapsedStates);
                            states["_ungrouped"] = !(states["_ungrouped"] ?? false);
                            root.groupCollapsedStates = states;
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: !(root.groupCollapsedStates["_ungrouped"] ?? false)
                    leftPadding: root.allGroups.length > 0 ? Theme.spacingM : 0

                    Repeater {
                        model: ScriptModel {
                            objectProp: "id"
                            values: ungroupedSection.ungroupedInstances
                        }

                        Item {
                            id: ungroupedDelegateItem
                            required property var modelData
                            required property int index

                            property bool held: ungroupedDragArea.pressed
                            property real originalY: y

                            readonly property string instanceIdRef: modelData.id
                            readonly property var liveInstanceData: {
                                const instances = root.allInstances;
                                return instances.find(inst => inst.id === instanceIdRef) ?? modelData;
                            }

                            width: ungroupedSection.width - (root.allGroups.length > 0 ? Theme.spacingM : 0)
                            height: ungroupedCard.height
                            z: held ? 2 : 1

                            DesktopWidgetInstanceCard {
                                id: ungroupedCard
                                width: parent.width
                                headerLeftPadding: 20
                                instanceData: ungroupedDelegateItem.liveInstanceData
                                isExpanded: root.expandedStates[ungroupedDelegateItem.instanceIdRef] ?? false

                                onExpandedChanged: {
                                    if (expanded === (root.expandedStates[ungroupedDelegateItem.instanceIdRef] ?? false))
                                        return;
                                    var states = Object.assign({}, root.expandedStates);
                                    states[ungroupedDelegateItem.instanceIdRef] = expanded;
                                    root.expandedStates = states;
                                }

                                onDuplicateRequested: SettingsData.duplicateDesktopWidgetInstance(ungroupedDelegateItem.instanceIdRef)

                                onDeleteRequested: {
                                    SettingsData.removeDesktopWidgetInstance(ungroupedDelegateItem.instanceIdRef);
                                    ToastService.showInfo(I18n.tr("Widget removed"));
                                }
                            }

                            MouseArea {
                                id: ungroupedDragArea
                                anchors.left: parent.left
                                anchors.top: parent.top
                                width: 40
                                height: 50
                                hoverEnabled: true
                                cursorShape: Qt.SizeVerCursor
                                drag.target: ungroupedDelegateItem.held ? ungroupedDelegateItem : undefined
                                drag.axis: Drag.YAxis
                                preventStealing: true

                                onPressed: {
                                    ungroupedDelegateItem.z = 2;
                                    ungroupedDelegateItem.originalY = ungroupedDelegateItem.y;
                                }
                                onReleased: {
                                    ungroupedDelegateItem.z = 1;
                                    if (!drag.active) {
                                        ungroupedDelegateItem.y = ungroupedDelegateItem.originalY;
                                        return;
                                    }
                                    const spacing = Theme.spacingM;
                                    const itemH = ungroupedDelegateItem.height + spacing;
                                    var newIndex = Math.round(ungroupedDelegateItem.y / itemH);
                                    newIndex = Math.max(0, Math.min(newIndex, ungroupedSection.ungroupedInstances.length - 1));
                                    if (newIndex !== ungroupedDelegateItem.index)
                                        SettingsData.reorderDesktopWidgetInstanceInGroup(ungroupedDelegateItem.instanceIdRef, null, newIndex);
                                    ungroupedDelegateItem.y = ungroupedDelegateItem.originalY;
                                }
                            }

                            DankIcon {
                                x: Theme.spacingL - 2
                                y: Theme.spacingL + (Theme.iconSize / 2) - (size / 2)
                                name: "drag_indicator"
                                size: 18
                                color: Theme.outline
                                opacity: ungroupedDragArea.containsMouse || ungroupedDragArea.pressed ? 1 : 0.5
                            }

                            Behavior on y {
                                enabled: !ungroupedDragArea.pressed && !ungroupedDragArea.drag.active
                                NumberAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }
                    }
                }
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
                }
            }
        }
    }
}
