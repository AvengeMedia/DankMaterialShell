import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Card {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    Component.onCompleted: DgopService.addRef("system")
    Component.onDestruction: DgopService.removeRef("system")

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingM

        DankCircularImage {
            id: avatarContainer

            width: 77
            height: 77
            anchors.verticalCenter: parent.verticalCenter
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
            spacing: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: UserInfoService.username || I18n.tr("brandon")
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
                elide: Text.ElideRight
                width: parent.parent.parent.width - avatarContainer.width - Theme.spacingM * 3
                horizontalAlignment: Text.AlignLeft
            }

            Row {
                anchors.left: parent.left
                spacing: Theme.spacingS

                SystemLogo {
                    width: 16
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    colorOverride: Theme.primary
                }

                StyledText {
                    text: {
                        if (CompositorService.isNiri)
                            return I18n.tr("on Niri");
                        if (CompositorService.isHyprland)
                            return I18n.tr("on Hyprland");
                        // technically they might not be on mangowc, but its what we support in the docs
                        if (CompositorService.isDwl)
                            return I18n.tr("on MangoWC");
                        if (CompositorService.isSway)
                            return I18n.tr("on Sway");
                        if (CompositorService.isScroll)
                            return I18n.tr("on Scroll");
                        if (CompositorService.isMiracle)
                            return I18n.tr("on Miracle WM");
                        return "";
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    width: parent.parent.parent.parent.width - avatarContainer.width - Theme.spacingM * 3 - 16 - Theme.spacingS
                    horizontalAlignment: Text.AlignLeft
                }
            }

            Row {
                anchors.left: parent.left
                spacing: Theme.spacingS

                DankIcon {
                    name: "schedule"
                    size: 16
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: DgopService.shortUptime || I18n.tr("up")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
