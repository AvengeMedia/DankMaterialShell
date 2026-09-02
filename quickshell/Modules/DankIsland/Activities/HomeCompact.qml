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
    required property var systemModel

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
    readonly property var brightnessDevice: DisplayService.getCurrentDeviceInfo()
    readonly property real brightnessMaximum: DisplayService.brightnessMaximum(root.brightnessDevice)
    readonly property int brightnessPercent: root.brightnessMaximum > 0 ? Math.round(DisplayService.brightnessLevel / root.brightnessMaximum * 100) : 0
    readonly property int volumePercent: Math.min(AudioService.sinkMaxVolume, Math.round((AudioService.sink?.audio?.volume ?? 0) * 100))
    readonly property var groupIds: root.groupsForSide("left").concat(["clock"]).concat(root.groupsForSide("right"))
    property bool weatherRefHeld: false

    function groupsForSide(side) {
        const ids = [];
        const order = side === "left" ? root.controller.homeLeftOrder : root.controller.homeRightOrder;
        for (const id of order) {
            if (id === "media" && root.controller.homeMediaSlot === side)
                ids.push(id);
            else if (id === "weather" && root.controller.homeWeatherSlot === side && WeatherService.weather.available)
                ids.push(id);
            else if (id === "status" && root.controller.homeStatusSlot === side)
                ids.push(id);
            else if (id === "notifications" && side === "right" && root.controller.homeNotificationBadge)
                ids.push(id);
            else if (id === "volume" && root.controller.homeVolumeSlot === side && AudioService.sink?.audio)
                ids.push(id);
            else if (id === "brightness" && root.controller.homeBrightnessSlot === side && DisplayService.brightnessAvailable && root.brightnessDevice)
                ids.push(id);
        }
        return ids;
    }

    function adjustSystemLevel(activityId, delta) {
        if (delta === 0)
            return;
        const direction = delta > 0 ? 1 : -1;
        if (activityId === "volume") {
            if (!AudioService.sink?.audio)
                return;
            SessionData.suppressOSDTemporarily();
            AudioService.adjustDefaultSinkVolume(5, direction);
            AudioService.playVolumeChangeSoundIfEnabled();
            return;
        }
        if (activityId !== "brightness" || !root.brightnessDevice)
            return;
        const next = Math.max(DisplayService.brightnessMinimum(root.brightnessDevice), Math.min(root.brightnessMaximum, DisplayService.brightnessLevel + direction * 5));
        DisplayService.setBrightness(next, root.brightnessDevice.id, true);
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
        readonly property bool isVolume: item.groupId === "volume"
        readonly property bool isBrightness: item.groupId === "brightness"
        readonly property bool usesBattery: item.isStatus && BatteryService.batteryAvailable

        width: {
            if (item.isMedia)
                return root.iconSize;
            if (item.isWeather)
                return weatherRow.implicitWidth;
            if (item.isNotifications)
                return notificationRow.implicitWidth;
            if (item.isVolume || item.isBrightness)
                return systemLevelRow.implicitWidth;
            if (item.isStatus)
                return item.usesBattery ? batteryMeter.width : root.iconSize;
            return clockRow.implicitWidth;
        }
        height: root.slotSize

        HoverBackdrop {
            visible: item.isMedia || item.isWeather || item.isNotifications || item.isVolume || item.isBrightness || (item.isStatus && !item.usesBattery)
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

        Row {
            id: systemLevelRow

            readonly property string displayMode: item.isVolume ? root.controller.homeVolumeDisplay : root.controller.homeBrightnessDisplay

            anchors.verticalCenter: parent.verticalCenter
            visible: item.isVolume || item.isBrightness
            spacing: Theme.spacingXXS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: systemLevelRow.displayMode !== "percentage"
                name: item.isVolume ? AudioService.sinkVolumeIconName : DisplayService.brightnessIconName(root.brightnessDevice, DisplayService.brightnessLevel)
                size: root.statusIconSize
                color: item.isBrightness ? Theme.primary : Theme.surfaceTextSecondary
            }

            NumericText {
                anchors.verticalCenter: parent.verticalCenter
                visible: systemLevelRow.displayMode !== "icon"
                text: (item.isVolume ? root.volumePercent : root.brightnessPercent) + "%"
                reserveText: item.isVolume ? Math.round(AudioService.sinkMaxVolume) + "%" : "100%"
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
                if (item.isVolume || item.isBrightness) {
                    root.systemModel.show(item.groupId);
                    return;
                }
                root.controller.requestControlCenter("", false);
            }
            onWheel: wheel => {
                if (!item.isVolume && !item.isBrightness)
                    return;
                root.adjustSystemLevel(item.groupId, wheel.angleDelta.y || wheel.angleDelta.x);
                wheel.accepted = true;
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
