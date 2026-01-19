import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property bool isActive: false
    property var popoutTarget: null
    property var widgetData: null
    property string screenName: ""
    property string screenModel: ""
    property bool showNetworkIcon: widgetData?.showNetworkIcon !== undefined ? widgetData.showNetworkIcon : SettingsData.controlCenterShowNetworkIcon
    property bool showBluetoothIcon: widgetData?.showBluetoothIcon !== undefined ? widgetData.showBluetoothIcon : SettingsData.controlCenterShowBluetoothIcon
    property bool showAudioIcon: widgetData?.showAudioIcon !== undefined ? widgetData.showAudioIcon : SettingsData.controlCenterShowAudioIcon
    property bool showAudioPercent: widgetData?.showAudioPercent !== undefined ? widgetData.showAudioPercent : SettingsData.controlCenterShowAudioPercent
    property bool showVpnIcon: widgetData?.showVpnIcon !== undefined ? widgetData.showVpnIcon : SettingsData.controlCenterShowVpnIcon
    property bool showBrightnessIcon: widgetData?.showBrightnessIcon !== undefined ? widgetData.showBrightnessIcon : SettingsData.controlCenterShowBrightnessIcon
    property bool showBrightnessPercent: widgetData?.showBrightnessPercent !== undefined ? widgetData.showBrightnessPercent : SettingsData.controlCenterShowBrightnessPercent
    property bool showMicIcon: widgetData?.showMicIcon !== undefined ? widgetData.showMicIcon : SettingsData.controlCenterShowMicIcon
    property bool showMicPercent: widgetData?.showMicPercent !== undefined ? widgetData.showMicPercent : SettingsData.controlCenterShowMicPercent
    property bool showBatteryIcon: widgetData?.showBatteryIcon !== undefined ? widgetData.showBatteryIcon : SettingsData.controlCenterShowBatteryIcon
    property bool showPrinterIcon: widgetData?.showPrinterIcon !== undefined ? widgetData.showPrinterIcon : SettingsData.controlCenterShowPrinterIcon
    property bool showScreenSharingIcon: widgetData?.showScreenSharingIcon !== undefined ? widgetData.showScreenSharingIcon : SettingsData.controlCenterShowScreenSharingIcon
    property real touchpadThreshold: 100
    property real micAccumulator: 0
    property real volumeAccumulator: 0
    property real brightnessAccumulator: 0
    readonly property real vIconSize: Theme.barIconSize(root.barThickness, -4, root.barConfig?.noBackground)

    Loader {
        active: root.showPrinterIcon
        sourceComponent: Component {
            Ref {
                service: CupsService
            }
        }
    }

    function getNetworkIconName() {
        if (NetworkService.wifiToggling)
            return "sync";
        switch (NetworkService.networkStatus) {
        case "ethernet":
            return "lan";
        case "vpn":
            return NetworkService.ethernetConnected ? "lan" : NetworkService.wifiSignalIcon;
        default:
            return NetworkService.wifiSignalIcon;
        }
    }

    function getNetworkIconColor() {
        if (NetworkService.wifiToggling)
            return Theme.primary;
        return NetworkService.networkStatus !== "disconnected" ? Theme.primary : Theme.surfaceText;
    }

    function getVolumeIconName() {
        if (!AudioService.sink?.audio)
            return "volume_up";
        if (AudioService.sink.audio.muted)
            return "volume_off";
        if (AudioService.sink.audio.volume === 0)
            return "volume_mute";
        if (AudioService.sink.audio.volume * 100 < 33)
            return "volume_down";
        return "volume_up";
    }

    function getMicIconName() {
        if (!AudioService.source?.audio)
            return "mic";
        if (AudioService.source.audio.muted || AudioService.source.audio.volume === 0)
            return "mic_off";
        return "mic";
    }

    function getMicIconColor() {
        if (!AudioService.source?.audio)
            return Theme.surfaceText;
        if (AudioService.source.audio.muted || AudioService.source.audio.volume === 0)
            return Theme.surfaceText;
        return Theme.widgetIconColor;
    }

    function getBrightnessIconName() {
        const deviceName = getPinnedBrightnessDevice();
        if (!deviceName)
            return "brightness_medium";
        const level = DisplayService.getDeviceBrightness(deviceName);
        if (level <= 33)
            return "brightness_low";
        if (level <= 66)
            return "brightness_medium";
        return "brightness_high";
    }

    function getScreenPinKey() {
        if (!root.screenName)
            return "";
        const screen = Quickshell.screens.find(s => s.name === root.screenName);
        if (screen) {
            return SettingsData.getScreenDisplayName(screen);
        }
        if (SettingsData.displayNameMode === "model" && root.screenModel && root.screenModel.length > 0) {
            return root.screenModel;
        }
        return root.screenName;
    }

    function getPinnedBrightnessDevice() {
        const pinKey = getScreenPinKey();
        if (!pinKey)
            return "";
        const pins = SettingsData.brightnessDevicePins || {};
        return pins[pinKey] || "";
    }

    function hasPinnedBrightnessDevice() {
        return getPinnedBrightnessDevice().length > 0;
    }

    function handleVolumeWheel(delta) {
        if (!AudioService.sink?.audio)
            return;

        var step = 5;
        const isMouseWheel = Math.abs(delta) >= 120 && (Math.abs(delta) % 120) === 0;
        if (!isMouseWheel) {
            step = 1;
            volumeAccumulator += delta;
            if (Math.abs(volumeAccumulator) < touchpadThreshold)
                return;

            delta = volumeAccumulator;
            volumeAccumulator = 0;
        }

        const currentVolume = AudioService.sink.audio.volume * 100;
        const newVolume = delta > 0 ? Math.min(100, currentVolume + step) : Math.max(0, currentVolume - step);
        AudioService.sink.audio.muted = false;
        AudioService.sink.audio.volume = newVolume / 100;
        AudioService.playVolumeChangeSoundIfEnabled();
    }

    function handleMicWheel(delta) {
        if (!AudioService.source?.audio)
            return;

        var step = 5;
        const isMouseWheel = Math.abs(delta) >= 120 && (Math.abs(delta) % 120) === 0;
        if (!isMouseWheel) {
            step = 1;
            micAccumulator += delta;
            if (Math.abs(micAccumulator) < touchpadThreshold)
                return;

            delta = micAccumulator;
            micAccumulator = 0;
        }

        const currentVolume = AudioService.source.audio.volume * 100;
        const newVolume = delta > 0 ? Math.min(100, currentVolume + step) : Math.max(0, currentVolume - step);
        AudioService.source.audio.muted = false;
        AudioService.source.audio.volume = newVolume / 100;
    }

    function handleBrightnessWheel(delta) {
        const deviceName = getPinnedBrightnessDevice();
        if (!deviceName) {
            return;
        }

        var step = 5;
        const isMouseWheel = Math.abs(delta) >= 120 && (Math.abs(delta) % 120) === 0;
        if (!isMouseWheel) {
            step = 1;
            brightnessAccumulator += delta;
            if (Math.abs(brightnessAccumulator) < touchpadThreshold)
                return;

            delta = brightnessAccumulator;
            brightnessAccumulator = 0;
        }

        const currentBrightness = DisplayService.getDeviceBrightness(deviceName);
        const newBrightness = delta > 0 ? Math.min(100, currentBrightness + step) : Math.max(1, currentBrightness - step);
        DisplayService.setBrightness(newBrightness, deviceName);
    }

    function getBrightness() {
        const deviceName = getPinnedBrightnessDevice();
        if (!deviceName) {
            return;
        }
        return DisplayService.getDeviceBrightness(deviceName) / 100;
    }

    function getBatteryIconColor() {
        if (!BatteryService.batteryAvailable)
            return Theme.widgetIconColor;
        if (BatteryService.isLowBattery && !BatteryService.isCharging)
            return Theme.error;
        if (BatteryService.isCharging || BatteryService.isPluggedIn)
            return Theme.primary;
        return Theme.widgetIconColor;
    }

    function hasPrintJobs() {
        return CupsService.getTotalJobsNum() > 0;
    }

    function hasNoVisibleIcons() {
        if (root.showScreenSharingIcon && NiriService.hasCasts)
            return false;
        if (root.showNetworkIcon && NetworkService.networkAvailable)
            return false;
        if (root.showVpnIcon && NetworkService.vpnAvailable && NetworkService.vpnConnected)
            return false;
        if (root.showBluetoothIcon && BluetoothService.available && BluetoothService.enabled)
            return false;
        if (root.showAudioIcon)
            return false;
        if (root.showMicIcon)
            return false;
        if (root.showBrightnessIcon && DisplayService.brightnessAvailable && root.hasPinnedBrightnessDevice())
            return false;
        if (root.showBatteryIcon && BatteryService.batteryAvailable)
            return false;
        if (root.showPrinterIcon && CupsService.cupsAvailable && root.hasPrintJobs())
            return false;
        return true;
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? (root.widgetThickness - root.horizontalPadding * 2) : controlIndicators.implicitWidth
            implicitHeight: root.isVerticalOrientation ? controlColumn.implicitHeight : (root.widgetThickness - root.horizontalPadding * 2)

            Column {
                id: controlColumn
                visible: root.isVerticalOrientation
                width: root.vIconSize
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingXS

                Item {
                    width: root.vIconSize
                    height: root.vIconSize
                    visible: root.showScreenSharingIcon && NiriService.hasCasts

                    DankIcon {
                        name: "screen_record"
                        size: root.vIconSize
                        color: NiriService.hasActiveCast ? Theme.primary : Theme.surfaceText
                        anchors.centerIn: parent
                    }
                }

                Item {
                    width: root.vIconSize
                    height: root.vIconSize
                    visible: root.showNetworkIcon && NetworkService.networkAvailable

                    DankIcon {
                        name: root.getNetworkIconName()
                        size: root.vIconSize
                        color: root.getNetworkIconColor()
                        anchors.centerIn: parent
                    }
                }

                Item {
                    width: root.vIconSize
                    height: root.vIconSize
                    visible: root.showVpnIcon && NetworkService.vpnAvailable && NetworkService.vpnConnected

                    DankIcon {
                        name: "vpn_lock"
                        size: root.vIconSize
                        color: NetworkService.vpnConnected ? Theme.primary : Theme.surfaceText
                        anchors.centerIn: parent
                    }
                }

                Item {
                    width: root.vIconSize
                    height: root.vIconSize
                    visible: root.showBluetoothIcon && BluetoothService.available && BluetoothService.enabled

                    DankIcon {
                        name: "bluetooth"
                        size: root.vIconSize
                        color: BluetoothService.connected ? Theme.primary : Theme.surfaceText
                        anchors.centerIn: parent
                    }
                }

                Item {
                    width: root.vIconSize
                    height: root.vIconSize + (root.showAudioPercent ? audioPercentV.implicitHeight + 2 : 0)
                    visible: root.showAudioIcon

                    DankIcon {
                        id: audioIconV
                        name: root.getVolumeIconName()
                        size: root.vIconSize
                        color: Theme.widgetIconColor
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                    }

                    StyledText {
                        id: audioPercentV
                        visible: root.showAudioPercent
                        text: Math.round((AudioService.sink?.audio?.volume ?? 0) * 100) + "%"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.widgetTextColor
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: audioIconV.bottom
                        anchors.topMargin: 2
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        onWheel: function (wheelEvent) {
                            root.handleVolumeWheel(wheelEvent.angleDelta.y);
                            wheelEvent.accepted = true;
                        }
                        onClicked: {
                            AudioService.toggleMute();
                        }
                    }
                }

                Item {
                    width: root.vIconSize
                    height: root.vIconSize + (root.showMicPercent ? micPercentV.implicitHeight + 2 : 0)
                    visible: root.showMicIcon

                    DankIcon {
                        id: micIconV
                        name: root.getMicIconName()
                        size: root.vIconSize
                        color: root.getMicIconColor()
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                    }

                    StyledText {
                        id: micPercentV
                        visible: root.showMicPercent
                        text: Math.round((AudioService.source?.audio?.volume ?? 0) * 100) + "%"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.widgetTextColor
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: micIconV.bottom
                        anchors.topMargin: 2
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        onWheel: function (wheelEvent) {
                            root.handleMicWheel(wheelEvent.angleDelta.y);
                            wheelEvent.accepted = true;
                        }
                        onClicked: {
                            AudioService.toggleMicMute();
                        }
                    }
                }

                Item {
                    width: root.vIconSize
                    height: root.vIconSize + (root.showBrightnessPercent ? brightnessPercentV.implicitHeight + 2 : 0)
                    visible: root.showBrightnessIcon && DisplayService.brightnessAvailable && root.hasPinnedBrightnessDevice()

                    DankIcon {
                        id: brightnessIconV
                        name: root.getBrightnessIconName()
                        size: root.vIconSize
                        color: Theme.widgetIconColor
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                    }

                    StyledText {
                        id: brightnessPercentV
                        visible: root.showBrightnessPercent
                        text: Math.round(getBrightness() * 100) + "%"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.widgetTextColor
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: brightnessIconV.bottom
                        anchors.topMargin: 2
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: function (wheelEvent) {
                            root.handleBrightnessWheel(wheelEvent.angleDelta.y);
                            wheelEvent.accepted = true;
                        }
                    }
                }

                Item {
                    width: root.vIconSize
                    height: root.vIconSize
                    visible: root.showBatteryIcon && BatteryService.batteryAvailable

                    DankIcon {
                        name: Theme.getBatteryIcon(BatteryService.batteryLevel, BatteryService.isCharging, BatteryService.batteryAvailable)
                        size: root.vIconSize
                        color: root.getBatteryIconColor()
                        anchors.centerIn: parent
                    }
                }

                Item {
                    width: root.vIconSize
                    height: root.vIconSize
                    visible: root.showPrinterIcon && CupsService.cupsAvailable && root.hasPrintJobs()

                    DankIcon {
                        name: "print"
                        size: root.vIconSize
                        color: Theme.primary
                        anchors.centerIn: parent
                    }
                }

                Item {
                    width: root.vIconSize
                    height: root.vIconSize
                    visible: root.hasNoVisibleIcons()

                    DankIcon {
                        name: "settings"
                        size: root.vIconSize
                        color: root.isActive ? Theme.primary : Theme.widgetIconColor
                        anchors.centerIn: parent
                    }
                }
            }

            Row {
                id: controlIndicators
                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: "screen_record"
                    size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.noBackground)
                    color: NiriService.hasActiveCast ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showScreenSharingIcon && NiriService.hasCasts
                }

                DankIcon {
                    id: networkIcon
                    name: root.getNetworkIconName()
                    size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.noBackground)
                    color: root.getNetworkIconColor()
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showNetworkIcon && NetworkService.networkAvailable
                }

                DankIcon {
                    id: vpnIcon
                    name: "vpn_lock"
                    size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.noBackground)
                    color: NetworkService.vpnConnected ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showVpnIcon && NetworkService.vpnAvailable && NetworkService.vpnConnected
                }

                DankIcon {
                    id: bluetoothIcon
                    name: "bluetooth"
                    size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.noBackground)
                    color: BluetoothService.connected ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showBluetoothIcon && BluetoothService.available && BluetoothService.enabled
                }

                Rectangle {
                    width: audioIcon.implicitWidth + (root.showAudioPercent ? audioPercent.implicitWidth : 0) + 4
                    height: audioIcon.implicitHeight + 4
                    color: "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showAudioIcon

                    DankIcon {
                        id: audioIcon
                        name: root.getVolumeIconName()
                        size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.noBackground)
                        color: Theme.widgetIconColor
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                    }

                    StyledText {
                        id: audioPercent
                        visible: root.showAudioPercent
                        text: Math.round((AudioService.sink?.audio?.volume ?? 0) * 100) + "%"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.widgetTextColor
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: audioIcon.right
                        anchors.leftMargin: 2
                    }

                    MouseArea {
                        id: audioWheelArea
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        onWheel: function (wheelEvent) {
                            root.handleVolumeWheel(wheelEvent.angleDelta.y);
                            wheelEvent.accepted = true;
                        }
                        onClicked: {
                            AudioService.toggleMute();
                        }
                    }
                }

                Rectangle {
                    width: micIcon.implicitWidth + (root.showMicPercent ? micPercent.implicitWidth : 0) + 4
                    height: micIcon.implicitHeight + 4
                    color: "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showMicIcon

                    DankIcon {
                        id: micIcon
                        name: root.getMicIconName()
                        size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.noBackground)
                        color: root.getMicIconColor()
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                    }

                    StyledText {
                        id: micPercent
                        visible: root.showMicPercent
                        text: Math.round((AudioService.source?.audio?.volume ?? 0) * 100) + "%"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.widgetTextColor
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: micIcon.right
                        anchors.leftMargin: 2
                    }

                    MouseArea {
                        id: micWheelArea
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        onWheel: function (wheelEvent) {
                            root.handleMicWheel(wheelEvent.angleDelta.y);
                            wheelEvent.accepted = true;
                        }
                        onClicked: {
                            AudioService.toggleMicMute();
                        }
                    }
                }

                Rectangle {
                    width: brightnessIcon.implicitWidth + (root.showBrightnessPercent ? brightnessPercent.implicitWidth : 0) + 4
                    height: brightnessIcon.implicitHeight + 4
                    color: "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showBrightnessIcon && DisplayService.brightnessAvailable && root.hasPinnedBrightnessDevice()

                    DankIcon {
                        id: brightnessIcon
                        name: root.getBrightnessIconName()
                        size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.noBackground)
                        color: Theme.widgetIconColor
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                    }

                    StyledText {
                        id: brightnessPercent
                        visible: root.showBrightnessPercent
                        text: Math.round(getBrightness() * 100) + "%"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.widgetTextColor
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: brightnessIcon.right
                        anchors.leftMargin: 2
                    }

                    MouseArea {
                        id: brightnessWheelArea
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: function (wheelEvent) {
                            root.handleBrightnessWheel(wheelEvent.angleDelta.y);
                            wheelEvent.accepted = true;
                        }
                    }
                }

                DankIcon {
                    id: batteryIcon
                    name: Theme.getBatteryIcon(BatteryService.batteryLevel, BatteryService.isCharging, BatteryService.batteryAvailable)
                    size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.noBackground)
                    color: root.getBatteryIconColor()
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showBatteryIcon && BatteryService.batteryAvailable
                }

                DankIcon {
                    id: printerIcon
                    name: "print"
                    size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.noBackground)
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showPrinterIcon && CupsService.cupsAvailable && root.hasPrintJobs()
                }

                DankIcon {
                    name: "settings"
                    size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.noBackground)
                    color: root.isActive ? Theme.primary : Theme.widgetIconColor
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.hasNoVisibleIcons()
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.NoButton
            }
        }
    }
}
