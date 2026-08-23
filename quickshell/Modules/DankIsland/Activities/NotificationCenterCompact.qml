pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    required property var controller

    readonly property int unreadCount: NotificationService.notifications.length

    function pushMeasuredWidth() {
        root.controller.setDestinationContentWidth("notificationcenter", compactRow.implicitWidth);
    }

    Component.onCompleted: root.pushMeasuredWidth()

    Row {
        id: compactRow

        anchors.centerIn: parent
        spacing: Theme.spacingS

        onImplicitWidthChanged: root.pushMeasuredWidth()

        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.unreadCount > 0 ? "notifications_active" : "notifications"
            size: Theme.iconSizeSmall
            color: Theme.primary
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.unreadCount > 0 ? I18n.tr("Notifications (%1)").arg(root.unreadCount) : I18n.tr("Notifications")
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.DemiBold
        }
    }
}
