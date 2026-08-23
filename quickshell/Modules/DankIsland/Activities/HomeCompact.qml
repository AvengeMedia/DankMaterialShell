pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Modules.DankBar.Widgets
import qs.Services
import qs.Widgets

Item {
    id: root

    required property var controller

    readonly property string timeText: systemClock.date.toLocaleTimeString(I18n.locale(), SettingsData.getEffectiveTimeFormat())
    readonly property string dateText: systemClock.date.toLocaleDateString(I18n.locale(), SettingsData.getEffectiveDateFormat("ddd MMM d"))
    readonly property bool tight: root.controller.homeCompactTight
    readonly property real slotSize: root.tight ? 24 : 32
    readonly property real iconSize: root.tight ? 16 : Theme.iconSizeSmall
    readonly property real itemSpacing: root.tight ? Theme.spacingXS : Theme.spacingS
    readonly property real dotSize: root.tight ? 3 : 4
    readonly property bool weatherSlotEnabled: root.controller.homeWeatherSlot !== "hidden"
    readonly property bool batteryStatus: BatteryService.batteryAvailable
    readonly property var leftSlotIds: root.slotsForSide("left")
    readonly property var rightSlotIds: root.slotsForSide("right")
    readonly property var clusterIds: root.clusterItemsForSide("left").concat(["clock"]).concat(root.clusterItemsForSide("right"))
    property bool weatherRefHeld: false

    function slotsForSide(side) {
        const ids = [];
        if (root.controller.homeMediaSlot === side)
            ids.push("media");
        if (root.controller.homeStatusSlot === side && !root.batteryStatus)
            ids.push("status");
        return ids;
    }

    function clusterItemsForSide(side) {
        const ids = [];
        if (root.controller.homeWeatherSlot === side)
            ids.push("weather");
        if (root.controller.homeStatusSlot === side && root.batteryStatus)
            ids.push("battery");
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

        readonly property bool isMedia: slot.actionId === "media"

        width: root.slotSize
        height: root.slotSize

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: slotArea.containsMouse ? Theme.surfaceTextHover : "transparent"
        }

        AudioVisualization {
            anchors.centerIn: parent
            width: root.tight ? 16 : 20
            height: width
            maxBarHeight: Math.max(3, height - 2)
            idleIconName: "graphic_eq"
            visible: slot.isMedia && root.controller.mediaAvailable
        }

        DankIcon {
            anchors.centerIn: parent
            visible: slot.isMedia && !root.controller.mediaAvailable
            name: "search"
            size: root.iconSize
            color: Theme.surfaceTextMedium
        }

        DankIcon {
            anchors.centerIn: parent
            visible: !slot.isMedia
            name: "tune"
            size: root.iconSize
            color: Theme.surfaceText
        }

        IslandSlotHoverArea {
            id: slotArea

            anchors.fill: parent
            controller: root.controller
            onClicked: {
                if (!slot.isMedia) {
                    root.controller.requestControlCenter("", false);
                    return;
                }
                if (root.controller.mediaAvailable) {
                    root.controller.requestActivity("media", false, false);
                    return;
                }
                root.controller.requestLauncher("", "", false);
            }
        }
    }

    component ClusterDot: Rectangle {
        property bool unread: false

        anchors.verticalCenter: parent.verticalCenter
        width: root.dotSize + (unread ? 1 : 0)
        height: width
        radius: height / 2
        color: unread ? Theme.secondary : Theme.primary
    }

    component ClusterItem: Row {
        id: item

        required property string itemId
        property int itemIndex: 0

        readonly property bool isClock: item.itemId === "clock"
        readonly property bool isWeather: item.itemId === "weather"
        readonly property bool isBattery: item.itemId === "battery"

        spacing: root.itemSpacing

        ClusterDot {
            visible: item.itemIndex > 0
        }

        Item {
            width: clockRow.implicitWidth
            height: root.slotSize
            visible: item.isClock

            Row {
                id: clockRow

                anchors.verticalCenter: parent.verticalCenter
                spacing: root.itemSpacing

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.timeText
                    color: Theme.surfaceText
                    font.pixelSize: root.tight ? Theme.fontSizeSmall : Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                }

                ClusterDot {
                    id: unreadDot

                    unread: root.controller.homeNotificationBadge

                    IslandSlotHoverArea {
                        anchors.centerIn: parent
                        width: parent.width + Theme.spacingS
                        height: parent.height + Theme.spacingS
                        enabled: unreadDot.unread
                        controller: root.controller
                        onClicked: root.controller.requestNotificationCenter(false)
                    }
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.dateText
                    color: Theme.surfaceTextMedium
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                }
            }
        }

        Item {
            width: weatherRow.implicitWidth
            height: root.slotSize
            visible: item.isWeather

            Rectangle {
                anchors.centerIn: parent
                width: parent.width + Theme.spacingS
                height: parent.height
                radius: height / 2
                color: weatherArea.containsMouse ? Theme.surfaceTextHover : "transparent"
            }

            Row {
                id: weatherRow

                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXXS

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
                    size: root.iconSize
                    color: Theme.primary
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: WeatherService.currentTempText()
                    color: Theme.surfaceTextSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                }
            }

            IslandSlotHoverArea {
                id: weatherArea

                anchors.centerIn: parent
                width: parent.width + Theme.spacingS
                height: parent.height
                controller: root.controller
                onClicked: root.controller.requestWeather(false)
            }
        }

        Item {
            width: batteryMeter.width
            height: root.slotSize
            visible: item.isBattery

            BatteryMeter {
                id: batteryMeter

                anchors.centerIn: parent
                thickness: root.tight ? 12 : 14
                hovered: batteryArea.containsMouse
                outlined: SettingsData.dankIslandBatteryStyle === "outline"
            }

            IslandSlotHoverArea {
                id: batteryArea

                anchors.centerIn: parent
                width: parent.width + Theme.spacingS
                height: parent.height
                controller: root.controller
                onClicked: root.controller.requestControlCenter("", false)
            }
        }
    }

    Row {
        id: compactRow

        anchors.centerIn: parent
        spacing: root.controller.homeClusterGap

        Repeater {
            model: root.leftSlotIds

            HomeActionSlot {
                required property var modelData
                actionId: String(modelData)
            }
        }

        Row {
            height: root.slotSize
            spacing: root.itemSpacing

            Repeater {
                model: root.clusterIds

                ClusterItem {
                    required property var modelData
                    required property int index
                    itemId: String(modelData)
                    itemIndex: index
                }
            }
        }

        Repeater {
            model: root.rightSlotIds

            HomeActionSlot {
                required property var modelData
                actionId: String(modelData)
            }
        }
    }
}
