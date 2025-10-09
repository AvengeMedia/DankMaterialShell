import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    width: parent.width
    height: 200
    visible: NotificationService.notifications.length === 0

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingXS
        width: parent.width * 0.8

        DankIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "notifications_none"
            size: Theme.iconSizeLarge + 16
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.3)
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.tr("Nothing to see here")
            font.pixelSize: Theme.fontSizeLarge
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.3)
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
