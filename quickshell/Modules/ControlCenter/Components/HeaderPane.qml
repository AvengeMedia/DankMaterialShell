import QtQuick
import qs.Common
import qs.Modules.ControlCenter
import qs.Services
import qs.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property bool editMode: false
    property bool tapToClose: false
    property bool live: true

    signal powerButtonClicked
    signal lockRequested
    signal editModeToggled
    signal editCancelled
    signal settingsButtonClicked
    signal headerTapped

    Ref {
        service: DgopService
        modules: "system"
        active: root.live && root.visible && (root.Window.window?.visible ?? false)
    }

    implicitHeight: CcMetrics.headerHeight
    height: implicitHeight

    MouseArea {
        anchors.fill: parent
        enabled: root.tapToClose
        acceptedButtons: Qt.LeftButton
        onClicked: root.headerTapped()
    }

    Item {
        anchors.left: parent.left
        anchors.right: actionButtonsRow.left
        anchors.rightMargin: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacingS
        height: CcMetrics.headerAvatarSize

        DankCircularImage {
            id: avatar
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: CcMetrics.headerAvatarSize
            height: CcMetrics.headerAvatarSize
            imageSource: {
                if (PortalService.profileImage === "")
                    return "";
                if (PortalService.profileImage.startsWith("/"))
                    return "file://" + PortalService.profileImage;
                return PortalService.profileImage;
            }
            fallbackIcon: "person"
        }

        Item {
            anchors.left: avatar.right
            anchors.leftMargin: Theme.spacingM
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: userLabel.implicitHeight + Theme.spacingXXS + uptimeLabel.implicitHeight

            StyledText {
                id: userLabel
                width: parent.width
                text: UserInfoService.fullName || UserInfoService.username || I18n.tr("User")
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Theme.fontWeightMedium
                color: Theme.surfaceText
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
            }

            StyledText {
                id: uptimeLabel
                y: userLabel.implicitHeight + Theme.spacingXXS
                width: parent.width
                text: DgopService.uptime ? I18n.tr("up", "uptime prefix, e.g. 'up 4h 2m'") + " " + DgopService.uptime.slice(3) : I18n.tr("Unknown")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
            }
        }
    }

    Row {
        id: actionButtonsRow
        height: CcMetrics.headerActionSize
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXS

        DankActionButton {
            buttonSize: CcMetrics.headerActionSize
            iconSize: CcMetrics.headerActionIconSize
            iconName: "lock"
            iconColor: Theme.surfaceText
            Accessible.name: I18n.tr("Lock")
            onClicked: root.lockRequested()
        }

        DankActionButton {
            buttonSize: CcMetrics.headerActionSize
            iconSize: CcMetrics.headerActionIconSize
            iconName: "power_settings_new"
            iconColor: Theme.surfaceText
            Accessible.name: I18n.tr("Power")
            onClicked: root.powerButtonClicked()
        }

        DankActionButton {
            buttonSize: CcMetrics.headerActionSize
            iconSize: CcMetrics.headerActionIconSize
            iconName: "settings"
            iconColor: Theme.surfaceText
            Accessible.name: I18n.tr("Settings")
            onClicked: root.settingsButtonClicked()
        }

        DankActionButton {
            buttonSize: CcMetrics.headerActionSize
            iconSize: CcMetrics.headerActionIconSize
            iconName: "close"
            iconColor: Theme.surfaceText
            visible: root.editMode
            Accessible.name: I18n.tr("Cancel")
            onClicked: root.editCancelled()
        }

        DankActionButton {
            buttonSize: CcMetrics.headerActionSize
            iconSize: CcMetrics.headerActionIconSize
            iconName: root.editMode ? "done" : "edit"
            iconColor: root.editMode ? Theme.onSecondaryContainer : Theme.surfaceText
            backgroundColor: root.editMode ? Theme.secondaryContainer : "transparent"
            Accessible.name: root.editMode ? I18n.tr("Finish") : I18n.tr("Edit")
            onClicked: root.editModeToggled()
        }
    }
}
