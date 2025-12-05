import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Row {
    id: root

    property string deviceName: ""
    property string instanceId: ""
    property string screenName: ""
    property var parentScreen: null

    signal iconClicked

    height: 40
    spacing: 0

    DankTooltipV2 {
        id: sharedTooltip
    }

    property string targetDeviceName: {
        if (!DisplayService.brightnessAvailable || !DisplayService.devices || DisplayService.devices.length === 0) {
            return "";
        }

        if (screenName && screenName.length > 0) {
            const pins = SettingsData.brightnessDevicePins || {};
            const pinnedDevice = pins[screenName];
            if (pinnedDevice && pinnedDevice.length > 0) {
                const found = DisplayService.devices.find(dev => dev.name === pinnedDevice);
                if (found) {
                    return found.name;
                }
            }
        }

        if (deviceName && deviceName.length > 0) {
            const found = DisplayService.devices.find(dev => dev.name === deviceName);
            if (found) {
                return found.name;
            }
        }

        const currentDeviceName = DisplayService.currentDevice;
        if (currentDeviceName) {
            const found = DisplayService.devices.find(dev => dev.name === currentDeviceName);
            if (found) {
                return found.name;
            }
        }

        const backlight = DisplayService.devices.find(d => d.class === "backlight");
        if (backlight) {
            return backlight.name;
        }

        const ddc = DisplayService.devices.find(d => d.class === "ddc");
        if (ddc) {
            return ddc.name;
        }

        return DisplayService.devices.length > 0 ? DisplayService.devices[0].name : "";
    }

    property var targetDevice: {
        if (!targetDeviceName || !DisplayService.devices) {
            return null;
        }

        return DisplayService.devices.find(dev => dev.name === targetDeviceName) || null;
    }

    property real targetBrightness: {
        DisplayService.brightnessVersion;
        if (!targetDeviceName) {
            return 0;
        }

        return DisplayService.getDeviceBrightness(targetDeviceName);
    }

    Rectangle {
        width: Theme.iconSize + Theme.spacingS * 2
        height: Theme.iconSize + Theme.spacingS * 2
        anchors.verticalCenter: parent.verticalCenter
        radius: (Theme.iconSize + Theme.spacingS * 2) / 2
        color: iconArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Theme.withAlpha(Theme.primary, 0)

        MouseArea {
            id: iconArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: DisplayService.devices && DisplayService.devices.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor

            onClicked: {
                if (DisplayService.devices && DisplayService.devices.length > 1) {
                    root.iconClicked();
                }
            }

            onEntered: {
                const tooltipText = targetDevice ? "bl device: " + targetDevice.name : "Backlight Control";
                sharedTooltip.show(tooltipText, iconArea, 0, 0, "bottom");
            }

            onExited: {
                sharedTooltip.hide();
            }

            DankIcon {
                anchors.centerIn: parent
                name: {
                    if (!DisplayService.brightnessAvailable || !targetDevice) {
                        return "brightness_low";
                    }

                    if (targetDevice.class === "backlight" || targetDevice.class === "ddc") {
                        const brightness = targetBrightness;
                        if (brightness <= 33)
                            return "brightness_low";
                        if (brightness <= 66)
                            return "brightness_medium";
                        return "brightness_high";
                    } else if (targetDevice.name.includes("kbd")) {
                        return "keyboard";
                    } else {
                        return "lightbulb";
                    }
                }
                size: Theme.iconSize
                color: DisplayService.brightnessAvailable && targetDevice && targetBrightness > 0 ? Theme.primary : Theme.surfaceText
            }
        }
    }

    DankSlider {
        id: brightnessSlider

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - (Theme.iconSize + Theme.spacingS * 2)
        enabled: DisplayService.brightnessAvailable && targetDeviceName.length > 0
        minimum: {
            if (!targetDevice)
                return 1;
            const isExponential = SessionData.getBrightnessExponential(targetDevice.id);
            if (isExponential) {
                return 1;
            }
            return (targetDevice.class === "backlight" || targetDevice.class === "ddc") ? 1 : 0;
        }
        maximum: {
            if (!targetDevice)
                return 100;
            const isExponential = SessionData.getBrightnessExponential(targetDevice.id);
            if (isExponential) {
                return 100;
            }
            return targetDevice.displayMax || 100;
        }
        showValue: true
        unit: {
            if (!targetDevice)
                return "%";
            const isExponential = SessionData.getBrightnessExponential(targetDevice.id);
            if (isExponential) {
                return "%";
            }
            return targetDevice.class === "ddc" ? "" : "%";
        }
        onSliderValueChanged: function (newValue) {
            if (DisplayService.brightnessAvailable && targetDeviceName) {
                DisplayService.setBrightness(newValue, targetDeviceName, true);
            }
        }
        thumbOutlineColor: Theme.surfaceContainer
        trackColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

        Binding on value {
            value: root.targetBrightness
            when: !brightnessSlider.isDragging
        }
    }
}
