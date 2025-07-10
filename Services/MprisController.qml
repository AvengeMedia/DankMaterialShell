import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
pragma Singleton
pragma ComponentBehavior: Bound

/**
 * A service that provides easy access to the active Mpris player.
 */
Singleton {
    id: root
    property MprisPlayer trackedPlayer: null
    property MprisPlayer activePlayer: trackedPlayer ?? Mpris.players.values[0] ?? null
    signal trackChanged(reverse: bool)

    property bool __reverse: false

    property var activeTrack

    Instantiator {
        model: Mpris.players

        Connections {
            required property MprisPlayer modelData
            target: modelData

            Component.onCompleted: {
                console.log("MPRIS Player connected:", modelData.identity)
                if (root.trackedPlayer == null || modelData.isPlaying) {
                    root.trackedPlayer = modelData
                }
            }

            Component.onDestruction: {
                if (root.trackedPlayer == null || !root.trackedPlayer.isPlaying) {
                    for (const player of Mpris.players.values) {
                        if (player.playbackState.isPlaying) {
                            root.trackedPlayer = player
                            break
                        }
                    }

                    if (trackedPlayer == null && Mpris.players.values.length != 0) {
                        trackedPlayer = Mpris.players.values[0]
                    }
                }
            }

            function onPlaybackStateChanged() {
                if (root.trackedPlayer !== modelData) root.trackedPlayer = modelData
            }
        }
    }

    Connections {
        target: activePlayer

        function onPostTrackChanged() {
            root.updateTrack()
        }

        function onTrackArtUrlChanged() {
            if (root.activePlayer.uniqueId == root.activeTrack.uniqueId && root.activePlayer.trackArtUrl != root.activeTrack.artUrl) {
                const r = root.__reverse
                root.updateTrack()
                root.__reverse = r
            }
        }
    }

    onActivePlayerChanged: this.updateTrack()

    function updateTrack() {
        console.log(`MPRIS Track Update: ${this.activePlayer?.trackTitle ?? ""} : ${this.activePlayer?.trackArtist}`)
        this.activeTrack = {
            uniqueId: this.activePlayer?.uniqueId ?? 0,
            artUrl: this.activePlayer?.trackArtUrl ?? "",
            title: this.activePlayer?.trackTitle || "Unknown Title",
            artist: this.activePlayer?.trackArtist || "Unknown Artist",
            album: this.activePlayer?.trackAlbum || "Unknown Album",
        }

        this.trackChanged(__reverse)
        this.__reverse = false
    }

    property bool isPlaying: this.activePlayer && this.activePlayer.isPlaying
    property bool canTogglePlaying: this.activePlayer?.canTogglePlaying ?? false
    function togglePlaying() {
        if (this.canTogglePlaying) this.activePlayer.togglePlaying()
    }

    property bool canGoPrevious: this.activePlayer?.canGoPrevious ?? false
    function previous() {
        if (this.canGoPrevious) {
            this.__reverse = true
            this.activePlayer.previous()
        }
    }

    property bool canGoNext: this.activePlayer?.canGoNext ?? false
    function next() {
        if (this.canGoNext) {
            this.__reverse = false
            this.activePlayer.next()
        }
    }

    property bool canChangeVolume: this.activePlayer && this.activePlayer.volumeSupported && this.activePlayer.canControl

    property bool loopSupported: this.activePlayer && this.activePlayer.loopSupported && this.activePlayer.canControl
    property var loopState: this.activePlayer?.loopState ?? MprisLoopState.None
    function setLoopState(loopState) {
        if (this.loopSupported) {
            this.activePlayer.loopState = loopState
        }
    }

    property bool shuffleSupported: this.activePlayer && this.activePlayer.shuffleSupported && this.activePlayer.canControl
    property bool hasShuffle: this.activePlayer?.shuffle ?? false
    function setShuffle(shuffle) {
        if (this.shuffleSupported) {
            this.activePlayer.shuffle = shuffle
        }
    }

    function setActivePlayer(player) {
        const targetPlayer = player ?? Mpris.players[0]
        console.log(`[Mpris] Active player ${targetPlayer} << ${activePlayer}`)

        if (targetPlayer && this.activePlayer) {
            this.__reverse = Mpris.players.indexOf(targetPlayer) < Mpris.players.indexOf(this.activePlayer)
        } else {
            this.__reverse = false
        }

        this.trackedPlayer = targetPlayer
    }

    // Debug timer
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            console.log(`[MprisController] Players: ${Mpris.players.length}, Active: ${activePlayer?.identity || 'none'}, Playing: ${isPlaying}`)
            if (activePlayer) {
                console.log(`  Track: ${activePlayer.trackTitle || 'Unknown'} by ${activePlayer.trackArtist || 'Unknown'}`)
                console.log(`  State: ${activePlayer.playbackState}`)
            } else if (Mpris.players.length === 0) {
                console.log("  No MPRIS players detected. Try:")
                console.log("    - mpv --script-opts=mpris-title='{{media-title}}' file.mp3")
                console.log("    - firefox/chromium (YouTube, Spotify Web)")
                console.log("    - vlc file.mp3")
                console.log("  Check available players: busctl --user list | grep mpris")
            }
        }
    }
}