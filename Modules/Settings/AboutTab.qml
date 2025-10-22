import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: aboutTab

    property bool isHyprland: CompositorService.isHyprland

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
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: asciiSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Item {
                        width: parent.width
                        height: asciiText.implicitHeight

                        StyledText {
                            id: asciiText

                            text: "██████╗  █████╗ ███╗   ██╗██╗  ██╗\n██╔══██╗██╔══██╗████╗  ██║██║ ██╔╝\n██║  ██║███████║██╔██╗ ██║█████╔╝ \n██║  ██║██╔══██║██║╚██╗██║██╔═██╗ \n██████╔╝██║  ██║██║ ╚████║██║  ██╗\n╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝"
                            isMonospace: true
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.primary
                            anchors.centerIn: parent
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
                            if (isHyprland) {
                                return compositorButton.width + discordButton.width + Theme.spacingM + redditButton.width + Theme.spacingM
                            } else {
                                return compositorButton.width + matrixButton.width + 4 + discordButton.width + Theme.spacingM + redditButton.width + Theme.spacingM
                            }
                        }

                        // Compositor logo (Niri or Hyprland)
                        Item {
                            id: compositorButton
                            width: 24
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -2
                            x: 0

                            property bool hovered: false
                            property string tooltipText: isHyprland ? "Hyprland Website" : "niri GitHub"

                            Image {
                                anchors.fill: parent
                                source: Qt.resolvedUrl(".").toString().replace(
                                            "file://", "").replace(
                                            "/Modules/Settings/",
                                            "") + (isHyprland ? "/assets/hyprland.svg" : "/assets/niri.svg")
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
                                onClicked: Qt.openUrlExternally(
                                               isHyprland ? "https://hypr.land" : "https://github.com/YaLTeR/niri")
                            }
                        }

                        // Matrix button (only for Niri)
                        Item {
                            id: matrixButton
                            width: 30
                            height: 24
                            x: compositorButton.x + compositorButton.width + 4
                            visible: !isHyprland

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

                        // Discord button
                        Item {
                            id: discordButton
                            width: 20
                            height: 20
                            x: isHyprland ? compositorButton.x + compositorButton.width + Theme.spacingM : matrixButton.x + matrixButton.width + Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter

                            property bool hovered: false
                            property string tooltipText: isHyprland ? "Hyprland Discord Server" : "niri Discord Server"

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
                                onClicked: Qt.openUrlExternally(
                                               isHyprland ? "https://discord.com/invite/hQ9XvMUjjr" : "https://discord.gg/vT8Sfjy7sx")
                            }
                        }

                        // Reddit button
                        Item {
                            id: redditButton
                            width: 20
                            height: 20
                            x: discordButton.x + discordButton.width + Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter

                            property bool hovered: false
                            property string tooltipText: isHyprland ? "r/hyprland Subreddit" : "r/niri Subreddit"

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
                                onClicked: Qt.openUrlExternally(
                                               isHyprland ? "https://reddit.com/r/hyprland" : "https://reddit.com/r/niri")
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
                color: Theme.surfaceContainerHigh
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

            // Technical Details
            StyledRect {
                width: parent.width
                height: techSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
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
                            text: I18n.tr("Technical Details")
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
                            text: I18n.tr("Framework:")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: `<a href="https://quickshell.org" style="text-decoration:none; color:${Theme.primary};">Quickshell</a>`
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
                            text: I18n.tr("Language:")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: I18n.tr("QML, JavaScript, Go")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            text: I18n.tr("Compositor:")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        Row {
                            spacing: 4

                            StyledText {
                                text: `<a href="https://github.com/YaLTeR/niri" style="text-decoration:none; color:${Theme.primary};">niri</a>`
                                font.pixelSize: Theme.fontSizeMedium
                                linkColor: Theme.primary
                                textFormat: Text.RichText
                                color: Theme.surfaceVariantText
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
                                text: "&"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: `<a href="https://github.com/hyprwm/Hyprland" style="text-decoration:none; color:${Theme.primary};">hyprland</a>`
                                font.pixelSize: Theme.fontSizeMedium
                                linkColor: Theme.primary
                                textFormat: Text.RichText
                                color: Theme.surfaceVariantText
                                onLinkActivated: url => Qt.openUrlExternally(url)
                                anchors.verticalCenter: parent.verticalCenter

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    acceptedButtons: Qt.NoButton
                                    propagateComposedEvents: true
                                }
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

                        StyledText {
                            text: I18n.tr("Dank Suite:")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        Row {
                            spacing: 4

                            StyledText {
                                text: `<a href="https://danklinux.com" style="text-decoration:none; color:${Theme.primary};">danklinux.com</a>`
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
                        }
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
            if (discordButton.hovered) return discordButton
            if (redditButton.hovered) return redditButton
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
