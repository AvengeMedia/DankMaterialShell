import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DankOSD {
    id: root

    property string deviceName: ""
    property string deviceIcon: "speaker"

    osdWidth: Math.min(Math.max(120, Theme.iconSize + textMetrics.width + Theme.spacingS * 4), Screen.width - Theme.spacingM * 2)
    osdHeight: 40 + Theme.spacingS * 2
    autoHideInterval: 2500
    enableMouseInteraction: false

    TextMetrics {
        id: textMetrics
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        font.family: Theme.fontFamily
        text: root.deviceName
    }

    function getIconForSink(sink) {
        if (!sink)
            return "speaker";
        const name = sink.name || "";
        if (name.includes("bluez"))
            return "headset";
        if (name.includes("hdmi"))
            return "tv";
        if (name.includes("usb"))
            return "headset";
        return "speaker";
    }

    Connections {
        target: AudioService

        function onAudioOutputCycled(name) {
            if (!SettingsData.osdAudioOutputEnabled)
                return;
            root.deviceName = name;
            root.deviceIcon = getIconForSink(AudioService.sink);
            root.show();
        }
    }

    content: Item {
        property int gap: Theme.spacingS

        anchors.centerIn: parent
        width: parent.width - Theme.spacingS * 2
        height: 40

        DankIcon {
            id: iconItem
            width: Theme.iconSize
            height: Theme.iconSize
            x: parent.gap
            anchors.verticalCenter: parent.verticalCenter
            name: root.deviceIcon
            size: Theme.iconSize
            color: Theme.primary
        }

        StyledText {
            id: textItem
            x: parent.gap * 2 + Theme.iconSize
            width: parent.width - Theme.iconSize - parent.gap * 3
            anchors.verticalCenter: parent.verticalCenter
            text: root.deviceName
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
            elide: Text.ElideRight
        }
    }
}
