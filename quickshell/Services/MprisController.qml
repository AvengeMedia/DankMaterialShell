pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Common

Singleton {
    id: root

    readonly property list<MprisPlayer> availablePlayers: Mpris.players.values
    property MprisPlayer activePlayer: null

    onAvailablePlayersChanged: _resolveActivePlayer()
    Component.onCompleted: _resolveActivePlayer()

    Instantiator {
        model: root.availablePlayers
        delegate: Connections {
            required property MprisPlayer modelData
            target: modelData
            function onIsPlayingChanged() {
                if (modelData.isPlaying)
                    root._resolveActivePlayer();
            }
        }
    }

    function _resolveActivePlayer(): void {
        const playing = availablePlayers.find(p => p.isPlaying);
        if (playing) {
            activePlayer = playing;
            _persistIdentity(playing.identity);
            return;
        }
        if (activePlayer && availablePlayers.indexOf(activePlayer) >= 0)
            return;
        const savedId = SessionData.lastPlayerIdentity;
        if (savedId) {
            const match = availablePlayers.find(p => p.identity === savedId);
            if (match) {
                activePlayer = match;
                return;
            }
        }
        activePlayer = availablePlayers.find(p => p.canControl && p.canPlay) ?? null;
        if (activePlayer)
            _persistIdentity(activePlayer.identity);
    }

    function setActivePlayer(player: MprisPlayer): void {
        activePlayer = player;
        if (player)
            _persistIdentity(player.identity);
    }

    function _persistIdentity(identity: string): void {
        if (identity && SessionData.lastPlayerIdentity !== identity)
            SessionData.set("lastPlayerIdentity", identity);
    }

    Timer {
        interval: 1000
        running: root.activePlayer?.playbackState === MprisPlaybackState.Playing
        repeat: true
        onTriggered: root.activePlayer?.positionChanged()
    }

    function isFirefoxYoutubeHoverPreview(player: MprisPlayer): bool {
        if (!player)
            return false;
        const id = (player.identity || "").toLowerCase();
        if (!id.includes("firefox"))
            return false;
        const url = (player.metadata?.["xesam:url"] || "").toString();
        return /^https?:\/\/(www\.)?youtube\.com\/?($|\?|#)/i.test(url);
    }

    function previousOrRewind(): void {
        if (!activePlayer)
            return;
        if (activePlayer.position > 8 && activePlayer.canSeek)
            activePlayer.position = 0;
        else if (activePlayer.canGoPrevious)
            activePlayer.previous();
    }
}
