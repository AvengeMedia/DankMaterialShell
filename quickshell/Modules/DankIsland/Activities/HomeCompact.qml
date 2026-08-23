pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    required property var controller
    required property var mediaModel

    readonly property string timeText: systemClock.date.toLocaleTimeString(I18n.locale(), SettingsData.getEffectiveTimeFormat())
    readonly property string dateText: systemClock.date.toLocaleDateString(I18n.locale(), SettingsData.getEffectiveDateFormat("ddd MMM d"))
    readonly property bool tight: root.controller.homeCompactTight
    readonly property real slotSize: root.tight ? 24 : 32
    readonly property real slotSpacing: root.controller.homeSlotSpacing
    readonly property bool weatherSlotEnabled: root.controller.homeWeatherSlot !== "hidden"
    readonly property var leftActionIds: homeActionsForSide("left")
    readonly property var rightActionIds: homeActionsForSide("right")
    property bool weatherRefHeld: false

    function homeActionsForSide(side) {
        const ids = [];
        if (root.controller.homeMediaSlot === side)
            ids.push("media");
        if (root.controller.homeWeatherSlot === side)
            ids.push("weather");
        if (root.controller.homeStatusSlot === side)
            ids.push("status");
        return ids;
    }

    function syncWeatherRef(wanted) {
        if (wanted === weatherRefHeld)
            return;
        weatherRefHeld = wanted;
        if (wanted) {
            WeatherService.addRef();
            return;
        }
        WeatherService.removeRef();
    }

    onWeatherSlotEnabledChanged: root.syncWeatherRef(root.weatherSlotEnabled)
    Component.onCompleted: {
        root.syncWeatherRef(root.weatherSlotEnabled);
        root.controller.setHomeContentWidth(compactRow.implicitWidth);
    }
    Component.onDestruction: root.syncWeatherRef(false)

    Connections {
        target: compactRow

        function onImplicitWidthChanged() {
            root.controller.setHomeContentWidth(compactRow.implicitWidth);
        }
    }

    SystemClock {
        id: systemClock

        precision: SettingsData.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    component HomeActionSlot: Item {
        id: slot

        required property string actionId
        required property var controller
        required property var mediaModel
        property real slotSize: 32
        property bool tight: false

        readonly property bool isMedia: actionId === "media"
        readonly property bool isStatus: actionId === "status"
        readonly property bool isWeather: actionId === "weather"
        readonly property bool usesBattery: isStatus && BatteryService.batteryAvailable
        readonly property string weatherTempText: {
            if (!WeatherService.weather.available)
                return "--°";
            const temp = SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp;
            return Math.round(Number(temp)) + "°";
        }

        implicitWidth: {
            if (usesBattery)
                return statusPill.width + 8;
            if (isWeather)
                return weatherRow.implicitWidth;
            return slot.slotSize;
        }
        implicitHeight: slot.slotSize
        width: implicitWidth
        height: implicitHeight

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: slotArea.containsMouse && !slot.usesBattery ? Theme.surfaceTextHover : "transparent"
        }

        MediaCava {
            anchors.centerIn: parent
            width: slot.tight ? 16 : 20
            height: slot.tight ? 16 : 20
            visible: slot.isMedia && slot.controller.mediaAvailable
            mediaModel: slot.mediaModel
        }

        DankIcon {
            anchors.centerIn: parent
            visible: slot.isMedia && !slot.controller.mediaAvailable
            name: "search"
            size: slot.tight ? 16 : Theme.iconSizeSmall
            color: Theme.surfaceTextMedium
        }

        BatteryPill {
            id: statusPill

            anchors.centerIn: parent
            visible: slot.usesBattery
            hovered: slotArea.containsMouse
            outlined: SettingsData.dankIslandBatteryStyle === "outline"
        }

        DankIcon {
            anchors.centerIn: parent
            visible: slot.isStatus && !slot.usesBattery
            name: "tune"
            size: slot.tight ? 16 : Theme.iconSizeSmall
            color: Theme.surfaceText
        }

        Row {
            id: weatherRow

            anchors.centerIn: parent
            spacing: Theme.spacingXXS
            visible: slot.isWeather

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
                size: slot.tight ? 16 : Theme.iconSizeSmall
                color: Theme.primary
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: slot.weatherTempText
                color: Theme.surfaceTextSecondary
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
            }
        }

        IslandSlotHoverArea {
            id: slotArea

            anchors.fill: parent
            controller: slot.controller
            onClicked: {
                if (slot.isMedia) {
                    if (slot.controller.mediaAvailable)
                        slot.controller.requestActivity("media", false, false);
                    else
                        slot.controller.requestLauncher("", "", false);
                    return;
                }
                if (slot.isWeather) {
                    slot.controller.requestWeather(false);
                    return;
                }
                slot.controller.requestControlCenter("", false);
            }
        }
    }

    Row {
        id: compactRow

        anchors.centerIn: parent
        spacing: root.controller.homeClusterGap

        Row {
            id: leftActions

            anchors.verticalCenter: parent.verticalCenter
            spacing: root.slotSpacing
            visible: root.leftActionIds.length > 0

            Repeater {
                model: root.leftActionIds

                HomeActionSlot {
                    required property var modelData
                    actionId: String(modelData)
                    controller: root.controller
                    mediaModel: root.mediaModel
                    slotSize: root.slotSize
                    tight: root.tight
                }
            }
        }

        Row {
            id: clockRow

            anchors.verticalCenter: parent.verticalCenter
            spacing: root.tight ? Theme.spacingXS : Theme.spacingS

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.timeText
                color: Theme.surfaceText
                font.pixelSize: root.tight ? Theme.fontSizeSmall : Theme.fontSizeMedium
                font.weight: Font.DemiBold
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: root.tight ? 3 : 4
                height: root.tight ? 3 : 4
                radius: width / 2
                color: Theme.primary
            }

            StyledText {
                id: dateLabel

                anchors.verticalCenter: parent.verticalCenter
                text: root.dateText
                color: Theme.surfaceTextMedium
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.controller.homeNotificationBadge
                width: visible ? 10 : 0
                height: 16

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 1
                    width: 5
                    height: 5
                    radius: 2.5
                    color: Theme.secondary
                }

                IslandSlotHoverArea {
                    anchors.fill: parent
                    controller: root.controller
                    onClicked: root.controller.requestNotificationCenter(false)
                }
            }
        }

        Row {
            id: rightActions

            anchors.verticalCenter: parent.verticalCenter
            spacing: root.slotSpacing
            visible: root.rightActionIds.length > 0

            Repeater {
                model: root.rightActionIds

                HomeActionSlot {
                    required property var modelData
                    actionId: String(modelData)
                    controller: root.controller
                    mediaModel: root.mediaModel
                    slotSize: root.slotSize
                    tight: root.tight
                }
            }
        }
    }
}
