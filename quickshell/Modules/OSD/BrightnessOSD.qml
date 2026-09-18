import QtQuick
import qs.Common
import qs.Services

LevelOSD {
    id: root

    readonly property var device: BrightnessService.getCurrentDeviceInfo()
    property int displayLevel: BrightnessService.brightnessLevel

    iconName: BrightnessService.brightnessIconName(device, displayLevel)
    insetIconName: BrightnessService.brightnessIconName(device)
    endIconName: {
        switch (device?.class) {
        case "backlight":
        case "ddc":
            return "monitor";
        default:
            return BrightnessService.brightnessIconName(device);
        }
    }
    iconColor: Theme.onPrimary
    value: displayLevel
    minimum: BrightnessService.brightnessMinimum(device)
    maximum: BrightnessService.brightnessMaximum(device)
    unit: BrightnessService.brightnessUnit(device)
    available: BrightnessService.brightnessAvailable

    onLevelRequested: level => {
        displayLevel = level;
        BrightnessService.setBrightness(level, BrightnessService.lastIpcDevice, true);
    }

    Connections {
        target: BrightnessService

        function onBrightnessChanged(showOsd) {
            root.displayLevel = BrightnessService.brightnessLevel;
            if (showOsd && SettingsData.osdBrightnessEnabled)
                root.show();
        }
    }
}
