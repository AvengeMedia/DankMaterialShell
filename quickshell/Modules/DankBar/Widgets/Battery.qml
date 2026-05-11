import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: battery

    property bool batteryPopupVisible: false
    property var popoutTarget: null

    readonly property int barPosition: {
        switch (axis?.edge) {
        case "top":
            return 0;
        case "bottom":
            return 1;
        case "left":
            return 2;
        case "right":
            return 3;
        default:
            return 0;
        }
    }

    // Helper to get only non-charging icons so we can layer our own bolt
    function getBaseBatteryIcon(level) {
        if (level >= 95) return "battery_full";
        if (level >= 80) return "battery_6_bar";
        if (level >= 60) return "battery_5_bar";
        if (level >= 40) return "battery_4_bar";
        if (level >= 20) return "battery_3_bar";
        if (level >= 10) return "battery_1_bar";
        return "battery_0_bar";
    }

    signal toggleBatteryPopup

    visible: true

    content: Component {
        Item {
            implicitWidth: battery.isVerticalOrientation ? (battery.widgetThickness - battery.horizontalPadding * 2) : batteryContent.implicitWidth
            implicitHeight: battery.isVerticalOrientation ? batteryColumn.implicitHeight : (battery.widgetThickness - battery.horizontalPadding * 2)

            // VERTICAL BAR ORIENTATION
            Column {
                id: batteryColumn
                visible: battery.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 1

                Item {
                    width: Theme.barIconSize(battery.barThickness, undefined, battery.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    height: width
                    anchors.horizontalCenter: parent.horizontalCenter

                    DankIcon {
                        anchors.centerIn: parent
                        name: battery.getBaseBatteryIcon(BatteryService.batteryLevel)
                        size: parent.width
                        // Vertical bar keeps the battery vertical
                        color: {
                            if (!BatteryService.batteryAvailable) return Theme.widgetIconColor;
                            if (BatteryService.isLowBattery && !BatteryService.isCharging) return Theme.error;
                            return Theme.widgetIconColor;
                        }
                    }

                    DankIcon {
                        anchors.centerIn: parent
                        name: "bolt"
                        size: parent.width * 0.75
                        visible: BatteryService.isCharging || BatteryService.isPluggedIn
                        color: Qt.darker(Theme.primary, 1.2)
                        
                        SequentialAnimation on opacity {
                            running: BatteryService.isCharging || BatteryService.isPluggedIn
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 1000; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                        }
                    }
                }

                StyledText {
                    text: BatteryService.batteryLevel.toString()
                    font.pixelSize: Theme.barTextSize(battery.barThickness, battery.barConfig?.fontScale, battery.barConfig?.maximizeWidgetText)
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: BatteryService.batteryAvailable
                }
            }

            // HORIZONTAL BAR ORIENTATION
            Row {
                id: batteryContent
                visible: !battery.isVerticalOrientation
                anchors.centerIn: parent
                spacing: (barConfig?.noBackground ?? false) ? 1 : 2

                Item {
                    width: Theme.barIconSize(battery.barThickness, -4, battery.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    height: width
                    anchors.verticalCenter: parent.verticalCenter

                    DankIcon {
                        anchors.centerIn: parent
                        name: battery.getBaseBatteryIcon(BatteryService.batteryLevel)
                        size: parent.width
                        rotation: 90 // <--- Makes the battery horizontal!
                        color: {
                            if (!BatteryService.batteryAvailable) return Theme.widgetIconColor;
                            if (BatteryService.isLowBattery && !BatteryService.isCharging) return Theme.error;
                            return Theme.widgetIconColor; 
                        }
                    }

                    DankIcon {
                        anchors.centerIn: parent
                        name: "bolt"
                        size: parent.width * 0.75 // Slightly smaller bolt to fit inside the battery
                        visible: BatteryService.isCharging || BatteryService.isPluggedIn
                        color: Qt.darker(Theme.primary, 1.2) // The bolt stays primary accent color!
                        
                        SequentialAnimation on opacity {
                            running: BatteryService.isCharging || BatteryService.isPluggedIn
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 1000; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                        }
                    }
                }

                StyledText {
                    text: `${BatteryService.batteryLevel}%`
                    font.pixelSize: Theme.barTextSize(battery.barThickness, battery.barConfig?.fontScale, battery.barConfig?.maximizeWidgetText)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                    visible: BatteryService.batteryAvailable
                }
            }
        }
    }

    MouseArea {
        x: -battery.leftMargin
        y: -battery.topMargin
        width: battery.width + battery.leftMargin + battery.rightMargin
        height: battery.height + battery.topMargin + battery.bottomMargin
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onPressed: mouse => {
            battery.triggerRipple(this, mouse.x, mouse.y);
            toggleBatteryPopup();
        }
    }
}
