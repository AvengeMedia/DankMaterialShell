pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    required property var controller

    readonly property real logoSize: Math.max(12, Theme.iconSizeSmall + SettingsData.launcherLogoSizeOffset)
    readonly property string logoMode: SettingsData.launcherLogoMode
    readonly property bool compositorAvailable: CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango || CompositorService.isSway || CompositorService.isScroll || CompositorService.isMiracle || CompositorService.isLabwc
    readonly property bool showCustom: logoMode === "custom" && SettingsData.launcherLogoCustomPath !== ""
    readonly property bool showCompositor: logoMode === "compositor" && root.compositorAvailable
    readonly property bool showOs: logoMode === "os"
    readonly property bool showDank: logoMode === "dank"
    readonly property bool showApps: !root.showCustom && !root.showCompositor && !root.showOs && !root.showDank
    readonly property color iconColor: Theme.effectiveLogoColor !== "" ? Theme.effectiveLogoColor : Theme.surfaceText
    readonly property string compositorSource: {
        if (CompositorService.isNiri)
            return "file://" + Theme.shellDir + "/assets/niri.svg";
        if (CompositorService.isHyprland)
            return "file://" + Theme.shellDir + "/assets/hyprland.svg";
        if (CompositorService.isMango)
            return "file://" + Theme.shellDir + "/assets/mango.png";
        if (CompositorService.isSway || CompositorService.isScroll)
            return "file://" + Theme.shellDir + "/assets/sway.svg";
        if (CompositorService.isMiracle)
            return "file://" + Theme.shellDir + "/assets/miraclewm.svg";
        if (CompositorService.isLabwc)
            return "file://" + Theme.shellDir + "/assets/labwc.png";
        return "";
    }

    function pushMeasuredWidth() {
        root.controller.setDestinationContentWidth("launcher", compactRow.implicitWidth);
    }

    Component.onCompleted: root.pushMeasuredWidth()

    Row {
        id: compactRow

        anchors.centerIn: parent
        spacing: Theme.spacingS

        onImplicitWidthChanged: root.pushMeasuredWidth()

        Item {
            width: root.logoSize
            height: root.logoSize
            anchors.verticalCenter: parent.verticalCenter

            DankIcon {
                visible: root.showApps
                anchors.centerIn: parent
                name: "apps"
                size: root.logoSize
                color: root.iconColor
            }

            SystemLogo {
                visible: root.showOs
                anchors.centerIn: parent
                width: root.logoSize
                height: root.logoSize
                colorOverride: root.iconColor
                brightnessOverride: SettingsData.launcherLogoBrightness
                contrastOverride: SettingsData.launcherLogoContrast
            }

            IconImage {
                visible: root.showDank
                anchors.centerIn: parent
                width: root.logoSize
                height: root.logoSize
                smooth: true
                mipmap: true
                asynchronous: true
                source: "file://" + Theme.shellDir + "/assets/danklogo.svg"
                layer.enabled: true
                layer.smooth: true
                layer.mipmap: true
                layer.effect: MultiEffect {
                    saturation: 0
                    colorization: 1
                    colorizationColor: root.iconColor
                }
            }

            IconImage {
                visible: root.showCompositor
                anchors.centerIn: parent
                width: root.logoSize
                height: root.logoSize
                smooth: true
                asynchronous: true
                source: root.compositorSource
                layer.enabled: true
                layer.effect: MultiEffect {
                    saturation: 0
                    colorization: 1
                    colorizationColor: root.iconColor
                    brightness: SettingsData.launcherLogoBrightness
                    contrast: SettingsData.launcherLogoContrast
                }
            }

            IconImage {
                visible: root.showCustom
                anchors.centerIn: parent
                width: root.logoSize
                height: root.logoSize
                smooth: true
                asynchronous: true
                source: SettingsData.launcherLogoCustomPath ? "file://" + SettingsData.launcherLogoCustomPath.replace("file://", "") : ""
                layer.enabled: true
                layer.effect: MultiEffect {
                    saturation: 0
                    colorization: 1
                    colorizationColor: root.iconColor
                    brightness: SettingsData.launcherLogoBrightness
                    contrast: SettingsData.launcherLogoContrast
                }
            }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.tr("Launcher")
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.DemiBold
        }
    }
}
