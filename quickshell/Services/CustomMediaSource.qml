pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

Singleton {
    id: root

    // Signals for OSD and other listeners
    signal playingStateChanged()
    signal trackInfoChanged()
    signal artworkChanged()

    // Media state (populated via IPC hooks)
    property string trackTitle: ""
    property string trackArtist: ""
    property string trackAlbum: ""
    property string trackArtUrl: ""
    property int playbackState: 0  // 0=stopped, 1=playing, 2=paused
    property real position: 0
    property real length: 0
    property real volume: 0.5
    property bool volumeSupported: true
    property bool canControl: true
    property bool canPlay: true
    property bool canPause: true
    property bool canGoNext: true
    property bool canGoPrevious: true
    property bool canSeek: false
    property bool shuffle: false
    property bool shuffleSupported: false
    property int loopState: 0
    property bool loopSupported: false
    property bool available: false
    property string identity: ""
    property string sourceId: ""

    // Internal tracking for change detection
    property string _lastTitle: ""
    property bool _lastIsPlaying: false

    // Playback state constants
    readonly property int stateStopped: 0
    readonly property int statePlaying: 1
    readonly property int statePaused: 2

    // Commands to execute for playback control
    property string _playCommand: ""
    property string _pauseCommand: ""
    property string _toggleCommand: ""
    property string _nextCommand: ""
    property string _previousCommand: ""
    property string _volumeCommand: ""

    readonly property bool isPlaying: playbackState === 1

    // Monitor isPlaying changes
    onIsPlayingChanged: {
        if (isPlaying !== _lastIsPlaying) {
            _lastIsPlaying = isPlaying
            root.playingStateChanged()
        }
    }

    // Monitor trackTitle changes
    onTrackTitleChanged: {
        if (trackTitle !== _lastTitle) {
            _lastTitle = trackTitle
            root.trackInfoChanged()
        }
    }

    // Monitor trackArtUrl changes
    onTrackArtUrlChanged: {
        root.artworkChanged()
    }

    // Called via IPC: media.update '{"title": "...", "artist": "...", ...}'
    function update(data: var) {
        if (data.title !== undefined) trackTitle = data.title
        if (data.artist !== undefined) trackArtist = data.artist
        if (data.album !== undefined) trackAlbum = data.album
        if (data.artUrl !== undefined) trackArtUrl = data.artUrl
        if (data.state !== undefined) playbackState = data.state
        if (data.position !== undefined) position = data.position
        if (data.length !== undefined) length = data.length
        if (data.elapsed !== undefined) position = data.elapsed
        if (data.duration !== undefined) length = data.duration
        if (data.volume !== undefined) volume = data.volume
        if (data.available !== undefined) available = data.available
        if (data.identity !== undefined) identity = data.identity
        if (data.sourceId !== undefined) sourceId = data.sourceId
    }

    function setCommands(cmds: var) {
        if (cmds.play !== undefined) _playCommand = cmds.play
        if (cmds.pause !== undefined) _pauseCommand = cmds.pause
        if (cmds.toggle !== undefined) _toggleCommand = cmds.toggle
        if (cmds.next !== undefined) _nextCommand = cmds.next
        if (cmds.previous !== undefined) _previousCommand = cmds.previous
        if (cmds.prev !== undefined) _previousCommand = cmds.prev
        if (cmds.volume !== undefined) _volumeCommand = cmds.volume
    }

    function _exec(cmd) {
        if (cmd) Quickshell.execDetached(["sh", "-c", cmd])
    }

    function play() {
        playbackState = statePlaying
        _exec(_playCommand)
    }

    function pause() {
        playbackState = statePaused
        _exec(_pauseCommand)
    }

    function togglePlaying() {
        playbackState = isPlaying ? statePaused : statePlaying
        _exec(_toggleCommand)
    }

    function next() {
        _exec(_nextCommand)
    }

    function previous() {
        _exec(_previousCommand)
    }

    function stop() {
        playbackState = stateStopped
        _exec(_pauseCommand)
    }

    function clear() {
        trackTitle = ""
        trackArtist = ""
        trackAlbum = ""
        trackArtUrl = ""
        playbackState = 0
        position = 0
        length = 0
        available = false
        identity = ""
        sourceId = ""
    }
}
