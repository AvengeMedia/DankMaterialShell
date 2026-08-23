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
    readonly property var clusterIds: root.itemsForSide("left").concat(["clock"]).concat(root.itemsForSide("right"))
    property bool weatherRefHeld: false

    function itemsForSide(side) {
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

    component ClusterDot: Rectangle {
        property bool unread: false

        anchors.verticalCenter: parent.verticalCenter
        width: root.dotSize + (unread ? 1 : 0)
        height: width
        radius: height / 2
        color: unread ? Theme.secondary : Theme.primary
    }

    component HoverBackdrop: Rectangle {
        property bool hovered: false

        anchors.centerIn: parent
        width: parent.width + Theme.spacingS
        height: root.slotSize
        radius: height / 2
        color: hovered ? Theme.surfaceTextHover : "transparent"
    }

    component ClusterItem: Row {
        id: item

        required property string itemId
        property int itemIndex: 0

        readonly property bool isClock: item.itemId === "clock"
        readonly property bool isMedia: item.itemId === "media"
        readonly property bool isWeather: item.itemId === "weather"
        readonly property bool isStatus: item.itemId === "status"
        readonly property bool usesBattery: item.isStatus && BatteryService.batteryAvailable

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

                NumericText {
                    anchors.verticalCenter: parent.verticalCenter
                    isMonospace: false
                    text: root.timeText
                    reserveText: root.timeText.replace(/\d/g, "0")
                    width: Math.ceil(Math.max(implicitWidth, reservedWidth))
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                }

                ClusterDot {
                    id: unreadDot

                    unread: root.controller.homeNotificationBadge

                    IslandSlotHoverArea {
                        anchors.centerIn: parent
                        width: parent.width + Theme.spacingXS
                        height: parent.height + Theme.spacingXS
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
                }
            }
        }

        Item {
            width: root.iconSize + Theme.spacingXS
            height: root.slotSize
            visible: item.isMedia

            HoverBackdrop {
                hovered: mediaArea.containsMouse
            }

            AudioVisualization {
                anchors.centerIn: parent
                width: root.iconSize + Theme.spacingXS
                height: width
                maxBarHeight: Math.max(3, height - 2)
                idleIconName: "graphic_eq"
                visible: root.controller.mediaAvailable
            }

            DankIcon {
                anchors.centerIn: parent
                visible: !root.controller.mediaAvailable
                name: "search"
                size: root.iconSize
                color: Theme.surfaceTextMedium
            }

            IslandSlotHoverArea {
                id: mediaArea

                anchors.fill: parent
                controller: root.controller
                onClicked: {
                    if (root.controller.mediaAvailable) {
                        root.controller.requestActivity("media", false, false);
                        return;
                    }
                    root.controller.requestLauncher("", "", false);
                }
            }
        }

        Item {
            width: weatherRow.implicitWidth
            height: root.slotSize
            visible: item.isWeather

            HoverBackdrop {
                hovered: weatherArea.containsMouse
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
                }
            }

            IslandSlotHoverArea {
                id: weatherArea

                anchors.fill: parent
                controller: root.controller
                onClicked: root.controller.requestWeather(false)
            }
        }

        Item {
            width: item.usesBattery ? batteryMeter.width : root.iconSize
            height: root.slotSize
            visible: item.isStatus

            HoverBackdrop {
                hovered: statusArea.containsMouse && !item.usesBattery
            }

            BatteryMeter {
                id: batteryMeter

                anchors.centerIn: parent
                visible: item.usesBattery
                thickness: root.tight ? 12 : 14
                fontSize: Theme.fontSizeSmall
                hovered: statusArea.containsMouse
                outlined: SettingsData.dankIslandBatteryStyle === "outline"
            }

            DankIcon {
                anchors.centerIn: parent
                visible: !item.usesBattery
                name: "tune"
                size: root.iconSize
                color: Theme.surfaceText
            }

            IslandSlotHoverArea {
                id: statusArea

                anchors.fill: parent
                controller: root.controller
                onClicked: root.controller.requestControlCenter("", false)
            }
        }
    }

    Row {
        id: compactRow

        anchors.centerIn: parent
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
}
