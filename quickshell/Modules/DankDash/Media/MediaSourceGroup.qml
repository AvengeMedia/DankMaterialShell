pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import "../../../DankCommon/Common/FocusNavigation.js" as FocusNavigation

Item {
    id: root

    required property var player

    readonly property var focusTargets: [volumeButton, devicesButton]
    readonly property var panelButtons: [volumeButton, devicesButton]
    readonly property string devicesLabel: I18n.tr("Devices", "Media player output device picker")
    readonly property string sinkName: AudioService.displayName(AudioService.sink)
    readonly property string fittedSinkName: {
        const room = devicesButton.maximumLabelWidth;
        // advanceWidth() is not reactive, this read re-evaluates once the font resolves
        if (labelMetrics.averageCharacterWidth <= 0)
            return "";
        if (Math.ceil(labelMetrics.advanceWidth(sinkName)) <= room)
            return sinkName;
        const words = sinkName.split(/\s+/);
        while (words.length > 1) {
            words.pop();
            const shortened = words.join(" ");
            if (Math.ceil(labelMetrics.advanceWidth(shortened)) <= room)
                return shortened;
        }
        return "";
    }
    readonly property bool muted: player.usePlayerVolume ? player.currentVolume === 0 : AudioService.sinkSilent
    readonly property real volumeRatio: player.maxVolumePercent > 0 ? player.currentVolume * 100 / player.maxVolumePercent : 0

    implicitHeight: volumeRing.height

    Keys.onPressed: event => event.accepted = FocusNavigation.handleHorizontalKey(event, focusTargets, I18n.isRtl)

    FontMetrics {
        id: labelMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Theme.fontWeightMedium
    }

    DankRingGauge {
        id: volumeRing

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: volumeButton.buttonSize + (strokeWidth + trackGap) * 2
        height: width
        value: !root.player.volumeAvailable || root.muted ? 0 : root.volumeRatio
        startAngle: 135
        spanAngle: 270
        strokeWidth: Theme.outlineWidthFocused + Theme.dividerWidth
        trackGap: Theme.spacingXXS
        ringColor: MediaAccentService.accent
        trackColor: MediaAccentService.accentTrack
        animated: root.player.live

        DankActionButton {
            id: volumeButton

            readonly property string panelId: "volume"

            anchors.centerIn: parent
            buttonSize: Theme.buttonHeightXS
            radius: Theme.fullRadius(width, height)
            iconName: root.player.getVolumeIcon()
            iconColor: root.muted ? Theme.onSurfaceVariant : Theme.onSurface
            enabled: root.player.volumeAvailable
            tooltipText: I18n.tr("Volume") + ": " + Math.round(root.player.currentVolume * 100) + "%"
            onClicked: root.player.togglePanel(panelId)

            MediaVolumeWheel {
                player: root.player
                button: volumeButton
            }
        }
    }

    DankButton {
        id: devicesButton

        readonly property string panelId: "devices"

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        maximumWidth: Math.max(0, root.width - volumeRing.width - Theme.spacingXS)
        text: root.fittedSinkName || root.devicesLabel
        iconName: AudioService.sinkIcon(AudioService.sink)
        tooltipText: root.fittedSinkName === root.sinkName ? root.devicesLabel : root.sinkName
        Accessible.name: root.devicesLabel + ": " + root.sinkName
        backgroundColor: "transparent"
        textColor: Theme.onSurfaceVariant
        horizontalPadding: Theme.spacingS
        onClicked: root.player.togglePanel("devices")

        MediaSinkWheel {}
    }
}
