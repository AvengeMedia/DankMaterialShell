pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.Common
import qs.DCommon.Widgets
import qs.Widgets

DContextMenu {
    id: root

    property var hiddenItems: []
    property var contextMenu: null
    property var parentScreen: null

    signal itemActivated(var item)

    layerNamespace: "dms:tray-overflow-menu"
    minMenuWidth: 0

    readonly property real iconSize: Theme.iconSizeSmall
    readonly property real itemSize: iconSize + Theme.spacingS
    readonly property real iconSpacing: Theme.spacingXXS
    readonly property int cols: Math.min(5, Math.max(1, hiddenItems.length))
    readonly property int rows: Math.ceil(Math.max(1, hiddenItems.length) / cols)
    readonly property real expectedHeight: rows * itemSize + (rows - 1) * iconSpacing + Theme.spacingS * 2

    // DContextMenu has flickable margins Theme.spacingS on both sides
    customContentWidth: cols * itemSize + (cols - 1) * iconSpacing + Theme.spacingS * 2
    readonly property real naturalMenuHeight: expectedHeight

    function openAt(targetX, targetY, screen, edge) {
        root.menuEdge = edge || "top";
        parentScreen = screen;
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
    }

    customContent: Component {
        Item {
            id: contentContainer
            implicitWidth: overflowGrid.implicitWidth
            implicitHeight: overflowGrid.implicitHeight
            width: implicitWidth
            height: implicitHeight

            Grid {
                id: overflowGrid
                anchors.centerIn: parent
                columns: root.cols
                spacing: root.iconSpacing

                Repeater {
                    model: root.hiddenItems

                    Item {
                        id: overflowItemRoot
                        required property var modelData
                        readonly property var trayItem: modelData

                        width: root.itemSize
                        height: root.itemSize

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.fullRadius(width, height)
                            color: itemArea.pressed
                                ? Theme.withAlpha(Theme.surfaceText, Theme.stateLayerPressed)
                                : (itemArea.containsMouse ? Theme.surfaceTextHover : "transparent")
                        }

                        TrayItemIcon {
                            anchors.centerIn: parent
                            trayItem: overflowItemRoot.trayItem
                            source: TrayMenuManager.iconSourceFor(overflowItemRoot.trayItem)
                            iconSize: root.iconSize
                            fallbackTextColor: Theme.surfaceTextSecondary
                        }

                        MouseArea {
                            id: itemArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor

                            onClicked: mouse => {
                                if (!overflowItemRoot.trayItem)
                                    return;
                                const screen = root.parentScreen;

                                if (mouse.button === Qt.RightButton) {
                                    if (overflowItemRoot.trayItem.hasMenu && root.contextMenu) {
                                        root.itemActivated(overflowItemRoot.trayItem);
                                        root.hide();
                                        root.contextMenu.openFor(overflowItemRoot.trayItem, root.originX, root.originY, screen, root.menuEdge);
                                        return;
                                    }
                                    const gp = itemArea.mapToGlobal(mouse.x, mouse.y);
                                    TrayMenuManager.callContextMenuFallback(overflowItemRoot.trayItem.id, gp.x, gp.y);
                                    root.hide();
                                    return;
                                }

                                if (!overflowItemRoot.trayItem.onlyMenu) {
                                    overflowItemRoot.trayItem.activate();
                                    root.hide();
                                    return;
                                }
                                if (overflowItemRoot.trayItem.hasMenu && root.contextMenu) {
                                    root.itemActivated(overflowItemRoot.trayItem);
                                    root.hide();
                                    root.contextMenu.openFor(overflowItemRoot.trayItem, root.originX, root.originY, screen, root.menuEdge);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
