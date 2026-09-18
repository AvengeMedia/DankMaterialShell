import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.DankDash

Card {
    id: root

    property bool live: Window.window?.visible ?? false
    property bool dgopRefHeld: false

    readonly property bool narrow: width < DashMetrics.gridRowUnit * 2
    readonly property bool tall: height >= DashMetrics.gridRowUnit * 2
    readonly property bool showHostname: options.hostname !== false && UserInfoService.hostname !== ""
    readonly property bool showCompositor: options.compositor !== false && compositorName !== ""
    readonly property bool showUptime: options.uptime !== false
    readonly property bool showBadge: options.badge !== false
    readonly property real avatarSize: Math.min(tall ? DashMetrics.avatarSizeHero : DashMetrics.avatarSize, height - pad * 2, width - pad * 2)
    readonly property color badgeColor: tinted ? contentColor : Theme.primaryContainer
    readonly property color badgeContentColor: tinted ? containerColor : Theme.onPrimaryContainer
    readonly property string compositorName: CompositorService.displayName
    readonly property string uptimeText: {
        const prefix = I18n.tr("up", "uptime prefix, e.g. 'up 4h 2m'");
        return DgopService.shortUptime ? prefix + DgopService.shortUptime.slice(2) : prefix;
    }
    readonly property string avatarSource: {
        if (PortalService.profileImage === "")
            return "";
        if (PortalService.profileImage.startsWith("/"))
            return "file://" + PortalService.profileImage;
        return PortalService.profileImage;
    }

    entryId: "user"

    function syncDgopRef(wanted) {
        if (wanted === dgopRefHeld)
            return;
        dgopRefHeld = wanted;
        if (wanted) {
            DgopService.addRef("system");
            return;
        }
        DgopService.removeRef("system");
    }

    onLiveChanged: syncDgopRef(live && showUptime)
    onShowUptimeChanged: syncDgopRef(live && showUptime)
    Component.onCompleted: syncDgopRef(live && showUptime)
    Component.onDestruction: syncDgopRef(false)

    Item {
        id: avatarBox

        x: root.narrow ? (parent.width - width) / 2 : 0
        anchors.verticalCenter: parent.verticalCenter
        width: root.avatarSize
        height: root.avatarSize

        DankCircularImage {
            anchors.fill: parent
            imageSource: root.avatarSource
            fallbackIcon: "material:person"
        }

        DankMaterialShape {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -DashMetrics.userBadgeSize * DashMetrics.userBadgeOverhang
            anchors.bottomMargin: -DashMetrics.userBadgeSize * DashMetrics.userBadgeOverhang
            width: DashMetrics.userBadgeSize
            height: DashMetrics.userBadgeSize
            shape: "gem"
            color: root.badgeColor
            visible: root.showBadge

            SystemLogo {
                anchors.centerIn: parent
                width: DashMetrics.userBadgeIconSize
                height: DashMetrics.userBadgeIconSize
                colorOverride: root.badgeContentColor
            }
        }
    }

    Column {
        anchors.left: avatarBox.right
        anchors.leftMargin: Theme.spacingM
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXS
        visible: !root.narrow

        StyledText {
            width: parent.width
            text: root.showHostname ? UserInfoService.username + " @ " + UserInfoService.hostname : UserInfoService.username
            font.pixelSize: root.tall ? Theme.fontSizeXLarge : Theme.fontSizeLarge
            font.weight: Theme.fontWeightMedium
            color: root.contentColor
            elide: Text.ElideRight
        }

        Row {
            id: detailRow

            width: parent.width
            height: DashMetrics.userChipHeight
            spacing: Theme.spacingS

            Row {
                id: compositorDetails
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS
                visible: root.showCompositor

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "select_window"
                    size: Theme.iconSizeSmall
                    color: root.mutedColor
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.compositorName
                    font.pixelSize: Theme.fontSizeSmall
                    color: root.mutedColor
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (compositorDetails.visible ? compositorDetails.width + parent.spacing : 0)
                spacing: Theme.spacingXS
                visible: root.showUptime && DgopService.shortUptime !== ""

                DankIcon {
                    id: uptimeIcon
                    anchors.verticalCenter: parent.verticalCenter
                    name: "schedule"
                    size: Theme.iconSizeSmall
                    color: root.mutedColor
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - uptimeIcon.width - parent.spacing
                    text: root.uptimeText
                    font.pixelSize: Theme.fontSizeSmall
                    color: root.mutedColor
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }
            }
        }
    }
}
