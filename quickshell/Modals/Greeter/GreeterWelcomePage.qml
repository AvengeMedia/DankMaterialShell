import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    readonly property real logoSize: Math.round(Theme.iconSize * 5.3)

    Column {
        id: mainColumn
        anchors.centerIn: parent
        width: Math.min(Math.round(Theme.fontSizeMedium * 43), parent.width - Theme.spacingXL * 2)
        spacing: Theme.spacingXL

        Column {
            width: parent.width
            spacing: Theme.spacingM

            Image {
                width: root.logoSize
                height: width * (569.94629 / 506.50931)
                anchors.horizontalCenter: parent.horizontalCenter
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
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: I18n.tr("Welcome to DankMaterialShell", "greeter welcome page title")
                    font.pixelSize: Theme.fontSizeXLarge + 4
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: I18n.tr("A modern desktop shell for Wayland compositors", "greeter welcome page tagline")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
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
                text: I18n.tr("Features", "greeter welcome page section header")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            Grid {
                width: parent.width
                columns: 3
                rowSpacing: Theme.spacingS
                columnSpacing: Theme.spacingS

                GreeterFeatureCard {
                    width: (parent.width - Theme.spacingS * 2) / 3
                    iconName: "auto_awesome"
                    title: I18n.tr("Dynamic Theming", "greeter feature card title")
                    description: I18n.tr("Colors from wallpaper", "greeter feature card description")
                    onClicked: PopoutService.openSettingsWithTab("theme")
                }

                GreeterFeatureCard {
                    width: (parent.width - Theme.spacingS * 2) / 3
                    iconName: "format_paint"
                    title: I18n.tr("App Theming", "greeter feature card title")
                    description: I18n.tr("GTK, Qt, IDEs, more", "greeter feature card description")
                    onClicked: PopoutService.openSettingsWithTab("theme")
                }

                GreeterFeatureCard {
                    width: (parent.width - Theme.spacingS * 2) / 3
                    iconName: "download"
                    title: I18n.tr("Theme Registry", "greeter feature card title")
                    description: I18n.tr("Community themes", "greeter feature card description")
                    onClicked: PopoutService.openSettingsWithTab("theme")
                }

                GreeterFeatureCard {
                    width: (parent.width - Theme.spacingS * 2) / 3
                    iconName: "view_carousel"
                    title: I18n.tr("DankBar", "greeter feature card title")
                    description: I18n.tr("Modular widget bar", "greeter feature card description")
                    onClicked: PopoutService.openSettingsWithTab("dankbar_settings")
                }

                GreeterFeatureCard {
                    width: (parent.width - Theme.spacingS * 2) / 3
                    iconName: "extension"
                    title: I18n.tr("Plugins", "greeter feature card title")
                    description: I18n.tr("Extensible architecture", "greeter feature card description")
                    onClicked: PopoutService.openSettingsWithTab("plugins")
                }

                GreeterFeatureCard {
                    width: (parent.width - Theme.spacingS * 2) / 3
                    iconName: "layers"
                    title: I18n.tr("Multi-Monitor", "greeter feature card title")
                    description: I18n.tr("Per-screen config", "greeter feature card description")
                    onClicked: {
                        const hasDisplayConfig = CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango;
                        PopoutService.openSettingsWithTab(hasDisplayConfig ? "display_config" : "display_widgets");
                    }
                }

                GreeterFeatureCard {
                    width: (parent.width - Theme.spacingS * 2) / 3
                    iconName: "nightlight"
                    title: I18n.tr("Display Control", "greeter feature card title")
                    description: I18n.tr("Night mode & gamma", "greeter feature card description")
                    onClicked: PopoutService.openSettingsWithTab("display_gamma")
                }

                GreeterFeatureCard {
                    width: (parent.width - Theme.spacingS * 2) / 3
                    iconName: "tune"
                    title: I18n.tr("Control Center", "greeter feature card title")
                    description: I18n.tr("Quick system toggles", "greeter feature card description")
                    onClicked: BarWidgetService.getBarWindowOnFocusedScreen()?.triggerControlCenter()
                }

                GreeterFeatureCard {
                    width: (parent.width - Theme.spacingS * 2) / 3
                    iconName: "lock"
                    title: I18n.tr("Lock Screen", "greeter feature card title")
                    description: I18n.tr("Security & privacy", "greeter feature card description")
                    onClicked: PopoutService.openSettingsWithTab("lock_screen")
                }
            }
        }
    }
}
