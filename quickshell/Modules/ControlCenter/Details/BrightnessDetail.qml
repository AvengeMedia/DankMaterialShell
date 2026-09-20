pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Modules.ControlCenter
import qs.Modules.ControlCenter.Widgets
import qs.Services
import qs.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string initialDeviceName: ""
    property string instanceId: ""
    property string screenName: ""
    property string screenModel: ""
    property string currentDeviceName: ""

    readonly property string title: I18n.tr("Brightness")
    readonly property var devices: BrightnessService.devices || []
    readonly property bool multipleDevices: devices.length > 1
    readonly property bool showPins: screenName.length > 0 && multipleDevices

    signal deviceNameChanged(string newDeviceName)

    function getScreenPinKey() {
        if (!screenName)
            return "";
        const screen = Quickshell.screens.find(s => s.name === screenName);
        if (screen)
            return SettingsData.getScreenDisplayName(screen);
        if (SettingsData.displayNameMode === "model" && screenModel)
            return screenModel;
        return screenName;
    }

    function resolveCurrentDevice() {
        if (!BrightnessService.brightnessAvailable || devices.length === 0)
            return "";
        const pinKey = getScreenPinKey();
        const pinnedDevice = pinKey ? (CacheData.brightnessDevicePins || {})[pinKey] : "";
        if (pinnedDevice && devices.find(d => d.name === pinnedDevice))
            return pinnedDevice;
        if (instanceId) {
            const widget = (SettingsData.controlCenterWidgets || []).find(w => w.id === "brightnessSlider" && w.instanceId === instanceId);
            if (widget?.deviceName && devices.find(d => d.name === widget.deviceName))
                return widget.deviceName;
        }
        if (BrightnessService.currentDevice && devices.find(d => d.name === BrightnessService.currentDevice))
            return BrightnessService.currentDevice;
        if (initialDeviceName && devices.find(d => d.name === initialDeviceName))
            return initialDeviceName;
        const backlight = devices.find(d => d.class === "backlight");
        if (backlight)
            return backlight.name;
        const ddc = devices.find(d => d.class === "ddc");
        if (ddc)
            return ddc.name;
        return devices[0].name;
    }

    function selectDevice(deviceName) {
        if (!deviceName || deviceName === currentDeviceName)
            return;
        const pinKey = getScreenPinKey();
        if (pinKey) {
            const pins = CacheData.brightnessDevicePins || {};
            if (pins[pinKey] && pins[pinKey] !== deviceName) {
                const next = JSON.parse(JSON.stringify(pins));
                delete next[pinKey];
                CacheData.set("brightnessDevicePins", next);
            }
        }
        currentDeviceName = deviceName;
        BrightnessService.setCurrentDevice(deviceName, true);
        deviceNameChanged(deviceName);
    }

    function isDevicePinnedToScreen(deviceName) {
        const pinKey = getScreenPinKey();
        if (!pinKey || !deviceName)
            return false;
        return (CacheData.brightnessDevicePins || {})[pinKey] === deviceName;
    }

    function togglePinForDevice(deviceName) {
        const pinKey = getScreenPinKey();
        if (!pinKey || !deviceName)
            return;
        const pins = JSON.parse(JSON.stringify(CacheData.brightnessDevicePins || {}));
        if (pins[pinKey] === deviceName)
            delete pins[pinKey];
        else
            pins[pinKey] = deviceName;
        CacheData.set("brightnessDevicePins", pins);
    }

    function deviceIcon(device, brightness) {
        const deviceClass = device.class || "";
        if (deviceClass === "backlight" || deviceClass === "ddc") {
            if (brightness <= CcMetrics.brightnessLowMax)
                return "brightness_low";
            return brightness <= CcMetrics.brightnessMediumMax ? "brightness_medium" : "brightness_high";
        }
        return (device.name || "").includes("kbd") ? "keyboard" : "lightbulb";
    }

    function deviceClassLabel(device) {
        switch (device.class || "") {
        case "backlight":
            return I18n.tr("Backlight device");
        case "ddc":
            return I18n.tr("DDC/CI monitor");
        case "leds":
            return I18n.tr("LED device");
        default:
            return device.class || "";
        }
    }

    Component.onCompleted: currentDeviceName = resolveCurrentDevice()

    DankFlickable {
        anchors.fill: parent
        contentHeight: column.height
        clip: true

        Column {
            id: column
            width: parent.width
            spacing: CcMetrics.detailContentGap

            CcEmptyState {
                visible: !BrightnessService.brightnessAvailable || root.devices.length === 0
                iconName: BrightnessService.brightnessAvailable ? "brightness_6" : "error"
                iconColor: BrightnessService.brightnessAvailable ? Theme.primary : Theme.error
                title: BrightnessService.brightnessAvailable ? I18n.tr("No brightness devices available") : I18n.tr("Brightness control not available")
            }

            CcSectionLabel {
                visible: root.showPins
                text: root.getScreenPinKey() || I18n.tr("Unknown Monitor")

                actions: CcPinChip {
                    readonly property bool pinnedHere: {
                        CacheData.brightnessDevicePins;
                        return root.isDevicePinnedToScreen(root.currentDeviceName);
                    }

                    iconOnly: false
                    pinned: pinnedHere
                    enabled: root.currentDeviceName.length > 0
                    onToggled: root.togglePinForDevice(root.currentDeviceName)
                }
            }

            CcGroup {
                visible: root.devices.length > 0

                Repeater {
                    model: root.devices

                    CcListRow {
                        id: deviceRow

                        required property var modelData

                        readonly property string deviceName: modelData.name || ""
                        readonly property real deviceBrightness: {
                            BrightnessService.brightnessVersion;
                            return BrightnessService.getDeviceBrightness(deviceName);
                        }
                        readonly property bool pinnedHere: {
                            CacheData.brightnessDevicePins;
                            return root.isDevicePinnedToScreen(deviceName);
                        }
                        readonly property bool exponential: SessionData.getBrightnessExponential(deviceName)
                        readonly property real exponent: SessionData.getBrightnessExponent(deviceName)

                        iconName: root.deviceIcon(modelData, deviceBrightness)
                        active: deviceName === root.currentDeviceName
                        showActiveCheck: true
                        title: BrightnessService.deviceTitle(modelData)
                        subtitle: deviceName + " • " + root.deviceClassLabel(modelData)
                        trailingBadge: Math.round(deviceBrightness) + "%"
                        clickable: true
                        onClicked: root.selectDevice(deviceName)

                        CcPinChip {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.showPins
                            pinned: deviceRow.pinnedHere
                            onToggled: root.togglePinForDevice(deviceRow.deviceName)
                        }

                        body: Row {
                            width: parent.width
                            spacing: Theme.spacingM
                            visible: deviceRow.active

                            DankToggle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - stepper.width - parent.spacing
                                text: I18n.tr("Exponential", "adjective, toggle for an exponential brightness curve per device")
                                checked: deviceRow.exponential
                                onToggled: checked => SessionData.setBrightnessExponential(deviceRow.deviceName, checked)
                            }

                            DankNumberStepper {
                                id: stepper
                                anchors.verticalCenter: parent.verticalCenter
                                visible: deviceRow.exponential
                                text: deviceRow.exponent.toFixed(1)
                                decrementEnabled: deviceRow.exponent > CcMetrics.brightnessExponentMin
                                incrementEnabled: deviceRow.exponent < CcMetrics.brightnessExponentMax
                                onDecrement: () => SessionData.setBrightnessExponent(deviceRow.deviceName, Math.max(CcMetrics.brightnessExponentMin, Math.round((deviceRow.exponent - CcMetrics.brightnessExponentStep) * 10) / 10))
                                onIncrement: () => SessionData.setBrightnessExponent(deviceRow.deviceName, Math.min(CcMetrics.brightnessExponentMax, Math.round((deviceRow.exponent + CcMetrics.brightnessExponentStep) * 10) / 10))
                            }
                        }
                    }
                }
            }
        }
    }
}
