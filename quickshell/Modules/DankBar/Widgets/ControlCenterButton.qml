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
    property bool showNetworkIcon: SettingsData.controlCenterShowNetworkIcon
    property bool showBluetoothIcon: SettingsData.controlCenterShowBluetoothIcon
    property bool showAudioIcon: SettingsData.controlCenterShowAudioIcon
    property bool showVpnIcon: SettingsData.controlCenterShowVpnIcon
    property bool showBrightnessIcon: SettingsData.controlCenterShowBrightnessIcon
    property bool showMicIcon: SettingsData.controlCenterShowMicIcon
    property bool showBatteryIcon: SettingsData.controlCenterShowBatteryIcon
    property bool showPrinterIcon: SettingsData.controlCenterShowPrinterIcon

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
        return NetworkService.networkStatus !== "disconnected" ? Theme.primary : Theme.outlineButton;
    }

    function getVolumeIconName() {
        if (!AudioService.sink?.audio)
            return "volume_up";
        if (AudioService.sink.audio.muted || AudioService.sink.audio.volume === 0)
            return "volume_off";
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
            return Theme.outlineButton;
        if (AudioService.source.audio.muted || AudioService.source.audio.volume === 0)
            return Theme.outlineButton;
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
        const currentVolume = AudioService.sink.audio.volume * 100;
        const newVolume = delta > 0 ? Math.min(100, currentVolume + 5) : Math.max(0, currentVolume - 5);
        AudioService.sink.audio.muted = false;
        AudioService.sink.audio.volume = newVolume / 100;
        AudioService.playVolumeChangeSoundIfEnabled();
    }

    function handleMicWheel(delta) {
        if (!AudioService.source?.audio)
            return;
        const currentVolume = AudioService.source.audio.volume * 100;
        const newVolume = delta > 0 ? Math.min(100, currentVolume + 5) : Math.max(0, currentVolume - 5);
        AudioService.source.audio.muted = false;
        AudioService.source.audio.volume = newVolume / 100;
    }

    function handleBrightnessWheel(delta) {
        const deviceName = getPinnedBrightnessDevice();
        if (!deviceName) {
            return;
        }
        const currentBrightness = DisplayService.getDeviceBrightness(deviceName);
        const newBrightness = delta > 0 ? Math.min(100, currentBrightness + 5) : Math.max(1, currentBrightness - 5);
        DisplayService.setBrightness(newBrightness, deviceName);
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
        return !root.showNetworkIcon && !root.showBluetoothIcon && !root.showAudioIcon && !root.showVpnIcon && !root.showBrightnessIcon && !root.showMicIcon && !root.showBatteryIcon && !root.showPrinterIcon;
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? (root.widgetThickness - root.horizontalPadding * 2) : controlIndicators.implicitWidth
            implicitHeight: root.isVerticalOrientation ? controlColumn.implicitHeight : (root.widgetThickness - root.horizontalPadding * 2)

            Column {
                id: controlColumn
                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: root.getNetworkIconName()
                    size: Theme.barIconSize(root.barThickness)
                    color: root.getNetworkIconColor()
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showNetworkIcon && NetworkService.networkAvailable
                }

                DankIcon {
                    name: "vpn_lock"
                    size: Theme.barIconSize(root.barThickness)
                    color: NetworkService.vpnConnected ? Theme.primary : Theme.outlineButton
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showVpnIcon && NetworkService.vpnAvailable && NetworkService.vpnConnected
                }

                DankIcon {
                    name: "bluetooth"
                    size: Theme.barIconSize(root.barThickness)
                    color: BluetoothService.connected ? Theme.primary : Theme.outlineButton
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showBluetoothIcon && BluetoothService.available && BluetoothService.enabled
                }

                Rectangle {
                    width: audioIconV.implicitWidth + 4
                    height: audioIconV.implicitHeight + 4
                    color: "transparent"
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showAudioIcon

                    DankIcon {
                        id: audioIconV
                        name: root.getVolumeIconName()
                        size: Theme.barIconSize(root.barThickness)
                        color: Theme.widgetIconColor
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: function (wheelEvent) {
                            root.handleVolumeWheel(wheelEvent.angleDelta.y);
                            wheelEvent.accepted = true;
                        }
                    }
                }

                Rectangle {
                    width: micIconV.implicitWidth + 4
                    height: micIconV.implicitHeight + 4
                    color: "transparent"
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showMicIcon

                    DankIcon {
                        id: micIconV
                        name: root.getMicIconName()
                        size: Theme.barIconSize(root.barThickness)
                        color: root.getMicIconColor()
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: function (wheelEvent) {
                            root.handleMicWheel(wheelEvent.angleDelta.y);
                            wheelEvent.accepted = true;
                        }
                    }
                }

                Rectangle {
                    width: brightnessIconV.implicitWidth + 4
                    height: brightnessIconV.implicitHeight + 4
                    color: "transparent"
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showBrightnessIcon && DisplayService.brightnessAvailable && root.hasPinnedBrightnessDevice()

                    DankIcon {
                        id: brightnessIconV
                        name: root.getBrightnessIconName()
                        size: Theme.barIconSize(root.barThickness)
                        color: Theme.widgetIconColor
                        anchors.centerIn: parent
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

                DankIcon {
                    name: Theme.getBatteryIcon(BatteryService.batteryLevel, BatteryService.isCharging, BatteryService.batteryAvailable)
                    size: Theme.barIconSize(root.barThickness)
                    color: root.getBatteryIconColor()
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showBatteryIcon && BatteryService.batteryAvailable
                }

                DankIcon {
                    name: "print"
                    size: Theme.barIconSize(root.barThickness)
                    color: Theme.primary
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showPrinterIcon && CupsService.cupsAvailable && root.hasPrintJobs()
                }

                DankIcon {
                    name: "settings"
                    size: Theme.barIconSize(root.barThickness)
                    color: root.isActive ? Theme.primary : Theme.widgetIconColor
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.hasNoVisibleIcons()
                }
            }

            Row {
                id: controlIndicators
                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    id: networkIcon
                    name: root.getNetworkIconName()
                    size: Theme.barIconSize(root.barThickness)
                    color: root.getNetworkIconColor()
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showNetworkIcon && NetworkService.networkAvailable
                }

                DankIcon {
                    id: vpnIcon
                    name: "vpn_lock"
                    size: Theme.barIconSize(root.barThickness)
                    color: NetworkService.vpnConnected ? Theme.primary : Theme.outlineButton
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showVpnIcon && NetworkService.vpnAvailable && NetworkService.vpnConnected
                }

                DankIcon {
                    id: bluetoothIcon
                    name: "bluetooth"
                    size: Theme.barIconSize(root.barThickness)
                    color: BluetoothService.connected ? Theme.primary : Theme.outlineButton
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showBluetoothIcon && BluetoothService.available && BluetoothService.enabled
                }

                Rectangle {
                    width: audioIcon.implicitWidth + 4
                    height: audioIcon.implicitHeight + 4
                    color: "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showAudioIcon

                    DankIcon {
                        id: audioIcon
                        name: root.getVolumeIconName()
                        size: Theme.barIconSize(root.barThickness)
                        color: Theme.widgetIconColor
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: audioWheelArea
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: function (wheelEvent) {
                            root.handleVolumeWheel(wheelEvent.angleDelta.y);
                            wheelEvent.accepted = true;
                        }
                    }
                }

                Rectangle {
                    width: micIcon.implicitWidth + 4
                    height: micIcon.implicitHeight + 4
                    color: "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showMicIcon

                    DankIcon {
                        id: micIcon
                        name: root.getMicIconName()
                        size: Theme.barIconSize(root.barThickness)
                        color: root.getMicIconColor()
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: micWheelArea
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: function (wheelEvent) {
                            root.handleMicWheel(wheelEvent.angleDelta.y);
                            wheelEvent.accepted = true;
                        }
                    }
                }

                Rectangle {
                    width: brightnessIcon.implicitWidth + 4
                    height: brightnessIcon.implicitHeight + 4
                    color: "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showBrightnessIcon && DisplayService.brightnessAvailable && root.hasPinnedBrightnessDevice()

                    DankIcon {
                        id: brightnessIcon
                        name: root.getBrightnessIconName()
                        size: Theme.barIconSize(root.barThickness)
                        color: Theme.widgetIconColor
                        anchors.centerIn: parent
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
                    size: Theme.barIconSize(root.barThickness)
                    color: root.getBatteryIconColor()
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showBatteryIcon && BatteryService.batteryAvailable
                }

                DankIcon {
                    id: printerIcon
                    name: "print"
                    size: Theme.barIconSize(root.barThickness)
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showPrinterIcon && CupsService.cupsAvailable && root.hasPrintJobs()
                }

                DankIcon {
                    name: "settings"
                    size: Theme.barIconSize(root.barThickness)
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
