import QtQuick
import qs.Common
import qs.Modules.Notifications
import qs.Services
import qs.Widgets

Item {
    id: root

    width: parent.width
    height: NotificationMetrics.emptyHeight
    visible: NotificationService.notifications.length === 0

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingXS
        width: parent.width * NotificationMetrics.screenHeightRatio

        DankIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "notifications_none"
            size: Theme.iconSizeLarge + Theme.spacingL
            color: Theme.onSurfaceVariant
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.tr("Nothing to see here")
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.onSurfaceVariant
            font.weight: Theme.fontWeightMedium
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
