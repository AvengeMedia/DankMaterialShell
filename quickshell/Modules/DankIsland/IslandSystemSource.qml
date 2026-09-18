pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services

QtObject {
    id: root

    required property IslandController controller

    property string kind: "volume"

    readonly property bool volumeActivity: kind === "volume"
    readonly property bool available: volumeActivity ? !!AudioService.sink?.audio : BrightnessService.brightnessAvailable
    readonly property bool muted: volumeActivity && (AudioService.sink?.audio?.muted ?? false)
    readonly property real value: volumeActivity ? AudioService.sinkVolumePercent : BrightnessService.brightnessLevel
    readonly property var brightnessDevice: BrightnessService.getCurrentDeviceInfo()
    readonly property real maximum: volumeActivity ? AudioService.sinkMaxVolume : BrightnessService.brightnessMaximum(brightnessDevice)
    readonly property int minimum: volumeActivity ? 0 : BrightnessService.brightnessMinimum(brightnessDevice)
    readonly property real ratio: maximum > 0 ? Math.max(0, Math.min(1, value / maximum)) : 0
    readonly property string title: volumeActivity ? I18n.tr("Volume", "island system face: volume title") : I18n.tr("Brightness", "island system face: brightness title")
    readonly property string unit: volumeActivity ? "%" : BrightnessService.brightnessUnit(brightnessDevice)
    readonly property string displayValue: muted ? I18n.tr("Muted", "island system face: muted value label") : Math.round(value) + unit
    readonly property string iconName: volumeActivity ? AudioService.sinkVolumeIconName : BrightnessService.brightnessIconName(brightnessDevice, value)

    function show(activityKind) {
        if (SessionData.suppressOSD)
            return;
        open(activityKind);
    }

    function open(activityKind) {
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
        BrightnessService.setBrightness(Math.round(clampedRatio * maximum), BrightnessService.lastIpcDevice, true);
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
        target: BrightnessService

        function onBrightnessChanged(showOsd) {
            if (showOsd && SettingsData.osdBrightnessEnabled)
                root.show("brightness");
        }
    }
}
