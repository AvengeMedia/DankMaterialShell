import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    // Passed in by TopBar
    property int widgetHeight: 28
    property int barHeight: 32
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    signal toggleVpnPopup()

    width: Theme.iconSize + horizontalPadding * 2
    height: widgetHeight
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) {
            return "transparent";
        }

        const baseColor = clickArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    DankIcon {
        id: icon

        name: VpnService.isBusy ? "sync" : (VpnService.connected ? "vpn_lock" : "vpn_key_off")
        size: Theme.iconSize - 6
        color: VpnService.connected ? Theme.primary : Theme.surfaceText
        anchors.centerIn: parent

        RotationAnimation on rotation {
            running: VpnService.isBusy
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 900
        }

    }

    MouseArea {
        id: clickArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            if (popupTarget && popupTarget.setTriggerPosition) {
                const globalPos = mapToGlobal(0, 0);
                const currentScreen = parentScreen || Screen;
                const screenX = currentScreen.x || 0;
                const relativeX = globalPos.x - screenX;
                popupTarget.setTriggerPosition(relativeX, SettingsData.getPopupYPosition(barHeight), width, section, currentScreen);
            }
            root.toggleVpnPopup();
        }
    }

    Rectangle {
        id: tooltip

        width: Math.max(120, tooltipText.contentWidth + Theme.spacingM * 2)
        height: tooltipText.contentHeight + Theme.spacingS * 2
        radius: Theme.cornerRadius
        color: Theme.widgetBaseBackgroundColor
        border.color: Theme.surfaceVariantAlpha
        border.width: 1
        visible: clickArea.containsMouse && !(popupTarget && popupTarget.shouldBeVisible)
        anchors.bottom: parent.top
        anchors.bottomMargin: Theme.spacingS
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: clickArea.containsMouse ? 1 : 0

        Text {
            id: tooltipText

            anchors.centerIn: parent
            text: {
                if (!VpnService.connected) {
                    return "VPN Disconnected";
                }

                const names = VpnService.activeNames || [];
                if (names.length <= 1) {
                    return "VPN Connected • " + (names[0] || "");
                }

                return "VPN Connected • " + names[0] + " +" + (names.length - 1);
            }
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }

        }

    }

}
