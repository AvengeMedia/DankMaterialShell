import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var keyboardController: null
    property bool showSettings: false

    width: parent.width
    height: 32

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXS

        StyledText {
            text: I18n.tr("Notifications")
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.surfaceText
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }

        DankActionButton {
            id: doNotDisturbButton

            iconName: SessionData.doNotDisturb ? "notifications_off" : "notifications"
            iconColor: SessionData.doNotDisturb ? Theme.error : Theme.surfaceText
            buttonSize: 28
            anchors.verticalCenter: parent.verticalCenter
            onClicked: SessionData.setDoNotDisturb(!SessionData.doNotDisturb)
            onEntered: {
                tooltipLoader.active = true
                if (tooltipLoader.item) {
                    const p = mapToItem(null, width / 2, 0)
                    tooltipLoader.item.show(I18n.tr("Do Not Disturb"), p.x, p.y - 40, null)
                }
            }
            onExited: {
                if (tooltipLoader.item) {
                    tooltipLoader.item.hide()
                }
                tooltipLoader.active = false
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXS

        DankActionButton {
            id: helpButton
            iconName: "info"
            iconColor: (keyboardController && keyboardController.showKeyboardHints) ? Theme.primary : Theme.surfaceText
            buttonSize: 28
            visible: keyboardController !== null
            anchors.verticalCenter: parent.verticalCenter
            onClicked: {
                if (keyboardController) {
                    keyboardController.showKeyboardHints = !keyboardController.showKeyboardHints
                }
            }
        }

        DankActionButton {
            id: settingsButton
            iconName: "settings"
            iconColor: root.showSettings ? Theme.primary : Theme.surfaceText
            buttonSize: 28
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.showSettings = !root.showSettings
        }

        Rectangle {
            id: clearAllButton

            width: 120
            height: 28
            radius: Theme.cornerRadius
            visible: NotificationService.notifications.length > 0
            color: clearArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceContainerHigh

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: "delete_sweep"
                    size: Theme.iconSizeSmall
                    color: clearArea.containsMouse ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: I18n.tr("Clear")
                    font.pixelSize: Theme.fontSizeSmall
                    color: clearArea.containsMouse ? Theme.primary : Theme.surfaceText
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: clearArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: NotificationService.clearAllNotifications()
            }

        }
    }

    Loader {
        id: tooltipLoader

        active: false
        sourceComponent: DankTooltip {}
    }
}
