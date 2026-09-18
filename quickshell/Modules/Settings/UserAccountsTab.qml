import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Column {
    id: root

    property var parentModal: null

    spacing: Theme.spacingL

    SettingsCard {
        title: I18n.tr("Profile", "noun, user account settings card title, profile image")
        settingKey: "userProfile"
        tags: ["user", "account", "profile", "avatar", "image"]

        SettingsRow {
            title: UserInfoService.fullName || UserInfoService.username
            subtitle: UserInfoService.username
            settingKey: "profileImage"
            tags: ["user", "account", "profile", "avatar", "image"]

            leading: DankCircularImage {
                width: SettingsMetrics.avatarSize
                height: width
                imageSource: PortalService.profileImage
                fallbackIcon: "person"
            }

            DankActionButton {
                iconName: "edit"
                tooltipText: I18n.tr("Select Profile Image", "profile image file browser title")
                onClicked: root.parentModal?.openProfileBrowser()
            }

            DankActionButton {
                iconName: "close"
                Accessible.name: I18n.tr("Clear")
                enabled: PortalService.profileImage !== ""
                onClicked: PortalService.setProfileImage("")
            }
        }
    }
}
