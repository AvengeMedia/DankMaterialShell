import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

BasePill {
    id: root

    property bool hasUnread: false
    property bool isActive: false

    content: Component {
        Item {
            implicitWidth: root.widgetThickness - root.horizontalPadding * 2
            implicitHeight: root.widgetThickness - root.horizontalPadding * 2

            DankIcon {
                id: notifIcon
                anchors.centerIn: parent
                name: SessionData.doNotDisturb ? "notifications_off" : "notifications"
                size: Theme.barIconSize(root.barThickness, -4)
                color: SessionData.doNotDisturb ? Theme.error : (root.isActive ? Theme.primary : Theme.surfaceText)
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
}
