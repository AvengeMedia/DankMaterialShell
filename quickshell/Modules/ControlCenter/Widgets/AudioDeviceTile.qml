import QtQuick
import qs.Common
import qs.Modules.ControlCenter
import qs.Services

CcTile {
    id: root

    property bool isInput: false

    readonly property var node: isInput ? AudioService.source : AudioService.sink
    readonly property var audio: node?.audio ?? null
    readonly property real maxVolume: isInput ? 100 : AudioService.sinkMaxVolume

    iconName: {
        if (!isInput)
            return AudioService.sinkVolumeIconName;
        return audio && !audio.muted ? "mic" : "mic_off";
    }
    title: node?.description || (isInput ? I18n.tr("No input device", "audio status") : I18n.tr("No output device", "audio status"))
    subtitle: {
        if (!audio)
            return I18n.tr("Select device", "audio status");
        if (audio.muted)
            return I18n.tr("Muted", "audio status");
        const volume = audio.volume;
        if (typeof volume !== "number" || isNaN(volume))
            return "0%";
        return Math.round(volume * 100) + "%";
    }
    active: !!audio && !audio.muted
    showExpand: true
    enabled: widgetDef?.enabled ?? true

    onClicked: {
        if (!audio)
            return;
        audio.muted = !audio.muted;
    }

    onWheel: wheelEvent => {
        if (!audio)
            return;
        const current = audio.volume * 100;
        const step = wheelEvent.angleDelta.y > 0 ? CcMetrics.wheelVolumeStep : -CcMetrics.wheelVolumeStep;
        audio.muted = false;
        audio.volume = Math.max(0, Math.min(maxVolume, current + step)) / 100;
        wheelEvent.accepted = true;
    }
}
