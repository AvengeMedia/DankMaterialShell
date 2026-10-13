pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.DCommon.Widgets
import qs.Widgets

DContextMenu {
    id: root

    property var trayItem: null
    readonly property var menuHandle: trayItem?.menu ?? null

    layerNamespace: "dms:tray-context-menu"
    customContentWidth: Theme.fieldDefaultWidth

    onOpenStateChanged: {
        const screenName = root.targetScreen?.name;
        if (!screenName)
            return;
        if (openState) {
            TrayMenuManager.registerMenu(screenName, { close: () => root.hide() });
            customContentItem?.clearState?.();
        } else {
            TrayMenuManager.unregisterMenu(screenName);
            customContentItem?.clearState?.();
        }
    }

    Component.onDestruction: {
        if (openState && root.targetScreen?.name)
            TrayMenuManager.unregisterMenu(root.targetScreen.name);
    }

    onBackdropRightClicked: root.hide()

    function openFor(item, targetX, targetY, screen, edgeOrBottom) {
        let edge = "top";
        if (typeof edgeOrBottom === "string")
            edge = edgeOrBottom;
        else if (edgeOrBottom === true)
            edge = "bottom";
        root.menuEdge = edge;
        trayItem = item;
        const h = item?.menu ?? null;
        if (h && typeof h.updateLayout === "function")
            h.updateLayout();

        let menuX = targetX;
        let menuY = targetY;

        switch (edge) {
        case "bottom":
            menuX = targetX - effectiveMenuWidth / 2;
            menuY = targetY - Theme.spacingXS;
            break;
        case "left":
            menuX = targetX + Theme.spacingXS;
            menuY = targetY;
            break;
        case "right":
            menuX = targetX - Theme.spacingXS;
            menuY = targetY;
            break;
        case "top":
        default:
            menuX = targetX - effectiveMenuWidth / 2;
            menuY = targetY + Theme.spacingXS;
            break;
        }

        root.open(screen, menuX, menuY, false);
        root.originX = targetX;
        root.originY = targetY;
        customContentItem?.clearState?.();
    }

    Timer {
        id: pendingActionCloseTimer
        interval: 80
        repeat: false
        onTriggered: root.hide()
    }

    customContent: Component {
        Item {
            id: contentRoot
            focus: true

            implicitWidth: root.customContentWidth
            implicitHeight: menuColumn.implicitHeight

            Component.onCompleted: {
                forceActiveFocus();
            }

            ListModel {
                id: entryStack
            }

            function clearState() {
                entryStack.clear();
            }

            function topEntry() {
                return entryStack.count ? entryStack.get(entryStack.count - 1).handle : null;
            }

            function showSubMenu(entry) {
                if (!entry || !entry.hasChildren)
                    return;
                entryStack.append({
                    handle: entry
                });
                const h = entry.menu || entry;
                if (h && typeof h.updateLayout === "function")
                    h.updateLayout();
                submenuHydrator.menu = h;
                submenuHydrator.open();
                Qt.callLater(() => submenuHydrator.close());
            }

            function goBack() {
                if (!entryStack.count)
                    return;
                entryStack.remove(entryStack.count - 1);
            }

            QsMenuAnchor {
                id: submenuHydrator
                anchor.window: root.contextWindow
            }

            QsMenuOpener {
                id: rootOpener
                menu: root.menuHandle
            }

            QsMenuOpener {
                id: subOpener
                menu: {
                    const e = contentRoot.topEntry();
                    return e ? (e.menu || e) : null;
                }
            }

            Keys.onEscapePressed: {
                if (entryStack.count > 0)
                    contentRoot.goBack();
                else
                    root.hide();
            }

            Column {
                id: menuColumn
                width: parent ? parent.width : root.customContentWidth
                spacing: 0

                Rectangle {
                    visible: entryStack.count === 0
                    width: parent.width
                    height: Theme.menuItemHeight
                    radius: Theme.cornerRadiusS
                    color: Theme.withAlpha(Theme.onSurface, visibilityToggleArea.pressed ? Theme.stateLayerPressed : visibilityToggleArea.containsMouse ? Theme.stateLayerHover : 0)

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.trayItem?.tooltipTitle || root.trayItem?.id || I18n.tr("Unknown")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                        elide: Text.ElideMiddle
                        wrapMode: Text.NoWrap
                        maximumLineCount: 1
                        width: parent.width - Theme.spacingS * 2 - (Theme.iconSizeSmall + Theme.spacingS)
                    }

                    DIcon {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        name: SessionData.isHiddenTrayId(root.trayItem?.id || "") ? "visibility" : "visibility_off"
                        size: Theme.iconSizeSmall
                        color: Theme.widgetTextColor
                    }

                    MouseArea {
                        id: visibilityToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const itemId = root.trayItem?.id || "";
                            if (!itemId)
                                return;
                            if (SessionData.isHiddenTrayId(itemId))
                                SessionData.showTrayId(itemId);
                            else
                                SessionData.hideTrayId(itemId);
                            root.hide();
                        }
                    }
                }

                Rectangle {
                    visible: entryStack.count === 0
                    width: parent.width
                    height: Theme.dividerWidth
                    color: Theme.outlineHeavy
                }

                Rectangle {
                    visible: entryStack.count > 0
                    width: parent.width
                    height: Theme.menuItemHeight
                    radius: Theme.cornerRadiusS
                    color: Theme.withAlpha(Theme.onSurface, backArea.pressed ? Theme.stateLayerPressed : backArea.containsMouse ? Theme.stateLayerHover : 0)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        DIcon {
                            name: "arrow_back"
                            size: Theme.iconSizeSmall
                            color: Theme.widgetTextColor
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Back")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.widgetTextColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: backArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: contentRoot.goBack()
                    }
                }

                Rectangle {
                    visible: entryStack.count > 0
                    width: parent.width
                    height: Theme.dividerWidth
                    color: Theme.outlineHeavy
                }

                Repeater {
                    model: entryStack.count ? (subOpener.children ? subOpener.children : (contentRoot.topEntry()?.children || [])) : rootOpener.children

                    Rectangle {
                        id: menuEntryDelegate
                        required property var modelData
                        readonly property var menuEntry: modelData

                        width: menuColumn.width
                        height: menuEntry?.isSeparator ? Theme.dividerWidth : Theme.menuItemHeight
                        radius: menuEntry?.isSeparator ? 0 : Theme.cornerRadiusS
                        color: {
                            if (menuEntry?.isSeparator)
                                return Theme.outlineHeavy;
                            return Theme.withAlpha(Theme.onSurface, entryItemArea.pressed ? Theme.stateLayerPressed : entryItemArea.containsMouse ? Theme.stateLayerHover : 0);
                        }

                        MouseArea {
                            id: entryItemArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !menuEntry?.isSeparator && (menuEntry?.enabled !== false)
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                if (!menuEntry || menuEntry.isSeparator)
                                    return;
                                if (menuEntry.hasChildren) {
                                    contentRoot.showSubMenu(menuEntry);
                                    return;
                                }
                                if (typeof menuEntry.activate === "function") {
                                    menuEntry.activate();
                                } else if (typeof menuEntry.triggered === "function") {
                                    menuEntry.triggered();
                                }
                                pendingActionCloseTimer.restart();
                            }
                        }

                        RowLayout {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS
                            visible: !menuEntry?.isSeparator

                            Rectangle {
                                Layout.preferredWidth: Theme.iconSizeSmall
                                Layout.preferredHeight: Theme.iconSizeSmall
                                Layout.alignment: Qt.AlignVCenter
                                visible: menuEntry?.buttonType !== undefined && menuEntry.buttonType !== 0
                                radius: menuEntry?.buttonType === 2 ? Theme.cornerRadiusFull : Theme.cornerRadiusXXS
                                border.width: Theme.outlineWidth
                                border.color: Theme.outline
                                color: "transparent"

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width - Theme.spacingXS - Theme.spacingXXS
                                    height: parent.height - Theme.spacingXS - Theme.spacingXXS
                                    radius: menuEntry?.buttonType === 2 ? Theme.cornerRadiusFull : Theme.cornerRadiusXXS
                                    color: Theme.primary
                                    visible: menuEntry?.checkState === 2
                                }

                                DIcon {
                                    anchors.centerIn: parent
                                    name: "check"
                                    size: Theme.iconSizeSmall - Theme.spacingXS - Theme.spacingXXS
                                    color: Theme.primaryText
                                    visible: menuEntry?.buttonType === 1 && menuEntry?.checkState === 2
                                }
                            }

                            Item {
                                Layout.preferredWidth: Theme.iconSizeSmall
                                Layout.preferredHeight: Theme.iconSizeSmall
                                Layout.alignment: Qt.AlignVCenter
                                visible: (menuEntry?.icon ?? "") !== ""

                                Image {
                                    anchors.fill: parent
                                    source: menuEntry?.icon || ""
                                    sourceSize.width: Theme.iconSizeSmall
                                    sourceSize.height: Theme.iconSizeSmall
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }
                            }

                            StyledText {
                                text: menuEntry?.text || ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: (menuEntry?.enabled !== false) ? Theme.surfaceText : Theme.surfaceTextMedium
                                elide: Text.ElideRight
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                wrapMode: Text.NoWrap
                            }

                            Item {
                                Layout.preferredWidth: Theme.iconSizeSmall
                                Layout.preferredHeight: Theme.iconSizeSmall
                                Layout.alignment: Qt.AlignVCenter
                                visible: menuEntry?.hasChildren ?? false

                                DIcon {
                                    anchors.centerIn: parent
                                    name: "chevron_right"
                                    size: Theme.iconSizeSmall - 2
                                    color: Theme.widgetTextColor
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
