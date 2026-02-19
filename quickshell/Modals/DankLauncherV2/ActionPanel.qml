pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property var selectedItem: null
    property var controller: null
    property bool expanded: false
    property int selectedActionIndex: 0

    function getPluginContextMenuActions() {
        if (selectedItem?.type !== "plugin" || !selectedItem?.pluginId)
            return [];
        var instance = PluginService.pluginInstances[selectedItem.pluginId];
        if (!instance)
            return [];
        if (typeof instance.getContextMenuActions !== "function")
            return [];
        var actions = instance.getContextMenuActions(selectedItem.data);
        if (!Array.isArray(actions))
            return [];
        return actions;
    }

    readonly property var actions: {
        var result = [];
        if (selectedItem?.primaryAction) {
            result.push(selectedItem.primaryAction);
        }

        switch (selectedItem?.type) {
        case "plugin":
            var pluginActions = getPluginContextMenuActions();
            for (var i = 0; i < pluginActions.length; i++) {
                var act = pluginActions[i];
                result.push({
                    name: act.text || act.name || "",
                    icon: act.icon || "play_arrow",
                    action: "plugin_action",
                    pluginAction: act.action
                });
            }
            break;
        case "plugin_browse":
            if (selectedItem?.actions) {
                for (var i = 0; i < selectedItem.actions.length; i++) {
                    result.push(selectedItem.actions[i]);
                }
            }
            break;
        case "app":
            if (selectedItem?.isCore)
                break;
            if (SessionService.nvidiaCommand) {
                result.push({
                    name: I18n.tr("Launch on dGPU"),
                    icon: "memory",
                    action: "launch_dgpu"
                });
            }
            if (selectedItem?.actions) {
                for (var i = 0; i < selectedItem.actions.length; i++) {
                    result.push(selectedItem.actions[i]);
                }
            }
            break;
        }
        return result;
    }

    readonly property bool hasActions: {
        switch (selectedItem?.type) {
        case "app":
            return !selectedItem?.isCore;
        case "plugin":
            return getPluginContextMenuActions().length > 0;
        case "plugin_browse":
            return selectedItem?.actions?.length > 0;
        default:
            return actions.length > 1;
        }
    }

    width: parent?.width ?? 200
    height: expanded && hasActions ? 52 : 0
    color: Theme.surfaceContainerHigh
    radius: Theme.cornerRadius

    clip: true

    Behavior on height {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: Theme.outlineMedium
    }

    Item {
        anchors.fill: parent
        anchors.margins: Theme.spacingS

        Flickable {
            id: actionsFlickable
            anchors.left: parent.left
            anchors.right: tabHint.left
            anchors.rightMargin: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            contentWidth: actionsRow.width
            contentHeight: height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick

            Row {
                id: actionsRow
                height: parent.height
                spacing: Theme.spacingS

                Repeater {
                    model: root.actions

                    Rectangle {
                        id: actionButton

                        required property var modelData
                        required property int index

                        width: actionContent.implicitWidth + Theme.spacingM * 2
                        height: actionsRow.height
                        radius: Theme.cornerRadius
                        color: index === root.selectedActionIndex ? Theme.primaryHover : actionArea.containsMouse ? Theme.surfaceHover : "transparent"

                        Row {
                            id: actionContent
                            anchors.centerIn: parent
                            spacing: Theme.spacingXS

                            DankIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: actionButton.modelData?.icon ?? "play_arrow"
                                size: 16
                                color: actionButton.index === root.selectedActionIndex ? Theme.primary : Theme.surfaceText
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: actionButton.modelData?.name ?? ""
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: actionButton.index === root.selectedActionIndex ? Theme.primary : Theme.surfaceText
                            }
                        }

                        MouseArea {
                            id: actionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.controller && root.selectedItem) {
                                    root.controller.executeAction(root.selectedItem, actionButton.modelData);
                                }
                            }
                            onEntered: root.selectedActionIndex = actionButton.index
                        }
                    }
                }
            }
        }

        StyledText {
            id: tabHint
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasActions
            text: "Tab"
            font.pixelSize: Theme.fontSizeSmall - 2
            color: Theme.outlineButton
        }
    }

    function toggle() {
        expanded = !expanded;
        selectedActionIndex = 0;
    }

    function show() {
        expanded = true;
        selectedActionIndex = actions.length > 1 ? 1 : 0;
    }

    function hide() {
        expanded = false;
        selectedActionIndex = 0;
    }

    function cycleAction() {
        if (actions.length > 0) {
            selectedActionIndex = (selectedActionIndex + 1) % actions.length;
            ensureSelectedVisible();
        }
    }

    function ensureSelectedVisible() {
        if (selectedActionIndex < 0 || !actionsRow.children || selectedActionIndex >= actionsRow.children.length)
            return;
        var buttonX = 0;
        for (var i = 0; i < selectedActionIndex; i++) {
            var child = actionsRow.children[i];
            if (child)
                buttonX += child.width + actionsRow.spacing;
        }

        var button = actionsRow.children[selectedActionIndex];
        if (!button)
            return;
        var buttonRight = buttonX + button.width;
        var viewLeft = actionsFlickable.contentX;
        var viewRight = viewLeft + actionsFlickable.width;

        if (buttonX < viewLeft) {
            actionsFlickable.contentX = Math.max(0, buttonX - Theme.spacingS);
        } else if (buttonRight > viewRight) {
            actionsFlickable.contentX = Math.min(actionsFlickable.contentWidth - actionsFlickable.width, buttonRight - actionsFlickable.width + Theme.spacingS);
        }
    }

    function executeSelectedAction() {
        if (!controller || !selectedItem || selectedActionIndex >= actions.length)
            return;
        var action = actions[selectedActionIndex];
        if (action.action === "plugin_action" && typeof action.pluginAction === "function") {
            action.pluginAction();
            controller.performSearch();
            controller.itemExecuted();
        } else {
            controller.executeAction(selectedItem, action);
        }
    }
}
