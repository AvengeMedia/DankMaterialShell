import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property bool editMode: false

    signal powerButtonClicked
    signal lockRequested
    signal editModeToggled
    signal settingsButtonClicked

    Component.onCompleted: DgopService.addRef("system")
    Component.onDestruction: DgopService.removeRef("system")

    implicitHeight: 70
    radius: Theme.cornerRadius
    color: Theme.nestedSurface
    border.color: Theme.outlineMedium
    border.width: Theme.layerOutlineWidth

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacingL
        anchors.rightMargin: Theme.spacingL
        spacing: Theme.spacingM

        DankCircularImage {
            id: avatarContainer

            width: 60
            height: 60
            imageSource: {
                if (PortalService.profileImage === "")
                    return "";

                if (PortalService.profileImage.startsWith("/"))
                    return "file://" + PortalService.profileImage;

                return PortalService.profileImage;
            }
            fallbackIcon: "person"
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Typography {
                text: UserInfoService.fullName || UserInfoService.username || I18n.tr("User")
                style: Typography.Style.Subtitle
                color: Theme.surfaceText
            }

            Typography {
                text: DgopService.uptime || I18n.tr("Unknown")
                style: Typography.Style.Caption
                color: Theme.surfaceVariantText
            }
        }
    }

    Row {
        id: actionButtonsRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: Theme.spacingXS
        spacing: Theme.spacingXS

        DankActionButton {
            buttonSize: 36
            iconName: "lock"
            iconSize: Theme.iconSize - 4
            iconColor: Theme.surfaceText
            backgroundColor: "transparent"
            onClicked: {
                root.lockRequested();
            }
        }

        DankActionButton {
            buttonSize: 36
            iconName: "power_settings_new"
            iconSize: Theme.iconSize - 4
            iconColor: Theme.surfaceText
            backgroundColor: "transparent"
            onClicked: root.powerButtonClicked()
        }

        DankActionButton {
            buttonSize: 36
            iconName: "settings"
            iconSize: Theme.iconSize - 4
            iconColor: Theme.surfaceText
            backgroundColor: "transparent"
            onClicked: {
                root.settingsButtonClicked();
                PopoutService.focusOrToggleSettings();
            }
        }

        DankActionButton {
            buttonSize: 36
            iconName: editMode ? "done" : "edit"
            iconSize: Theme.iconSize - 4
            iconColor: editMode ? Theme.primary : Theme.surfaceText
            backgroundColor: "transparent"
            onClicked: root.editModeToggled()
        }
    }
}
