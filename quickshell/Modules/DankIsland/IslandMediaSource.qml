pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services

QtObject {
    id: root

    required property IslandController controller

    readonly property var player: MprisController.activePlayer
    readonly property bool available: !!player && player.playbackState !== MprisPlaybackState.Stopped
    readonly property string title: MprisController.stableTitle || player?.trackTitle || I18n.tr("Unknown Track", "island media face: fallback title")
    readonly property string artist: MprisController.stableArtist || player?.trackArtist || player?.identity || I18n.tr("Unknown Artist", "island media face: fallback artist")
    readonly property string artUrl: TrackArtService.resolvedArtUrl || player?.trackArtUrl || ""
    readonly property bool playing: !!player?.isPlaying

    Component.onCompleted: controller.updateMediaAvailability(available)
    onAvailableChanged: controller.updateMediaAvailability(available)
}
