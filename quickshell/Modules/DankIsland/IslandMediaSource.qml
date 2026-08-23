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
    readonly property string title: MprisController.stableTitle || player?.trackTitle || I18n.tr("Unknown Track")
    readonly property string artist: MprisController.stableArtist || player?.trackArtist || player?.identity || I18n.tr("Unknown Artist")
    readonly property string album: MprisController.stableAlbum || player?.trackAlbum || ""
    readonly property string artUrl: TrackArtService.resolvedArtUrl
    readonly property bool playing: !!player?.isPlaying
    readonly property bool canToggle: !!player?.canTogglePlaying
    readonly property bool canGoPrevious: !!player?.canGoPrevious
    readonly property bool canGoNext: !!player?.canGoNext
    readonly property bool canSeek: !!player?.canSeek && length > 0
    readonly property real position: Math.max(0, player?.position || 0)
    readonly property real length: Math.max(0, MprisController.activePlayerStableLength)
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

    function togglePlaying() {
        if (player?.canTogglePlaying)
            player.togglePlaying();
    }

    function previous() {
        MprisController.previousOrRewind();
    }

    function next() {
        MprisController.next();
    }

    function seekRatio(ratio) {
        if (!canSeek || length <= 0)
            return;
        player.position = Math.max(0.1, Math.min(length - 0.1, length * Math.max(0, Math.min(1, ratio))));
    }

    Component.onCompleted: controller.updateMediaAvailability(available)
    onAvailableChanged: controller.updateMediaAvailability(available)
}
