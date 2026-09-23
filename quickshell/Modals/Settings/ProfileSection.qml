import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

SettingsNavRow {
    id: root

    title: UserInfoService.fullName || I18n.tr("User")
    hint: DgopService.hostname || "DMS"
    singleLineTitle: true
    paddingH: Theme.spacingL
    paddingV: Theme.spacingS
    minHeight: Theme.listItemHeight
    showChevron: false

    leading: Item {
        width: SettingsMetrics.navIconSize + Theme.spacingM - Theme.spacingL
        height: Theme.minimumTouchTargetSize

        DankCircularImage {
            width: Theme.minimumTouchTargetSize
            height: width
            anchors.left: parent.left
            anchors.leftMargin: (SettingsMetrics.navIconSize - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            imageSource: PortalService.profileImage
            fallbackIcon: imageSource ? "person" : ""
            fallbackText: root.title.charAt(0).toLocaleUpperCase()
        }
    }
}
