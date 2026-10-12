import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modals.Common

Popup {
    id: processContextMenu

    property var processData: null
    property int selectedIndex: -1
    property bool keyboardNavigation: false
    property var parentFocusItem: null
    property var transientSurfaceTracker: null

    readonly property bool confirmationOpen: confirmation.opened

    signal menuClosed
    signal processKilled

    onVisibleChanged: transientSurfaceTracker?.setActive(processContextMenu, visible || confirmationOpen, null)
    onConfirmationOpenChanged: transientSurfaceTracker?.setActive(processContextMenu, visible || confirmationOpen, null)
    Component.onDestruction: transientSurfaceTracker?.unregister(processContextMenu)

    Connections {
        target: processContextMenu.transientSurfaceTracker
        ignoreUnknownSignals: true

        function onCloseRequested() {
            processContextMenu.dismiss();
        }
    }

    readonly property var menuItems: [
        {
            text: I18n.tr("Copy PID"),
            icon: "tag",
            action: copyPid,
            enabled: true
        },
        {
            text: I18n.tr("Copy Name"),
            icon: "content_copy",
            action: copyName,
            enabled: true
        },
        {
            text: I18n.tr("Copy Full Command"),
            icon: "code",
            action: copyFullCommand,
            enabled: true
        },
        {
            type: "separator"
        },
        {
            text: I18n.tr("Quit", "process action: ask the process to exit (SIGTERM)"),
            icon: "close",
            action: () => requestAction("quit"),
            enabled: ProcessActions.canEnd(processData),
            dangerous: true
        },
        {
            text: I18n.tr("Force quit", "process action: kill the process immediately (SIGKILL)"),
            icon: "dangerous",
            action: () => requestAction("force"),
            enabled: ProcessActions.canEnd(processData),
            dangerous: true
        },
        {
            text: I18n.tr("End process tree", "process action: quit the process and every process it started"),
            icon: "account_tree",
            action: () => requestAction("tree"),
            enabled: ProcessActions.canEnd(processData),
            dangerous: true
        },
        {
            text: actionTitle("restart", processData),
            icon: "restart_alt",
            action: () => requestAction("restart"),
            enabled: ProcessActions.canRestart(processData)
        }
    ]

    readonly property int visibleItemCount: {
        let count = 0;
        for (let i = 0; i < menuItems.length; i++) {
            if (menuItems[i].type !== "separator")
                count++;
        }
        return count;
    }

    function show(x, y, fromKeyboard) {
        let finalX = x;
        let finalY = y;

        if (processContextMenu.parent) {
            const parentWidth = processContextMenu.parent.width;
            const parentHeight = processContextMenu.parent.height;
            const menuWidth = processContextMenu.width;
            const menuHeight = processContextMenu.height;

            if (finalX + menuWidth > parentWidth)
                finalX = Math.max(0, parentWidth - menuWidth);
            if (finalY + menuHeight > parentHeight)
                finalY = Math.max(0, parentHeight - menuHeight);
        }

        processContextMenu.x = finalX;
        processContextMenu.y = finalY;
        keyboardNavigation = fromKeyboard || false;
        selectedIndex = fromKeyboard ? 0 : -1;
        open();
    }

    function selectNext() {
        if (visibleItemCount === 0)
            return;
        let current = selectedIndex;
        let next = current;
        do {
            next = (next + 1) % menuItems.length;
        } while (menuItems[next].type === "separator" && next !== current)
        selectedIndex = next;
    }

    function selectPrevious() {
        if (visibleItemCount === 0)
            return;
        let current = selectedIndex;
        let prev = current;
        do {
            prev = (prev - 1 + menuItems.length) % menuItems.length;
        } while (menuItems[prev].type === "separator" && prev !== current)
        selectedIndex = prev;
    }

    function activateSelected() {
        if (selectedIndex < 0 || selectedIndex >= menuItems.length)
            return;
        const item = menuItems[selectedIndex];
        if (item.type === "separator" || !item.enabled)
            return;
        item.action();
    }

    function copyPid() {
        if (processData)
            Quickshell.execDetached(["dms", "cl", "copy", processData.pid.toString()]);
        close();
    }

    function copyName() {
        if (processData) {
            const name = processData.command || "";
            Quickshell.execDetached(["dms", "cl", "copy", name]);
        }
        close();
    }

    function copyFullCommand() {
        if (processData) {
            const fullCmd = processData.fullCommand || processData.command || "";
            Quickshell.execDetached(["dms", "cl", "copy", fullCmd]);
        }
        close();
    }

    function killProcess() {
        requestAction("quit");
    }

    function actionTitle(action, process) {
        return ProcessActions.title(action, process);
    }

    // Ending a critical process warns and offers a restart instead; everything else gets a plain confirmation.
    function requestAction(action) {
        if (!processData || !(action === "restart" ? ProcessActions.canRestart(processData) : ProcessActions.canEnd(processData)))
            return;
        const process = Object.assign({}, processData);
        close();
        confirmation.open(process, action, action !== "restart" && ProcessActions.isCritical(process));
    }

    function dismiss() {
        close();
        confirmation.close();
    }

    ProcessActionDialog {
        id: confirmation
        parent: processContextMenu.parent
        onChosen: (action, process) => {
            if ((process?.pid ?? 0) <= 0)
                return;
            ProcessActions.run(action, process);
            processContextMenu.processKilled();
        }
        onOpenedChanged: {
            if (!opened)
                focusRestore.restart();
        }
    }

    DeferredAction {
        id: focusRestore
        onTriggered: {
            if (!processContextMenu.confirmationOpen && processContextMenu.parentFocusItem?.visible)
                processContextMenu.parentFocusItem.forceActiveFocus();
        }
    }

    width: ProcessListMetrics.menuWidth
    height: menuColumn.implicitHeight + Theme.spacingS * 2
    padding: 0
    modal: false
    closePolicy: Popup.CloseOnEscape

    onClosed: {
        closePolicy = Popup.CloseOnEscape;
        keyboardNavigation = false;
        selectedIndex = -1;
        menuClosed();
        focusRestore.restart();
    }

    onOpened: {
        outsideClickTimer.start();
        if (keyboardNavigation)
            Qt.callLater(() => keyboardHandler.forceActiveFocus());
    }

    Timer {
        id: outsideClickTimer
        interval: 100
        onTriggered: processContextMenu.closePolicy = Popup.CloseOnEscape | Popup.CloseOnPressOutside
    }

    background: Rectangle {
        color: "transparent"
    }

    contentItem: Rectangle {
        color: Theme.foregroundColor(Theme.chipSurfaceNested, Theme.isFloatingWindow(processContextMenu))
        radius: Theme.windowRadius
        border.color: Theme.outlineMedium
        border.width: Theme.layerOutlineWidth

        Item {
            id: keyboardHandler
            anchors.fill: parent
            focus: keyboardNavigation

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Down:
                case Qt.Key_J:
                    keyboardNavigation = true;
                    selectNext();
                    event.accepted = true;
                    return;
                case Qt.Key_Up:
                case Qt.Key_K:
                    keyboardNavigation = true;
                    selectPrevious();
                    event.accepted = true;
                    return;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                case Qt.Key_Space:
                    activateSelected();
                    event.accepted = true;
                    return;
                case Qt.Key_Escape:
                case Qt.Key_Left:
                case Qt.Key_H:
                    close();
                    event.accepted = true;
                    return;
                }
            }
        }

        Column {
            id: menuColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            spacing: Theme.groupedListGap

            Repeater {
                model: menuItems

                Item {
                    width: parent.width
                    height: modelData.type === "separator" ? Theme.spacingS : Theme.menuItemHeight
                    visible: modelData.type !== "separator" || index > 0

                    property int itemVisibleIndex: {
                        let count = 0;
                        for (let i = 0; i < index; i++) {
                            if (menuItems[i].type !== "separator")
                                count++;
                        }
                        return count;
                    }

                    Rectangle {
                        visible: modelData.type === "separator"
                        width: parent.width - Theme.spacingS * 2
                        height: Theme.dividerWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.outlineStrong
                    }

                    Rectangle {
                        id: menuItem
                        visible: modelData.type !== "separator"
                        width: parent.width
                        height: Theme.menuItemHeight
                        radius: Theme.cornerRadiusM
                        color: {
                            if (!modelData.enabled)
                                return "transparent";
                            const isSelected = keyboardNavigation && selectedIndex === index;
                            if (modelData.dangerous) {
                                if (isSelected)
                                    return Theme.errorPressed;
                                return menuItemArea.containsMouse ? Theme.errorHover : Theme.withAlpha(Theme.errorHover, 0);
                            }
                            if (isSelected)
                                return Theme.selectedContainer;
                            return menuItemArea.pressed ? Theme.withAlpha(Theme.onSurface, Theme.stateLayerPressed) : menuItemArea.containsMouse ? Theme.withAlpha(Theme.onSurface, Theme.stateLayerHover) : "transparent";
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DIcon {
                                name: modelData.icon || ""
                                size: Theme.iconSizeSmall
                                color: {
                                    if (!modelData.enabled)
                                        return Theme.onSurface_38;
                                    const isSelected = keyboardNavigation && selectedIndex === index;
                                    if (modelData.dangerous && (menuItemArea.containsMouse || isSelected))
                                        return Theme.error;
                                    return Theme.surfaceText;
                                }
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: modelData.text || ""
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeight
                                color: {
                                    if (!modelData.enabled)
                                        return Theme.onSurface_38;
                                    const isSelected = keyboardNavigation && selectedIndex === index;
                                    if (modelData.dangerous && (menuItemArea.containsMouse || isSelected))
                                        return Theme.error;
                                    return Theme.surfaceText;
                                }
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                width: parent.width - Theme.iconSizeSmall - Theme.spacingS
                            }
                        }

                        DRipple {
                            id: menuItemRipple
                            rippleColor: modelData.dangerous ? Theme.error : Theme.surfaceText
                            cornerRadius: menuItem.radius
                        }

                        MouseArea {
                            id: menuItemArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: modelData.enabled ?? false
                            onEntered: {
                                keyboardNavigation = false;
                                selectedIndex = index;
                            }
                            onPressed: mouse => menuItemRipple.trigger(mouse.x, mouse.y)
                            onClicked: modelData.action()
                        }
                    }
                }
            }
        }
    }
}
