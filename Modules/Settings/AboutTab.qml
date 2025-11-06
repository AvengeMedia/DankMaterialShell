import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: aboutTab

    property bool isHyprland: CompositorService.isHyprland
    property bool isNiri: CompositorService.isNiri
    property bool isSway: CompositorService.isSway
    property bool isDwl: CompositorService.isDwl

    property string compositorName: {
        if (isHyprland) return "hyprland"
        if (isSway) return "sway"
        if (isDwl) return "mangowc"
        return "niri"
    }

    property string compositorLogo: {
        if (isHyprland) return "/assets/hyprland.svg"
        if (isSway) return "/assets/sway.svg"
        if (isDwl) return "/assets/mango.png"
        return "/assets/niri.svg"
    }

    property string compositorUrl: {
        if (isHyprland) return "https://hypr.land"
        if (isSway) return "https://swaywm.org"
        if (isDwl) return "https://github.com/DreamMaoMao/mangowc"
        return "https://github.com/YaLTeR/niri"
    }

    property string compositorTooltip: {
        if (isHyprland) return "Hyprland Website"
        if (isSway) return "Sway Website"
        if (isDwl) return "mangowc GitHub"
        return "niri GitHub"
    }

    property string dmsDiscordUrl: "https://discord.gg/vT8Sfjy7sx"
    property string dmsDiscordTooltip: "niri/dms Discord"

    property string compositorDiscordUrl: {
        if (isHyprland) return "https://discord.com/invite/hQ9XvMUjjr"
        if (isDwl) return "https://discord.gg/CPjbDxesh5"
        return ""
    }

    property string compositorDiscordTooltip: {
        if (isHyprland) return "Hyprland Discord Server"
        if (isDwl) return "mangowc Discord Server"
        return ""
    }

    property string redditUrl: "https://reddit.com/r/niri"
    property string redditTooltip: "r/niri Subreddit"

    property bool showMatrix: isNiri && !isHyprland && !isSway && !isDwl
    property bool showCompositorDiscord: isHyprland || isDwl
    property bool showReddit: isNiri && !isHyprland && !isSway && !isDwl

    DankFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn

            width: parent.width
            spacing: Theme.spacingXL

            // ASCII Art Header
            StyledRect {
                width: parent.width
                height: asciiSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: asciiSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingL

                        Image {
                            id: logoImage

                            anchors.verticalCenter: parent.verticalCenter
                            width: 120
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
                            font.pixelSize: 48
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
                        text: SystemUpdateService.shellVersion ? `dms ${SystemUpdateService.shellVersion}` : "dms"
                        font.pixelSize: Theme.fontSizeXLarge
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                    }

                    Item {
                        id: communityIcons
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 24
                        width: {
                            let baseWidth = compositorButton.width + dmsDiscordButton.width + Theme.spacingM
                            if (showMatrix) {
                                baseWidth += matrixButton.width + 4
                            }
                            if (showCompositorDiscord) {
                                baseWidth += compositorDiscordButton.width + Theme.spacingM
                            }
                            if (showReddit) {
                                baseWidth += redditButton.width + Theme.spacingM
                            }
                            return baseWidth
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
                                source: Qt.resolvedUrl(".").toString().replace(
                                            "file://", "").replace(
                                            "/Modules/Settings/",
                                            "") + compositorLogo
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
                                source: Qt.resolvedUrl(".").toString().replace(
                                            "file://", "").replace(
                                            "/Modules/Settings/",
                                            "") + "/assets/matrix-logo-white.svg"
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
                                onClicked: Qt.openUrlExternally(
                                               "https://matrix.to/#/#niri:matrix.org")
                            }
                        }

                        Item {
                            id: dmsDiscordButton
                            width: 20
                            height: 20
                            x: showMatrix ? matrixButton.x + matrixButton.width + Theme.spacingM : compositorButton.x + compositorButton.width + Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter

                            property bool hovered: false
                            property string tooltipText: dmsDiscordTooltip

                            Image {
                                anchors.fill: parent
                                source: Qt.resolvedUrl(".").toString().replace(
                                            "file://", "").replace(
                                            "/Modules/Settings/",
                                            "") + "/assets/discord.svg"
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
                                source: Qt.resolvedUrl(".").toString().replace(
                                            "file://", "").replace(
                                            "/Modules/Settings/",
                                            "") + "/assets/discord.svg"
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
                                source: Qt.resolvedUrl(".").toString().replace(
                                            "file://", "").replace(
                                            "/Modules/Settings/",
                                            "") + "/assets/reddit.svg"
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
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
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
                width: parent.width
                height: techSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: techSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "code"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Resources")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Grid {
                        width: parent.width
                        columns: 2
                        columnSpacing: Theme.spacingL
                        rowSpacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Website:")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: `<a href="https://danklinux.com" style="text-decoration:none; color:${Theme.primary};">danklinux.com</a>`
                            linkColor: Theme.primary
                            textFormat: Text.RichText
                            onLinkActivated: url => Qt.openUrlExternally(url)
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                                acceptedButtons: Qt.NoButton
                                propagateComposedEvents: true
                            }
                        }

                        StyledText {
                            text: I18n.tr("Plugins:")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: `<a href="https://plugins.danklinux.com" style="text-decoration:none; color:${Theme.primary};">plugins.danklinux.com</a>`
                            linkColor: Theme.primary
                            textFormat: Text.RichText
                            onLinkActivated: url => Qt.openUrlExternally(url)
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                                acceptedButtons: Qt.NoButton
                                propagateComposedEvents: true
                            }
                        }

                        StyledText {
                            text: I18n.tr("Github:")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        Row {
                            spacing: 4

                            StyledText {
                                text: `<a href="https://github.com/AvengeMedia/DankMaterialShell" style="text-decoration:none; color:${Theme.primary};">DankMaterialShell</a>`
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                linkColor: Theme.primary
                                textFormat: Text.RichText
                                onLinkActivated: url => Qt.openUrlExternally(url)
                                anchors.verticalCenter: parent.verticalCenter

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    acceptedButtons: Qt.NoButton
                                    propagateComposedEvents: true
                                }
                            }

                            StyledText {
                                text: I18n.tr("- Support Us With a Star ⭐")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        StyledText {
                            text: I18n.tr("System Monitoring:")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        Row {
                            spacing: 4

                            StyledText {
                                text: `<a href="https://github.com/AvengeMedia/dgop" style="text-decoration:none; color:${Theme.primary};">dgop</a>`
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                linkColor: Theme.primary
                                textFormat: Text.RichText
                                onLinkActivated: url => Qt.openUrlExternally(url)
                                anchors.verticalCenter: parent.verticalCenter

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    acceptedButtons: Qt.NoButton
                                    propagateComposedEvents: true
                                }
                            }

                            StyledText {
                                text: I18n.tr("- Stateless System Monitoring")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }

            // Support Section
            StyledRect {
                width: parent.width
                height: supportSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

                Row {
                    id: supportSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        spacing: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter

                        DankIcon {
                            name: "volunteer_activism"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Support Development")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Item {
                        width: parent.width - parent.spacing - kofiButton.width - supportSection.children[0].width
                        height: 1
                    }

                    DankButton {
                        id: kofiButton
                        text: I18n.tr("Donate on Ko-fi")
                        iconName: "favorite"
                        iconSize: 20
                        backgroundColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                        textColor: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: Qt.openUrlExternally("https://ko-fi.com/danklinux")
                    }
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
            if (compositorButton.hovered) return compositorButton
            if (matrixButton.visible && matrixButton.hovered) return matrixButton
            if (dmsDiscordButton.hovered) return dmsDiscordButton
            if (compositorDiscordButton.visible && compositorDiscordButton.hovered) return compositorDiscordButton
            if (redditButton.visible && redditButton.hovered) return redditButton
            return null
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
