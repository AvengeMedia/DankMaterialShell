import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets

Popup {
    id: processContextMenu

    property var processData: null
    property int selectedIndex: -1
    property bool keyboardNavigation: false
    property var parentFocusItem: null

    signal menuClosed
    signal processKilled

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
            text: I18n.tr("Kill Process"),
            icon: "close",
            action: killProcess,
            enabled: true,
            dangerous: true
        },
        {
            text: I18n.tr("Force Kill (SIGKILL)"),
            icon: "dangerous",
            action: forceKillProcess,
            enabled: processData && processData.pid > 1000,
            dangerous: true
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
        if (processData)
            Quickshell.execDetached(["kill", processData.pid.toString()]);
        processKilled();
        close();
    }

    function forceKillProcess() {
        if (processData)
            Quickshell.execDetached(["kill", "-9", processData.pid.toString()]);
        processKilled();
        close();
    }

    width: 200
    height: menuColumn.implicitHeight + Theme.spacingS * 2
    padding: 0
    modal: false
    closePolicy: Popup.CloseOnEscape

    onClosed: {
        closePolicy = Popup.CloseOnEscape;
        keyboardNavigation = false;
        selectedIndex = -1;
        menuClosed();
        if (parentFocusItem)
            Qt.callLater(() => parentFocusItem.forceActiveFocus());
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
        color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
        radius: Theme.cornerRadius
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1

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
            spacing: 1

            Repeater {
                model: menuItems

                Item {
                    width: parent.width
                    height: modelData.type === "separator" ? 5 : 32
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
                        height: 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                    }

                    Rectangle {
                        id: menuItem
                        visible: modelData.type !== "separator"
                        width: parent.width
                        height: 32
                        radius: Theme.cornerRadius
                        color: {
                            if (!modelData.enabled)
                                return "transparent";
                            const isSelected = keyboardNavigation && selectedIndex === index;
                            if (modelData.dangerous) {
                                if (isSelected)
                                    return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2);
                                return menuItemArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12) : "transparent";
                            }
                            if (isSelected)
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2);
                            return menuItemArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent";
                        }
                        opacity: modelData.enabled ? 1 : 0.5

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: modelData.icon || ""
                                size: 16
                                color: {
                                    if (!modelData.enabled)
                                        return Theme.surfaceVariantText;
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
                                font.weight: Font.Normal
                                color: {
                                    if (!modelData.enabled)
                                        return Theme.surfaceVariantText;
                                    const isSelected = keyboardNavigation && selectedIndex === index;
                                    if (modelData.dangerous && (menuItemArea.containsMouse || isSelected))
                                        return Theme.error;
                                    return Theme.surfaceText;
                                }
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        DankRipple {
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
