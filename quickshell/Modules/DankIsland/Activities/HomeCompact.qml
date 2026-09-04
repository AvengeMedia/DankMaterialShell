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
    readonly property string hourText: {
        const hours = systemClock.date.getHours();
        if (SettingsData.use24HourClock)
            return String(hours).padStart(2, "0");
        return String(hours === 0 ? 12 : (hours > 12 ? hours - 12 : hours)).padStart(2, "0");
    }
    readonly property string minuteText: String(systemClock.date.getMinutes()).padStart(2, "0")
    readonly property string monthText: systemClock.date.toLocaleDateString(I18n.locale(), "MMM")
    readonly property string dayText: String(systemClock.date.getDate())
    readonly property string dateText: systemClock.date.toLocaleDateString(I18n.locale(), SettingsData.getEffectiveDateFormat("ddd MMM d"))
    readonly property bool tight: root.controller.homeCompactTight
    readonly property real slotSize: root.tight ? Theme.iconSize : Theme.iconSizeLarge
    readonly property real textSize: root.tight ? Theme.fontSizeSmall : Theme.fontSizeMedium
    readonly property real iconSize: root.textSize + Theme.spacingXS
    readonly property real statusIconSize: root.textSize + Theme.spacingXXS
    readonly property real groupSpacing: root.controller.homeSlotMargin
    readonly property bool isVertical: root.controller.isVertical
    readonly property string clockDisplay: root.controller.homeClockDisplay
    readonly property real edgePad: Math.max(root.groupSpacing, ((root.isVertical ? root.height - compactColumn.height : root.width - compactRow.width)) / 2)
    readonly property bool weatherSlotEnabled: root.controller.homeWeatherEnabled
    readonly property var brightnessDevice: DisplayService.getCurrentDeviceInfo()
    readonly property real brightnessMaximum: DisplayService.brightnessMaximum(root.brightnessDevice)
    readonly property int brightnessPercent: root.brightnessMaximum > 0 ? Math.round(DisplayService.brightnessLevel / root.brightnessMaximum * 100) : 0
    readonly property int volumePercent: Math.min(AudioService.sinkMaxVolume, Math.round((AudioService.sink?.audio?.volume ?? 0) * 100))
    readonly property var groupIds: root.groupsForSide("left").concat(["clock"]).concat(root.groupsForSide("right"))
    readonly property real touchpadThreshold: 100
    property real wheelAccumulator: 0
    property bool weatherRefHeld: false

    function groupsForSide(side) {
        const groups = side === "left" ? root.controller.homeLeftGroups : root.controller.homeRightGroups;
        return groups.filter(id => root.groupShown(id));
    }

    function groupShown(id) {
        switch (id) {
        case "weather":
            return root.controller.homeWeatherEnabled && WeatherService.weather.available;
        case "notifications":
            return root.controller.homeNotificationBadge;
        case "volume":
            return !!AudioService.sink?.audio;
        case "brightness":
            return DisplayService.brightnessAvailable && !!root.brightnessDevice;
        }
        return true;
    }

    function wheelDirection(delta) {
        const isMouseWheel = Math.abs(delta) >= 120 && Math.abs(delta) % 120 === 0;
        if (isMouseWheel)
            return delta > 0 ? 1 : -1;
        root.wheelAccumulator += delta;
        if (Math.abs(root.wheelAccumulator) < root.touchpadThreshold)
            return 0;
        const direction = root.wheelAccumulator > 0 ? 1 : -1;
        root.wheelAccumulator = 0;
        return direction;
    }

    function activateGroup(groupId) {
        switch (groupId) {
        case "media":
            if (root.controller.mediaAvailable) {
                root.controller.requestActivity("media", false, false);
                return;
            }
            root.controller.requestLauncher("", "", false);
            return;
        case "weather":
            root.controller.requestWeather(false);
            return;
        case "notifications":
            root.controller.requestNotificationCenter(false);
            return;
        case "volume":
        case "brightness":
            root.systemModel.open(groupId);
            return;
        }
        root.controller.requestControlCenter("", false);
    }

    function adjustSystemLevel(activityId, delta) {
        const direction = root.wheelDirection(delta);
        if (direction === 0)
            return;
        switch (activityId) {
        case "volume":
            root.adjustVolume(direction);
            return;
        case "brightness":
            root.adjustBrightness(direction);
            return;
        }
    }

    function adjustVolume(direction) {
        if (!AudioService.sink?.audio)
            return;
        SessionData.suppressOSDTemporarily();
        AudioService.adjustDefaultSinkVolume(AudioService.wheelVolumeStep, direction);
        AudioService.playVolumeChangeSoundIfEnabled();
    }

    function adjustBrightness(direction) {
        if (!root.brightnessDevice)
            return;
        SessionData.suppressOSDTemporarily();
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

    function pushMeasuredLength() {
        root.controller.setHomeContentLength(root.isVertical ? compactColumn.implicitHeight : compactRow.implicitWidth);
    }

    onWeatherSlotEnabledChanged: root.syncWeatherRef(root.weatherSlotEnabled)
    onIsVerticalChanged: root.pushMeasuredLength()
    Component.onCompleted: {
        root.syncWeatherRef(root.weatherSlotEnabled);
        root.pushMeasuredLength();
    }
    Component.onDestruction: root.syncWeatherRef(false)

    Connections {
        target: compactRow

        function onImplicitWidthChanged() {
            root.pushMeasuredLength();
        }
    }

    Connections {
        target: compactColumn

        function onImplicitHeightChanged() {
            root.pushMeasuredLength();
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

            readonly property string displayMode: root.controller.homeClockDisplay

            anchors.verticalCenter: parent.verticalCenter
            visible: item.isClock
            spacing: Theme.spacingS

            NumericText {
                anchors.verticalCenter: parent.verticalCenter
                visible: clockRow.displayMode !== "date"
                isMonospace: false
                text: root.timeText
                reserveText: root.timeText.replace(/\d/g, "0")
                width: Math.ceil(Math.max(implicitWidth, reservedWidth))
                color: Theme.surfaceText
                font.pixelSize: root.textSize
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: clockRow.displayMode === "both"
                width: Theme.spacingXS
                height: Theme.spacingXS
                radius: height / 2
                color: Theme.primary
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: clockRow.displayMode !== "time"
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
                color: Theme.surfaceTextSecondary
            }

            NumericText {
                anchors.verticalCenter: parent.verticalCenter
                visible: systemLevelRow.displayMode !== "icon"
                text: (item.isVolume ? root.volumePercent : root.brightnessPercent) + "%"
                reserveText: item.isVolume ? AudioService.sinkMaxVolume + "%" : "100%"
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
            meterStyle: root.controller.batteryStyle
            levelColors: (root.controller.barConfig?.batteryColorMode ?? "theme") === "level"
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
            onClicked: root.activateGroup(item.groupId)
            onWheel: wheel => {
                if (!item.isVolume && !item.isBrightness)
                    return;
                root.adjustSystemLevel(item.groupId, wheel.angleDelta.y || wheel.angleDelta.x);
                wheel.accepted = true;
            }
        }
    }

    // Side edges only have the strip's width to work with, so every slot stacks its own content.
    component VerticalGroupItem: Item {
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

        width: root.width
        height: stack.implicitHeight

        Rectangle {
            anchors.centerIn: parent
            visible: !item.isClock
            width: root.slotSize
            height: parent.height + Theme.spacingXS
            radius: Theme.cornerRadius
            color: groupArea.containsMouse ? Theme.surfaceTextHover : "transparent"
        }

        Column {
            id: stack

            anchors.centerIn: parent
            spacing: 0

            NumericText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: item.isClock && root.clockDisplay !== "date"
                isMonospace: false
                text: root.hourText
                reserveText: "00"
                color: Theme.surfaceText
                font.pixelSize: root.textSize
            }

            NumericText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: item.isClock && root.clockDisplay !== "date"
                isMonospace: false
                text: root.minuteText
                reserveText: "00"
                color: Theme.surfaceTextMedium
                font.pixelSize: root.textSize
            }

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: item.isClock && root.clockDisplay === "both"
                width: Theme.spacingXS
                height: root.textSize

                Rectangle {
                    anchors.centerIn: parent
                    width: Theme.spacingXS
                    height: Theme.spacingXS
                    radius: height / 2
                    color: Theme.primary
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: item.isClock && root.clockDisplay !== "time"
                text: root.monthText
                color: Theme.surfaceTextMedium
                font.pixelSize: root.textSize
            }

            NumericText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: item.isClock && root.clockDisplay !== "time"
                isMonospace: false
                text: root.dayText
                reserveText: "00"
                color: Theme.surfaceTextMedium
                font.pixelSize: root.textSize
            }

            AudioVisualization {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.iconSize + Theme.spacingXS
                height: width
                maxBarHeight: Math.max(3, height - 2)
                idleIconName: "graphic_eq"
                visible: item.isMedia && root.controller.mediaAvailable
            }

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: item.isMedia && !root.controller.mediaAvailable
                name: "search"
                size: root.iconSize
                color: Theme.surfaceTextMedium
            }

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: item.isWeather
                name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
                size: root.statusIconSize
                color: Theme.surfaceTextSecondary
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: item.isWeather
                text: WeatherService.currentTempText()
                color: Theme.surfaceTextSecondary
                font.pixelSize: root.textSize
            }

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: item.isNotifications
                name: "notifications"
                size: root.statusIconSize
                color: Theme.secondary
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: item.isNotifications
                text: root.controller.unreadNotificationCount
                color: Theme.surfaceTextSecondary
                font.pixelSize: root.textSize
            }

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: item.isVolume || item.isBrightness
                name: item.isVolume ? AudioService.sinkVolumeIconName : DisplayService.brightnessIconName(root.brightnessDevice, DisplayService.brightnessLevel)
                size: root.statusIconSize
                color: Theme.surfaceTextSecondary
            }

            NumericText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: (item.isVolume || item.isBrightness) && (item.isVolume ? root.controller.homeVolumeDisplay : root.controller.homeBrightnessDisplay) !== "icon"
                text: item.isVolume ? root.volumePercent : root.brightnessPercent
                reserveText: item.isVolume ? String(AudioService.sinkMaxVolume) : "100"
                color: Theme.surfaceTextSecondary
                font.pixelSize: root.textSize
            }

            BatteryMeter {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: item.usesBattery
                vertical: true
                thickness: root.statusIconSize
                fontSize: root.textSize
                hovered: groupArea.containsMouse
                meterStyle: root.controller.batteryStyle
                levelColors: (root.controller.barConfig?.batteryColorMode ?? "theme") === "level"
            }

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: item.isStatus && !item.usesBattery
                name: "tune"
                size: root.iconSize
                color: Theme.surfaceText
            }
        }

        IslandSlotHoverArea {
            id: groupArea

            anchors.horizontalCenter: parent.horizontalCenter
            y: -item.leadPad
            width: root.width
            height: parent.height + item.leadPad + item.trailPad
            enabled: !item.isClock
            controller: root.controller
            onClicked: root.activateGroup(item.groupId)
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
        visible: !root.isVertical
        height: root.slotSize
        spacing: root.groupSpacing

        Repeater {
            model: root.isVertical ? [] : root.groupIds

            GroupItem {
                required property var modelData
                required property int index
                groupId: String(modelData)
                slotIndex: index
            }
        }
    }

    Column {
        id: compactColumn

        anchors.centerIn: parent
        visible: root.isVertical
        width: root.width
        spacing: root.groupSpacing

        Repeater {
            model: root.isVertical ? root.groupIds : []

            VerticalGroupItem {
                required property var modelData
                required property int index
                groupId: String(modelData)
                slotIndex: index
            }
        }
    }
}
