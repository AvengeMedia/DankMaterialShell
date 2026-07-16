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
                if (!exLower)
                    return false;

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
    // Chromium can report blank metadata between tracks
    property string stableTitle: ""
    property string stableArtist: ""

    Connections {
        target: root.activePlayer
        function onTrackTitleChanged() {
            root.activePlayerStableLength = (root.activePlayer && root.activePlayer.lengthSupported && root.activePlayer.length > 1) ? root.activePlayer.length : 0;
            root._syncStableMeta();
            root._checkIdle();
        }
        function onTrackArtistChanged() {
            root._syncStableMeta();
            root._checkIdle();
        }
        function onLengthChanged() {
            if (root.activePlayer && root.activePlayer.lengthSupported && root.activePlayer.length > 1) {
                root.activePlayerStableLength = root.activePlayer.length;
            }
        }
        function onPlaybackStateChanged() {
            root._syncStableMeta();
            root._checkIdle();
        }
    }

    onActivePlayerChanged: {
        activePlayerStableLength = (activePlayer && activePlayer.lengthSupported && activePlayer.length > 1) ? activePlayer.length : 0;
        stableTitle = activePlayer?.trackTitle || "";
        stableArtist = activePlayer?.trackArtist || "";
        _checkIdle();
    }

    function _syncStableMeta(): void {
        const p = activePlayer;
        if (!p) {
            stableTitle = "";
            stableArtist = "";
            return;
        }
        if (isFirefoxYoutubeHoverPreview(p))
            return;
        if (p.trackTitle)
            stableTitle = p.trackTitle;
        if (p.trackArtist)
            stableArtist = p.trackArtist;
    }

    // Chromium reports stopped media w/blank metadata, resolve by checking idle status
    Timer {
        id: _idleGraceTimer
        interval: 1223
        onTriggered: {
            if (!root.isIdle(root.activePlayer))
                return;
            root.stableTitle = "";
            root.stableArtist = "";
            root._resolveActivePlayer();
        }
    }

    function _checkIdle(): void {
        if (!isIdle(activePlayer)) {
            _idleGraceTimer.stop();
            return;
        }
        if (!_idleGraceTimer.running)
            _idleGraceTimer.start();
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
        return player && player.playbackState === MprisPlaybackState.Stopped && !player.trackTitle && !player.trackArtist;
    }

    function _resolveActivePlayer(): void {
        // A playing player always wins; otherwise keep the selection stable w/idle
        const playing = availablePlayers.find(p => p.isPlaying);
        if (playing) {
            if (activePlayer !== playing) {
                activePlayer = playing;
                _persistIdentity(playing.identity);
            }
            return;
        }
        if (activePlayer && availablePlayers.indexOf(activePlayer) >= 0 && (!isIdle(activePlayer) || _idleGraceTimer.running))
            return;
        if (activePlayer && availablePlayers.indexOf(activePlayer) < 0) {
            const successor = availablePlayers.find(p => p.identity === activePlayer.identity);
            if (successor) {
                activePlayer = successor;
                return;
            }
        }
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

    function next(): void {
        const player = activePlayer;
        if (player?.canGoNext)
            player.next();
    }
}
