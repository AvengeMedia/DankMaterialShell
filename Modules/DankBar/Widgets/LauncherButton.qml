import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property bool isActive: false
    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property string section: "left"
    property var popupTarget: null
    property var parentScreen: null
    property real widgetThickness: 30
    property real barThickness: 48
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetThickness / 30))

    signal clicked()

    width: widgetThickness
    height: widgetThickness

    MouseArea {
        id: launcherArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onPressed: {
            root.clicked();
            if (popupTarget && popupTarget.setTriggerPosition) {
                const globalPos = mapToGlobal(0, 0);
                const currentScreen = parentScreen || Screen;
                const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, width);
                popupTarget.setTriggerPosition(pos.x, pos.y, pos.width, section, currentScreen);
            }
        }
    }

    Rectangle {
        id: launcherContent

        anchors.fill: parent
        radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
        color: {
            if (SettingsData.dankBarNoBackground) {
                return "transparent";
            }

            const baseColor = launcherArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
            return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
        }

        DankIcon {
            visible: SettingsData.launcherLogoMode === "apps"
            anchors.centerIn: parent
            name: "apps"
            size: Theme.barIconSize(barThickness, -4)
            color: Theme.surfaceText
        }

        SystemLogo {
            visible: SettingsData.launcherLogoMode === "os"
            anchors.centerIn: parent
            width: Theme.barIconSize(barThickness, SettingsData.launcherLogoSizeOffset)
            height: Theme.barIconSize(barThickness, SettingsData.launcherLogoSizeOffset)
            colorOverride: Theme.effectiveLogoColor
            brightnessOverride: SettingsData.launcherLogoBrightness
            contrastOverride: SettingsData.launcherLogoContrast
        }

        IconImage {
            visible: SettingsData.launcherLogoMode === "compositor"
            anchors.centerIn: parent
            width: Theme.barIconSize(barThickness, SettingsData.launcherLogoSizeOffset)
            height: Theme.barIconSize(barThickness, SettingsData.launcherLogoSizeOffset)
            smooth: true
            asynchronous: true
            source: {
                if (CompositorService.isNiri) {
                    return "file://" + Theme.shellDir + "/assets/niri.svg"
                } else if (CompositorService.isHyprland) {
                    return "file://" + Theme.shellDir + "/assets/hyprland.svg"
                }
                return ""
            }
            layer.enabled: Theme.effectiveLogoColor !== ""
            layer.effect: MultiEffect {
                saturation: 0
                colorization: 1
                colorizationColor: Theme.effectiveLogoColor
                brightness: SettingsData.launcherLogoBrightness
                contrast: SettingsData.launcherLogoContrast
            }
        }

        IconImage {
            visible: SettingsData.launcherLogoMode === "custom" && SettingsData.launcherLogoCustomPath !== ""
            anchors.centerIn: parent
            width: Theme.barIconSize(barThickness, SettingsData.launcherLogoSizeOffset)
            height: Theme.barIconSize(barThickness, SettingsData.launcherLogoSizeOffset)
            smooth: true
            asynchronous: true
            source: SettingsData.launcherLogoCustomPath ? "file://" + SettingsData.launcherLogoCustomPath.replace("file://", "") : ""
            layer.enabled: Theme.effectiveLogoColor !== ""
            layer.effect: MultiEffect {
                saturation: 0
                colorization: 1
                colorizationColor: Theme.effectiveLogoColor
                brightness: SettingsData.launcherLogoBrightness
                contrast: SettingsData.launcherLogoContrast
            }
        }
    }
}
