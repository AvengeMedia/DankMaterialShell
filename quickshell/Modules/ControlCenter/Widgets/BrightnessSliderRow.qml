import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Row {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string deviceName: ""
    property string instanceId: ""
    property string screenName: ""
    property var parentScreen: null
    property color sliderTrackColor: "transparent"
    property real sliderTrackOpacity: Theme.ccSliderTrackOpacity

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
            const screen = Quickshell.screens.find(s => s.name === screenName);
            const pinKey = screen ? SettingsData.getScreenDisplayName(screen) : screenName;
            const pins = CacheData.brightnessDevicePins || {};
            const pinnedDevice = pins[pinKey];
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
        color: iconArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primary, 0)

        DankRipple {
            id: iconRipple
            cornerRadius: parent.radius
        }

        MouseArea {
            id: iconArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: DisplayService.devices && DisplayService.devices.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor

            onPressed: mouse => iconRipple.trigger(mouse.x, mouse.y)
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
                name: DisplayService.brightnessAvailable && targetDevice ? DisplayService.brightnessIconName(targetDevice, targetBrightness) : "brightness_low"
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
        minimum: DisplayService.brightnessMinimum(targetDevice)
        maximum: DisplayService.brightnessMaximum(targetDevice)
        showValue: true
        unit: DisplayService.brightnessUnit(targetDevice)
        onSliderValueChanged: function (newValue) {
            if (DisplayService.brightnessAvailable && targetDeviceName) {
                DisplayService.setBrightness(newValue, targetDeviceName, true);
            }
        }
        thumbOutlineColor: Theme.surfaceContainer
        trackColor: root.sliderTrackColor.a > 0 ? root.sliderTrackColor : Theme.ccSliderTrackColor
        trackOpacity: root.sliderTrackOpacity

        Binding on value {
            value: root.targetBrightness
            when: !brightnessSlider.isDragging
        }
    }
}
