pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.DankDash
import "../../../DankCommon/Common/FocusNavigation.js" as FocusNavigation

Item {
    id: root

    required property var player

    readonly property var focusTargets: [volumeButton, deviceChip, deviceIcon]
    readonly property var panelButtons: [volumeButton, deviceChip, deviceIcon]
    readonly property string devicesLabel: I18n.tr("Devices", "Media player output device picker")
    readonly property string sinkName: AudioService.displayName(AudioService.sink)
    readonly property string deviceTooltip: devicesLabel + ": " + sinkName
    readonly property bool showSinkName: root.player.options?.deviceName ?? MediaOptions.defaults.deviceName
    readonly property string volumeLabel: root.player.usePlayerVolume ? I18n.tr("Media volume") : I18n.tr("Volume")
    readonly property bool muted: player.usePlayerVolume ? player.currentVolume === 0 : AudioService.sinkSilent
    readonly property real volumeRatio: player.maxVolumePercent > 0 ? player.currentVolume * 100 / player.maxVolumePercent : 0

    implicitHeight: volumeRing.height

    Keys.onPressed: event => event.accepted = FocusNavigation.handleHorizontalKey(event, focusTargets, I18n.isRtl)

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
            tooltipText: root.volumeLabel + ": " + Math.round(root.player.currentVolume * 100) + "%"
            onClicked: root.player.togglePanel(panelId)

            MediaVolumeWheel {
                player: root.player
                button: volumeButton
            }
        }
    }

    DankButton {
        id: deviceChip

        readonly property string panelId: "devices"

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showSinkName
        maximumWidth: Math.round(root.width * DashMetrics.mediaDeviceNameWidthRatio)
        text: root.sinkName
        iconName: AudioService.sinkIcon(AudioService.sink)
        tooltipText: root.deviceTooltip
        Accessible.name: root.deviceTooltip
        buttonHeight: Theme.buttonHeightXS
        backgroundColor: MediaAccentService.accentSecondaryContainer
        textColor: MediaAccentService.onAccentSecondaryContainer
        horizontalPadding: Theme.spacingM
        onClicked: root.player.togglePanel(panelId)

        MediaSinkWheel {}
    }

    DankActionButton {
        id: deviceIcon

        readonly property string panelId: "devices"

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.showSinkName
        buttonSize: volumeRing.width
        iconName: AudioService.sinkIcon(AudioService.sink)
        iconColor: MediaAccentService.onAccentSecondaryContainer
        backgroundColor: MediaAccentService.accentSecondaryContainer
        tooltipText: root.deviceTooltip
        onClicked: root.player.togglePanel(panelId)

        MediaSinkWheel {}
    }
}
