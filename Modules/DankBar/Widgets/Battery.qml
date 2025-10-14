import QtQuick
import Quickshell.Services.UPower
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: battery

    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property bool batteryPopupVisible: false
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property real widgetThickness: 30
    property real barThickness: 48
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetThickness / 30))

    signal toggleBatteryPopup()

    width: isVertical ? widgetThickness : (batteryContent.implicitWidth + horizontalPadding * 2)
    height: isVertical ? (batteryColumn.implicitHeight + horizontalPadding * 2) : widgetThickness
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) {
            return "transparent";
        }

        const baseColor = batteryArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }
    visible: true

    Column {
        id: batteryColumn
        visible: battery.isVertical
        anchors.centerIn: parent
        spacing: 1

        DankIcon {
            name: BatteryService.getBatteryIcon()
            size: Theme.barIconSize(barThickness)
            color: {
                if (!BatteryService.batteryAvailable) {
                    return Theme.surfaceText
                }

                if (BatteryService.isLowBattery && !BatteryService.isCharging) {
                    return Theme.error
                }

                if (BatteryService.isCharging || BatteryService.isPluggedIn) {
                    return Theme.primary
                }

                return Theme.surfaceText
            }
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: BatteryService.batteryLevel.toString()
            font.pixelSize: Theme.barTextSize(barThickness)
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
            visible: BatteryService.batteryAvailable
        }
    }

    Row {
        id: batteryContent
        visible: !battery.isVertical
        anchors.centerIn: parent
        spacing: SettingsData.dankBarNoBackground ? 1 : 2

        DankIcon {
            name: BatteryService.getBatteryIcon()
            size: Theme.barIconSize(barThickness, -4)
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
            font.pixelSize: Theme.barTextSize(barThickness)
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
                const globalPos = mapToGlobal(0, 0)
                const currentScreen = parentScreen || Screen
                const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, width)
                popupTarget.setTriggerPosition(pos.x, pos.y, pos.width, section, currentScreen)
            }
            toggleBatteryPopup();
        }
    }
}