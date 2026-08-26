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

    onRightClicked: {
        const screen = root.parentScreen || Screen;
        if (!screen)
            return;

        const isVertical = root.axis?.isVertical ?? false;
        const edge = root.axis?.edge ?? "top";
        const gap = Math.max(Theme.spacingXS, root.barSpacing ?? Theme.spacingXS);
        const barOffset = root.barThickness + root.barSpacing + gap;
        const localPos = root.visualContent.mapToItem(null, root.visualContent.width / 2, root.visualContent.height / 2);

        let anchorX;
        let anchorY;
        if (isVertical) {
            anchorX = edge === "left" ? barOffset : screen.width - barOffset;
            anchorY = localPos.y;
        } else {
            anchorX = localPos.x;
            anchorY = edge === "bottom" ? screen.height - barOffset : barOffset;
        }

        dndPopupLoader.active = true;
        const popup = dndPopupLoader.item;
        if (!popup)
            return;

        popup.showAt(anchorX, anchorY, isVertical, edge, screen);
    }

    MouseArea {
        x: -root.leftMargin
        y: -root.topMargin
        width: root.width + root.leftMargin + root.rightMargin
        height: root.height + root.topMargin + root.bottomMargin
        acceptedButtons: Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            root.triggerRipple(this, mouse.x, mouse.y);
            SessionData.setDoNotDisturb(!SessionData.doNotDisturb);
        }
    }

    Loader {
        id: dndPopupLoader
        active: false
        sourceComponent: DndDurationPopup {}
    }
}
