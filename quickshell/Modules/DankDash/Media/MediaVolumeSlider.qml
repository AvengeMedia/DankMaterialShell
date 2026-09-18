import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DankSlider {
    id: root

    required property real volume
    property bool muted: volume === 0
    property real maximumVolume: 100
    property color accent: MediaAccentService.accent
    property color accentText: MediaAccentService.onAccent

    readonly property string volumeIcon: AudioService.volumeIcon(volume, muted)
    readonly property string muteLabel: muted ? I18n.tr("Unmute") : I18n.tr("Mute", "Mute media volume")

    signal volumeChangedByUser(real volume)
    signal muteRequested

    size: "m"
    insetIcon: volumeIcon
    insetIconClickable: true
    insetIconLabel: muteLabel
    onInsetIconClicked: muteRequested()
    Accessible.name: I18n.tr("Volume")
    minimum: 0
    maximum: Math.max(1, Math.round(maximumVolume))
    wheelStep: SettingsData.audioWheelScrollAmount
    wheelInsideScrollable: true
    thumbOutlineColor: Theme.cardSurface
    fillColor: accent
    fillTextColor: accentText
    trackColor: MediaAccentService.accentTrack
    trackTextColor: Theme.onSurface
    valueOverride: Math.round(volume * 100)
    onSliderValueChanged: newValue => volumeChangedByUser(newValue / 100)

    Binding on value {
        value: Math.round(root.volume * 100)
        restoreMode: Binding.RestoreNone
        when: !root.isDragging
    }
}
