import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

SettingsNavRow {
    title: UserInfoService.fullName || I18n.tr("User")
    hint: DgopService.hostname || "DMS"
    paddingH: Theme.spacingL
    rowColor: "transparent"
    showChevron: false

    leading: DankCircularImage {
        width: SettingsMetrics.avatarSize
        height: width
        imageSource: PortalService.profileImage
        fallbackIcon: "person"
    }
}
