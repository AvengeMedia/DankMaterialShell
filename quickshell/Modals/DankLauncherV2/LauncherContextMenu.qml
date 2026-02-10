pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Popup {
    id: root

    property var item: null
    property var controller: null
    property var searchField: null
    property var parentHandler: null

    signal hideRequested
    signal editAppRequested(var app)

    function hasContextMenuActions(spotlightItem) {
        if (!spotlightItem)
            return false;
        if (spotlightItem.type === "app")
            return true;
        if (spotlightItem.type === "plugin" && spotlightItem.pluginId) {
            var instance = PluginService.pluginInstances[spotlightItem.pluginId];
            if (!instance)
                return false;
            if (typeof instance.getContextMenuActions !== "function")
                return false;
            var actions = instance.getContextMenuActions(spotlightItem.data);
            return Array.isArray(actions) && actions.length > 0;
        }
        return false;
    }

    readonly property bool isCoreApp: item?.type === "app" && !!item?.isCore
    readonly property var coreAppData: isCoreApp ? item?.data ?? null : null
    readonly property var desktopEntry: !isCoreApp ? (item?.data ?? null) : null
    readonly property string appId: {
        if (isCoreApp) {
            return item?.id || coreAppData?.builtInPluginId || "";
        }
        return desktopEntry?.id || desktopEntry?.execString || "";
    }
    readonly property bool isPinned: appId ? SessionData.isPinnedApp(appId) : false
    readonly property bool isRegularApp: item?.type === "app" && !item.isCore && desktopEntry
    readonly property bool isPluginItem: item?.type === "plugin"

    function getPluginContextMenuActions() {
        if (!isPluginItem || !item?.pluginId)
            return [];

        var instance = PluginService.pluginInstances[item.pluginId];
        if (!instance)
            return [];
        if (typeof instance.getContextMenuActions !== "function")
            return [];

        var actions = instance.getContextMenuActions(item.data);
        if (!Array.isArray(actions))
            return [];

        return actions;
    }

    function executePluginAction(actionOrObj) {
        var actionFunc = typeof actionOrObj === "function" ? actionOrObj : actionOrObj?.action;
        var closeLauncher = typeof actionOrObj === "object" && actionOrObj?.closeLauncher;

        if (typeof actionFunc === "function")
            actionFunc();

        if (closeLauncher) {
            controller?.itemExecuted();
        } else {
            controller?.performSearch();
        }
        hide();
    }

    readonly property var menuItems: {
        var items = [];

        if (isPluginItem) {
            var pluginActions = getPluginContextMenuActions();
            for (var i = 0; i < pluginActions.length; i++) {
                var act = pluginActions[i];
                items.push({
                    type: "item",
                    icon: act.icon || "play_arrow",
                    text: act.text || act.name || "",
                    pluginAction: act
                });
            }
            return items;
        }

        if (item?.type === "app") {
            items.push({
                type: "item",
                icon: isPinned ? "keep_off" : "push_pin",
                text: isPinned ? I18n.tr("Unpin from Dock") : I18n.tr("Pin to Dock"),
                action: togglePin
            });
        }

        if (isRegularApp) {
            items.push({
                type: "item",
                icon: "visibility_off",
                text: I18n.tr("Hide App"),
                action: hideCurrentApp
            });
            items.push({
                type: "item",
                icon: "edit",
                text: I18n.tr("Edit App"),
                action: editCurrentApp
            });
        }

        if (item?.actions && item.actions.length > 0) {
            items.push({
                type: "separator"
            });
            for (var i = 0; i < item.actions.length; i++) {
                var act = item.actions[i];
                items.push({
                    type: "item",
                    icon: act.icon || "play_arrow",
                    text: act.name || "",
                    actionData: act
                });
            }
        }

        items.push({
            type: "separator"
        });

        if (isRegularApp && SessionService.nvidiaCommand) {
            items.push({
                type: "item",
                icon: "memory",
                text: I18n.tr("Launch on dGPU"),
                action: launchWithNvidia
            });
        }

        items.push({
            type: "item",
            icon: "launch",
            text: I18n.tr("Launch"),
            action: launchApp
        });

        return items;
    }

    function show(x, y, spotlightItem, fromKeyboard) {
        if (!spotlightItem?.data)
            return;
        item = spotlightItem;
        selectedMenuIndex = fromKeyboard ? 0 : -1;
        keyboardNavigation = fromKeyboard;

        if (parentHandler)
            parentHandler.enabled = false;

        Qt.callLater(() => {
            var parentW = parent?.width ?? 500;
            var parentH = parent?.height ?? 600;
            var menuW = width > 0 ? width : 200;
            var menuH = height > 0 ? height : 200;
            var margin = 8;

            var posX = x + 4;
            var posY = y + 4;

            if (posX + menuW > parentW - margin) {
                posX = Math.max(margin, parentW - menuW - margin);
            }
            if (posY + menuH > parentH - margin) {
                posY = Math.max(margin, parentH - menuH - margin);
            }

            root.x = posX;
            root.y = posY;
            open();
        });
    }

    function hide() {
        if (parentHandler)
            parentHandler.enabled = true;
        close();
    }

    function togglePin() {
        if (!appId)
            return;
        if (isPinned)
            SessionData.removePinnedApp(appId);
        else
            SessionData.addPinnedApp(appId);
        hide();
    }

    function hideCurrentApp() {
        if (!appId)
            return;
        SessionData.hideApp(appId);
        controller?.performSearch();
        hide();
    }

    function editCurrentApp() {
        if (!desktopEntry)
            return;
        editAppRequested(desktopEntry);
        hide();
    }

    function launchApp() {
        if (isCoreApp) {
            if (!coreAppData)
                return;
            AppSearchService.executeCoreApp(coreAppData);
            controller?.itemExecuted();
            hide();
            return;
        }
        if (!desktopEntry)
            return;
        SessionService.launchDesktopEntry(desktopEntry);
        AppUsageHistoryData.addAppUsage(desktopEntry);
        controller?.itemExecuted();
        hide();
    }

    function launchWithNvidia() {
        if (!desktopEntry)
            return;
        SessionService.launchDesktopEntry(desktopEntry, true);
        AppUsageHistoryData.addAppUsage(desktopEntry);
        controller?.itemExecuted();
        hide();
    }

    function executeDesktopAction(actionData) {
        if (!desktopEntry || !actionData)
            return;
        SessionService.launchDesktopAction(desktopEntry, actionData.actionData || actionData);
        AppUsageHistoryData.addAppUsage(desktopEntry);
        controller?.itemExecuted();
        hide();
    }

    property int selectedMenuIndex: 0
    property bool keyboardNavigation: false

    readonly property int visibleItemCount: {
        var count = 0;
        for (var i = 0; i < menuItems.length; i++) {
            if (menuItems[i].type === "item")
                count++;
        }
        return count;
    }

    function selectNext() {
        if (visibleItemCount > 0)
            selectedMenuIndex = (selectedMenuIndex + 1) % visibleItemCount;
    }

    function selectPrevious() {
        if (visibleItemCount > 0)
            selectedMenuIndex = (selectedMenuIndex - 1 + visibleItemCount) % visibleItemCount;
    }

    function activateSelected() {
        var itemIndex = 0;
        for (var i = 0; i < menuItems.length; i++) {
            if (menuItems[i].type !== "item")
                continue;
            if (itemIndex === selectedMenuIndex) {
                var menuItem = menuItems[i];
                if (menuItem.action)
                    menuItem.action();
                else if (menuItem.pluginAction)
                    executePluginAction(menuItem.pluginAction);
                else if (menuItem.actionData)
                    executeDesktopAction(menuItem.actionData);
                return;
            }
            itemIndex++;
        }
    }

    width: menuContainer.implicitWidth
    height: menuContainer.implicitHeight
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    modal: true
    dim: false
    background: Item {}

    onOpened: {
        Qt.callLater(() => keyboardHandler.forceActiveFocus());
    }

    onClosed: {
        if (parentHandler)
            parentHandler.enabled = true;
        if (searchField?.visible) {
            Qt.callLater(() => searchField.forceActiveFocus());
        }
    }

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.shortDuration
            easing.type: Theme.emphasizedEasing
        }
    }

    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1
            to: 0
            duration: Theme.shortDuration
            easing.type: Theme.emphasizedEasing
        }
    }

    contentItem: Item {
        id: keyboardHandler
        focus: true
        implicitWidth: menuContainer.implicitWidth
        implicitHeight: menuContainer.implicitHeight

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Down:
                root.selectNext();
                event.accepted = true;
                return;
            case Qt.Key_Up:
                root.selectPrevious();
                event.accepted = true;
                return;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                root.activateSelected();
                event.accepted = true;
                return;
            case Qt.Key_Escape:
            case Qt.Key_Left:
                root.hide();
                event.accepted = true;
                return;
            }
        }

        Rectangle {
            id: menuContainer
            anchors.fill: parent
            implicitWidth: Math.max(180, menuColumn.implicitWidth + Theme.spacingS * 2)
            implicitHeight: menuColumn.implicitHeight + Theme.spacingS * 2
            color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
            radius: Theme.cornerRadius
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
            border.width: 1

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 4
                anchors.leftMargin: 2
                anchors.rightMargin: -2
                anchors.bottomMargin: -4
                radius: parent.radius
                color: Qt.rgba(0, 0, 0, 0.15)
                z: -1
            }

            Column {
                id: menuColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: 1

                Repeater {
                    model: root.menuItems

                    Item {
                        id: menuItemDelegate
                        required property var modelData
                        required property int index

                        width: menuColumn.width
                        height: modelData.type === "separator" ? 5 : 32

                        readonly property int itemIndex: {
                            var count = 0;
                            for (var i = 0; i < index; i++) {
                                if (root.menuItems[i].type === "item")
                                    count++;
                            }
                            return count;
                        }

                        Rectangle {
                            visible: menuItemDelegate.modelData.type === "separator"
                            width: parent.width - Theme.spacingS * 2
                            height: parent.height
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: "transparent"

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: 1
                                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                            }
                        }

                        Rectangle {
                            visible: menuItemDelegate.modelData.type === "item"
                            width: parent.width
                            height: parent.height
                            radius: Theme.cornerRadius
                            color: {
                                if (root.keyboardNavigation && root.selectedMenuIndex === menuItemDelegate.itemIndex) {
                                    return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2);
                                }
                                return itemMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent";
                            }

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingS
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingS

                                Item {
                                    width: Theme.iconSize - 2
                                    height: Theme.iconSize - 2
                                    anchors.verticalCenter: parent.verticalCenter

                                    DankIcon {
                                        visible: (menuItemDelegate.modelData?.icon ?? "").length > 0
                                        name: menuItemDelegate.modelData?.icon ?? ""
                                        size: Theme.iconSize - 2
                                        color: Theme.surfaceText
                                        opacity: 0.7
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                StyledText {
                                    text: menuItemDelegate.modelData.text || ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    font.weight: Font.Normal
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    width: parent.width - (Theme.iconSize - 2) - Theme.spacingS
                                }
                            }

                            DankRipple {
                                id: menuItemRipple
                                rippleColor: Theme.surfaceText
                                cornerRadius: Theme.cornerRadius
                            }

                            MouseArea {
                                id: itemMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: {
                                    root.keyboardNavigation = false;
                                    root.selectedMenuIndex = menuItemDelegate.itemIndex;
                                }
                                onPressed: mouse => menuItemRipple.trigger(mouse.x, mouse.y)
                                onClicked: {
                                    var menuItem = menuItemDelegate.modelData;
                                    if (menuItem.action)
                                        menuItem.action();
                                    else if (menuItem.pluginAction)
                                        root.executePluginAction(menuItem.pluginAction);
                                    else if (menuItem.actionData)
                                        root.executeDesktopAction(menuItem.actionData);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
