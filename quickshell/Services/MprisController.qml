pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property list<MprisPlayer> availablePlayers: Mpris.players.values
    property MprisPlayer activePlayer: availablePlayers.find(p => p.isPlaying) ?? availablePlayers.find(p => p.canControl && p.canPlay) ?? null

    // Manual source selection (null = auto, "custom" = force custom source)
    property string forcedSource: "auto"

    // Check if custom source has actual content
    readonly property bool customHasContent: CustomMediaSource.available && CustomMediaSource.trackTitle !== ""

    // Use custom source when forced or when auto-detect determines it
    readonly property bool useCustomSource: {
        if (forcedSource === "custom") return CustomMediaSource.available
        if (forcedSource === "mpris") return false
        // Auto: use custom when it has content (track loaded), regardless of playing state
        return customHasContent
    }

    readonly property var currentPlayer: useCustomSource ? CustomMediaSource : activePlayer

    // Direct property bindings for reliable UI updates (QML doesn't track nested var properties well)
    readonly property int currentPlaybackState: useCustomSource ? CustomMediaSource.playbackState : (activePlayer ? activePlayer.playbackState : 0)
    readonly property bool currentIsPlaying: currentPlaybackState === CustomMediaSource.statePlaying
    readonly property string currentTrackTitle: useCustomSource ? CustomMediaSource.trackTitle : (activePlayer ? activePlayer.trackTitle : "")
    readonly property string currentTrackArtist: useCustomSource ? CustomMediaSource.trackArtist : (activePlayer ? activePlayer.trackArtist : "")
    readonly property string currentTrackAlbum: useCustomSource ? CustomMediaSource.trackAlbum : (activePlayer ? activePlayer.trackAlbum : "")
    readonly property string currentTrackArtUrl: useCustomSource ? CustomMediaSource.trackArtUrl : (activePlayer ? activePlayer.trackArtUrl : "")
    readonly property string currentIdentity: useCustomSource ? CustomMediaSource.identity : (activePlayer ? activePlayer.identity : "")

    // Combined list of all sources (for player selector dropdown)
    readonly property var allSources: {
        const sources = []
        // Add custom source first if available
        if (CustomMediaSource.available) {
            sources.push({
                isCustom: true,
                identity: CustomMediaSource.identity || "Custom Media",
                sourceId: CustomMediaSource.sourceId
            })
        }
        // Add MPRIS players
        for (let i = 0; i < availablePlayers.length; i++) {
            sources.push({
                isCustom: false,
                identity: availablePlayers[i].identity,
                player: availablePlayers[i]
            })
        }
        return sources
    }

    function selectSource(source) {
        if (source && source.isCustom) {
            forcedSource = "custom"
        } else if (source && source.player) {
            forcedSource = "mpris"
            activePlayer = source.player
        } else {
            forcedSource = "auto"
        }
    }
}
