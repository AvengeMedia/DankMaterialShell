import QtQuick
import QtQuick.Effects
import qs.Common
import qs.DankCommon.Common as DankCommon
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: aboutTab

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property bool isHyprland: CompositorService.isHyprland
    property bool isNiri: CompositorService.isNiri
    property bool isSway: CompositorService.isSway
    property bool isScroll: CompositorService.isScroll
    property bool isMiracle: CompositorService.isMiracle
    property bool isMango: CompositorService.isMango
    property bool isLabwc: CompositorService.isLabwc
    property bool isAqueous: CompositorService.isAqueous

    property string compositorName: {
        if (isHyprland)
            return "hyprland";
        if (isSway)
            return "sway";
        if (isScroll)
            return "scroll";
        if (isMiracle)
            return "miracle";
        if (isMango)
            return "mangowc";
        if (isLabwc)
            return "labwc";
        if (isAqueous)
            return "aqueous";
        return "niri";
    }

    property string compositorLogo: {
        if (isHyprland)
            return "/assets/hyprland.svg";
        if (isSway)
            return "/assets/sway.svg";
        if (isScroll)
            return "/assets/sway.svg";
        if (isMiracle)
            return "/assets/miraclewm.svg";
        if (isMango)
            return "/assets/mango.png";
        if (isLabwc)
            return "/assets/labwc.png";
        if (isAqueous)
            return "/assets/aqueous.svg";
        return "/assets/niri.svg";
    }

    property string compositorUrl: {
        if (isHyprland)
            return "https://hypr.land";
        if (isSway)
            return "https://swaywm.org";
        if (isScroll)
            return "https://github.com/dawsers/scroll";
        if (isMiracle)
            return "https://github.com/miracle-wm-org/miracle-wm";
        if (isMango)
            return "https://github.com/DreamMaoMao/mangowc";
        if (isLabwc)
            return "https://labwc.github.io/";
        if (isAqueous)
            return "";
        return "https://github.com/niri-wm/niri";
    }

    property string compositorTooltip: {
        if (isHyprland)
            return I18n.tr("Hyprland website");
        if (isSway)
            return I18n.tr("Sway website");
        if (isScroll)
            return I18n.tr("Scroll GitHub");
        if (isMiracle)
            return I18n.tr("Scroll GitHub");
        if (isMango)
            return I18n.tr("mangowc GitHub");
        if (isLabwc)
            return I18n.tr("LabWC website");
        if (isAqueous)
            return "Aqueous";
        return I18n.tr("niri GitHub");
    }

    property string dmsDiscordUrl: "https://discord.gg/ppWTpKmPgT"
    property string dmsDiscordTooltip: I18n.tr("niri/dms Discord")

    property string compositorDiscordUrl: {
        if (isHyprland)
            return "https://discord.com/invite/hQ9XvMUjjr";
        if (isMango)
            return "https://discord.gg/CPjbDxesh5";
        return "";
    }

    property string compositorDiscordTooltip: {
        if (isHyprland)
            return I18n.tr("Hyprland Discord server");
        if (isMango)
            return I18n.tr("mangowc Discord server");
        return "";
    }

    property string redditUrl: "https://reddit.com/r/niri"
    property string redditTooltip: I18n.tr("r/niri subreddit")

    property string ircUrl: "https://web.libera.chat/gamja/?channels=#labwc"
    property string ircTooltip: I18n.tr("LabWC IRC channel")

    property bool showMatrix: isNiri && !isHyprland && !isSway && !isScroll && !isMiracle && !isMango && !isLabwc
    property bool showCompositorDiscord: isHyprland || isMango
    property bool showReddit: isNiri && !isHyprland && !isSway && !isScroll && !isMiracle && !isMango && !isLabwc
    property bool showIrc: isLabwc

    SettingsPage {
        id: mainColumn

        SettingsCard {
            width: parent.width

            SettingsRow {
                body: Column {
                    id: asciiSection
                    width: parent.width
                    spacing: Theme.spacingM

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: parent.width < 350 ? Theme.spacingM : Theme.spacingL

                        property bool compactLogo: parent.width < 400
                        property bool hideLogo: parent.width < 280

                        Image {
                            id: logoImage

                            visible: !parent.hideLogo
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.compactLogo ? 80 : 120
                            height: width * (569.94629 / 506.50931)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            asynchronous: true
                            source: "file://" + Theme.shellDir + "/assets/danklogonormal.svg"
                            layer.enabled: true
                            layer.smooth: true
                            layer.mipmap: true
                            layer.effect: MultiEffect {
                                saturation: 0
                                colorization: 1
                                colorizationColor: Theme.primary
                            }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "DANK LINUX"
                            font.pixelSize: parent.compactLogo ? 32 : 48
                            font.weight: Theme.fontWeightMedium
                            font.family: DankCommon.Fonts.sans
                            color: Theme.surfaceText
                            antialiasing: true
                        }
                    }

                    StyledText {
                        text: {
                            if (!ShellVersionService.shellVersion && !DMSService.cliVersion)
                                return "dms";

                            let version = ShellVersionService.shellVersion || "";
                            let cliVersion = DMSService.cliVersion || "";

                            // Debian/Ubuntu/OpenSUSE git format: 1.0.3+git2264.c5c5ce84
                            let match = version.match(/^([\d.]+)\+git(\d+)\./);
                            if (match) {
                                return `dms (git) v${match[1]}-${match[2]}`;
                            }

                            // Fedora COPR git format: 0.0.git.2267.d430cae9
                            match = version.match(/^[\d.]+\.git\.(\d+)\./);
                            if (match) {
                                function extractBaseVersion(value) {
                                    if (!value)
                                        return "";
                                    let baseMatch = value.match(/(\d+\.\d+\.\d+)/);
                                    if (baseMatch)
                                        return baseMatch[1];
                                    baseMatch = value.match(/(\d+\.\d+)/);
                                    if (baseMatch)
                                        return baseMatch[1];
                                    return "";
                                }

                                let baseVersion = extractBaseVersion(cliVersion);
                                if (!baseVersion)
                                    baseVersion = extractBaseVersion(ShellVersionService.semverVersion);
                                if (baseVersion) {
                                    return `dms (git) v${baseVersion}-${match[1]}`;
                                }
                                return `dms (git) v${match[1]}`;
                            }

                            // Stable release format: 1.0.3
                            match = version.match(/^([\d.]+)$/);
                            if (match) {
                                return `dms v${match[1]}`;
                            }

                            if (!version && cliVersion) {
                                match = cliVersion.match(/^([\d.]+)\+git(\d+)\./);
                                if (match) {
                                    return `dms (git) v${match[1]}-${match[2]}`;
                                }
                                match = cliVersion.match(/^([\d.]+)$/);
                                if (match) {
                                    return `dms v${match[1]}`;
                                }
                                return `dms ${cliVersion}`;
                            }

                            return `dms ${version}`;
                        }
                        font.pixelSize: Theme.fontSizeXLarge
                        color: Theme.surfaceText
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                    }

                    StyledText {
                        visible: ShellVersionService.shellCodename.length > 0
                        text: `"${ShellVersionService.shellCodename}"`
                        font.pixelSize: Theme.fontSizeMedium
                        font.italic: true
                        color: Theme.surfaceVariantText
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                    }

                    Row {
                        id: resourceButtonsRow
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingS

                        property bool compactMode: parent.width < 450

                        DankButton {
                            id: docsButton
                            tooltipText: resourceButtonsRow.compactMode ? I18n.tr("Docs") + " - danklinux.com/docs" : "danklinux.com/docs"
                            text: resourceButtonsRow.compactMode ? "" : I18n.tr("Docs")
                            iconName: "menu_book"
                            iconSize: 18
                            backgroundColor: Theme.surfaceTextHover
                            textColor: Theme.surfaceText
                            onClicked: Qt.openUrlExternally("https://danklinux.com/docs")
                        }

                        DankButton {
                            id: pluginsButton
                            tooltipText: resourceButtonsRow.compactMode ? I18n.tr("Plugins") + " - plugins.danklinux.com" : "plugins.danklinux.com"
                            text: resourceButtonsRow.compactMode ? "" : I18n.tr("Plugins")
                            iconName: "extension"
                            iconSize: 18
                            backgroundColor: Theme.surfaceTextHover
                            textColor: Theme.surfaceText
                            onClicked: Qt.openUrlExternally("https://plugins.danklinux.com")
                        }

                        DankButton {
                            id: githubButton
                            tooltipText: resourceButtonsRow.compactMode ? "GitHub - AvengeMedia/DankMaterialShell" : "github.com/AvengeMedia/DankMaterialShell"
                            text: resourceButtonsRow.compactMode ? "" : "GitHub"
                            iconName: "code"
                            iconSize: 18
                            backgroundColor: Theme.surfaceTextHover
                            textColor: Theme.surfaceText
                            onClicked: Qt.openUrlExternally("https://github.com/AvengeMedia/DankMaterialShell")
                        }

                        DankButton {
                            id: kofiButton
                            tooltipText: resourceButtonsRow.compactMode ? "Ko-fi" + " - ko-fi.com/danklinux" : "ko-fi.com/danklinux"
                            text: resourceButtonsRow.compactMode ? "" : "Ko-fi"
                            iconName: "favorite"
                            iconSize: 18
                            backgroundColor: Theme.primaryHover
                            textColor: Theme.primary
                            onClicked: Qt.openUrlExternally("https://ko-fi.com/danklinux")
                        }
                    }

                    Row {
                        id: communityIcons
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingXS

                        DankActionButton {
                            tooltipText: compositorTooltip
                            tooltipSide: "top"
                            onClicked: {
                                if (compositorUrl === "")
                                    return;
                                Qt.openUrlExternally(compositorUrl);
                            }

                            Image {
                                anchors.centerIn: parent
                                width: Theme.iconSize
                                height: Theme.iconSize
                                source: Qt.resolvedUrl(".").toString().replace("file://", "").replace("/Modules/Settings/", "") + compositorLogo
                                sourceSize: Qt.size(24, 24)
                                smooth: true
                                fillMode: Image.PreserveAspectFit
                            }
                        }

                        DankActionButton {
                            visible: showMatrix
                            tooltipText: I18n.tr("niri Matrix chat")
                            tooltipSide: "top"
                            onClicked: Qt.openUrlExternally("https://matrix.to/#/#niri:matrix.org")

                            Image {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingXXS
                                source: Qt.resolvedUrl(".").toString().replace("file://", "").replace("/Modules/Settings/", "") + "/assets/matrix-logo-white.svg"
                                sourceSize: Qt.size(28, 18)
                                smooth: true
                                fillMode: Image.PreserveAspectFit
                                layer.enabled: true

                                layer.effect: MultiEffect {
                                    colorization: 1
                                    colorizationColor: Theme.surfaceText
                                }
                            }
                        }

                        DankActionButton {
                            visible: showIrc
                            iconName: "forum"
                            iconSize: Theme.iconSizeMedium
                            iconColor: Theme.surfaceText
                            tooltipText: ircTooltip
                            tooltipSide: "top"
                            onClicked: Qt.openUrlExternally(ircUrl)
                        }

                        DankActionButton {
                            tooltipText: dmsDiscordTooltip
                            tooltipSide: "top"
                            onClicked: Qt.openUrlExternally(dmsDiscordUrl)

                            Image {
                                anchors.centerIn: parent
                                width: Theme.iconSizeMedium
                                height: Theme.iconSizeMedium
                                source: Qt.resolvedUrl(".").toString().replace("file://", "").replace("/Modules/Settings/", "") + "/assets/discord.svg"
                                sourceSize: Qt.size(20, 20)
                                smooth: true
                                fillMode: Image.PreserveAspectFit
                            }
                        }

                        DankActionButton {
                            visible: showCompositorDiscord
                            tooltipText: compositorDiscordTooltip
                            tooltipSide: "top"
                            onClicked: Qt.openUrlExternally(compositorDiscordUrl)

                            Image {
                                anchors.centerIn: parent
                                width: Theme.iconSizeMedium
                                height: Theme.iconSizeMedium
                                source: Qt.resolvedUrl(".").toString().replace("file://", "").replace("/Modules/Settings/", "") + "/assets/discord.svg"
                                sourceSize: Qt.size(20, 20)
                                smooth: true
                                fillMode: Image.PreserveAspectFit
                            }
                        }

                        DankActionButton {
                            visible: showReddit
                            tooltipText: redditTooltip
                            tooltipSide: "top"
                            onClicked: Qt.openUrlExternally(redditUrl)

                            Image {
                                anchors.centerIn: parent
                                width: Theme.iconSizeMedium
                                height: Theme.iconSizeMedium
                                source: Qt.resolvedUrl(".").toString().replace("file://", "").replace("/Modules/Settings/", "") + "/assets/reddit.svg"
                                sourceSize: Qt.size(20, 20)
                                smooth: true
                                fillMode: Image.PreserveAspectFit
                            }
                        }
                    }
                }
            }
        }

        SettingsCard {
            width: parent.width
            iconName: "info"
            title: I18n.tr("About")

            SettingsRow {
                body: StyledText {
                    text: I18n.tr('DMS is a highly customizable modern desktop shell with a %1 inspired design.<br/><br/>It is built with %2, a QT6 framework for building desktop shells, and %3, a statically typed, compiled programming language.', 'about page blurb, %1 is a Material 3 link, %2 is a Quickshell link, %3 is a Go link').arg(`<a href="https://m3.material.io/" style="text-decoration:none; color:${Theme.primary};">Material Design 3</a>`).arg(`<a href="https://quickshell.org" style="text-decoration:none; color:${Theme.primary};">Quickshell</a>`).arg(`<a href="https://go.dev" style="text-decoration:none; color:${Theme.primary};">Go</a>`)
                    textFormat: Text.RichText
                    font.pixelSize: Theme.fontSizeMedium
                    linkColor: Theme.primary
                    onLinkActivated: url => Qt.openUrlExternally(url)
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.WordWrap

                    HoverHandler {
                        cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }
            }
        }

        SettingsCard {
            visible: DMSService.isConnected
            width: parent.width
            iconName: "dns"
            title: I18n.tr("Backend", "noun, settings label for the backend service in use")

            SettingsRow {
                title: I18n.tr("Version")
                trailingBadge: DMSService.cliVersion || "—"
            }

            SettingsRow {
                title: I18n.tr("API", "about page card title, application programming interface version")
                trailingBadge: `v${DMSService.apiVersion}`
            }

            SettingsRow {
                title: I18n.tr("Status")
                trailingBadge: I18n.tr("Connected")

                DankBadge {
                    color: Theme.success
                }
            }

            SettingsRow {
                visible: DMSService.capabilities.length > 0
                title: I18n.tr("Capabilities")
                body: Flow {
                    width: parent.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: DMSService.capabilities

                        DankBadge {
                            text: modelData
                            color: Theme.primaryHover
                            textColor: Theme.primary
                        }
                    }
                }
            }
        }

        SettingsCard {
            width: parent.width
            iconName: "build"
            title: I18n.tr("Tools", "about page card title for welcome and system check")

            SettingsNavRow {
                iconName: "waving_hand"
                title: I18n.tr("Show welcome")
                onClicked: FirstLaunchService.showWelcome()
            }

            SettingsNavRow {
                iconName: "vital_signs"
                title: I18n.tr("System check")
                onClicked: FirstLaunchService.showDoctor()
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: `<a href="https://github.com/AvengeMedia/DankMaterialShell/blob/master/LICENSE" style="text-decoration:none; color:${Theme.surfaceVariantText};">${I18n.tr('MIT License')}</a>`
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceVariantText
            textFormat: Text.RichText
            wrapMode: Text.NoWrap
            onLinkActivated: url => Qt.openUrlExternally(url)

            HoverHandler {
                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }
    }
}
