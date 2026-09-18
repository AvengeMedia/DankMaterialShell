import QtQuick
import Quickshell
import qs.Common
import qs.Services

CcSliderRow {
    id: root

    property string deviceName: widgetData.deviceName || ""
    property string screenName: host?.screenName ?? ""

    property string targetDeviceName: {
        if (!BrightnessService.brightnessAvailable || !BrightnessService.devices || BrightnessService.devices.length === 0)
            return "";
        if (screenName) {
            const screen = Quickshell.screens.find(s => s.name === screenName);
            const pinKey = screen ? SettingsData.getScreenDisplayName(screen) : screenName;
            const pinnedDevice = (CacheData.brightnessDevicePins || {})[pinKey];
            if (pinnedDevice && BrightnessService.devices.find(dev => dev.name === pinnedDevice))
                return pinnedDevice;
        }
        if (deviceName && BrightnessService.devices.find(dev => dev.name === deviceName))
            return deviceName;
        const currentDeviceName = BrightnessService.currentDevice;
        if (currentDeviceName && BrightnessService.devices.find(dev => dev.name === currentDeviceName))
            return currentDeviceName;
        const backlight = BrightnessService.devices.find(d => d.class === "backlight");
        if (backlight)
            return backlight.name;
        const ddc = BrightnessService.devices.find(d => d.class === "ddc");
        if (ddc)
            return ddc.name;
        return BrightnessService.devices[0].name;
    }

    readonly property var targetDevice: targetDeviceName && BrightnessService.devices ? (BrightnessService.devices.find(dev => dev.name === targetDeviceName) || null) : null

    readonly property real targetBrightness: {
        BrightnessService.brightnessVersion;
        if (!targetDeviceName)
            return 0;
        return BrightnessService.getDeviceBrightness(targetDeviceName);
    }

    iconName: BrightnessService.brightnessAvailable && targetDevice ? BrightnessService.brightnessIconName(targetDevice, targetBrightness) : "brightness_low"
    sliderLabel: I18n.tr("Brightness")
    iconLabel: I18n.tr("Configure")
    iconTooltip: targetDevice ? BrightnessService.deviceTitle(targetDevice) : ""
    sliderEnabled: BrightnessService.brightnessAvailable && targetDeviceName.length > 0
    minimum: BrightnessService.brightnessMinimum(targetDevice)
    maximum: BrightnessService.brightnessMaximum(targetDevice)
    unit: BrightnessService.brightnessUnit(targetDevice)

    onIconClicked: expandClicked()

    onSliderValueChanged: newValue => {
        if (!BrightnessService.brightnessAvailable || !targetDeviceName)
            return;
        BrightnessService.setBrightness(newValue, targetDeviceName, true);
    }

    Binding {
        target: root.slider
        property: "value"
        value: root.targetBrightness
        restoreMode: Binding.RestoreNone
        when: !root.isDragging
    }
}
