pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.DankBar.Widgets
import qs.Services
import qs.Widgets

Item {
    id: root

    required property var controller
    required property var systemModel

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
    readonly property var brightnessDevice: BrightnessService.getCurrentDeviceInfo()
    readonly property real brightnessMaximum: BrightnessService.brightnessMaximum(root.brightnessDevice)
    readonly property int brightnessPercent: root.brightnessMaximum > 0 ? Math.round(BrightnessService.brightnessLevel / root.brightnessMaximum * 100) : 0
    readonly property int volumePercent: AudioService.sinkVolumePercent
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
            return BrightnessService.brightnessAvailable && !!root.brightnessDevice;
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
        const next = Math.max(BrightnessService.brightnessMinimum(root.brightnessDevice), Math.min(root.brightnessMaximum, BrightnessService.brightnessLevel + direction * 5));
        BrightnessService.setBrightness(next, root.brightnessDevice.id, true);
    }

    function connectivityIconName(type) {
        if (type === "wifi") {
            if (!NetworkService.wifiAvailable || !NetworkService.networkAvailable)
                return "wifi_off";
            if (NetworkService.wifiToggling)
                return "sync";
            if (!NetworkService.wifiEnabled)
                return "wifi_off";
            return NetworkService.wifiSignalIcon;
        }

        if (!BluetoothService.available)
            return "bluetooth_disabled";
        return BluetoothService.connected ? "bluetooth_connected" : "bluetooth";
    }

    function connectivityIconColor(type) {
        if (type === "wifi") {
            if (!NetworkService.wifiAvailable || !NetworkService.networkAvailable)
                return Theme.surfaceTextMedium;
            if (NetworkService.wifiToggling || NetworkService.isWifiConnecting || NetworkService.wifiConnected)
                return Theme.primary;
            if (!NetworkService.wifiEnabled)
                return Theme.surfaceTextMedium;
            return Theme.surfaceText;
        }

        if (!BluetoothService.available || !BluetoothService.enabled)
            return Theme.surfaceTextMedium;
        return (BluetoothService.connected || BluetoothService.connecting) ? Theme.primary : Theme.surfaceText;
    }

    function connectivityIconOpacity(type) {
        if (type === "wifi")
            return NetworkService.wifiAvailable && NetworkService.networkAvailable && (NetworkService.wifiEnabled || NetworkService.wifiToggling) ? 1 : 0.5;
        return BluetoothService.available && BluetoothService.enabled ? 1 : 0.5;
    }

    function connectivityBusy(type) {
        return type === "wifi" ? (NetworkService.wifiToggling || NetworkService.isWifiConnecting) : BluetoothService.connecting;
    }

    function toggleConnectivity(type) {
        if (type === "wifi") {
            if (!NetworkService.wifiAvailable || !NetworkService.networkAvailable || NetworkService.wifiToggling || NetworkService.isWifiConnecting)
                return;
            NetworkService.toggleWifiRadio();
            return;
        }

        if (!BluetoothService.available || BluetoothService.connecting)
            return;
        BluetoothService.toggleBluetooth();
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

    component IslandClock: ClockContent {
        vertical: root.isVertical
        displayMode: root.clockDisplay
        fontSize: root.textSize
        availableWidth: root.width
        dateColor: Theme.surfaceTextMedium
        separatorColor: Theme.primary
    }

    component ConnectivityIcon: Item {
        id: connectivityIcon

        required property string type

        width: root.iconSize
        height: root.iconSize
        opacity: root.connectivityIconOpacity(connectivityIcon.type)

        DankIcon {
            id: connectivityGlyph

            anchors.centerIn: parent
            name: root.connectivityIconName(connectivityIcon.type)
            size: root.statusIconSize
            color: root.connectivityIconColor(connectivityIcon.type)

            DankBlink {
                target: connectivityGlyph
                running: connectivityIcon.visible && root.connectivityBusy(connectivityIcon.type)
            }
        }
    }

    component GroupHoverArea: IslandSlotHoverArea {
        required property var group

        enabled: !group.isClock
        controller: root.controller
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        function connectivityTypeAt(event) {
            const clickPos = group.vertical ? event.y : event.x;
            const groupMid = group.leadPad + (group.vertical ? group.height : group.width) / 2;
            return clickPos < groupMid ? "wifi" : "bluetooth";
        }

        onClicked: event => {
            if (event.button === Qt.MiddleButton) {
                if (group.usesConnectivity)
                    root.toggleConnectivity(connectivityTypeAt(event));
                if (group.isMedia && root.controller.mediaAvailable && MprisController.activePlayer?.canTogglePlaying)
                    MprisController.activePlayer.togglePlaying();
                if (group.isVolume && AudioService.sink?.audio) {
                    SessionData.suppressOSDTemporarily();
                    AudioService.toggleMute();
                }
                return;
            }
            root.activateGroup(group.groupId);
        }
        onWheel: wheel => {
            if (!group.isVolume && !group.isBrightness)
                return;
            root.adjustSystemLevel(group.groupId, wheel.angleDelta.y || wheel.angleDelta.x);
            wheel.accepted = true;
        }
    }

    component HomeGroup: Item {
        id: group

        required property string groupId
        required property int slotIndex

        readonly property bool vertical: root.isVertical
        readonly property real leadPad: group.slotIndex === 0 ? root.edgePad : root.groupSpacing / 2
        readonly property real trailPad: group.slotIndex === root.groupIds.length - 1 ? root.edgePad : root.groupSpacing / 2
        readonly property bool isClock: group.groupId === "clock"
        readonly property bool isMedia: group.groupId === "media"
        readonly property bool isWeather: group.groupId === "weather"
        readonly property bool isStatus: group.groupId === "status"
        readonly property bool isNotifications: group.groupId === "notifications"
        readonly property bool isVolume: group.groupId === "volume"
        readonly property bool isBrightness: group.groupId === "brightness"
        readonly property bool isSystemLevel: group.isVolume || group.isBrightness
        readonly property bool usesConnectivity: group.isStatus && root.controller.homeStatusContent === "connectivity"
        readonly property bool usesBattery: group.isStatus && !group.usesConnectivity && BatteryService.batteryAvailable
        readonly property bool iconOnly: group.isMedia || (group.isStatus && !group.usesBattery && !group.usesConnectivity)
        readonly property string levelDisplay: group.isVolume ? root.controller.homeVolumeDisplay : root.controller.homeBrightnessDisplay
        readonly property int levelPercent: group.isVolume ? root.volumePercent : root.brightnessPercent
        readonly property string levelReserve: group.isVolume ? String(AudioService.sinkMaxVolume) : "100"

        width: group.vertical ? root.width : (group.iconOnly ? root.iconSize : content.implicitWidth)
        height: group.vertical ? content.implicitHeight : root.slotSize

        Rectangle {
            anchors.centerIn: parent
            width: group.vertical ? root.slotSize : parent.width + Theme.spacingS
            height: group.vertical ? parent.height + Theme.spacingXS : root.slotSize
            radius: group.vertical ? Theme.cornerRadius : Theme.fullRadius(width, height)
            color: groupArea.containsMouse ? Theme.surfaceTextHover : "transparent"
            visible: !group.isClock && (group.vertical || !group.usesBattery)
        }

        Grid {
            id: content

            anchors.centerIn: parent
            columns: group.vertical ? 1 : Math.max(1, content.visibleChildren.length)
            spacing: group.vertical ? 0 : Theme.spacingXXS
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            Loader {
                active: group.isClock
                visible: active
                sourceComponent: IslandClock {}
            }

            AudioVisualization {
                width: root.iconSize + Theme.spacingXS
                height: width
                maxBarHeight: Math.max(3, height - 2)
                idleIconName: "graphic_eq"
                visible: group.isMedia && root.controller.mediaAvailable
            }

            DankIcon {
                visible: group.isMedia && !root.controller.mediaAvailable
                name: "search"
                size: root.iconSize
                color: Theme.surfaceTextMedium
            }

            DankIcon {
                visible: group.isWeather
                name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
                size: root.statusIconSize
                color: Theme.surfaceTextSecondary
            }

            StyledText {
                visible: group.isWeather
                text: WeatherService.currentTempText()
                color: Theme.surfaceTextSecondary
                font.pixelSize: root.textSize
            }

            DankIcon {
                visible: group.isNotifications
                name: "notifications"
                size: root.statusIconSize
                color: Theme.secondary
            }

            StyledText {
                visible: group.isNotifications
                text: root.controller.unreadNotificationCount
                color: Theme.surfaceTextSecondary
                font.pixelSize: root.textSize
            }

            DankIcon {
                visible: group.isSystemLevel && (group.vertical || group.levelDisplay !== "percentage")
                name: group.isVolume ? AudioService.sinkVolumeIconName : BrightnessService.brightnessIconName(root.brightnessDevice, BrightnessService.brightnessLevel)
                size: root.statusIconSize
                color: Theme.surfaceTextSecondary
            }

            NumericText {
                visible: group.isSystemLevel && group.levelDisplay !== "icon"
                text: group.vertical ? group.levelPercent : group.levelPercent + "%"
                reserveText: group.vertical ? group.levelReserve : group.levelReserve + "%"
                color: Theme.surfaceTextSecondary
                font.pixelSize: root.textSize
            }

            BatteryMeter {
                visible: group.usesBattery
                vertical: group.vertical
                thickness: root.statusIconSize
                fontSize: root.textSize
                hovered: groupArea.containsMouse
                meterStyle: root.controller.batteryStyle
                levelColors: (root.controller.barConfig?.batteryColorMode ?? "theme") === "level"
            }

            Grid {
                visible: group.usesConnectivity
                columns: group.vertical ? 1 : 2
                spacing: Theme.spacingXXS

                ConnectivityIcon {
                    type: "wifi"
                }

                ConnectivityIcon {
                    type: "bluetooth"
                }
            }

            DankIcon {
                visible: group.isStatus && !group.usesBattery && !group.usesConnectivity
                name: "tune"
                size: root.iconSize
                color: Theme.surfaceText
            }
        }

        GroupHoverArea {
            id: groupArea

            group: group
            anchors.verticalCenter: group.vertical ? undefined : parent.verticalCenter
            anchors.horizontalCenter: group.vertical ? parent.horizontalCenter : undefined
            x: group.vertical ? 0 : -group.leadPad
            y: group.vertical ? -group.leadPad : 0
            width: group.vertical ? root.width : parent.width + group.leadPad + group.trailPad
            height: group.vertical ? parent.height + group.leadPad + group.trailPad : root.height
        }
    }

    Row {
        id: compactRow

        anchors.centerIn: parent
        visible: !root.isVertical
        onImplicitWidthChanged: root.pushMeasuredLength()
        height: root.slotSize
        spacing: root.groupSpacing

        Repeater {
            model: root.isVertical ? [] : root.groupIds

            HomeGroup {
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
        onImplicitHeightChanged: root.pushMeasuredLength()
        width: root.width
        spacing: root.groupSpacing

        Repeater {
            model: root.isVertical ? root.groupIds : []

            HomeGroup {
                required property var modelData
                required property int index
                groupId: String(modelData)
                slotIndex: index
            }
        }
    }
}
