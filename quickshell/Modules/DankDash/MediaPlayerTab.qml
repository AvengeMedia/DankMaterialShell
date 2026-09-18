import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Modules.DankDash.Media

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property real stableLength: MprisController.activePlayerStableLength
    property var allPlayers: MprisController.availablePlayers
    property bool live: Window.window?.visible ?? false
    property string entryId: "media"
    readonly property var options: DashRegistry.resolvedOptions(entryId)
    readonly property string playerStyle: options?.playerStyle ?? MediaOptions.defaultPlayerStyle
    readonly property bool lyricsEnabled: (options?.lyrics ?? MediaOptions.defaults.lyrics) && DMSService.capabilities.includes("lyrics")
    property bool lyricsOpen: false
    property bool playerPaneOpen: true
    property Item lyricsFocusTarget: null
    property Item lyricsOpener: null
    readonly property alias lyrics: lyricsController
    readonly property var presentation: mediaPresentation.current
    readonly property bool presentationSettling: mediaPresentation.settling
    property bool wallpaperEnabled: MediaOptions.albumArtBackdrop
    property string panel: ""
    property Item contentViewport: null
    readonly property bool blocksTabNavigation: panel !== ""
    property bool isSeeking: false
    property real previousVolume: 0.0

    readonly property color accent: MediaAccentService.accent

    readonly property Item focusTarget: mediaChrome.item?.focusTarget ?? null
    readonly property Item previousFocusTarget: mediaChrome.item?.previousFocusTarget ?? null

    readonly property bool __isChromeBrowser: {
        if (!activePlayer?.identity)
            return false;
        const id = activePlayer.identity.toLowerCase();
        return id.includes("chrome") || id.includes("chromium");
    }
    readonly property bool volumeAvailable: !!((activePlayer && activePlayer.volumeSupported && !__isChromeBrowser) || (AudioService.sink && AudioService.sink.audio))
    readonly property bool usePlayerVolume: activePlayer && activePlayer.volumeSupported && !__isChromeBrowser
    readonly property real currentVolume: usePlayerVolume ? activePlayer.volume : (AudioService.sink?.audio?.volume ?? 0)
    readonly property real maxVolumePercent: usePlayerVolume ? 100 : AudioService.sinkMaxVolume

    implicitWidth: DashMetrics.contentWidthFor(SettingsData.showWeekNumber, DashMetrics.panelColumnsFor(entryId))
    implicitHeight: mediaChrome.item?.implicitHeight ?? DashMetrics.tabMinHeight

    onPlayerStyleChanged: {
        panel = "";
        lyricsOpen = false;
        playerPaneOpen = true;
        isSeeking = false;
        restoreLyrics();
    }

    onLyricsEnabledChanged: {
        if (lyricsEnabled) {
            restoreLyrics();
            return;
        }
        lyricsOpen = false;
        playerPaneOpen = true;
    }

    onLyricsOpenChanged: {
        if (!lyricsOpen)
            lyricsFocusTimer.restart();
    }

    LyricsController {
        id: lyricsController
        player: root
        enabled: root.lyricsOpen && root.live && root.lyricsEnabled
    }

    Timer {
        id: lyricsFocusTimer
        interval: 0
        onTriggered: {
            if (!root.live || !root.lyricsOpener?.visible || !root.lyricsOpener.enabled)
                return;
            if (typeof root.lyricsOpener.requestFocus === "function") {
                root.lyricsOpener.requestFocus(false);
                return;
            }
            root.lyricsOpener.forceActiveFocus(Qt.PopupFocusReason);
        }
    }

    MediaPresentation {
        id: mediaPresentation
        player: root
    }

    Timer {
        interval: DashMetrics.mediaPositionPollInterval
        running: root.live && root.activePlayer?.playbackState === MprisPlaybackState.Playing && !root.isSeeking
        repeat: true
        onTriggered: root.activePlayer?.positionChanged()
    }

    onLiveChanged: {
        if (live) {
            restoreLyrics();
            return;
        }
        panel = "";
        lyricsOpen = false;
        playerPaneOpen = true;
    }

    function cycleFocus(backwards) {
        return mediaChrome.item?.cycleFocus(backwards) ?? false;
    }

    function togglePanel(panelId) {
        panel = panel === panelId ? "" : panelId;
    }

    function showPanel(panelId) {
        panel = panelId;
    }

    function revealVolume() {
        if (mediaChrome.item?.inlineVolume)
            return;
        showPanel("volume");
    }

    function restoreLyrics() {
        if (live && lyricsEnabled && CacheData.mediaLyricsOpen)
            lyricsOpen = true;
    }

    function toggleLyrics(opener) {
        if (!lyricsEnabled)
            return;
        lyricsOpener = opener ?? null;
        lyricsOpen = !lyricsOpen;
        CacheData.set("mediaLyricsOpen", lyricsOpen);
        lyricsFocusTimer.stop();
    }

    function getVolumeIcon() {
        if (!volumeAvailable)
            return "volume_off";
        if (usePlayerVolume)
            return currentVolume === 0 ? "music_off" : "music_note";
        return AudioService.sinkVolumeIconName;
    }

    function setVolume(ratio) {
        if (!volumeAvailable)
            return;
        const clamped = Math.min(maxVolumePercent / 100, Math.max(0, ratio));
        SessionData.suppressOSDTemporarily();
        if (usePlayerVolume) {
            activePlayer.volume = clamped;
            return;
        }
        const audio = AudioService.sink?.audio;
        if (!audio)
            return;
        audio.volume = clamped;
        if (clamped > 0)
            audio.muted = false;
    }

    function adjustVolume(step) {
        setVolume((Math.round(currentVolume * 100) + step) / 100);
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
        if (!usePlayerVolume) {
            SessionData.suppressOSDTemporarily();
            AudioService.sink.audio.muted = !AudioService.sink.audio.muted;
            return;
        }
        if (currentVolume > 0) {
            root.previousVolume = currentVolume;
            setVolume(0);
            return;
        }
        setVolume(root.previousVolume > 0 ? root.previousVolume : 0.5);
    }

    function handleKeyEvent(event) {
        if (event.key === Qt.Key_F6)
            return cycleFocus(!!(event.modifiers & Qt.ShiftModifier));
        if (event.key === Qt.Key_Escape) {
            if (panel !== "") {
                const panelId = panel;
                panel = "";
                mediaChrome.item?.focusPanelButton(panelId);
                return true;
            }
            if (!lyricsOpen)
                return false;
            lyricsOpen = false;
            return true;
        }
        if (panel !== "")
            return true;
        if (!activePlayer)
            return false;

        if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
            if (!activePlayer.canSeek || stableLength <= 0)
                return false;
            const targetPosition = (event.key - Qt.Key_0) * 0.1 * stableLength;
            activePlayer.position = Math.max(0.1, Math.min(targetPosition, stableLength * 0.99));
            return true;
        }

        switch (event.key) {
        case Qt.Key_Left:
        case Qt.Key_H:
            if (!activePlayer.canSeek)
                return false;
            activePlayer.position = Math.max(0.1, activePlayer.position - 5);
            return true;
        case Qt.Key_Right:
        case Qt.Key_L:
            if (!activePlayer.canSeek || stableLength <= 0)
                return false;
            activePlayer.position = Math.max(0.1, Math.min(stableLength - 1, activePlayer.position + 5));
            return true;
        case Qt.Key_Up:
        case Qt.Key_K:
            if (!volumeAvailable)
                return false;
            adjustVolume(AudioService.wheelVolumeStep);
            revealVolume();
            return true;
        case Qt.Key_Down:
        case Qt.Key_J:
            if (!volumeAvailable)
                return false;
            adjustVolume(-AudioService.wheelVolumeStep);
            revealVolume();
            return true;
        case Qt.Key_Space:
            if (!activePlayer.canTogglePlaying)
                return false;
            activePlayer.togglePlaying();
            return true;
        case Qt.Key_M:
            if (!volumeAvailable)
                return false;
            toggleMute();
            revealVolume();
            return true;
        }
        return false;
    }

    Loader {
        id: mediaChrome
        anchors.fill: parent
        sourceComponent: root.playerStyle === "material" ? materialChrome : zurvanChrome
    }

    Component {
        id: zurvanChrome
        ZurvanChrome {
            player: root
        }
    }

    Component {
        id: materialChrome
        MaterialChrome {
            player: root
        }
    }
}
