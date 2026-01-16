import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property MprisPlayer activePlayer: MprisController.activePlayer
    property var allPlayers: MprisController.availablePlayers
    property var targetScreen: null
    property real popoutX: 0
    property real popoutY: 0
    property real popoutWidth: 0
    property real popoutHeight: 0
    property real contentOffsetY: 0
    property string section: ""
    property int barPosition: SettingsData.Position.Top

    signal showVolumeDropdown(point pos, var screen, bool rightEdge, var player, var players)
    signal showAudioDevicesDropdown(point pos, var screen, bool rightEdge)
    signal showPlayersDropdown(point pos, var screen, bool rightEdge, var player, var players)
    signal hideDropdowns
    signal volumeButtonExited

    property bool volumeExpanded: false
    property bool devicesExpanded: false
    property bool playersExpanded: false

    function resetDropdownStates() {
        volumeExpanded = false;
        devicesExpanded = false;
        playersExpanded = false;
    }

    DankTooltipV2 {
        id: sharedTooltip
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
    readonly property bool volumeAvailable: (activePlayer && activePlayer.volumeSupported && !__isChromeBrowser) || (AudioService.sink && AudioService.sink.audio)
    readonly property bool usePlayerVolume: activePlayer && activePlayer.volumeSupported && !__isChromeBrowser
    readonly property real currentVolume: usePlayerVolume ? activePlayer.volume : (AudioService.sink?.audio?.volume ?? 0)

    property bool isSwitching: false
    property string _lastArtUrl: ""
    property string _bgArtSource: ""

    // Derived "no players" state: always correct, no timers.
    readonly property int _playerCount: allPlayers ? allPlayers.length : 0
    readonly property bool _noneAvailable: _playerCount === 0
    readonly property bool _trulyIdle: activePlayer && activePlayer.playbackState === MprisPlaybackState.Stopped && !activePlayer.trackTitle && !activePlayer.trackArtist
    readonly property bool showNoPlayerNow: (!_switchHold) && (_noneAvailable || _trulyIdle)

    property bool _switchHold: false
    Timer {
        id: _switchHoldTimer
        interval: 650
        repeat: false
        onTriggered: _switchHold = false
    }

    onActivePlayerChanged: {
        if (!activePlayer) {
            isSwitching = false;
            _switchHold = false;
            return;
        }
        isSwitching = true;
        _switchHold = true;
        _switchHoldTimer.restart();
        if (activePlayer.trackArtUrl)
            loadArtwork(activePlayer.trackArtUrl);
    }

    property string activeTrackArtFile: ""

    function loadArtwork(url) {
        if (!url)
            return;
        if (url.startsWith("http://") || url.startsWith("https://")) {
            const filename = "/tmp/.dankshell/trackart_" + Date.now() + ".jpg";
            activeTrackArtFile = filename;

            cleanupProcess.command = ["sh", "-c", "mkdir -p /tmp/.dankshell && find /tmp/.dankshell -name 'trackart_*' ! -name '" + filename.split('/').pop() + "' -delete"];
            cleanupProcess.running = true;

            imageDownloader.command = ["curl", "-L", "-s", "--user-agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36", "-o", filename, url];
            imageDownloader.targetFile = filename;
            imageDownloader.running = true;
            return;
        }
        _bgArtSource = url;
    }

    function maybeFinishSwitch() {
        if (activePlayer && activePlayer.trackTitle !== "") {
            isSwitching = false;
            _switchHold = false;
        }
    }

    readonly property real ratio: {
        if (!activePlayer || !activePlayer.length || activePlayer.length <= 0) {
            return 0;
        }
        const pos = (activePlayer.position || 0) % Math.max(1, activePlayer.length);
        const calculatedRatio = pos / activePlayer.length;
        return Math.max(0, Math.min(1, calculatedRatio));
    }

    implicitWidth: 700
    implicitHeight: 410

    Connections {
        target: activePlayer
        function onTrackTitleChanged() {
            _switchHoldTimer.restart();
            maybeFinishSwitch();
        }
        function onTrackArtUrlChanged() {
            if (activePlayer?.trackArtUrl) {
                _lastArtUrl = activePlayer.trackArtUrl;
                loadArtwork(activePlayer.trackArtUrl);
            }
        }
    }

    Connections {
        target: MprisController
        function onAvailablePlayersChanged() {
            const count = (MprisController.availablePlayers?.length || 0);
            if (count === 0) {
                isSwitching = false;
                _switchHold = false;
            } else {
                _switchHold = true;
                _switchHoldTimer.restart();
            }
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
        const current = Math.round(currentVolume * 100);
        const newVolume = Math.min(100, Math.max(0, current + step));

        SessionData.suppressOSDTemporarily();
        if (usePlayerVolume) {
            activePlayer.volume = newVolume / 100;
        } else if (AudioService.sink?.audio) {
            AudioService.sink.audio.volume = newVolume / 100;
        }
    }

    Process {
        id: imageDownloader
        running: false
        property string targetFile: ""

        onExited: exitCode => {
            if (exitCode === 0 && targetFile)
                _bgArtSource = "file://" + targetFile;
        }
    }

    Process {
        id: cleanupProcess
        running: false
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
        visible: _bgArtSource !== ""

        Image {
            id: bgImage
            anchors.centerIn: parent
            width: Math.max(parent.width, parent.height) * 1.1
            height: width
            source: _bgArtSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: false
            onStatusChanged: {
                if (status === Image.Ready)
                    maybeFinishSwitch();
            }
        }

        Item {
            id: blurredBg
            anchors.fill: parent
            visible: false

            MultiEffect {
                anchors.centerIn: parent
                width: bgImage.width
                height: bgImage.height
                source: bgImage
                blurEnabled: true
                blurMax: 64
                blur: 0.8
                saturation: -0.2
                brightness: -0.25
            }
        }

        Rectangle {
            id: bgMask
            anchors.fill: parent
            radius: Theme.cornerRadius
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: parent
            source: blurredBg
            maskEnabled: true
            maskSource: bgMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
            opacity: 0.7
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: Theme.surface
            opacity: 0.3
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingM
        visible: showNoPlayerNow

        DankIcon {
            name: "music_note"
            size: Theme.iconSize * 3
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: I18n.tr("No Active Players")
            font.pixelSize: Theme.fontSizeLarge
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Item {
        anchors.fill: parent
        clip: false
        visible: !_noneAvailable && (!showNoPlayerNow)
        ColumnLayout {
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
                        text: activePlayer?.trackTitle || "Unknown Track"
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
                        text: activePlayer?.trackArtist || "Unknown Artist"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.8)
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        wrapMode: Text.WordWrap
                        maximumLineCount: 1
                    }

                    StyledText {
                        text: activePlayer?.trackAlbum || ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        wrapMode: Text.WordWrap
                        maximumLineCount: 1
                        visible: text.length > 0
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
                        spacing: 2
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
                                    const pos = activePlayer.length ? rawPos % Math.max(1, activePlayer.length) : rawPos;
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
                                    if (!activePlayer || !activePlayer.length)
                                        return "0:00";
                                    const dur = Math.max(0, activePlayer.length || 0);
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
                                color: shuffleArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "shuffle"
                                    size: 20
                                    color: activePlayer && activePlayer.shuffle ? Theme.primary : Theme.surfaceText
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
                                color: prevBtnArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : "transparent"

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
                                    onClicked: {
                                        if (!activePlayer) {
                                            return;
                                        }

                                        if (activePlayer.position > 8 && activePlayer.canSeek) {
                                            activePlayer.position = 0;
                                        } else {
                                            activePlayer.previous();
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
                                width: 50
                                height: 50
                                radius: 25
                                anchors.centerIn: parent
                                color: Theme.primary

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                                    size: 28
                                    color: Theme.background
                                    weight: 500
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: activePlayer && activePlayer.togglePlaying()
                                }

                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    shadowEnabled: true
                                    shadowHorizontalOffset: 0
                                    shadowVerticalOffset: 0
                                    shadowBlur: 1.0
                                    shadowColor: Qt.rgba(0, 0, 0, 0.3)
                                    shadowOpacity: 0.3
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
                                color: nextBtnArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : "transparent"

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
                                    onClicked: activePlayer && activePlayer.next()
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
                                color: repeatArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

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
                                    color: activePlayer && activePlayer.loopState !== MprisLoopState.None ? Theme.primary : Theme.surfaceText
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
        color: playerSelectorArea.containsMouse || playersExpanded ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : "transparent"
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
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
                    hideDropdowns();
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
            onEntered: sharedTooltip.show("Media Players", playerSelectorButton, 0, 0, isRightEdge ? "right" : "left")
            onExited: sharedTooltip.hide()
        }
    }

    Rectangle {
        id: volumeButton
        width: 40
        height: 40
        radius: 20
        x: isRightEdge ? Theme.spacingM : parent.width - 40 - Theme.spacingM
        y: 130
        color: volumeButtonArea.containsMouse && volumeAvailable || volumeExpanded ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : "transparent"
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, volumeAvailable ? 0.3 : 0.15)
        border.width: 1
        z: 101
        enabled: volumeAvailable

        property real previousVolume: 0.0

        DankIcon {
            anchors.centerIn: parent
            name: getVolumeIcon()
            size: 18
            color: volumeAvailable && currentVolume > 0 ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, volumeAvailable ? 1.0 : 0.5)
        }

        MouseArea {
            id: volumeButtonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: {
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
                    volumeButtonExited();
            }
            onClicked: {
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
            onWheel: wheelEvent => {
                SessionData.suppressOSDTemporarily();
                const delta = wheelEvent.angleDelta.y;
                const current = (currentVolume * 100) || 0;
                const newVolume = delta > 0 ? Math.min(100, current + 5) : Math.max(0, current - 5);

                if (usePlayerVolume) {
                    activePlayer.volume = newVolume / 100;
                } else if (AudioService.sink?.audio) {
                    AudioService.sink.audio.volume = newVolume / 100;
                }
                wheelEvent.accepted = true;
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
        color: audioDevicesArea.containsMouse || devicesExpanded ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : "transparent"
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
        border.width: 1
        z: 100

        DankIcon {
            anchors.centerIn: parent
            name: devicesExpanded ? "expand_less" : "speaker"
            size: 18
            color: Theme.surfaceText
        }

        MouseArea {
            id: audioDevicesArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (devicesExpanded) {
                    hideDropdowns();
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
            onEntered: sharedTooltip.show("Output Device", audioDevicesButton, 0, 0, isRightEdge ? "right" : "left")
            onExited: sharedTooltip.hide()
        }
    }
}
