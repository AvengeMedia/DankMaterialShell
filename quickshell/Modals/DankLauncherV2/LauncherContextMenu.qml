pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property var item: null
    property var controller: null
    property var searchField: null
    property var parentHandler: null
    property bool allowEditActions: true
    property real menuMargin: 8
    property var targetScreen: null
    property real anchorX: 0
    property real anchorY: 0
    property bool openState: false
    property bool renderActive: false
    readonly property bool blurActive: renderActive && openState && BlurService.enabled && Theme.connectedSurfaceBlurEnabled

    readonly property real minMenuWidth: 180
    readonly property real maxMenuWidth: Math.max(0, (targetScreen?.width ?? 500) - menuMargin * 2)
    readonly property real maxMenuHeight: Math.max(0, (targetScreen?.height ?? 600) - menuMargin * 2)
    readonly property string longestMenuText: {
        let longest = "";
        for (let i = 0; i < menuItems.length; i++) {
            const text = menuItems[i].text || "";
            if (text.length > longest.length)
                longest = text;
        }
        return longest;
    }
    readonly property real naturalMenuWidth: Math.max(minMenuWidth, menuTextMetrics.width + Theme.iconSize + Theme.spacingS * 5)
    readonly property real effectiveMenuWidth: Math.max(0, Math.min(maxMenuWidth, naturalMenuWidth))
    readonly property real naturalMenuHeight: menuItemsHeight() + Theme.spacingS * 2
    readonly property real effectiveMenuHeight: Math.min(maxMenuHeight, naturalMenuHeight)
    readonly property bool menuScrolls: naturalMenuHeight > effectiveMenuHeight + 0.5

    signal hideRequested
    signal editAppRequested(var app)

    TextMetrics {
        id: menuTextMetrics
        text: root.longestMenuText
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Normal
    }

    function hasContextMenuActions(spotlightItem) {
        if (!spotlightItem)
            return false;
        if (spotlightItem.type === "app")
            return true;
        if (spotlightItem.type === "plugin" && spotlightItem.pluginId) {
            const instance = PluginService.pluginInstances[spotlightItem.pluginId];
            if (!instance)
                return false;
            if (typeof instance.getContextMenuActions !== "function")
                return false;
            const actions = instance.getContextMenuActions(spotlightItem.data);
            return Array.isArray(actions) && actions.length > 0;
        }
        if (spotlightItem.actions && spotlightItem.actions.length > 0)
            return true;
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

        const instance = PluginService.pluginInstances[item.pluginId];
        if (!instance)
            return [];
        if (typeof instance.getContextMenuActions !== "function")
            return [];

        const actions = instance.getContextMenuActions(item.data);
        if (!Array.isArray(actions))
            return [];

        return actions;
    }

    function executePluginAction(actionOrObj) {
        const actionFunc = typeof actionOrObj === "function" ? actionOrObj : actionOrObj?.action;
        const closeLauncher = typeof actionOrObj === "object" && actionOrObj?.closeLauncher;

        if (typeof actionFunc === "function")
            actionFunc();

        if (closeLauncher) {
            controller?.itemExecuted();
        } else {
            controller?.performSearch();
        }
        hide();
    }

    function executeLauncherAction(actionData) {
        if (!controller || !item || !actionData)
            return;
        controller.executeAction(item, actionData);
        hide();
    }

    readonly property var menuItems: {
        const items = [];

        if (isPluginItem) {
            const pluginActions = getPluginContextMenuActions();
            for (let i = 0; i < pluginActions.length; i++) {
                const act = pluginActions[i];
                items.push({
                    type: "item",
                    icon: act.icon || "play_arrow",
                    text: act.text || act.name || "",
                    pluginAction: act
                });
            }
            return items;
        }

        if (item?.type !== "app" && item?.actions && item.actions.length > 0) {
            for (let i = 0; i < item.actions.length; i++) {
                const genericAct = item.actions[i];
                items.push({
                    type: "item",
                    icon: genericAct.icon || "play_arrow",
                    text: genericAct.name || "",
                    launcherActionData: genericAct
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
            if (allowEditActions) {
                items.push({
                    type: "item",
                    icon: "edit",
                    text: I18n.tr("Edit App"),
                    action: editCurrentApp
                });
            }
        }

        if (item?.actions && item.actions.length > 0) {
            items.push({
                type: "separator"
            });
            for (let i = 0; i < item.actions.length; i++) {
                const act = item.actions[i];
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

    function menuItemsHeight() {
        let h = 0;
        for (let i = 0; i < menuItems.length; i++) {
            h += menuItems[i].type === "separator" ? 5 : 32;
        }
        if (menuItems.length > 1)
            h += menuItems.length - 1;
        return h;
    }

    function show(x, y, spotlightItem, fromKeyboard) {
        if (!spotlightItem?.data)
            return;

        item = spotlightItem;
        selectedMenuIndex = fromKeyboard ? 0 : -1;
        keyboardNavigation = fromKeyboard;

        const modal = parentHandler?.parentModal ?? null;
        const screenRef = modal?.effectiveScreen ?? parentHandler?.Window?.window?.screen ?? searchField?.Window?.window?.screen ?? null;
        const screenX = screenRef?.x || 0;
        const screenY = screenRef?.y || 0;
        const screenRelativeX = modal ? ((modal.alignedX ?? 0) + x) : ((parentHandler ? parentHandler.mapToGlobal(x, y).x : x) - screenX);
        const screenRelativeY = modal ? ((modal.alignedY ?? 0) + y) : ((parentHandler ? parentHandler.mapToGlobal(x, y).y : y) - screenY);

        targetScreen = screenRef;
        anchorX = screenRelativeX + 4;
        anchorY = screenRelativeY + 4;
        renderActive = true;
        openState = true;

        if (parentHandler)
            parentHandler.enabled = false;

        Qt.callLater(() => {
            menuFlickable.contentY = 0;
            keyboardHandler.forceActiveFocus();
            ensureSelectedVisible();
        });
    }

    function hide() {
        if (!renderActive)
            return;
        openState = false;
        hideRequested();
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
        let count = 0;
        for (let i = 0; i < menuItems.length; i++) {
            if (menuItems[i].type === "item")
                count++;
        }
        return count;
    }

    function selectNext() {
        if (visibleItemCount > 0) {
            keyboardNavigation = true;
            selectedMenuIndex = (selectedMenuIndex + 1) % visibleItemCount;
            ensureSelectedVisible();
        }
    }

    function selectPrevious() {
        if (visibleItemCount > 0) {
            keyboardNavigation = true;
            selectedMenuIndex = (selectedMenuIndex - 1 + visibleItemCount) % visibleItemCount;
            ensureSelectedVisible();
        }
    }

    function selectedDelegateIndex() {
        let itemIndex = 0;
        for (let i = 0; i < menuItems.length; i++) {
            if (menuItems[i].type !== "item")
                continue;
            if (itemIndex === selectedMenuIndex)
                return i;
            itemIndex++;
        }
        return -1;
    }

    function ensureSelectedVisible() {
        Qt.callLater(() => {
            if (!menuFlickable || !menuRepeater)
                return;
            const delegateIndex = selectedDelegateIndex();
            if (delegateIndex < 0)
                return;
            const delegate = menuRepeater.itemAt(delegateIndex);
            if (!delegate)
                return;
            const top = delegate.y;
            const bottom = top + delegate.height;
            const viewTop = menuFlickable.contentY;
            const viewBottom = viewTop + menuFlickable.height;
            if (top < viewTop) {
                menuFlickable.contentY = Math.max(0, top);
            } else if (bottom > viewBottom) {
                menuFlickable.contentY = Math.min(Math.max(0, menuFlickable.contentHeight - menuFlickable.height), bottom - menuFlickable.height);
            }
        });
    }

    function activateSelected() {
        let itemIndex = 0;
        for (let i = 0; i < menuItems.length; i++) {
            if (menuItems[i].type !== "item")
                continue;
            if (itemIndex === selectedMenuIndex) {
                const menuItem = menuItems[i];
                if (menuItem.action)
                    menuItem.action();
                else if (menuItem.pluginAction)
                    executePluginAction(menuItem.pluginAction);
                else if (menuItem.launcherActionData)
                    executeLauncherAction(menuItem.launcherActionData);
                else if (menuItem.actionData)
                    executeDesktopAction(menuItem.actionData);
                return;
            }
            itemIndex++;
        }
    }

    PanelWindow {
        id: menuWindow

        screen: root.targetScreen
        visible: root.renderActive
        color: "transparent"

        WlrLayershell.namespace: "dms:launcher-context-menu"
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: root.renderActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        WindowBlur {
            targetWindow: menuWindow
            blurX: root.blurActive ? menuContainer.x : 0
            blurY: root.blurActive ? menuContainer.y : 0
            blurWidth: root.blurActive ? menuContainer.width : 0
            blurHeight: root.blurActive ? menuContainer.height : 0
            blurRadius: Theme.cornerRadius
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            enabled: root.renderActive
            onClicked: root.hide()
        }

        Item {
            id: keyboardHandler
            anchors.fill: parent
            focus: root.openState

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
                x: Math.max(root.menuMargin, Math.min(menuWindow.width - width - root.menuMargin, root.anchorX))
                y: Math.max(root.menuMargin, Math.min(menuWindow.height - height - root.menuMargin, root.anchorY))
                width: root.effectiveMenuWidth
                height: root.effectiveMenuHeight
                color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
                radius: Theme.cornerRadius
                border.color: BlurService.enabled ? BlurService.borderColor : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                border.width: BlurService.enabled ? BlurService.borderWidth : 1
                opacity: root.openState ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.emphasizedEasing
                        onRunningChanged: {
                            if (!running && !root.openState) {
                                root.renderActive = false;
                                if (root.parentHandler)
                                    root.parentHandler.enabled = true;
                                if (root.searchField?.visible)
                                    Qt.callLater(() => root.searchField.forceActiveFocus());
                            }
                        }
                    }
                }

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

                Flickable {
                    id: menuFlickable
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    clip: true
                    contentWidth: width
                    contentHeight: menuColumn.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: root.menuScrolls

                    Column {
                        id: menuColumn
                        width: menuFlickable.width
                        spacing: 1

                        Repeater {
                            id: menuRepeater
                            model: root.menuItems

                            Item {
                                id: menuItemDelegate
                                required property var modelData
                                required property int index

                                width: menuColumn.width
                                height: modelData.type === "separator" ? 5 : 32

                                readonly property int itemIndex: {
                                    let count = 0;
                                    for (let i = 0; i < index; i++) {
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
                                        return itemMouseArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : "transparent";
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
                                            const menuItem = menuItemDelegate.modelData;
                                            if (menuItem.action)
                                                menuItem.action();
                                            else if (menuItem.pluginAction)
                                                root.executePluginAction(menuItem.pluginAction);
                                            else if (menuItem.launcherActionData)
                                                root.executeLauncherAction(menuItem.launcherActionData);
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
    }
}
