import QtQuick
import qs.Common
import qs.Modules.Notifications.Center
import qs.Modules.Plugins
import qs.Widgets

BasePill {
    id: root

    property bool hasUnread: false
    property bool isActive: false

    content: Component {
        Item {
            implicitWidth: notifIcon.width
            implicitHeight: root.widgetThickness - root.horizontalPadding * 2

            DankIcon {
                id: notifIcon
                anchors.centerIn: parent
                name: SessionData.doNotDisturb ? "notifications_off" : "notifications"
                size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                color: SessionData.doNotDisturb ? Theme.primary : (root.isActive ? Theme.primary : Theme.widgetIconColor)
            }

            Rectangle {
                width: 6
                height: 6
                radius: 3
                color: Theme.error
                anchors.right: notifIcon.right
                anchors.top: notifIcon.top
                visible: root.hasUnread
            }
        }
    }

    onRightClicked: (rx, ry) => {
        const screen = root.parentScreen || Screen;
        if (!screen)
            return;
        const globalPos = root.visualContent.mapToItem(null, 0, 0);
        const isVertical = root.axis?.isVertical ?? false;
        const edge = root.axis?.edge ?? "top";
        const gap = Math.max(Theme.spacingXS, root.barSpacing ?? Theme.spacingXS);
        const barOffset = root.barThickness + root.barSpacing + gap;

        let anchorX;
        let anchorY;
        let anchorEdge;
        if (isVertical) {
            anchorY = globalPos.y - (screen.y || 0) + root.visualContent.height / 2;
            if (edge === "left") {
                anchorX = barOffset;
                anchorEdge = "top";
            } else {
                anchorX = screen.width - barOffset;
                anchorEdge = "top";
            }
        } else {
            anchorX = globalPos.x - (screen.x || 0) + root.visualContent.width / 2;
            if (edge === "bottom") {
                anchorY = screen.height - barOffset;
                anchorEdge = "bottom";
            } else {
                anchorY = barOffset;
                anchorEdge = "top";
            }
        }

        dndPopupLoader.active = true;
        const popup = dndPopupLoader.item;
        if (!popup)
            return;
        popup.showAt(anchorX, anchorY, screen, anchorEdge);
    }

    Loader {
        id: dndPopupLoader
        active: false
        sourceComponent: DndDurationPopup {}
    }
}
