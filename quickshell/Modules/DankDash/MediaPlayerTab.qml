import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

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
    readonly property bool _noneAvailable: _playerCount === 0
    readonly property bool showNoPlayerNow: (!_switchHold) && (_noneAvailable || !activePlayer)

    property bool _switchHold: false
    Timer {
        id: _switchHoldTimer
        interval: 1500
        repeat: false
        onTriggered: _switchHold = false
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
    implicitHeight: playerContent.height + playerContent.anchors.topMargin * 2

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

    function adjustVolume(step) {
        if (!volumeAvailable)
            return;
        const maxVol = usePlayerVolume ? 100 : AudioService.sinkMaxVolume;
        const current = Math.round(currentVolume * 100);
        const newVolume = Math.min(maxVol, Math.max(0, current + step));

        SessionData.suppressOSDTemporarily();
        if (usePlayerVolume) {
            activePlayer.volume = newVolume / 100;
        } else if (AudioService.sink?.audio) {
            AudioService.sink.audio.volume = newVolume / 100;
        }
    }

    function triggerVolumeDropdown() {
        if (!volumeAvailable)
            return;
        if (volumeExpanded)
            return;
        hideDropdowns();
        volumeExpanded = true;
        const buttonsOnRight = !isRightEdge;
        const btnY = volumeButton.y + volumeButton.height / 2;
        const screenX = buttonsOnRight ? (popoutX + popoutWidth) : popoutX;
        const screenY = popoutY + contentOffsetY + btnY;
        showVolumeDropdown(Qt.point(screenX, screenY), targetScreen, buttonsOnRight, activePlayer, allPlayers);
    }

    function toggleMute() {
        if (!volumeAvailable)
            return;
        SessionData.suppressOSDTemporarily();
        if (currentVolume > 0) {
            volumeButton.previousVolume = currentVolume;
            if (usePlayerVolume) {
                activePlayer.volume = 0;
            } else if (AudioService.sink?.audio) {
                AudioService.sink.audio.volume = 0;
            }
        } else {
            const restoreVolume = volumeButton.previousVolume > 0 ? volumeButton.previousVolume : 0.5;
            if (usePlayerVolume) {
                activePlayer.volume = restoreVolume;
            } else if (AudioService.sink?.audio) {
                AudioService.sink.audio.volume = restoreVolume;
            }
        }
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
        running: activePlayer?.playbackState === MprisPlaybackState.Playing && !isSeeking
        repeat: true
        onTriggered: activePlayer?.positionChanged()
    }

    Item {
        id: bgContainer
        anchors.fill: parent

        // Fall back to the live mpris url so the background is never blank.
        readonly property string curArt: {
            const resolved = TrackArtService.resolvedArtUrl;
            if (resolved !== "")
                return resolved;
            const p = root.activePlayer;
            if (!p)
                return "";
            if (p.trackArtUrl)
                return p.trackArtUrl;
            const m = p.metadata;
            return m && m["mpris:artUrl"] ? m["mpris:artUrl"].toString() : "";
        }
        // Two layers crossfade: new art loads into the hidden one and fades in once decoded.
        property bool _showA: true
        visible: layerA.ready || layerB.ready

        onCurArtChanged: syncArt()
        Component.onCompleted: syncArt()

        function syncArt() {
            if (curArt === "")
                return;
            const front = _showA ? layerA : layerB;
            const back = _showA ? layerB : layerA;
            if (front.art == curArt)
                return;
            if (back.art == curArt) {
                // Already decoded in the hidden layer; flip once ready (else promote() does).
                if (back.ready)
                    _showA = !_showA;
                return;
            }
            back.art = curArt;
        }

        // Flip to the hidden layer only when it holds the current art, ignoring stale
        // Ready re-emits (e.g. popout re-expose) that would otherwise ping-pong _showA.
        function promote(layer) {
            const back = _showA ? layerB : layerA;
            if (layer !== back)
                return;
            if (layer.art != curArt)
                return;
            _showA = (layer === layerA);
            root.maybeFinishSwitch();
        }

        BgBlurLayer {
            id: layerA
            front: bgContainer._showA
            onLoaded: bgContainer.promote(layerA)
        }

        BgBlurLayer {
            id: layerB
            front: !bgContainer._showA
            onLoaded: bgContainer.promote(layerB)
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: Theme.surface
            opacity: 0.3
        }
    }

    component BgBlurLayer: ClippingRectangle {
        id: layer
        property alias art: layerImg.source
        readonly property bool ready: layerImg.status === Image.Ready && layerImg.source != ""
        property bool front: false
        signal loaded

        anchors.fill: parent
        radius: Theme.cornerRadius
        color: "transparent"
        antialiasing: true
        opacity: front ? 0.7 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 350
                easing.type: Easing.InOutQuad
            }
        }

        Image {
            id: layerImg
            anchors.centerIn: parent
            width: Math.max(parent.width, parent.height) * 1.1
            height: width
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: false
            onStatusChanged: {
                if (status === Image.Ready && source != "")
                    layer.loaded();
            }
        }

        MultiEffect {
            anchors.centerIn: parent
            width: layerImg.width
            height: layerImg.height
            source: layerImg
            blurEnabled: true
            blurMax: 64
            blur: 0.8
            saturation: -0.2
            brightness: -0.25
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingM
        visible: showNoPlayerNow

        DankIcon {
            name: "music_note"
            size: Theme.iconSize * 3
            color: Theme.surfaceTextSecondary
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: I18n.tr("No Active Players")
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.surfaceTextMedium
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Item {
        anchors.fill: parent
        clip: false
        visible: !_noneAvailable && (!showNoPlayerNow)
        ColumnLayout {
            id: playerContent
            width: 484
            height: 370
            spacing: Theme.spacingXS
            anchors.top: parent.top
            anchors.topMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter

            Item {
                width: parent.width
                height: 200
                clip: false

                DankAlbumArt {
                    width: Math.min(parent.width * 0.8, parent.height * 0.9)
                    height: width
                    anchors.centerIn: parent
                    activePlayer: root.activePlayer
                }
            }

            // Song Info and Controls Section
            Item {
                width: parent.width
                Layout.fillHeight: true

                Column {
                    id: songInfo
                    width: parent.width
                    spacing: Theme.spacingXS
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter

                    StyledText {
                        text: MprisController.stableTitle || I18n.tr("Unknown Track")
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                    }

                    StyledText {
                        text: MprisController.stableArtist || I18n.tr("Unknown Artist")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceTextMedium
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        wrapMode: Text.WordWrap
                        maximumLineCount: 1
                    }

                    StyledText {
                        text: activePlayer?.trackAlbum || ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextSecondary
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        wrapMode: Text.WordWrap
                        maximumLineCount: 1
                        // Reserve the line so late album metadata doesn't shift the seekbar.
                        height: Math.max(implicitHeight, Theme.fontSizeSmall * 1.4)
                    }
                }

                Item {
                    id: seekbarContainer
                    width: parent.width
                    anchors.top: songInfo.bottom
                    anchors.bottom: playbackControls.top
                    anchors.horizontalCenter: parent.horizontalCenter

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXXS
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: parent.height * 0.2

                        DankSeekbar {
                            width: parent.width * 0.8
                            height: 20
                            anchors.horizontalCenter: parent.horizontalCenter
                            activePlayer: root.activePlayer
                            isSeeking: root.isSeeking
                            onIsSeekingChanged: root.isSeeking = isSeeking
                        }

                        Item {
                            width: parent.width * 0.8
                            height: 16
                            anchors.horizontalCenter: parent.horizontalCenter

                            StyledText {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    if (!activePlayer)
                                        return "0:00";
                                    const rawPos = Math.max(0, activePlayer.position || 0);
                                    const pos = stableLength ? rawPos % Math.max(1, stableLength) : rawPos;
                                    const minutes = Math.floor(pos / 60);
                                    const seconds = Math.floor(pos % 60);
                                    const timeStr = minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
                                    return timeStr;
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    if (!activePlayer || stableLength <= 0)
                                        return "--:--";
                                    const dur = stableLength;
                                    const minutes = Math.floor(dur / 60);
                                    const seconds = Math.floor(dur % 60);
                                    return minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
                    }
                }

                Item {
                    id: playbackControls
                    width: parent.width
                    height: 50
                    anchors.bottom: parent.bottom

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingM
                        height: parent.height

                        Item {
                            width: 50
                            height: 50
                            anchors.verticalCenter: parent.verticalCenter
                            visible: activePlayer && activePlayer.shuffleSupported

                            Rectangle {
                                width: 40
                                height: 40
                                radius: 20
                                anchors.centerIn: parent
                                color: shuffleArea.containsMouse ? root.accentHover : Theme.withAlpha(root.accent, 0)

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "shuffle"
                                    size: 20
                                    color: activePlayer && activePlayer.shuffle ? root.accent : Theme.surfaceText
                                }

                                MouseArea {
                                    id: shuffleArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (activePlayer && activePlayer.canControl && activePlayer.shuffleSupported) {
                                            activePlayer.shuffle = !activePlayer.shuffle;
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            width: 50
                            height: 50
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                width: 40
                                height: 40
                                radius: 20
                                anchors.centerIn: parent
                                color: prevBtnArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : Theme.withAlpha(Theme.surfaceContainerHigh, 0)

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "skip_previous"
                                    size: 24
                                    color: Theme.surfaceText
                                }

                                MouseArea {
                                    id: prevBtnArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: MprisController.previousOrRewind()
                                }
                            }
                        }

                        Item {
                            width: 50
                            height: 50
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                width: 50
                                height: 50
                                radius: 25
                                anchors.centerIn: parent
                                color: root.accent

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                                    size: 28
                                    color: root.onAccent
                                    weight: 500
                                }

                                StateLayer {
                                    id: playPauseArea
                                    disabled: !root.activePlayer || !root.activePlayer.canTogglePlaying
                                    stateColor: root.onAccent
                                    cornerRadius: parent.radius
                                    onClicked: root.activePlayer.togglePlaying()
                                }

                                ElevationShadow {
                                    anchors.fill: parent
                                    z: -1
                                    level: Theme.elevationLevel1
                                    fallbackOffset: 1
                                    targetRadius: parent.radius
                                    targetColor: parent.color
                                    shadowOpacity: Theme.elevationLevel1 && Theme.elevationLevel1.alpha !== undefined ? Theme.elevationLevel1.alpha : 0.2
                                    shadowEnabled: Theme.elevationEnabled
                                }
                            }
                        }

                        Item {
                            width: 50
                            height: 50
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                width: 40
                                height: 40
                                radius: 20
                                anchors.centerIn: parent
                                color: nextBtnArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : Theme.withAlpha(Theme.surfaceContainerHigh, 0)

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "skip_next"
                                    size: 24
                                    color: Theme.surfaceText
                                }

                                MouseArea {
                                    id: nextBtnArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: MprisController.next()
                                }
                            }
                        }

                        Item {
                            width: 50
                            height: 50
                            anchors.verticalCenter: parent.verticalCenter
                            visible: activePlayer && activePlayer.loopSupported

                            Rectangle {
                                width: 40
                                height: 40
                                radius: 20
                                anchors.centerIn: parent
                                color: repeatArea.containsMouse ? root.accentHover : Theme.withAlpha(root.accent, 0)

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: {
                                        if (!activePlayer)
                                            return "repeat";
                                        switch (activePlayer.loopState) {
                                        case MprisLoopState.Track:
                                            return "repeat_one";
                                        case MprisLoopState.Playlist:
                                            return "repeat";
                                        default:
                                            return "repeat";
                                        }
                                    }
                                    size: 20
                                    color: activePlayer && activePlayer.loopState !== MprisLoopState.None ? root.accent : Theme.surfaceText
                                }

                                MouseArea {
                                    id: repeatArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (activePlayer && activePlayer.canControl && activePlayer.loopSupported) {
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
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: playerSelectorButton
        width: 40
        height: 40
        radius: 20
        x: isRightEdge ? Theme.spacingM : parent.width - 40 - Theme.spacingM
        y: 185
        color: playerSelectorArea.containsMouse || playersExpanded ? root.accentPressed : Theme.withAlpha(root.accentPressed, 0)
        border.color: Theme.outlineStrong
        border.width: 1
        z: 100
        visible: (allPlayers?.length || 0) >= 1

        DankIcon {
            anchors.centerIn: parent
            name: "assistant_device"
            size: 18
            color: Theme.surfaceText
        }

        MouseArea {
            id: playerSelectorArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (playersExpanded) {
                    const players = (root.allPlayers || []).filter(p => p && !MprisController.isIdle(p));
                    if (players.length > 1) {
                        let currentIndex = -1;
                        for (let i = 0; i < players.length; i++) {
                            if (players[i] === root.activePlayer) {
                                currentIndex = i;
                                break;
                            }
                        }
                        const nextIndex = (currentIndex + 1) % players.length;
                        MprisController.setActivePlayer(players[nextIndex]);
                    }
                    return;
                }
                hideDropdowns();
                playersExpanded = true;
                const buttonsOnRight = !isRightEdge;
                const btnY = playerSelectorButton.y + playerSelectorButton.height / 2;
                const screenX = buttonsOnRight ? (popoutX + popoutWidth) : popoutX;
                const screenY = popoutY + contentOffsetY + btnY;
                showPlayersDropdown(Qt.point(screenX, screenY), targetScreen, buttonsOnRight, activePlayer, allPlayers);
            }
            onEntered: {
                dropdownButtonEntered();
                if (playersExpanded)
                    return;
                hideDropdowns();
                playersExpanded = true;
                const buttonsOnRight = !isRightEdge;
                const btnY = playerSelectorButton.y + playerSelectorButton.height / 2;
                const screenX = buttonsOnRight ? (popoutX + popoutWidth) : popoutX;
                const screenY = popoutY + contentOffsetY + btnY;
                showPlayersDropdown(Qt.point(screenX, screenY), targetScreen, buttonsOnRight, activePlayer, allPlayers);
            }
            onExited: {
                if (playersExpanded)
                    dropdownButtonExited();
            }
        }
    }

    Rectangle {
        id: volumeButton
        width: 40
        height: 40
        radius: 20
        x: isRightEdge ? Theme.spacingM : parent.width - 40 - Theme.spacingM
        y: 130
        color: volumeButtonArea.containsMouse && volumeAvailable || volumeExpanded ? root.accentPressed : Theme.withAlpha(root.accentPressed, 0)
        border.color: volumeAvailable ? Theme.outlineStrong : Theme.outlineMedium
        border.width: 1
        z: 101
        enabled: volumeAvailable

        property real previousVolume: 0.0

        DankIcon {
            anchors.centerIn: parent
            name: getVolumeIcon()
            size: 18
            color: volumeAvailable && currentVolume > 0 ? root.accent : Theme.withAlpha(Theme.surfaceText, volumeAvailable ? 1.0 : 0.5)
        }

        MouseArea {
            id: volumeButtonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: {
                dropdownButtonEntered();
                if (volumeExpanded)
                    return;
                hideDropdowns();
                volumeExpanded = true;
                const buttonsOnRight = !isRightEdge;
                const btnY = volumeButton.y + volumeButton.height / 2;
                const screenX = buttonsOnRight ? (popoutX + popoutWidth) : popoutX;
                const screenY = popoutY + contentOffsetY + btnY;
                showVolumeDropdown(Qt.point(screenX, screenY), targetScreen, buttonsOnRight, activePlayer, allPlayers);
            }
            onExited: {
                if (volumeExpanded)
                    dropdownButtonExited();
            }
            onClicked: {
                toggleMute();
            }
            property real wheelAccum: 0
            onWheel: wheelEvent => {
                wheelEvent.accepted = true;
                wheelAccum += wheelEvent.angleDelta.y;
                const notches = wheelAccum > 0 ? Math.floor(wheelAccum / 120) : Math.ceil(wheelAccum / 120);
                if (notches === 0)
                    return;
                wheelAccum -= notches * 120;
                root.adjustVolume(notches * AudioService.wheelVolumeStep);
            }
        }
    }

    Rectangle {
        id: audioDevicesButton
        width: 40
        height: 40
        radius: 20
        x: isRightEdge ? Theme.spacingM : parent.width - 40 - Theme.spacingM
        y: 240
        color: audioDevicesArea.containsMouse || devicesExpanded ? root.accentPressed : Theme.withAlpha(root.accentPressed, 0)
        border.color: Theme.outlineStrong
        border.width: 1
        z: 100

        DankIcon {
            anchors.centerIn: parent
            name: "speaker"
            size: 18
            color: Theme.surfaceText
        }

        MouseArea {
            id: audioDevicesArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: mouse => {
                if (mouse.button === Qt.RightButton) {
                    mouse.accepted = true;
                }
            }
            onWheel: wheelEvent => {
                const delta = wheelEvent.angleDelta.y;
                if (delta !== 0) {
                    AudioService.cycleAudioOutputDirection(delta < 0);
                    wheelEvent.accepted = true;
                }
            }
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    if (AudioService.sink?.audio) {
                        SessionData.suppressOSDTemporarily();
                        AudioService.sink.audio.muted = !AudioService.sink.audio.muted;
                    }
                    return;
                }
                if (devicesExpanded) {
                    const sinks = AudioService.getAvailableSinks();
                    if (sinks && sinks.length > 1) {
                        let currentIndex = -1;
                        for (let i = 0; i < sinks.length; i++) {
                            if (sinks[i]?.name === AudioService.sink?.name) {
                                currentIndex = i;
                                break;
                            }
                        }
                        const nextIndex = (currentIndex + 1) % sinks.length;
                        AudioService.setSink(sinks[nextIndex]);
                    }
                    return;
                }
                hideDropdowns();
                devicesExpanded = true;
                const buttonsOnRight = !isRightEdge;
                const btnY = audioDevicesButton.y + audioDevicesButton.height / 2;
                const screenX = buttonsOnRight ? (popoutX + popoutWidth) : popoutX;
                const screenY = popoutY + contentOffsetY + btnY;
                showAudioDevicesDropdown(Qt.point(screenX, screenY), targetScreen, buttonsOnRight);
            }
            onEntered: {
                dropdownButtonEntered();
                if (devicesExpanded)
                    return;
                hideDropdowns();
                devicesExpanded = true;
                const buttonsOnRight = !isRightEdge;
                const btnY = audioDevicesButton.y + audioDevicesButton.height / 2;
                const screenX = buttonsOnRight ? (popoutX + popoutWidth) : popoutX;
                const screenY = popoutY + contentOffsetY + btnY;
                showAudioDevicesDropdown(Qt.point(screenX, screenY), targetScreen, buttonsOnRight);
            }
            onExited: {
                if (devicesExpanded)
                    dropdownButtonExited();
            }
        }
    }
}
