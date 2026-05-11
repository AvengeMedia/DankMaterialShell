import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets
import Qt5Compat.GraphicalEffects
import Quickshell.Services.UPower
// Import QtQuick Controls to get access to standard Icon rendering
import QtQuick.Controls

BasePill {
    id: battery

    property bool batteryPopupVisible: false
    property var popoutTarget: null

    readonly property int barPosition: {
        switch (axis?.edge) {
        case "top": return 0;
        case "bottom": return 1;
        case "left": return 2;
        case "right": return 3;
        default: return 0;
        }
    }

    signal toggleBatteryPopup

    visible: true

    function getBatteryColor() {
        if (!BatteryService.batteryAvailable) return Theme.widgetIconColor;
        if (BatteryService.isLowBattery && !BatteryService.isCharging) return Theme.error;
        if (BatteryService.isCharging || BatteryService.isPluggedIn) return Theme.primary;
        return Theme.widgetIconColor;
    }

    // Modern Android 16 "Expressive" Battery Component
    Component {
        id: pixelBattery
        Item {
            property int baseSize: Theme.barIconSize(battery.barThickness, -2, battery.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
            
            // The Pixel battery is naturally a wide pill shape
            width: battery.isVerticalOrientation ? baseSize * 0.6 : baseSize * 1.2
            height: battery.isVerticalOrientation ? baseSize * 1.2 : baseSize * 0.6

            // Automatically rotate for vertical bars
            rotation: battery.isVerticalOrientation ? -90 : 0
            
            property color iconColor: battery.getBatteryColor()

            // 1. Battery Body (The thick outline)
            Rectangle {
                id: body
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.88
                height: parent.height
                radius: height / 2 // Perfect pill rounding
                color: "transparent"
                border.color: parent.iconColor
                border.width: Math.max(1.5, parent.height * 0.12)

                // 2. Inner Fill (Dynamic level)
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: body.border.width + 1.5
                    
                    property real fillPercentage: BatteryService.batteryLevel / 100
                    property real maxWidth: parent.width - (anchors.margins * 2)
                    
                    // Keep minimum width equal to height to maintain the inner pill shape
                    width: Math.max(height, maxWidth * fillPercentage)
                    radius: height / 2
                    color: parent.iconColor
                    visible: BatteryService.batteryAvailable

                    // Smooth, aesthetic pulse effect for charging
                    SequentialAnimation on opacity {
                        running: BatteryService.isCharging || BatteryService.isPluggedIn
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 1000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                    }
                }
            }

            // 3. Battery Terminal (The cap on the right side)
            Rectangle {
                anchors.left: body.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 1
                width: parent.width * 0.08
                height: parent.height * 0.35
                radius: height / 2
                color: parent.iconColor
            }
        }
    }

    content: Component {
        Item {
            implicitWidth: battery.isVerticalOrientation ? (battery.widgetThickness - battery.horizontalPadding * 2) : batteryContent.implicitWidth
            implicitHeight: battery.isVerticalOrientation ? batteryColumn.implicitHeight : (battery.widgetThickness - battery.horizontalPadding * 2)

            // VERTICAL BAR ORIENTATION
            Column {
                id: batteryColumn
                visible: battery.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 4

                Loader {
                    sourceComponent: pixelBattery
                    anchors.horizontalCenter: parent.horizontalCenter
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
                spacing: (barConfig?.noBackground ?? false) ? 4 : 6

                Loader {
                    sourceComponent: pixelBattery
                    anchors.verticalCenter: parent.verticalCenter
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
