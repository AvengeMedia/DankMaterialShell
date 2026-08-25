import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: battery
    readonly property var log: Log.scoped("Battery")

    property bool batteryPopupVisible: false
    property var popoutTarget: null
    property var widgetData: null
    readonly property bool showPercentOnlyOnBattery: widgetData?.showBatteryPercentOnlyOnBattery !== undefined ? widgetData.showBatteryPercentOnlyOnBattery : SettingsData.showBatteryPercentOnlyOnBattery
    readonly property bool showPercent: {
        const base = widgetData?.showBatteryPercent !== undefined ? widgetData.showBatteryPercent : SettingsData.showBatteryPercent;
        return base && !(showPercentOnlyOnBattery && BatteryService.isPluggedIn);
    }
    readonly property bool showTime: widgetData?.showBatteryTime !== undefined ? widgetData.showBatteryTime : SettingsData.showBatteryTime
    readonly property bool showTimeOnlyOnBattery: widgetData?.showBatteryTimeOnlyOnBattery !== undefined ? widgetData.showBatteryTimeOnlyOnBattery : SettingsData.showBatteryTimeOnlyOnBattery
    readonly property bool pillStyle: widgetData?.batteryPillStyle !== undefined ? widgetData.batteryPillStyle : SettingsData.batteryPillStyle

    readonly property string batteryTimeText: {
        if (showTimeOnlyOnBattery && BatteryService.isPluggedIn) {
            return "";
        }
        const time = BatteryService.formatTimeRemaining();
        return time !== "Unknown" ? time : "";
    }

    readonly property string verticalBatteryTimeText: {
        if (!batteryTimeText)
            return "";

        // Parse batteryTimeText, e.g., "2h 41m" or "41m"
        let hours = 0;
        let minutes = 0;

        const hourMatch = batteryTimeText.match(/(\d+)h/);
        const minMatch = batteryTimeText.match(/(\d+)m/);

        if (hourMatch) {
            hours = parseInt(hourMatch[1], 10);
        }
        if (minMatch) {
            minutes = parseInt(minMatch[1], 10);
        }

        const hoursStr = hours < 10 ? "0" + hours : hours.toString();
        const minutesStr = minutes < 10 ? "0" + minutes : minutes.toString();

        return `${hoursStr}\n${minutesStr}`;
    }

    readonly property string horizontalDisplayText: {
        if (showPercent && showTime && batteryTimeText) {
            return `${BatteryService.batteryLevel}% (${batteryTimeText})`;
        }
        if (showPercent) {
            return `${BatteryService.batteryLevel}%`;
        }
        if (showTime && batteryTimeText) {
            return batteryTimeText;
        }
        return "";
    }

    // Percent always stays inside the pill; only the time shows beside it.
    readonly property string horizontalSideText: {
        if (!pillStyle) {
            return horizontalDisplayText;
        }
        return (showTime && batteryTimeText) ? batteryTimeText : "";
    }

    readonly property string verticalDisplayText: {
        if (showPercent && showTime && batteryTimeText) {
            return `${BatteryService.batteryLevel}\n${verticalBatteryTimeText}`;
        }
        if (showPercent) {
            return BatteryService.batteryLevel.toString();
        }
        if (showTime && batteryTimeText) {
            return verticalBatteryTimeText;
        }
        return "";
    }

    property real touchpadAccumulator: 0

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

    signal toggleBatteryPopup

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
                    visible: !battery.pillStyle
                    size: Theme.barIconSize(battery.barThickness, undefined, battery.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: {
                        if (!BatteryService.batteryAvailable) {
                            return Theme.widgetIconColor;
                        }

                        if (BatteryService.isLowBattery && !BatteryService.isCharging) {
                            return Theme.error;
                        }

                        if (BatteryService.isCharging || BatteryService.isPluggedIn) {
                            return Theme.primary;
                        }

                        return Theme.widgetIconColor;
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                BatteryMeter {
                    visible: battery.pillStyle
                    vertical: true
                    showNumber: false
                    thickness: Theme.barIconSize(battery.barThickness, undefined, battery.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: battery.verticalDisplayText
                    font.pixelSize: Theme.barTextSize(battery.barThickness, battery.barConfig?.fontScale, battery.barConfig?.maximizeWidgetText)
                    color: Theme.widgetTextColor
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: BatteryService.batteryAvailable && battery.verticalDisplayText !== ""
                }
            }

            Row {
                id: batteryContent
                visible: !battery.isVerticalOrientation
                anchors.centerIn: parent
                spacing: (barConfig?.noBackground ?? false) ? 1 : 2

                DankIcon {
                    name: BatteryService.getBatteryIcon()
                    visible: !battery.pillStyle
                    size: Theme.barIconSize(battery.barThickness, -4, battery.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: {
                        if (!BatteryService.batteryAvailable) {
                            return Theme.widgetIconColor;
                        }

                        if (BatteryService.isLowBattery && !BatteryService.isCharging) {
                            return Theme.error;
                        }

                        if (BatteryService.isCharging || BatteryService.isPluggedIn) {
                            return Theme.primary;
                        }

                        return Theme.widgetIconColor;
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }

                BatteryMeter {
                    visible: battery.pillStyle
                    showNumber: battery.showPercent
                    thickness: Theme.barIconSize(battery.barThickness, -4, battery.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    fontSize: Theme.barTextSize(battery.barThickness, battery.barConfig?.fontScale, battery.barConfig?.maximizeWidgetText)
                    anchors.verticalCenter: parent.verticalCenter
                }

                NumericText {
                    isMonospace: false
                    text: battery.horizontalSideText
                    reserveText: battery.horizontalSideText.replace(/\d/g, "0")
                    width: Math.ceil(Math.max(implicitWidth, reservedWidth))
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Theme.barTextSize(battery.barThickness, battery.barConfig?.fontScale, battery.barConfig?.maximizeWidgetText)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                    visible: BatteryService.batteryAvailable && battery.horizontalSideText !== ""
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
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            battery.triggerRipple(this, mouse.x, mouse.y);
            if (mouse.button === Qt.LeftButton) {
                toggleBatteryPopup();
            } else if (mouse.button === Qt.RightButton) {
                if (PowerProfileWatcher.available) {
                    PowerProfileWatcher.cycleProfile();
                } else {
                    ToastService.showError(I18n.tr("power-profiles-daemon not available"));
                }
            }
        }
        onWheel: wheel => {
            var delta = wheel.angleDelta.y;
            if (delta === 0)
                return;

            // Check if this is a touchpad
            if (delta !== 120 && delta !== -120) {
                touchpadAccumulator += delta;
                if (Math.abs(touchpadAccumulator) < 500)
                    return;
                delta = touchpadAccumulator;
                touchpadAccumulator = 0;
            }

            if (!DisplayService.brightnessAvailable) {
                return;
            }

            const step = 5;
            const change = delta > 0 ? step : -step;
            const newBrightness = Math.max(0, Math.min(100, DisplayService.brightnessLevel + change));
            DisplayService.setBrightness(newBrightness, "", false);
        }
    }
}
