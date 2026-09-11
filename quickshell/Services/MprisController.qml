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
    property string pinnedIdentity: SessionData.pinnedPlayerIdentity || ""
    property real activePlayerStableLength: 0
    // Chromium can report blank metadata between tracks
    property string stableTitle: ""
    property string stableArtist: ""
    property string stableAlbum: ""

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
        function onTrackAlbumChanged() {
            root._syncStableMeta();
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
        stableTitle = "";
        stableArtist = "";
        stableAlbum = "";
        _syncStableMeta();
        _checkIdle();
    }

    function _syncStableMeta(): void {
        const p = activePlayer;
        if (!p) {
            stableTitle = "";
            stableArtist = "";
            stableAlbum = "";
            return;
        }
        if (isFirefoxYoutubeHoverPreview(p))
            return;
        const metadataPlayer = bestMetadataPlayer(p);
        const nextTitle = displayTrackTitle(metadataPlayer);
        const trackChanged = nextTitle && stableTitle && nextTitle.toLowerCase() !== stableTitle.toLowerCase();
        if (trackChanged) {
            stableArtist = "";
            stableAlbum = "";
        }
        if (nextTitle)
            stableTitle = nextTitle;
        if (metadataPlayer.trackArtist)
            stableArtist = metadataPlayer.trackArtist;
        if (metadataPlayer.trackAlbum)
            stableAlbum = metadataPlayer.trackAlbum;
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
            root.stableAlbum = "";
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
            ignoreUnknownSignals: true
            function onIsPlayingChanged() {
                root._resolveActivePlayer();
                root._syncStableMeta();
            }
            function onTrackTitleChanged() {
                if (modelData.isPlaying)
                    root._resolveActivePlayer();
                root._syncStableMeta();
            }
            function onTrackArtistChanged() {
                if (modelData.isPlaying)
                    root._resolveActivePlayer();
                root._syncStableMeta();
            }
            function onTrackAlbumChanged() {
                if (modelData.isPlaying)
                    root._resolveActivePlayer();
                root._syncStableMeta();
            }
            function onMetadataChanged() {
                if (modelData.isPlaying)
                    root._resolveActivePlayer();
                root._syncStableMeta();
            }
        }
    }

    function isIdle(player: MprisPlayer): bool {
        return player && player.playbackState === MprisPlaybackState.Stopped;
    }

    // Known "<title> | <App>" suffixes stripped for matching only; display keeps the full title
    readonly property var _appTitleSuffixes: ["youtube", "youtube music", "soundcloud", "spotify", "chrome", "chromium", "firefox", "brave", "vivaldi", "twitch"]

    function _stripAppTitleSuffix(title: string): string {
        const idx = title.lastIndexOf(" | ");
        if (idx <= 0)
            return title;
        const suffix = title.substring(idx + 3).trim().toLowerCase();
        return _appTitleSuffixes.indexOf(suffix) !== -1 ? title.substring(0, idx).trim() : title;
    }

    function normalizedTrackTitle(player: MprisPlayer): string {
        return _stripAppTitleSuffix((player?.trackTitle || "").trim()).toLowerCase();
    }

    function displayTrackTitle(player: MprisPlayer): string {
        return (player?.trackTitle || "").trim();
    }

    function normalizedTrackArtist(player: MprisPlayer): string {
        return (player?.trackArtist || "").trim().toLowerCase();
    }

    // Artist missing on either side: fall back to URL, then album, before trusting a title-only match
    function isSameTrack(first: MprisPlayer, second: MprisPlayer): bool {
        const firstTitle = normalizedTrackTitle(first);
        if (!firstTitle || firstTitle !== normalizedTrackTitle(second))
            return false;
        const firstArtist = normalizedTrackArtist(first);
        const secondArtist = normalizedTrackArtist(second);
        if (firstArtist && secondArtist)
            return firstArtist === secondArtist;
        const firstUrl = (first?.metadata?.["xesam:url"] || "").toString();
        const secondUrl = (second?.metadata?.["xesam:url"] || "").toString();
        if (firstUrl && secondUrl)
            return firstUrl === secondUrl;
        const firstAlbum = (first?.trackAlbum || "").trim().toLowerCase();
        const secondAlbum = (second?.trackAlbum || "").trim().toLowerCase();
        if (firstAlbum && secondAlbum)
            return firstAlbum === secondAlbum;
        return true;
    }

    function metadataQuality(player: MprisPlayer): int {
        if (!player)
            return -1;
        let quality = player.trackArtist ? 100 : 0;
        quality += player.trackTitle ? 40 : 0;
        quality += player.trackAlbum ? 20 : 0;
        quality += player.trackArtUrl || player.metadata?.["mpris:artUrl"] ? 10 : 0;
        quality += player.metadata?.["xesam:url"] ? 5 : 0;
        return quality;
    }

    function equivalentPlayers(player: MprisPlayer): var {
        if (!player)
            return [];
        return availablePlayers.filter(candidate => {
            return candidate.playbackState !== MprisPlaybackState.Stopped && isSameTrack(player, candidate);
        });
    }

    function bestMetadataPlayer(player: MprisPlayer): MprisPlayer {
        const equivalents = equivalentPlayers(player);
        if (equivalents.length === 0)
            return player;
        return equivalents.reduce((best, candidate) => {
            return metadataQuality(candidate) > metadataQuality(best) ? candidate : best;
        }, player);
    }

    function _bestPlayingPlayer(): MprisPlayer {
        const playing = availablePlayers.filter(player => player.isPlaying);
        if (playing.length === 0)
            return null;

        if (pinnedIdentity !== "") {
            const pinLower = pinnedIdentity.toLowerCase();
            const exact = playing.filter(player => player.identity === pinnedIdentity);
            const matches = exact.length > 0 ? exact : playing.filter(player => (player.identity || "").toLowerCase().includes(pinLower));
            const pinned = matches.find(player => player.canControl) ?? matches[0];
            if (pinned)
                return pinned;
        }

        const controllable = playing.filter(player => player.canControl);
        if (activePlayer?.isPlaying) {
            if (activePlayer.canControl || controllable.length === 0)
                return activePlayer;
            // Playing but not controllable: only a same-track controllable peer may take over
            const mirror = controllable.find(player => isSameTrack(activePlayer, player));
            return mirror || activePlayer;
        }

        if (activePlayer?.canControl && activePlayer.playbackState === MprisPlaybackState.Paused) {
            const onlyEquivalentMirrors = playing.every(player => isSameTrack(activePlayer, player));
            if (onlyEquivalentMirrors)
                return null;
        }
        return controllable[0] || playing[0];
    }

    function _resolveActivePlayer(): void {
        const playing = _bestPlayingPlayer();
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

    function switchActivePlayer(player) {
        const current = root.activePlayer;
        if (current && current !== player && current.canPause)
            current.pause();
        setActivePlayer(player);
    }

    function setActivePlayer(player: MprisPlayer): void {
        activePlayer = player;
        if (player)
            _persistIdentity(player.identity);
    }

    function setPinned(identity: string): void {
        if (SessionData.pinnedPlayerIdentity !== identity)
            SessionData.set("pinnedPlayerIdentity", identity);
        _resolveActivePlayer();
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
