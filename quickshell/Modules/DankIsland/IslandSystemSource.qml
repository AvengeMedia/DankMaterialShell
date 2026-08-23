pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services

QtObject {
    id: root

    required property IslandController controller

    property string kind: "volume"

    readonly property bool volumeActivity: kind === "volume"
    readonly property bool available: volumeActivity ? !!AudioService.sink?.audio : DisplayService.brightnessAvailable
    readonly property bool muted: volumeActivity && (AudioService.sink?.audio?.muted ?? false)
    readonly property real value: volumeActivity ? Math.min(AudioService.sinkMaxVolume, Math.round((AudioService.sink?.audio?.volume ?? 0) * 100)) : DisplayService.brightnessLevel
    readonly property real maximum: {
        if (volumeActivity)
            return AudioService.sinkMaxVolume;
        const deviceInfo = DisplayService.getCurrentDeviceInfo();
        if (!deviceInfo)
            return 100;
        if (SessionData.getBrightnessExponential(deviceInfo.id))
            return 100;
        return deviceInfo.displayMax || 100;
    }
    readonly property int minimum: {
        if (volumeActivity)
            return 0;
        const deviceInfo = DisplayService.getCurrentDeviceInfo();
        if (!deviceInfo)
            return 1;
        if (SessionData.getBrightnessExponential(deviceInfo.id))
            return 1;
        return (deviceInfo.class === "backlight" || deviceInfo.class === "ddc") ? 1 : 0;
    }
    readonly property real ratio: maximum > 0 ? Math.max(0, Math.min(1, value / maximum)) : 0
    readonly property string title: volumeActivity ? I18n.tr("Volume") : I18n.tr("Brightness")
    readonly property string unit: {
        if (volumeActivity)
            return "%";
        const deviceInfo = DisplayService.getCurrentDeviceInfo();
        if (!deviceInfo)
            return "%";
        if (SessionData.getBrightnessExponential(deviceInfo.id))
            return "%";
        return deviceInfo.class === "ddc" ? "" : "%";
    }
    readonly property string displayValue: muted ? I18n.tr("Muted") : Math.round(value) + unit
    readonly property string iconName: volumeActivity ? volumeIconName() : brightnessIconName()

    function volumeIconName() {
        if (!available || muted)
            return "volume_off";
        const volume = AudioService.sink?.audio?.volume ?? 0;
        if (volume === 0)
            return "volume_mute";
        return volume <= 0.33 ? "volume_down" : "volume_up";
    }

    function brightnessIconName() {
        const deviceInfo = DisplayService.getCurrentDeviceInfo();
        if (!available || !deviceInfo)
            return "brightness_low";
        if (deviceInfo.class === "backlight" || deviceInfo.class === "ddc") {
            if (ratio <= 0.33)
                return "brightness_low";
            return ratio <= 0.66 ? "brightness_medium" : "brightness_high";
        }
        if (String(deviceInfo.name ?? "").includes("kbd"))
            return "keyboard";
        return "lightbulb";
    }

    function show(activityKind) {
        if (controller.requestSystemActivity(activityKind))
            kind = activityKind;
    }

    function setRatio(nextRatio) {
        const clampedRatio = Math.max(0, Math.min(1, nextRatio));
        SessionData.suppressOSDTemporarily();
        if (volumeActivity) {
            AudioService.setVolume(Math.round(clampedRatio * maximum));
            return;
        }
        DisplayService.setBrightness(Math.round(clampedRatio * maximum), DisplayService.lastIpcDevice, true);
    }

    function toggleMute() {
        if (!volumeActivity || !available)
            return;
        SessionData.suppressOSDTemporarily();
        AudioService.toggleMute();
    }

    property Connections audioConnection: Connections {
        target: AudioService.sink?.audio ?? null

        function onVolumeChanged() {
            if (SettingsData.osdVolumeEnabled)
                root.show("volume");
        }

        function onMutedChanged() {
            if (SettingsData.osdVolumeEnabled)
                root.show("volume");
        }
    }

    property Connections brightnessConnection: Connections {
        target: DisplayService

        function onBrightnessChanged(showOsd) {
            if (showOsd && SettingsData.osdBrightnessEnabled)
                root.show("brightness");
        }
    }
}
