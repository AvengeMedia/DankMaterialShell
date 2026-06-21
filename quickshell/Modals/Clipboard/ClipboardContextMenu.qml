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

    property var entry: null
    property var modal: null
    property var parentHandler: null
    property real menuMargin: 8
    property var targetScreen: null
    property real anchorX: 0
    property real anchorY: 0
    property bool openState: false
    property bool renderActive: false
    readonly property bool blurActive: renderActive && openState && BlurService.enabled && Theme.connectedSurfaceBlurEnabled

    readonly property bool hasPinnedDuplicate: !!entry && !entry.pinned && ClipboardService.getPinnedEntryByHash(entry.hash) !== null
    readonly property bool canEditEntry: !!entry && !(entry.isImage ?? false)
    readonly property string pinText: entry?.pinned || hasPinnedDuplicate ? I18n.tr("Unpin") : I18n.tr("Pin")
    readonly property string pinIcon: entry?.pinned || hasPinnedDuplicate ? "keep_off" : "push_pin"

    readonly property var menuItems: {
        const items = [
            {
                type: "item",
                icon: "content_copy",
                text: I18n.tr("Copy"),
                action: copyEntry
            },
            {
                type: "item",
                icon: pinIcon,
                text: pinText,
                action: togglePin
            }
        ];

        if (canEditEntry) {
            items.push({
                type: "item",
                icon: "edit",
                text: I18n.tr("Edit"),
                action: editEntry
            });
        }

        items.push({
            type: "item",
            icon: "delete",
            text: I18n.tr("Delete"),
            action: deleteEntry
        }, {
            type: "separator"
        }, {
            type: "item",
            icon: "content_paste",
            text: I18n.tr("Paste"),
            action: pasteEntry
        });

        return items;
    }

    readonly property real minMenuWidth: 160
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

    TextMetrics {
        id: menuTextMetrics
        text: root.longestMenuText
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Normal
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

    function show(x, y, targetEntry) {
        if (!targetEntry)
            return;

        entry = targetEntry;

        const host = modal?.surfaceHost ?? null;
        const modalWindow = modal?.Window?.window ?? null;
        const screenRef = host?.effectiveScreen ?? host?.screen ?? modalWindow?.screen ?? parentHandler?.Window?.window?.screen ?? null;
        const screenX = screenRef?.x || 0;
        const screenY = screenRef?.y || 0;
        const hostX = host?.alignedX;
        const hostY = host?.renderedAlignedY ?? host?.alignedY;
        const globalPos = (!isNaN(hostX) && !isNaN(hostY)) ? ({
            x: screenX + hostX + x,
            y: screenY + hostY + y
        }) : (parentHandler ? parentHandler.mapToGlobal(x, y) : ({
            x: screenX + x,
            y: screenY + y
        }));

        targetScreen = screenRef;
        anchorX = globalPos.x - screenX + 4;
        anchorY = globalPos.y - screenY + 4;
        renderActive = true;
        openState = true;

        Qt.callLater(() => menuFlickable.contentY = 0);
    }

    function hide() {
        if (!renderActive)
            return;
        openState = false;
    }

    function showFromWindowPoint(x, y) {
        if (!parentHandler || typeof parentHandler.contextEntryAtScreen !== "function") {
            hide();
            return;
        }

        const hit = parentHandler.contextEntryAtScreen(x, y);

        if (!hit || !hit.entry) {
            hide();
            return;
        }

        show(hit.x, hit.y, hit.entry);
    }

    function copyEntry() {
        if (!entry)
            return;
        modal?.copyEntry(entry);
        hide();
    }

    function togglePin() {
        if (!entry)
            return;
        if (entry.pinned) {
            modal?.unpinEntry(entry);
        } else {
            const duplicate = ClipboardService.getPinnedEntryByHash(entry.hash);
            if (duplicate)
                modal?.unpinEntry(duplicate);
            else
                modal?.pinEntry(entry);
        }
        hide();
    }

    function editEntry() {
        if (!entry || !canEditEntry)
            return;
        modal?.editEntry(entry);
        hide();
    }

    function deleteEntry() {
        if (!entry)
            return;
        if (entry.pinned)
            modal?.deletePinnedEntry(entry);
        else
            modal?.deleteEntry(entry);
        hide();
    }

    function pasteEntry() {
        if (!entry)
            return;
        modal?.pasteEntry(entry);
        hide();
    }

    PanelWindow {
        id: menuWindow

        screen: root.targetScreen
        visible: root.renderActive
        color: "transparent"

        WlrLayershell.namespace: "dms:clipboard-context-menu"
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

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
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    root.showFromWindowPoint(mouse.x, mouse.y);
                    return;
                }
                root.hide();
            }
        }

        Item {
            anchors.fill: parent

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
                            model: root.menuItems

                            Item {
                                id: menuItemDelegate
                                required property var modelData

                                width: menuColumn.width
                                height: modelData.type === "separator" ? 5 : 32

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
                                    color: itemMouseArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : "transparent"

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
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onPressed: mouse => menuItemRipple.trigger(mouse.x, mouse.y)
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.RightButton) {
                                                root.hide();
                                                return;
                                            }
                                            const menuItem = menuItemDelegate.modelData;
                                            if (menuItem.action)
                                                menuItem.action();
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
