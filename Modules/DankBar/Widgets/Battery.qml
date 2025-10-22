import QtQuick
import Quickshell.Services.UPower
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: battery

    property bool batteryPopupVisible: false
    property var popoutTarget: null

    signal toggleBatteryPopup()

    visible: true

    content: Component {
        Item {
            implicitWidth: battery.isVerticalOrientation ? (battery.widgetThickness - battery.horizontalPadding * 2) : batteryContent.implicitWidth
            implicitHeight: battery.isVerticalOrientation ? batteryColumn.implicitHeight : (battery.widgetThickness - battery.horizontalPadding * 2)

            Column {
                id: batteryColumn
                visible: battery.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 1

                DankIcon {
                    name: BatteryService.getBatteryIcon()
                    size: Theme.barIconSize(battery.barThickness)
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
                    font.pixelSize: Theme.barTextSize(battery.barThickness)
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: BatteryService.batteryAvailable
                }
            }

            Row {
                id: batteryContent
                visible: !battery.isVerticalOrientation
                anchors.centerIn: parent
                spacing: SettingsData.dankBarNoBackground ? 1 : 2

                DankIcon {
                    name: BatteryService.getBatteryIcon()
                    size: Theme.barIconSize(battery.barThickness, -4)
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
                    font.pixelSize: Theme.barTextSize(battery.barThickness)
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: BatteryService.batteryAvailable
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onPressed: {
            if (popoutTarget && popoutTarget.setTriggerPosition) {
                const globalPos = battery.visualContent.mapToGlobal(0, 0)
                const currentScreen = parentScreen || Screen
                const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, battery.visualWidth)
                popoutTarget.setTriggerPosition(pos.x, pos.y, pos.width, section, currentScreen)
            }
            toggleBatteryPopup();
        }
    }
}