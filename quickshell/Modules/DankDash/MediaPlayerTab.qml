import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property real stableLength: MprisController.activePlayerStableLength
    property var allPlayers: MprisController.availablePlayers
    property var targetScreen: null
    property real popoutX: 0
    property real popoutY: 0
    property real popoutWidth: 0
    property real popoutHeight: 0
    property real contentOffsetY: 0
    property string section: ""
    property int barPosition: SettingsData.Position.Top
    property bool live: Window.window?.visible ?? false
    property bool menusEnabled: true
    property string chrome: "dash"
    property bool wallpaperEnabled: SettingsData.mediaWallpaperEnabled
    readonly property bool islandChrome: chrome === "island"

    readonly property color accent: MediaAccentService.accent
    readonly property color onAccent: MediaAccentService.onAccent
    readonly property color accentHover: MediaAccentService.accentHover
    readonly property color accentPressed: MediaAccentService.accentPressed

    signal showVolumeDropdown(point pos, var screen, bool rightEdge, var player, var players)
    signal showAudioDevicesDropdown(point pos, var screen, bool rightEdge)
    signal showPlayersDropdown(point pos, var screen, bool rightEdge, var player, var players)
    signal hideDropdowns
    signal dropdownButtonExited
    signal dropdownButtonEntered

    property bool volumeExpanded: false
    property bool devicesExpanded: false
    property bool playersExpanded: false
    property real previousVolume: 0.0

    function resetDropdownStates() {
        volumeExpanded = false;
        devicesExpanded = false;
        playersExpanded = false;
    }

    readonly property bool isRightEdge: {
        if (barPosition === SettingsData.Position.Right)
            return true;
        if (barPosition === SettingsData.Position.Left)
            return false;
        return section === "right";
    }
    readonly property bool __isChromeBrowser: {
        if (!activePlayer?.identity)
            return false;
        const id = activePlayer.identity.toLowerCase();
        return id.includes("chrome") || id.includes("chromium");
    }
    readonly property bool volumeAvailable: !!((activePlayer && activePlayer.volumeSupported && !__isChromeBrowser) || (AudioService.sink && AudioService.sink.audio))
    readonly property bool usePlayerVolume: activePlayer && activePlayer.volumeSupported && !__isChromeBrowser
    readonly property real currentVolume: usePlayerVolume ? activePlayer.volume : (AudioService.sink?.audio?.volume ?? 0)

    property bool isSwitching: false

    // Derived "no players" state: always correct, no timers.
    readonly property int _playerCount: allPlayers ? allPlayers.length : 0
    readonly property bool noneAvailable: _playerCount === 0
    readonly property bool showNoPlayerNow: (!_switchHold) && (noneAvailable || !activePlayer)

    property bool _switchHold: false
    Timer {
        id: _switchHoldTimer
        interval: 1500
        repeat: false
        onTriggered: _switchHold = false
    }

    onMenusEnabledChanged: {
        if (!root.menusEnabled) {
            resetDropdownStates();
            hideDropdowns();
        }
    }

    onActivePlayerChanged: {
        if (!activePlayer) {
            isSwitching = false;
            _switchHold = true;
            _switchHoldTimer.restart();
            return;
        }
        isSwitching = true;
        _switchHold = true;
        _switchHoldTimer.restart();
    }

    function maybeFinishSwitch() {
        if (activePlayer && activePlayer.trackTitle !== "") {
            isSwitching = false;
            _switchHold = false;
        }
    }

    readonly property real ratio: {
        if (!activePlayer || stableLength <= 0) {
            return 0;
        }
        const pos = (activePlayer.position || 0) % Math.max(1, stableLength);
        const calculatedRatio = pos / stableLength;
        return Math.max(0, Math.min(1, calculatedRatio));
    }

    implicitWidth: SettingsData.showWeekNumber ? 736 : 700
    implicitHeight: chromeLoader.item?.implicitHeight ?? 410

    Connections {
        target: activePlayer
        ignoreUnknownSignals: true
        function onTrackTitleChanged() {
            _switchHoldTimer.restart();
            maybeFinishSwitch();
        }
    }

    Connections {
        target: MprisController
        function onAvailablePlayersChanged() {
            if ((MprisController.availablePlayers?.length || 0) === 0)
                isSwitching = false;
            _switchHold = true;
            _switchHoldTimer.restart();
        }
    }

    function getAudioDeviceIcon(device) {
        if (!device || !device.name)
            return "speaker";

        const name = device.name.toLowerCase();

        if (name.includes("bluez") || name.includes("bluetooth"))
            return "headset";
        if (name.includes("hdmi"))
            return "tv";
        if (name.includes("usb"))
            return "headset";
        if (name.includes("analog") || name.includes("built-in"))
            return "speaker";

        return "speaker";
    }

    function getVolumeIcon() {
        if (!volumeAvailable)
            return "volume_off";

        const volume = currentVolume;

        if (usePlayerVolume) {
            if (volume === 0.0)
                return "music_off";
            return "music_note";
        }

        if (volume === 0.0)
            return "volume_off";
        if (volume <= 0.33)
            return "volume_down";
        if (volume <= 0.66)
            return "volume_up";
        return "volume_up";
    }

    readonly property real maxVolumePercent: usePlayerVolume ? 100 : AudioService.sinkMaxVolume

    function setVolume(ratio) {
        if (!volumeAvailable)
            return;
        const clamped = Math.min(maxVolumePercent / 100, Math.max(0, ratio));
        SessionData.suppressOSDTemporarily();
        if (usePlayerVolume) {
            activePlayer.volume = clamped;
            return;
        }
        if (AudioService.sink?.audio)
            AudioService.sink.audio.volume = clamped;
    }

    function adjustVolume(step) {
        setVolume((Math.round(currentVolume * 100) + step) / 100);
    }

    function dropdownAnchor(button) {
        const buttonsOnRight = !root.isRightEdge;
        const btnY = button.mapToItem(root, 0, button.height / 2).y;
        return {
            "pos": Qt.point(buttonsOnRight ? (root.popoutX + root.popoutWidth) : root.popoutX, root.popoutY + root.contentOffsetY + btnY),
            "rightEdge": buttonsOnRight
        };
    }

    function triggerVolumeDropdown() {
        if (!root.menusEnabled || !volumeAvailable || volumeExpanded)
            return;
        const anchor = dropdownAnchor(chromeLoader.item.volumeButton);
        hideDropdowns();
        volumeExpanded = true;
        showVolumeDropdown(anchor.pos, targetScreen, anchor.rightEdge, activePlayer, allPlayers);
    }

    function triggerPlayersDropdown() {
        if (!root.menusEnabled || playersExpanded)
            return;
        const anchor = dropdownAnchor(chromeLoader.item.playerSelectorButton);
        hideDropdowns();
        playersExpanded = true;
        showPlayersDropdown(anchor.pos, targetScreen, anchor.rightEdge, activePlayer, allPlayers);
    }

    function triggerDevicesDropdown() {
        if (!root.menusEnabled || devicesExpanded)
            return;
        const anchor = dropdownAnchor(chromeLoader.item.audioDevicesButton);
        hideDropdowns();
        devicesExpanded = true;
        showAudioDevicesDropdown(anchor.pos, targetScreen, anchor.rightEdge);
    }

    function cycleNextPlayer() {
        const players = (root.allPlayers || []).filter(p => p && !MprisController.isIdle(p));
        if (players.length < 2)
            return;
        let currentIndex = -1;
        for (let i = 0; i < players.length; i++) {
            if (players[i] === root.activePlayer) {
                currentIndex = i;
                break;
            }
        }
        MprisController.setActivePlayer(players[(currentIndex + 1) % players.length]);
    }

    function cycleNextSink() {
        const sinks = AudioService.getAvailableSinks();
        if (!sinks || sinks.length < 2)
            return;
        let currentIndex = -1;
        for (let i = 0; i < sinks.length; i++) {
            if (sinks[i]?.name === AudioService.sink?.name) {
                currentIndex = i;
                break;
            }
        }
        AudioService.setSink(sinks[(currentIndex + 1) % sinks.length]);
    }

    function cycleLoopState() {
        if (!activePlayer?.canControl || !activePlayer.loopSupported)
            return;
        switch (activePlayer.loopState) {
        case MprisLoopState.None:
            activePlayer.loopState = MprisLoopState.Playlist;
            break;
        case MprisLoopState.Playlist:
            activePlayer.loopState = MprisLoopState.Track;
            break;
        case MprisLoopState.Track:
            activePlayer.loopState = MprisLoopState.None;
            break;
        }
    }

    function toggleMute() {
        if (!volumeAvailable)
            return;
        if (currentVolume > 0) {
            root.previousVolume = currentVolume;
            setVolume(0);
            return;
        }
        setVolume(root.previousVolume > 0 ? root.previousVolume : 0.5);
    }

    function handleKeyEvent(event) {
        if (!activePlayer)
            return false;

        // 1. Number keys 0-9 to seek to 0%-90%
        if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
            if (activePlayer.canSeek && stableLength > 0) {
                const ratio = (event.key - Qt.Key_0) * 0.1;
                const targetPosition = ratio * stableLength;
                activePlayer.position = Math.max(0.1, Math.min(targetPosition, stableLength * 0.99));
                return true;
            }
        }

        // 2. Left / Right arrows to seek backward / forward 5s
        if (event.key === Qt.Key_Left) {
            if (activePlayer.canSeek) {
                activePlayer.position = Math.max(0.1, activePlayer.position - 5);
                return true;
            }
        }
        if (event.key === Qt.Key_Right) {
            if (activePlayer.canSeek && stableLength > 0) {
                activePlayer.position = Math.max(0.1, Math.min(stableLength - 1, activePlayer.position + 5));
                return true;
            }
        }

        // 3. Up / Down arrows to adjust volume
        if (event.key === Qt.Key_Up) {
            adjustVolume(5);
            triggerVolumeDropdown();
            dropdownButtonExited();
            return true;
        }
        if (event.key === Qt.Key_Down) {
            adjustVolume(-5);
            triggerVolumeDropdown();
            dropdownButtonExited();
            return true;
        }

        // 4. Spacebar to play/pause
        if (event.key === Qt.Key_Space) {
            if (activePlayer.canTogglePlaying) {
                activePlayer.togglePlaying();
                return true;
            }
        }

        // 5. M key to toggle mute
        if (event.key === Qt.Key_M) {
            toggleMute();
            triggerVolumeDropdown();
            dropdownButtonExited();
            return true;
        }

        return false;
    }

    property bool isSeeking: false

    Timer {
        interval: 1000
        running: root.live && activePlayer?.playbackState === MprisPlaybackState.Playing && !isSeeking
        repeat: true
        onTriggered: activePlayer?.positionChanged()
    }

    Loader {
        id: chromeLoader

        anchors.fill: parent
        sourceComponent: root.islandChrome ? islandChromeComponent : dashChromeComponent
    }

    Component {
        id: dashChromeComponent

        MediaPlayerDashChrome {
            player: root
        }
    }

    Component {
        id: islandChromeComponent

        MediaPlayerIslandChrome {
            player: root
        }
    }
}
