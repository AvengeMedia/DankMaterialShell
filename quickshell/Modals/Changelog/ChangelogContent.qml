import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets

Column {
    id: root

    readonly property real logoSize: Math.round(Theme.iconSize * 2.8)
    readonly property real badgeHeight: Math.round(Theme.fontSizeSmall * 1.7)
    readonly property string releaseNotesUrl: "https://danklinux.com/blog/v1-6-release"
    readonly property string screenshotDocsUrl: "https://danklinux.com/docs/dankmaterialshell/cli-screenshot"

    topPadding: Theme.spacingL
    spacing: Theme.spacingL

    Column {
        width: parent.width
        spacing: Theme.spacingM

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingM

            Image {
                width: root.logoSize
                height: width * (569.94629 / 506.50931)
                anchors.verticalCenter: parent.verticalCenter
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

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS

                Row {
                    spacing: Theme.spacingS

                    StyledText {
                        text: "DMS " + ChangelogService.currentVersion
                        font.pixelSize: Theme.fontSizeXLarge + 2
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: codenameText.implicitWidth + Theme.spacingM * 2
                        height: root.badgeHeight
                        radius: root.badgeHeight / 2
                        color: Theme.primaryContainer
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            id: codenameText
                            anchors.centerIn: parent
                            text: "Marble Tabby"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.primary
                        }
                    }
                }

                StyledText {
                    text: "Dank Island, spring motion, performance & resource optimizations"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outlineMedium
        opacity: 0.3
    }

    Column {
        width: parent.width
        spacing: Theme.spacingM

        StyledText {
            text: "What's New"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        Grid {
            width: parent.width
            columns: 2
            rowSpacing: Theme.spacingS
            columnSpacing: Theme.spacingS

            ChangelogFeatureCard {
                width: (parent.width - Theme.spacingS) / 2
                iconName: "view_in_ar"
                title: "Dank Island"
                description: "A bar that reacts to you"
                onClicked: {
                    SettingsSearchService.navigateToSection("dankIslandInstance");
                    PopoutService.openSettingsWithTab("dank_island");
                }
            }

            ChangelogFeatureCard {
                width: (parent.width - Theme.spacingS) / 2
                iconName: "animation"
                title: "Spring Motion"
                description: "New motion physics"
                onClicked: {
                    SettingsSearchService.navigateToSection("springBounce");
                    PopoutService.openSettingsWithTab("typography");
                }
            }

            ChangelogFeatureCard {
                width: (parent.width - Theme.spacingS) / 2
                iconName: "speed"
                title: "Performance"
                description: "Big speedups, less memory"
                onClicked: Qt.openUrlExternally(root.releaseNotesUrl)
            }

            ChangelogFeatureCard {
                width: (parent.width - Theme.spacingS) / 2
                iconName: "wifi_tethering"
                title: "Network"
                description: "Hotspot, cellular, and OWE"
                onClicked: {
                    SettingsSearchService.navigateToSection("networkHotspot");
                    PopoutService.openSettingsWithTab("network_wifi");
                }
            }

            ChangelogFeatureCard {
                width: (parent.width - Theme.spacingS) / 2
                iconName: "extension"
                title: "Plugin Registries"
                description: "Add your own sources"
                onClicked: PopoutService.openSettingsWithTab("plugins")
            }

            ChangelogFeatureCard {
                width: (parent.width - Theme.spacingS) / 2
                iconName: "photo_camera"
                title: "Capture"
                description: "Grab regions across outputs"
                onClicked: Qt.openUrlExternally(root.screenshotDocsUrl)
            }

            ChangelogFeatureCard {
                width: (parent.width - Theme.spacingS) / 2
                iconName: "login"
                title: "Standalone Greeter"
                description: "Now its own app"
                onClicked: {
                    SettingsSearchService.navigateToSection("greeterStatus");
                    PopoutService.openSettingsWithTab("greeter");
                }
            }

            ChangelogFeatureCard {
                width: (parent.width - Theme.spacingS) / 2
                iconName: "dock_to_bottom"
                title: "Dock"
                description: "Pinned apps, running apps"
                onClicked: {
                    SettingsSearchService.navigateToSection("dockSeparatePinnedAndRunningApps");
                    PopoutService.openSettingsWithTab("dock");
                }
            }

            ChangelogFeatureCard {
                width: (parent.width - Theme.spacingS) / 2
                iconName: "content_paste"
                title: "Clipboard"
                description: "Drop in anything to store it"
                onClicked: PopoutService.openSettingsWithTab("clipboard")
            }

            ChangelogFeatureCard {
                width: (parent.width - Theme.spacingS) / 2
                iconName: "language"
                title: "Translations"
                description: "22 languages, plugin translations"
                onClicked: {
                    SettingsSearchService.navigateToSection("locale");
                    PopoutService.openSettingsWithTab("locale");
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outlineMedium
        opacity: 0.3
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        Row {
            spacing: Theme.spacingS

            DankIcon {
                name: "warning"
                size: Theme.iconSizeSmall
                color: Theme.warning
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: "Upgrade Notes"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            width: parent.width
            height: upgradeNotesColumn.height + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.warning, 0.08)
            border.width: 1
            border.color: Theme.withAlpha(Theme.warning, 0.2)

            Column {
                id: upgradeNotesColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                ChangelogUpgradeNote {
                    width: parent.width
                    text: "The shell is embedded in the dms binary. ~/.config/quickshell/dms is no longer auto-discovered, pass -c or set DMS_SHELL_DIR to override it"
                }

                ChangelogUpgradeNote {
                    width: parent.width
                    text: "The greeter is now a standalone application. dms greeter commands become dms-greeter"
                }

                ChangelogUpgradeNote {
                    width: parent.width
                    text: "settings.json only stores what differs from the defaults, and machine-specific state moved to session.json"
                }
            }
        }
    }
}
