import QtQuick
import Quickshell.Services.UPower
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: battery

    property bool batteryPopupVisible: false
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property real widgetHeight: 30
    property real barHeight: 48
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    signal toggleBatteryPopup()

    width: batteryContent.implicitWidth + horizontalPadding * 2
    height: widgetHeight
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) {
            return "transparent";
        }

        const baseColor = batteryArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }
    visible: true

    Row {
        id: batteryContent

        anchors.centerIn: parent
        spacing: SettingsData.dankBarNoBackground ? 1 : 2

        DankIcon {
            name: BatteryService.getBatteryIcon()
            size: Theme.iconSize - 6
            color: {
                if (!BatteryService.batteryAvailable) {
                    return Theme.surfaceText;
                }

                if (BatteryService.isLowBattery && !BatteryService.isCharging) {
                    return Theme.error;
                }

                if (BatteryService.isCharging || BatteryService.isPluggedIn) {
                    return Theme.primary;
                }

                return Theme.surfaceText;
            }
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: `${BatteryService.batteryLevel}%`
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            visible: BatteryService.batteryAvailable
        }

    }

    MouseArea {
        id: batteryArea

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
            toggleBatteryPopup();
        }
    }

    Rectangle {
        id: batteryTooltip

        width: Math.max(120, tooltipText.contentWidth + Theme.spacingM * 2)
        height: tooltipText.contentHeight + Theme.spacingS * 2
        radius: Theme.cornerRadius
        color: Theme.widgetBaseBackgroundColor
        border.color: Theme.surfaceVariantAlpha
        border.width: 1
        visible: batteryArea.containsMouse && !batteryPopupVisible
        anchors.bottom: parent.top
        anchors.bottomMargin: Theme.spacingS
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: batteryArea.containsMouse ? 1 : 0

        Column {
            anchors.centerIn: parent
            spacing: 2

            StyledText {
                id: tooltipText

                text: {
                    if (!BatteryService.batteryAvailable) {
                        if (typeof PowerProfiles === "undefined") {
                            return "Power Management";
                        }

                        switch (PowerProfiles.profile) {
                        case PowerProfile.PowerSaver:
                            return "Power Profile: Power Saver";
                        case PowerProfile.Performance:
                            return "Power Profile: Performance";
                        default:
                            return "Power Profile: Balanced";
                        }
                    }
                    const status = BatteryService.batteryStatus;
                    const level = `${BatteryService.batteryLevel}%`;
                    const time = BatteryService.formatTimeRemaining();
                    if (time !== "Unknown") {
                        return `${status} • ${level} • ${time}`;
                    } else {
                        return `${status} • ${level}`;
                    }
                }
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                horizontalAlignment: Text.AlignHCenter
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }

        }

    }


}
