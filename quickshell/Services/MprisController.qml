pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Common

Singleton {
    id: root

    readonly property list<MprisPlayer> availablePlayers: {
        const players = Mpris.players.values;
        const excluded = SettingsData.mediaExcludePlayers || [];
        if (excluded.length === 0)
            return players;
        return players.filter(p => {
            const identity = (p.identity || "").toLowerCase();
            const desktopEntry = ("desktopEntry" in p && p.desktopEntry) ? String(p.desktopEntry).toLowerCase() : "";
            return !excluded.some(ex => {
                const exLower = String(ex).toLowerCase().trim();
                if (!exLower) return false;
                
                // 1. Substring match
                if (identity.includes(exLower) || desktopEntry.includes(exLower))
                    return true;
                
                // 2. Match reverse-DNS segments (e.g. app.zen_browser.zen -> zen)
                if (exLower.indexOf(".") !== -1) {
                    const parts = exLower.split(".");
                    const lastPart = parts[parts.length - 1];
                    if (lastPart && (identity.includes(lastPart) || desktopEntry.includes(lastPart)))
                        return true;
                }
                
                // 3. Bidirectional match (longer excluded name contains shorter player identity)
                if (identity.length >= 3 && exLower.includes(identity))
                    return true;
                
                return false;
            });
        });
    }
    property MprisPlayer activePlayer: null
    property real activePlayerStableLength: 0

    Connections {
        target: root.activePlayer
        function onTrackTitleChanged() {
            root.activePlayerStableLength = (root.activePlayer && root.activePlayer.lengthSupported && root.activePlayer.length > 1) ? root.activePlayer.length : 0;
            if (root.isIdle(root.activePlayer))
                root._resolveActivePlayer();
        }
        function onTrackArtistChanged() {
            if (root.isIdle(root.activePlayer))
                root._resolveActivePlayer();
        }
        function onLengthChanged() {
            if (root.activePlayer && root.activePlayer.lengthSupported && root.activePlayer.length > 1) {
                root.activePlayerStableLength = root.activePlayer.length;
            }
        }
        function onPlaybackStateChanged() {
            if (root.isIdle(root.activePlayer))
                root._resolveActivePlayer();
        }
    }

    onActivePlayerChanged: {
        activePlayerStableLength = (activePlayer && activePlayer.lengthSupported && activePlayer.length > 1) ? activePlayer.length : 0;
    }

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

    function isIdle(player: MprisPlayer): bool {
        return player
            && player.playbackState === MprisPlaybackState.Stopped
            && !player.trackTitle
            && !player.trackArtist;
    }

    function _resolveActivePlayer(): void {
        const playing = availablePlayers.find(p => p.isPlaying);
        if (playing) {
            activePlayer = playing;
            _persistIdentity(playing.identity);
            return;
        }
        if (activePlayer && availablePlayers.indexOf(activePlayer) >= 0 && !isIdle(activePlayer))
            return;
        const savedId = SessionData.lastPlayerIdentity;
        if (savedId) {
            const match = availablePlayers.find(p => p.identity === savedId);
            if (match && !isIdle(match)) {
                activePlayer = match;
                return;
            }
        }
        activePlayer = availablePlayers.find(p => p.canControl && !isIdle(p)) ?? null;
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
            activePlayer.position = 0.1;
        else if (activePlayer.canGoPrevious)
            activePlayer.previous();
    }
}
