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
    readonly property real slotSize: root.tight ? Theme.iconSize : Theme.iconSizeLarge
    readonly property real textSize: root.tight ? Theme.fontSizeSmall : Theme.fontSizeMedium
    readonly property real iconSize: root.textSize + Theme.spacingXS
    readonly property real statusIconSize: root.textSize + Theme.spacingXXS
    readonly property real groupSpacing: root.controller.homeSlotMargin
    readonly property real edgePad: Math.max(root.groupSpacing, (root.width - compactRow.width) / 2)
    readonly property bool weatherSlotEnabled: root.controller.homeWeatherSlot !== "hidden"
    readonly property var groupIds: root.groupsForSide("left").concat(["clock"]).concat(root.groupsForSide("right"))
    property bool weatherRefHeld: false

    function groupsForSide(side) {
        const ids = [];
        const media = root.controller.homeMediaSlot === side;
        if (media && side === "left")
            ids.push("media");
        if (root.controller.homeWeatherSlot === side && WeatherService.weather.available)
            ids.push("weather");
        if (root.controller.homeStatusSlot === side)
            ids.push("status");
        if (side === "right" && root.controller.homeNotificationBadge)
            ids.push("notifications");
        if (media && side === "right")
            ids.push("media");
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

    component HoverBackdrop: Rectangle {
        property bool hovered: false

        anchors.centerIn: parent
        width: parent.width + Theme.spacingS
        height: root.slotSize
        radius: height / 2
        color: hovered ? Theme.surfaceTextHover : "transparent"
    }

    component GroupItem: Item {
        id: item

        required property string groupId
        required property int slotIndex

        readonly property real leadPad: item.slotIndex === 0 ? root.edgePad : root.groupSpacing / 2
        readonly property real trailPad: item.slotIndex === root.groupIds.length - 1 ? root.edgePad : root.groupSpacing / 2
        readonly property bool isClock: item.groupId === "clock"
        readonly property bool isMedia: item.groupId === "media"
        readonly property bool isWeather: item.groupId === "weather"
        readonly property bool isStatus: item.groupId === "status"
        readonly property bool isNotifications: item.groupId === "notifications"
        readonly property bool usesBattery: item.isStatus && BatteryService.batteryAvailable

        width: {
            if (item.isMedia)
                return root.iconSize;
            if (item.isWeather)
                return weatherRow.implicitWidth;
            if (item.isNotifications)
                return notificationRow.implicitWidth;
            if (item.isStatus)
                return item.usesBattery ? batteryMeter.width : root.iconSize;
            return clockRow.implicitWidth;
        }
        height: root.slotSize

        HoverBackdrop {
            visible: item.isMedia || item.isWeather || item.isNotifications || (item.isStatus && !item.usesBattery)
            hovered: groupArea.containsMouse
        }

        AudioVisualization {
            anchors.centerIn: parent
            width: root.iconSize + Theme.spacingXS
            height: width
            maxBarHeight: Math.max(3, height - 2)
            idleIconName: "graphic_eq"
            visible: item.isMedia && root.controller.mediaAvailable
        }

        DankIcon {
            anchors.centerIn: parent
            visible: item.isMedia && !root.controller.mediaAvailable
            name: "search"
            size: root.iconSize
            color: Theme.surfaceTextMedium
        }

        Row {
            id: clockRow

            anchors.verticalCenter: parent.verticalCenter
            visible: item.isClock
            spacing: Theme.spacingS

            NumericText {
                anchors.verticalCenter: parent.verticalCenter
                isMonospace: false
                text: root.timeText
                reserveText: root.timeText.replace(/\d/g, "0")
                width: Math.ceil(Math.max(implicitWidth, reservedWidth))
                color: Theme.surfaceText
                font.pixelSize: root.textSize
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.spacingXS
                height: Theme.spacingXS
                radius: height / 2
                color: Theme.primary
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.dateText
                color: Theme.surfaceTextMedium
                font.pixelSize: root.textSize
            }
        }

        Row {
            id: notificationRow

            anchors.verticalCenter: parent.verticalCenter
            visible: item.isNotifications
            spacing: Theme.spacingXXS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "notifications"
                size: root.statusIconSize
                color: Theme.secondary
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.controller.unreadNotificationCount
                color: Theme.surfaceTextSecondary
                font.pixelSize: root.textSize
            }
        }

        Row {
            id: weatherRow

            anchors.verticalCenter: parent.verticalCenter
            visible: item.isWeather
            spacing: Theme.spacingXXS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
                size: root.statusIconSize
                color: Theme.surfaceTextSecondary
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: WeatherService.currentTempText()
                color: Theme.surfaceTextSecondary
                font.pixelSize: root.textSize
            }
        }

        BatteryMeter {
            id: batteryMeter

            anchors.centerIn: parent
            visible: item.usesBattery
            thickness: root.statusIconSize
            fontSize: root.textSize
            hovered: groupArea.containsMouse
            outlined: SettingsData.dankIslandBatteryStyle === "outline"
        }

        DankIcon {
            anchors.centerIn: parent
            visible: item.isStatus && !item.usesBattery
            name: "tune"
            size: root.iconSize
            color: Theme.surfaceText
        }

        IslandSlotHoverArea {
            id: groupArea

            anchors.verticalCenter: parent.verticalCenter
            x: -item.leadPad
            width: parent.width + item.leadPad + item.trailPad
            height: root.height
            enabled: !item.isClock
            controller: root.controller
            onClicked: {
                if (item.isMedia && root.controller.mediaAvailable) {
                    root.controller.requestActivity("media", false, false);
                    return;
                }
                if (item.isMedia) {
                    root.controller.requestLauncher("", "", false);
                    return;
                }
                if (item.isWeather) {
                    root.controller.requestWeather(false);
                    return;
                }
                if (item.isNotifications) {
                    root.controller.requestNotificationCenter(false);
                    return;
                }
                root.controller.requestControlCenter("", false);
            }
        }
    }

    Row {
        id: compactRow

        anchors.centerIn: parent
        height: root.slotSize
        spacing: root.groupSpacing

        Repeater {
            model: root.groupIds

            GroupItem {
                required property var modelData
                required property int index
                groupId: String(modelData)
                slotIndex: index
            }
        }
    }
}
