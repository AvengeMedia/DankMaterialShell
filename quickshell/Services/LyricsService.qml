pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Services
import qs.Modules.DankDash.Media

Singleton {
    id: root

    property int refCount: 0
    readonly property bool subscribed: refCount > 0 && controller.available
    property var activePlayer: subscribed ? MprisController.activePlayer : null
    readonly property real stableLength: subscribed ? MprisController.activePlayerStableLength : 0

    readonly property LyricsController controller: LyricsController {
        enabled: root.subscribed && !!root.presenter.current
        track: root.presenter.current
        settling: root.presenter.settling
        player: root.activePlayer
        playing: root.activePlayer?.playbackState === MprisPlaybackState.Playing
        stopped: !root.activePlayer || root.activePlayer.playbackState === MprisPlaybackState.Stopped
        rate: root.activePlayer?.rate ?? 1
        url: root.activePlayer?.metadata?.["xesam:url"] ?? ""
        embeddedText: root.activePlayer?.metadata?.["xesam:asText"] ?? ""
    }

    readonly property MediaPresentation presenter: MediaPresentation {
        player: root
    }

    function addRef() {
        refCount++;
    }

    function removeRef() {
        refCount = Math.max(0, refCount - 1);
    }
}
