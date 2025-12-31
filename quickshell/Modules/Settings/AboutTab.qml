import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: aboutTab

    property bool isHyprland: CompositorService.isHyprland
    property bool isNiri: CompositorService.isNiri
    property bool isSway: CompositorService.isSway
    property bool isScroll: CompositorService.isScroll
    property bool isDwl: CompositorService.isDwl
    property bool isLabwc: CompositorService.isLabwc

    property string compositorName: {
        if (isHyprland)
            return "hyprland";
        if (isSway)
            return "sway";
        if (isScroll)
            return "scroll";
        if (isDwl)
            return "mangowc";
        if (isLabwc)
            return "labwc";
        return "niri";
    }

    property string compositorLogo: {
        if (isHyprland)
            return "/assets/hyprland.svg";
        if (isSway)
            return "/assets/sway.svg";
        if (isScroll)
            return "/assets/sway.svg";
        if (isDwl)
            return "/assets/mango.png";
        if (isLabwc)
            return "/assets/labwc.png";
        return "/assets/niri.svg";
    }

    property string compositorUrl: {
        if (isHyprland)
            return "https://hypr.land";
        if (isSway)
            return "https://swaywm.org";
        if (isScroll)
            return "https://github.com/dawsers/scroll";
        if (isDwl)
            return "https://github.com/DreamMaoMao/mangowc";
        if (isLabwc)
            return "https://labwc.github.io/";
        return "https://github.com/YaLTeR/niri";
    }

    property string compositorTooltip: {
        if (isHyprland)
            return "Hyprland Website";
        if (isSway)
            return "Sway Website";
        if (isScroll)
            return "Scroll Github";
        if (isDwl)
            return "mangowc GitHub";
        if (isLabwc)
            return "LabWC Website";
        return "niri GitHub";
    }

    property string dmsDiscordUrl: "https://discord.gg/ppWTpKmPgT"
    property string dmsDiscordTooltip: "niri/dms Discord"

    property string compositorDiscordUrl: {
        if (isHyprland)
            return "https://discord.com/invite/hQ9XvMUjjr";
        if (isDwl)
            return "https://discord.gg/CPjbDxesh5";
        return "";
    }

    property string compositorDiscordTooltip: {
        if (isHyprland)
            return "Hyprland Discord Server";
        if (isDwl)
            return "mangowc Discord Server";
        return "";
    }

    property string redditUrl: "https://reddit.com/r/niri"
    property string redditTooltip: "r/niri Subreddit"

    property string ircUrl: "https://web.libera.chat/gamja/?channels=#labwc"
    property string ircTooltip: "LabWC IRC Channel"

    property bool showMatrix: isNiri && !isHyprland && !isSway && !isScroll && !isDwl && !isLabwc
    property bool showCompositorDiscord: isHyprland || isDwl
    property bool showReddit: isNiri && !isHyprland && !isSway && !isScroll && !isDwl && !isLabwc
    property bool showIrc: isLabwc

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            topPadding: 4

            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            // ASCII Art Header
            StyledRect {
                width: parent.width
                height: asciiSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: asciiSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
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

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "DANK LINUX"
                            font.pixelSize: parent.compactLogo ? 32 : 48
                            font.weight: Font.Bold
                            font.family: interFont.name
                            color: Theme.surfaceText
                            antialiasing: true

                            FontLoader {
                                id: interFont
                                source: Qt.resolvedUrl("../../assets/fonts/inter/InterVariable.ttf")
                            }
                        }
                    }

                    StyledText {
                        text: {
                            if (!SystemUpdateService.shellVersion)
                                return "dms";

                            let version = SystemUpdateService.shellVersion;

                            // Debian/Ubuntu/OpenSUSE git format: 1.0.3+git2264.c5c5ce84
                            let match = version.match(/^([\d.]+)\+git(\d+)\./);
                            if (match) {
                                return `dms (git) v${match[1]}-${match[2]}`;
                            }

                            // Fedora COPR git format: 0.0.git.2267.d430cae9
                            match = version.match(/^[\d.]+\.git\.(\d+)\./);
                            if (match) {
                                return `dms (git) v1.0.3-${match[1]}`;
                            }

                            // Stable release format: 1.0.3
                            match = version.match(/^([\d.]+)$/);
                            if (match) {
                                return `dms v${match[1]}`;
                            }

                            return `dms ${version}`;
                        }
                        font.pixelSize: Theme.fontSizeXLarge
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                    }

                    StyledText {
                        visible: SystemUpdateService.shellCodename.length > 0
                        text: `"${SystemUpdateService.shellCodename}"`
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

                        property bool compactMode: parent.width < 400

                        DankButton {
                            id: docsButton
                            text: resourceButtonsRow.compactMode ? "" : I18n.tr("Docs")
                            iconName: "menu_book"
                            iconSize: 18
                            backgroundColor: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
                            textColor: Theme.surfaceText
                            onClicked: Qt.openUrlExternally("https://danklinux.com/docs")
                            onHoveredChanged: {
                                if (hovered)
                                    resourceTooltip.show(resourceButtonsRow.compactMode ? I18n.tr("Docs") + " - danklinux.com/docs" : "danklinux.com/docs", docsButton, 0, 0, "bottom");
                                else
                                    resourceTooltip.hide();
                            }
                        }

                        DankButton {
                            id: pluginsButton
                            text: resourceButtonsRow.compactMode ? "" : I18n.tr("Plugins")
                            iconName: "extension"
                            iconSize: 18
                            backgroundColor: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
                            textColor: Theme.surfaceText
                            onClicked: Qt.openUrlExternally("https://plugins.danklinux.com")
                            onHoveredChanged: {
                                if (hovered)
                                    resourceTooltip.show(resourceButtonsRow.compactMode ? I18n.tr("Plugins") + " - plugins.danklinux.com" : "plugins.danklinux.com", pluginsButton, 0, 0, "bottom");
                                else
                                    resourceTooltip.hide();
                            }
                        }

                        DankButton {
                            id: githubButton
                            text: resourceButtonsRow.compactMode ? "" : I18n.tr("GitHub")
                            iconName: "code"
                            iconSize: 18
                            backgroundColor: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
                            textColor: Theme.surfaceText
                            onClicked: Qt.openUrlExternally("https://github.com/AvengeMedia/DankMaterialShell")
                            onHoveredChanged: {
                                if (hovered)
                                    resourceTooltip.show(resourceButtonsRow.compactMode ? "GitHub - AvengeMedia/DankMaterialShell" : "github.com/AvengeMedia/DankMaterialShell", githubButton, 0, 0, "bottom");
                                else
                                    resourceTooltip.hide();
                            }
                        }

                        DankButton {
                            id: kofiButton
                            text: resourceButtonsRow.compactMode ? "" : I18n.tr("Ko-fi")
                            iconName: "favorite"
                            iconSize: 18
                            backgroundColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                            textColor: Theme.primary
                            onClicked: Qt.openUrlExternally("https://ko-fi.com/danklinux")
                            onHoveredChanged: {
                                if (hovered)
                                    resourceTooltip.show(resourceButtonsRow.compactMode ? I18n.tr("Ko-fi") + " - ko-fi.com/danklinux" : "ko-fi.com/danklinux", kofiButton, 0, 0, "bottom");
                                else
                                    resourceTooltip.hide();
                            }
                        }
                    }

                    DankTooltipV2 {
                        id: resourceTooltip
                    }

                    Item {
                        id: communityIcons
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 24
                        width: {
                            let baseWidth = compositorButton.width + dmsDiscordButton.width + Theme.spacingM;
                            if (showMatrix) {
                                baseWidth += matrixButton.width + 4;
                            }
                            if (showIrc) {
                                baseWidth += ircButton.width + Theme.spacingM;
                            }
                            if (showCompositorDiscord) {
                                baseWidth += compositorDiscordButton.width + Theme.spacingM;
                            }
                            if (showReddit) {
                                baseWidth += redditButton.width + Theme.spacingM;
                            }
                            return baseWidth;
                        }

                        Item {
                            id: compositorButton
                            width: 24
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -2
                            x: 0

                            property bool hovered: false
                            property string tooltipText: compositorTooltip

                            Image {
                                anchors.fill: parent
                                source: Qt.resolvedUrl(".").toString().replace("file://", "").replace("/Modules/Settings/", "") + compositorLogo
                                sourceSize: Qt.size(24, 24)
                                smooth: true
                                fillMode: Image.PreserveAspectFit
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: Qt.openUrlExternally(compositorUrl)
                            }
                        }

                        Item {
                            id: matrixButton
                            width: 30
                            height: 24
                            x: compositorButton.x + compositorButton.width + 4
                            visible: showMatrix

                            property bool hovered: false
                            property string tooltipText: "niri Matrix Chat"

                            Image {
                                anchors.fill: parent
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

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: Qt.openUrlExternally("https://matrix.to/#/#niri:matrix.org")
                            }
                        }

                        Item {
                            id: ircButton
                            width: 24
                            height: 24
                            x: compositorButton.x + compositorButton.width + Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            visible: showIrc

                            property bool hovered: false
                            property string tooltipText: ircTooltip

                            DankIcon {
                                anchors.centerIn: parent
                                name: "forum"
                                size: 20
                                color: Theme.surfaceText
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: Qt.openUrlExternally(ircUrl)
                            }
                        }

                        Item {
                            id: dmsDiscordButton
                            width: 20
                            height: 20
                            x: {
                                if (showMatrix)
                                    return matrixButton.x + matrixButton.width + Theme.spacingM;
                                if (showIrc)
                                    return ircButton.x + ircButton.width + Theme.spacingM;
                                return compositorButton.x + compositorButton.width + Theme.spacingM;
                            }
                            anchors.verticalCenter: parent.verticalCenter

                            property bool hovered: false
                            property string tooltipText: dmsDiscordTooltip

                            Image {
                                anchors.fill: parent
                                source: Qt.resolvedUrl(".").toString().replace("file://", "").replace("/Modules/Settings/", "") + "/assets/discord.svg"
                                sourceSize: Qt.size(20, 20)
                                smooth: true
                                fillMode: Image.PreserveAspectFit
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: Qt.openUrlExternally(dmsDiscordUrl)
                            }
                        }

                        Item {
                            id: compositorDiscordButton
                            width: 20
                            height: 20
                            x: dmsDiscordButton.x + dmsDiscordButton.width + Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            visible: showCompositorDiscord

                            property bool hovered: false
                            property string tooltipText: compositorDiscordTooltip

                            Image {
                                anchors.fill: parent
                                source: Qt.resolvedUrl(".").toString().replace("file://", "").replace("/Modules/Settings/", "") + "/assets/discord.svg"
                                sourceSize: Qt.size(20, 20)
                                smooth: true
                                fillMode: Image.PreserveAspectFit
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: Qt.openUrlExternally(compositorDiscordUrl)
                            }
                        }

                        Item {
                            id: redditButton
                            width: 20
                            height: 20
                            x: showCompositorDiscord ? compositorDiscordButton.x + compositorDiscordButton.width + Theme.spacingM : dmsDiscordButton.x + dmsDiscordButton.width + Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            visible: showReddit

                            property bool hovered: false
                            property string tooltipText: redditTooltip

                            Image {
                                anchors.fill: parent
                                source: Qt.resolvedUrl(".").toString().replace("file://", "").replace("/Modules/Settings/", "") + "/assets/reddit.svg"
                                sourceSize: Qt.size(20, 20)
                                smooth: true
                                fillMode: Image.PreserveAspectFit
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: Qt.openUrlExternally(redditUrl)
                            }
                        }
                    }
                }
            }

            // Project Information
            StyledRect {
                width: parent.width
                height: projectSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: projectSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "info"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("About")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        text: I18n.tr(`dms is a highly customizable, modern desktop shell with a <a href="https://m3.material.io/" style="text-decoration:none; color:${Theme.primary};">material 3 inspired</a> design.
                        <br /><br/>It is built with <a href="https://quickshell.org" style="text-decoration:none; color:${Theme.primary};">Quickshell</a>, a QT6 framework for building desktop shells, and <a href="https://go.dev" style="text-decoration:none; color:${Theme.primary};">Go</a>, a statically typed, compiled programming language.
                        `)
                        textFormat: Text.RichText
                        font.pixelSize: Theme.fontSizeMedium
                        linkColor: Theme.primary
                        onLinkActivated: url => Qt.openUrlExternally(url)
                        color: Theme.surfaceVariantText
                        width: parent.width
                        wrapMode: Text.WordWrap

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                            acceptedButtons: Qt.NoButton
                            propagateComposedEvents: true
                        }
                    }
                }
            }

            StyledRect {
                visible: DMSService.isConnected
                width: parent.width
                height: backendSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: backendSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "dns"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Backend")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        spacing: Theme.spacingL

                        Column {
                            spacing: 2

                            StyledText {
                                text: I18n.tr("Version")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                text: DMSService.cliVersion || "—"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                        }

                        Rectangle {
                            width: 1
                            height: 32
                            color: Theme.outlineVariant
                        }

                        Column {
                            spacing: 2

                            StyledText {
                                text: I18n.tr("API")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                text: `v${DMSService.apiVersion}`
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                        }

                        Rectangle {
                            width: 1
                            height: 32
                            color: Theme.outlineVariant
                        }

                        Column {
                            spacing: 2

                            StyledText {
                                text: I18n.tr("Status")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            Row {
                                spacing: 4

                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: Theme.success
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: I18n.tr("Connected")
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: DMSService.capabilities.length > 0

                        StyledText {
                            text: I18n.tr("Capabilities")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        Flow {
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: DMSService.capabilities

                                Rectangle {
                                    width: capText.implicitWidth + 16
                                    height: 26
                                    radius: 13
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)

                                    StyledText {
                                        id: capText
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.primary
                                    }
                                }
                            }
                        }
                    }
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: `<a href="https://github.com/AvengeMedia/DankMaterialShell/blob/master/LICENSE" style="text-decoration:none; color:${Theme.surfaceVariantText};">MIT License</a>`
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                textFormat: Text.RichText
                wrapMode: Text.NoWrap
                onLinkActivated: url => Qt.openUrlExternally(url)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                    acceptedButtons: Qt.NoButton
                    propagateComposedEvents: true
                }
            }
        }
    }

    // Community tooltip - positioned absolutely above everything
    Rectangle {
        id: communityTooltip
        parent: aboutTab
        z: 1000

        property var hoveredButton: {
            if (compositorButton.hovered)
                return compositorButton;
            if (matrixButton.visible && matrixButton.hovered)
                return matrixButton;
            if (ircButton.visible && ircButton.hovered)
                return ircButton;
            if (dmsDiscordButton.hovered)
                return dmsDiscordButton;
            if (compositorDiscordButton.visible && compositorDiscordButton.hovered)
                return compositorDiscordButton;
            if (redditButton.visible && redditButton.hovered)
                return redditButton;
            return null;
        }

        property string tooltipText: hoveredButton ? hoveredButton.tooltipText : ""

        visible: hoveredButton !== null && tooltipText !== ""
        width: tooltipLabel.implicitWidth + 24
        height: tooltipLabel.implicitHeight + 12

        color: Theme.surfaceContainer
        radius: Theme.cornerRadius
        border.width: 0
        border.color: Theme.outlineMedium

        x: hoveredButton ? hoveredButton.mapToItem(aboutTab, hoveredButton.width / 2, 0).x - width / 2 : 0
        y: hoveredButton ? communityIcons.mapToItem(aboutTab, 0, 0).y - height - 8 : 0

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowOpacity: 0.15
            shadowVerticalOffset: 2
            shadowBlur: 0.5
        }

        StyledText {
            id: tooltipLabel
            anchors.centerIn: parent
            text: communityTooltip.tooltipText
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
        }
    }
}
