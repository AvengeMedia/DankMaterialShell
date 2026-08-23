pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Services

QtObject {
    id: root

    required property IslandController controller

    readonly property bool demoEnabled: Quickshell.env("DMS_DANKISLAND_MEDIA_DEMO") === "1"
    readonly property var demoTracks: [
        {
            "title": "DankIsland Motion Study",
            "artist": "DankMaterialShell",
            "album": "Physical Springs",
            "icon": "applications-multimedia"
        },
        {
            "title": "Event Horizon",
            "artist": "Quickshell Ensemble",
            "album": "Signal Driven",
            "icon": "audio-x-generic"
        },
        {
            "title": "Warm Surface",
            "artist": "Scene Graph",
            "album": "Sixty Frames",
            "icon": "multimedia-player"
        }
    ]
    readonly property var demoTrack: demoTracks[demoTrackIndex]
    readonly property var player: MprisController.activePlayer
    readonly property bool realMediaAvailable: !!player && player.playbackState !== MprisPlaybackState.Stopped
    readonly property bool available: demoEnabled || realMediaAvailable
    readonly property string title: demoEnabled ? demoTrack.title : (MprisController.stableTitle || player?.trackTitle || "Unknown track")
    readonly property string artist: demoEnabled ? demoTrack.artist : (MprisController.stableArtist || player?.trackArtist || player?.identity || "Unknown artist")
    readonly property string album: demoEnabled ? demoTrack.album : (MprisController.stableAlbum || player?.trackAlbum || "")
    readonly property string artUrl: demoEnabled ? Quickshell.iconPath(demoTrack.icon, true) : TrackArtService.resolvedArtUrl
    readonly property bool playing: demoEnabled ? demoPlaying : !!player?.isPlaying
    readonly property bool canToggle: demoEnabled || !!player?.canTogglePlaying
    readonly property bool canGoPrevious: demoEnabled || !!player?.canGoPrevious
    readonly property bool canGoNext: demoEnabled || !!player?.canGoNext
    readonly property bool canSeek: demoEnabled || (!!player?.canSeek && length > 0)
    readonly property real position: demoEnabled ? demoPosition : Math.max(0, player?.position || 0)
    readonly property real length: demoEnabled ? 243 : Math.max(0, MprisController.activePlayerStableLength)
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

    property int demoTrackIndex: 0
    property bool demoPlaying: true
    property real demoPosition: 74

    function advanceDemoTrack(delta) {
        demoTrackIndex = (demoTrackIndex + delta + demoTracks.length) % demoTracks.length;
        demoPosition = 0;
    }

    function syncAvailability() {
        controller.updateMediaAvailability(available);
    }

    function togglePlaying() {
        if (demoEnabled) {
            demoPlaying = !demoPlaying;
            return;
        }
        if (player?.canTogglePlaying)
            player.togglePlaying();
    }

    function previous() {
        if (demoEnabled) {
            advanceDemoTrack(-1);
            return;
        }
        MprisController.previousOrRewind();
    }

    function next() {
        if (demoEnabled) {
            advanceDemoTrack(1);
            return;
        }
        MprisController.next();
    }

    function seekRatio(ratio) {
        if (!canSeek || length <= 0)
            return;
        const nextPosition = Math.max(0.1, Math.min(length - 0.1, length * Math.max(0, Math.min(1, ratio))));
        if (demoEnabled)
            demoPosition = nextPosition;
        else
            player.position = nextPosition;
    }

    Component.onCompleted: syncAvailability()
    onAvailableChanged: syncAvailability()

    property Timer demoTimer: Timer {
        interval: 1000
        repeat: true
        running: root.demoEnabled && root.demoPlaying
        onTriggered: root.demoPosition = (root.demoPosition + 1) % root.length
    }

    property Timer demoTrackTimer: Timer {
        interval: 4200
        repeat: true
        running: root.demoEnabled
        onTriggered: root.advanceDemoTrack(1)
    }
}
