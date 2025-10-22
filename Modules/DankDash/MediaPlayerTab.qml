import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Io
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property MprisPlayer activePlayer: MprisController.activePlayer
    property var allPlayers: MprisController.availablePlayers

    readonly property bool isRightEdge: SettingsData.dankBarPosition === SettingsData.Position.Right
    property var defaultSink: AudioService.sink

    // Palette that stays stable across track switches until new colors are ready
    property color dom: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 1.0)
    property color acc: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.25)
    property color _nextDom: dom
    property color _nextAcc: acc

    // Track-switch hold (prevents banner flicker only during switches)
    property bool isSwitching: false
    property bool paletteReady: false
    property string _lastArtUrl: ""
    property url _cqSource: ""

    // Derived "no players" state: always correct, no timers.
    readonly property int _playerCount: allPlayers ? allPlayers.length : 0
    readonly property bool _noneAvailable: _playerCount === 0
    readonly property bool _trulyIdle: activePlayer
          && activePlayer.playbackState === MprisPlaybackState.Stopped
          && !activePlayer.trackTitle && !activePlayer.trackArtist
    readonly property bool showNoPlayerNow: (!_switchHold) && (_noneAvailable || _trulyIdle)

    // Short hold only during track switches (not when players disappear)
    property bool _switchHold: false
    Timer {
      id: _switchHoldTimer
      interval: 650
      repeat: false
      onTriggered: _switchHold = false
    }

    onActivePlayerChanged: {
        isSwitching = true
        _switchHold = true
        paletteReady = false
        _switchHoldTimer.restart()
        if (activePlayer && activePlayer.trackArtUrl) {
            loadArtwork(activePlayer.trackArtUrl)
        }
    }

    property string activeTrackArtFile: ""

    function loadArtwork(url) {
        if (!url) return

        if (url.startsWith("http://") || url.startsWith("https://")) {
            const filename = "/tmp/.dankshell/trackart_" + Date.now() + ".jpg"
            activeTrackArtFile = filename

            cleanupProcess.command = ["sh", "-c", "mkdir -p /tmp/.dankshell && find /tmp/.dankshell -name 'trackart_*' ! -name '" + filename.split('/').pop() + "' -delete"]
            cleanupProcess.running = true

            imageDownloader.command = ["curl", "-L", "-s", "--user-agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36", "-o", filename, url]
            imageDownloader.targetFile = filename
            imageDownloader.running = true
        } else {
            _preloadImage.source = url
        }
    }

    function maybeFinishSwitch() {
        if (activePlayer && activePlayer.trackTitle !== "" && paletteReady) {
            isSwitching = false
            _switchHold = false
        }
    }

    readonly property real ratio: {
        if (!activePlayer || !activePlayer.length || activePlayer.length <= 0) {
            return 0
        }
        const pos = (activePlayer.position || 0) % Math.max(1, activePlayer.length)
        const calculatedRatio = pos / activePlayer.length
        return Math.max(0, Math.min(1, calculatedRatio))
    }

    implicitWidth: 700
    implicitHeight: 410

    Connections {
        target: activePlayer
        function onTrackTitleChanged() {
            _switchHoldTimer.restart()
            maybeFinishSwitch()
        }
        function onTrackArtUrlChanged() {
            if (activePlayer?.trackArtUrl) {
                _lastArtUrl = activePlayer.trackArtUrl
                loadArtwork(activePlayer.trackArtUrl)
            }
        }
    }

    Connections {
        target: MprisController
        function onAvailablePlayersChanged() {
            const count = (MprisController.availablePlayers?.length || 0)
            if (count === 0) {
                isSwitching = false
                _switchHold = false
            } else {
                _switchHold = true
                _switchHoldTimer.restart()
            }
        }
    }

    function getAudioDeviceIcon(device) {
        if (!device || !device.name) return "speaker"

        const name = device.name.toLowerCase()

        if (name.includes("bluez") || name.includes("bluetooth"))
            return "headset"
        if (name.includes("hdmi"))
            return "tv"
        if (name.includes("usb"))
            return "headset"
        if (name.includes("analog") || name.includes("built-in"))
            return "speaker"

        return "speaker"
    }

    function getVolumeIcon(sink) {
        if (!sink || !sink.audio) return "volume_off"

        const volume = sink.audio.volume
        const muted = sink.audio.muted

        if (muted || volume === 0.0) return "volume_off"
        if (volume <= 0.33) return "volume_down"
        if (volume <= 0.66) return "volume_up"
        return "volume_up"
    }

    function adjustVolume(step) {
        if (!defaultSink?.audio) return

        const currentVolume = Math.round(defaultSink.audio.volume * 100)
        const newVolume = Math.min(100, Math.max(0, currentVolume + step))

        defaultSink.audio.volume = newVolume / 100
        if (newVolume > 0 && defaultSink.audio.muted) {
            defaultSink.audio.muted = false
        }
    }

    Process {
        id: imageDownloader
        running: false
        property string targetFile: ""

        onExited: (exitCode) => {
            if (exitCode === 0 && targetFile) {
                _preloadImage.source = "file://" + targetFile
            }
        }
    }

    Process {
        id: cleanupProcess
        running: false
    }

    Image {
        id: _preloadImage
        source: ""
        asynchronous: true
        cache: true
        visible: false
        onStatusChanged: {
            if (status === Image.Ready) {
                _cqSource = source
                colorQuantizer.source = _cqSource
            }
            else if (status === Image.Error) {
                _cqSource = ""
            }
        }
    }

    ColorQuantizer {
        id: colorQuantizer
        source: _cqSource !== "" ? _cqSource : undefined
        depth: 8
        rescaleSize: 32
        onColorsChanged: {
            if (!colors || colors.length === 0) return

            function enhanceColor(color) {
                const satBoost = 1.4
                const valueBoost = 1.2
                return Qt.hsva(color.hsvHue, Math.min(1, color.hsvSaturation * satBoost), Math.min(1, color.hsvValue * valueBoost), color.a)
            }

            function getExtremeColor(startIdx, direction = 1) {
                let bestColor = colors[startIdx]
                let bestScore = 0

                for (let i = startIdx; i >= 0 && i < colors.length; i += direction) {
                    const c = colors[i]
                    const saturation = c.hsvSaturation
                    const brightness = c.hsvValue
                    const contrast = Math.abs(brightness - 0.5) * 2
                    const score = saturation * 0.7 + contrast * 0.3

                    if (score > bestScore) {
                        bestScore = score
                        bestColor = c
                    }
                }

                return enhanceColor(bestColor)
            }

            _pendingDom = getExtremeColor(Math.floor(colors.length * 0.2), 1)
            _pendingAcc = getExtremeColor(Math.floor(colors.length * 0.8), -1)
            paletteApplyDelay.restart()
        }
    }

    property color _pendingDom: dom
    property color _pendingAcc: acc
    Timer {
        id: paletteApplyDelay
        interval: 90
        repeat: false
        onTriggered: {
            const dist = (c1, c2) => {
                const dr = c1.r - c2.r, dg = c1.g - c2.g, db = c1.b - c2.b
                return Math.sqrt(dr*dr + dg*dg + db*db)
            }
            const domChanged = dist(_pendingDom, dom) > 0.02
            const accChanged = dist(_pendingAcc, acc) > 0.02
            if (domChanged || accChanged) {
                dom = _pendingDom
                acc = _pendingAcc
            }
            paletteReady = true
            maybeFinishSwitch()
        }
    }



    property bool isSeeking: false


    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        opacity: 1.0
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.rgba(dom.r, dom.g, dom.b, paletteReady ? 0.38 : 0.06)
            }
            GradientStop {
                position: 0.3
                color: Qt.rgba(acc.r, acc.g, acc.b, paletteReady ? 0.28 : 0.05)
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, paletteReady ? 0.92 : 0.985)
            }
        }
        Behavior on opacity { NumberAnimation { duration: 160 } }
    }

    Behavior on dom { ColorAnimation { duration: 220; easing.type: Easing.InOutQuad } }
    Behavior on acc { ColorAnimation { duration: 220; easing.type: Easing.InOutQuad } }

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

        MouseArea {
            anchors.fill: parent
            enabled: audioDevicesButton.devicesExpanded || volumeButton.volumeExpanded || playerSelectorButton.playersExpanded
            onClicked: function(mouse) {
                const clickOutside = (item) => {
                    return mouse.x < item.x || mouse.x > item.x + item.width ||
                           mouse.y < item.y || mouse.y > item.y + item.height
                }

                if (playerSelectorButton.playersExpanded && clickOutside(playerSelectorDropdown)) {
                    playerSelectorButton.playersExpanded = false
                }
                if (audioDevicesButton.devicesExpanded && clickOutside(audioDevicesDropdown)) {
                    audioDevicesButton.devicesExpanded = false
                }
                if (volumeButton.volumeExpanded && clickOutside(volumeSliderPanel) && clickOutside(volumeButton)) {
                    volumeButton.volumeExpanded = false
                }
            }
        }

        Popup {
            id: audioDevicesDropdown
            width: 280
            height: audioDevicesButton.devicesExpanded ? Math.max(200, Math.min(280, audioDevicesDropdown.availableDevices.length * 50 + 100)) : 0
            x: isRightEdge ? -width - Theme.spacingS : root.width + Theme.spacingS
            y: audioDevicesButton.y - 50
            visible: audioDevicesButton.devicesExpanded
            closePolicy: Popup.NoAutoClose
            modal: false
            dim: false
            padding: 0

            property var availableDevices: Pipewire.nodes.values.filter(node => {
                return node.audio && node.isSink && !node.isStream
            })

            background: Rectangle {
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.98)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.6)
                border.width: 2
                radius: Theme.cornerRadius * 2

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 8
                    shadowBlur: 1.0
                    shadowColor: Qt.rgba(0, 0, 0, 0.4)
                    shadowOpacity: 0.7
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: Anims.durShort
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Anims.emphasizedDecel
                }
            }

            enter: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Anims.durShort
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Anims.standard
                }
            }

            exit: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: Anims.durShort
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Anims.standard
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingM

                StyledText {
                    text: I18n.tr("Audio Output Devices (") + audioDevicesDropdown.availableDevices.length + ")"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    bottomPadding: Theme.spacingM
                }

                DankFlickable {
                    width: parent.width
                    height: parent.height - 40 
                    contentHeight: deviceColumn.height
                    clip: true

                    Column {
                        id: deviceColumn
                        width: parent.width
                        spacing: Theme.spacingS

                        Repeater {
                            model: audioDevicesDropdown.availableDevices
                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                width: parent.width
                                height: 48
                                radius: Theme.cornerRadius
                                color: deviceMouseAreaLeft.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Theme.surfaceContainerHigh
                                border.color: modelData === AudioService.sink ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                border.width: modelData === AudioService.sink ? 2 : 1

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingM
                                    width: parent.width - Theme.spacingM * 2

                                    DankIcon {
                                        name: getAudioDeviceIcon(modelData)
                                        size: 20
                                        color: modelData === AudioService.sink ? Theme.primary : Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 20 - Theme.spacingM * 2

                                        StyledText {
                                            text: AudioService.displayName(modelData)
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: Theme.surfaceText
                                            font.weight: modelData === AudioService.sink ? Font.Medium : Font.Normal
                                            elide: Text.ElideRight
                                            width: parent.width
                                            wrapMode: Text.NoWrap
                                        }

                                        StyledText {
                                            text: modelData === AudioService.sink ? "Active" : "Available"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            elide: Text.ElideRight
                                            width: parent.width
                                            wrapMode: Text.NoWrap
                                        }
                                    }
                                }

                                MouseArea {
                                    id: deviceMouseAreaLeft
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData) {
                                            Pipewire.preferredDefaultAudioSink = modelData
                                        }
                                        audioDevicesButton.devicesExpanded = false
                                    }
                                }

                                Behavior on border.color { ColorAnimation { duration: Anims.durShort } }
                            }
                        }
                    }
                }
            }
        }

        Popup {
            id: playerSelectorDropdown
            width: 240
            height: playerSelectorButton.playersExpanded ? Math.max(180, Math.min(240, (root.allPlayers?.length || 0) * 50 + 80)) : 0
            x: isRightEdge ? -width - Theme.spacingS : root.width + Theme.spacingS
            y: playerSelectorButton.y - 50
            visible: playerSelectorButton.playersExpanded
            closePolicy: Popup.NoAutoClose
            modal: false
            dim: false
            padding: 0

            background: Rectangle {
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.98)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.6)
                border.width: 2
                radius: Theme.cornerRadius * 2

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 8
                    shadowBlur: 1.0
                    shadowColor: Qt.rgba(0, 0, 0, 0.4)
                    shadowOpacity: 0.7
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: Anims.durShort
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Anims.emphasizedDecel
                }
            }

            enter: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Anims.durShort
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Anims.standard
                }
            }

            exit: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: Anims.durShort
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Anims.standard
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingM

                StyledText {
                    text: I18n.tr("Media Players (") + (allPlayers?.length || 0) + ")"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    bottomPadding: Theme.spacingM
                }

                DankFlickable {
                    width: parent.width
                    height: parent.height - 40
                    contentHeight: playerColumn.height
                    clip: true

                    Column {
                        id: playerColumn
                        width: parent.width
                        spacing: Theme.spacingS

                        Repeater {
                            model: allPlayers || []
                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                width: parent.width
                                height: 48
                                radius: Theme.cornerRadius
                                color: playerMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Theme.surfaceContainerHigh
                                border.color: modelData === activePlayer ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                border.width: modelData === activePlayer ? 2 : 1

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingM
                                    width: parent.width - Theme.spacingM * 2

                                    DankIcon {
                                        name: "music_note"
                                        size: 20
                                        color: modelData === activePlayer ? Theme.primary : Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 20 - Theme.spacingM * 2

                                        StyledText {
                                            text: {
                                                if (!modelData) return "Unknown Player"

                                                const identity = modelData.identity || "Unknown Player"
                                                const trackTitle = modelData.trackTitle || ""

                                                if (trackTitle.length > 0) {
                                                    return identity + " - " + trackTitle
                                                }

                                                return identity
                                            }
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: Theme.surfaceText
                                            font.weight: modelData === activePlayer ? Font.Medium : Font.Normal
                                            elide: Text.ElideRight
                                            width: parent.width
                                            wrapMode: Text.NoWrap
                                        }

                                        StyledText {
                                            text: {
                                                if (!modelData) return ""

                                                const artist = modelData.trackArtist || ""
                                                const isActive = modelData === activePlayer

                                                if (artist.length > 0) {
                                                    return artist + (isActive ? " (Active)" : "")
                                                }

                                                return isActive ? "Active" : "Available"
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            elide: Text.ElideRight
                                            width: parent.width
                                            wrapMode: Text.NoWrap
                                        }
                                    }
                                }

                                MouseArea {
                                    id: playerMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData && modelData.identity) {
                                            if (activePlayer && activePlayer !== modelData && activePlayer.canPause) {
                                                activePlayer.pause()
                                            }

                                            MprisController.activePlayer = modelData
                                        }
                                        playerSelectorButton.playersExpanded = false
                                    }
                                }

                                Behavior on border.color {
                                    ColorAnimation { 
                                        duration: Anims.durShort
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Anims.standard
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }      
        // Center Column: Main Media Content
        ColumnLayout {
            x: 72  
            y: 20  
            width: 484  
            height: 370  
            spacing: Theme.spacingXS  

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

                // Controls Group
                Column {
                    id: controlsGroup
                    width: parent.width
                    spacing: Theme.spacingXS
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 0

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
                        height: 20
                        anchors.horizontalCenter: parent.horizontalCenter

                        StyledText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (!activePlayer) return "0:00"
                                const rawPos = Math.max(0, activePlayer.position || 0)
                                const pos = activePlayer.length ? rawPos % Math.max(1, activePlayer.length) : rawPos
                                const minutes = Math.floor(pos / 60)
                                const seconds = Math.floor(pos % 60)
                                const timeStr = minutes + ":" + (seconds < 10 ? "0" : "") + seconds
                                return timeStr
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (!activePlayer || !activePlayer.length) return "0:00"
                                const dur = Math.max(0, activePlayer.length || 0)  // Length is already in seconds
                                const minutes = Math.floor(dur / 60)
                                const seconds = Math.floor(dur % 60)
                                return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }

                    Item {
                        width: parent.width
                        height: 50

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
                                            activePlayer.shuffle = !activePlayer.shuffle
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
                                color: prevBtnArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"

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
                                            return
                                        }

                                        if (activePlayer.position > 8 && activePlayer.canSeek) {
                                            activePlayer.position = 0
                                        } else {
                                            activePlayer.previous()
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
                                color: nextBtnArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"

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
                                        if (!activePlayer) return "repeat"
                                        switch(activePlayer.loopState) {
                                            case MprisLoopState.Track: return "repeat_one"
                                            case MprisLoopState.Playlist: return "repeat"
                                            default: return "repeat"
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
                                            switch(activePlayer.loopState) {
                                                case MprisLoopState.None:
                                                    activePlayer.loopState = MprisLoopState.Playlist
                                                    break
                                                case MprisLoopState.Playlist:
                                                    activePlayer.loopState = MprisLoopState.Track
                                                    break
                                                case MprisLoopState.Track:
                                                    activePlayer.loopState = MprisLoopState.None
                                                    break
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
            color: playerSelectorArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : "transparent"
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
            border.width: 1
            z: 100
            visible: (allPlayers?.length || 0) >= 1

            property bool playersExpanded: false

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
                    parent.playersExpanded = !parent.playersExpanded
                }
                onEntered: {
                    playerTooltipLoader.active = true
                    if (playerTooltipLoader.item) {
                        const p = playerSelectorButton.mapToItem(null, playerSelectorButton.width / 2, 0)
                        playerTooltipLoader.item.show("Media Player", p.x, p.y - 40, null)
                    }
                }
                onExited: {
                    if (playerTooltipLoader.item) {
                        playerTooltipLoader.item.hide()
                    }
                    playerTooltipLoader.active = false
                }
            }

        }

        Loader {
            id: playerTooltipLoader
            active: false
            sourceComponent: DankTooltip {}
        }

        Rectangle {
            id: volumeButton
            width: 40
            height: 40
            radius: 20
            x: isRightEdge ? Theme.spacingM : parent.width - 40 - Theme.spacingM
            y: 130
            color: volumeButtonArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : "transparent"
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
            border.width: 1
            z: 101

            property bool volumeExpanded: false

            Timer {
                id: volumeHideTimer
                interval: 500
                onTriggered: volumeButton.volumeExpanded = false
            }

            DankIcon {
                anchors.centerIn: parent
                name: getVolumeIcon(defaultSink)
                size: 18
                color: defaultSink && !defaultSink.audio.muted && defaultSink.audio.volume > 0 ? Theme.primary : Theme.surfaceText
            }

            MouseArea {
                id: volumeButtonArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    volumeButton.volumeExpanded = true
                    volumeHideTimer.stop()
                }
                onExited: {
                    volumeHideTimer.restart()
                }
                onClicked: {
                    if (defaultSink?.audio) {
                        defaultSink.audio.muted = !defaultSink.audio.muted
                    }
                }
                onWheel: wheelEvent => {
                    const step = Math.max(0.5, 100 / 100)
                    adjustVolume(wheelEvent.angleDelta.y > 0 ? step : -step)
                    volumeButton.volumeExpanded = true
                    wheelEvent.accepted = true
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
            color: audioDevicesArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : "transparent"
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
            border.width: 1
            z: 100

            property bool devicesExpanded: false

            DankIcon {
                anchors.centerIn: parent
                name: parent.devicesExpanded ? "expand_less" : "speaker"
                size: 18
                color: Theme.surfaceText
            }

            MouseArea {
                id: audioDevicesArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    parent.devicesExpanded = !parent.devicesExpanded
                }
                onEntered: {
                    audioDevicesTooltipLoader.active = true
                    if (audioDevicesTooltipLoader.item) {
                        const p = audioDevicesButton.mapToItem(null, audioDevicesButton.width / 2, 0)
                        audioDevicesTooltipLoader.item.show("Output Device", p.x, p.y - 40, null)
                    }
                }
                onExited: {
                    if (audioDevicesTooltipLoader.item) {
                        audioDevicesTooltipLoader.item.hide()
                    }
                    audioDevicesTooltipLoader.active = false
                }
            }

        }

        Loader {
            id: audioDevicesTooltipLoader
            active: false
            sourceComponent: DankTooltip {}
        }

    }

    Popup {
        id: volumeSliderPanel
        width: 60
        height: 180
        x: isRightEdge ? -width - Theme.spacingS : root.width + Theme.spacingS
        y: volumeButton.y - 50
        visible: volumeButton.volumeExpanded
        closePolicy: Popup.NoAutoClose
        modal: false
        dim: false
        padding: 0

        background: Rectangle {
            radius: Theme.cornerRadius * 2
            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
            border.width: 1

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 8
                shadowBlur: 1.0
                shadowColor: Qt.rgba(0, 0, 0, 0.4)
                shadowOpacity: 0.7
            }
        }

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Anims.durShort
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Anims.standard
            }
        }

        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: Anims.durShort
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Anims.standard
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: Theme.spacingS

            Item {
                id: volumeSlider
                width: parent.width * 0.5
                height: parent.height - Theme.spacingXL * 2
                anchors.top: parent.top
                anchors.topMargin: Theme.spacingS
                anchors.horizontalCenter: parent.horizontalCenter

                property bool dragging: false
                property bool containsMouse: volumeSliderArea.containsMouse
                property bool active: volumeSliderArea.containsMouse || volumeSliderArea.pressed || dragging

                Rectangle {
                    id: sliderTrack
                    width: parent.width
                    height: parent.height
                    anchors.centerIn: parent
                    color: Theme.surfaceContainerHigh
                    radius: Theme.cornerRadius
                }

                Rectangle {
                    id: sliderFill
                    width: parent.width
                    height: defaultSink ? (Math.min(1.0, defaultSink.audio.volume) * parent.height) : 0
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.primary
                    bottomLeftRadius: Theme.cornerRadius
                    bottomRightRadius: Theme.cornerRadius
                    topLeftRadius: 0
                    topRightRadius: 0
                }

                Rectangle {
                    id: sliderHandle
                    width: parent.width + 8
                    height: 8
                    radius: Theme.cornerRadius
                    y: {
                        const ratio = defaultSink ? Math.min(1.0, defaultSink.audio.volume) : 0
                        const travel = parent.height - height
                        return Math.max(0, Math.min(travel, travel * (1 - ratio)))
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.primary
                    border.width: 3
                    border.color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 1.0)

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.cornerRadius
                        color: Theme.onPrimary
                        opacity: volumeSliderArea.pressed ? 0.16 : (volumeSliderArea.containsMouse ? 0.08 : 0)
                        visible: opacity > 0
                    }

                    Rectangle {
                        id: ripple
                        anchors.centerIn: parent
                        width: 0
                        height: 0
                        radius: width / 2
                        color: Theme.onPrimary
                        opacity: 0

                        function start() {
                            opacity = 0.16
                            width = 0
                            height = 0
                            rippleAnimation.start()
                        }

                        SequentialAnimation {
                            id: rippleAnimation
                            NumberAnimation {
                                target: ripple
                                properties: "width,height"
                                to: 28
                                duration: 180
                            }
                            NumberAnimation {
                                target: ripple
                                property: "opacity"
                                to: 0
                                duration: 150
                            }
                        }
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onPressedChanged: {
                            if (pressed) {
                                ripple.start()
                            }
                        }
                    }

                    scale: volumeSlider.active ? 1.05 : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: Anims.durShort
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anims.standard
                        }
                    }
                }

                MouseArea {
                    id: volumeSliderArea
                    anchors.fill: parent
                    anchors.margins: -12
                    enabled: defaultSink !== null
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true

                    onEntered: {
                        volumeHideTimer.stop()
                    }

                    onExited: {
                        volumeHideTimer.restart()
                    }

                    onPressed: function(mouse) {
                        parent.dragging = true
                        updateVolume(mouse)
                    }

                    onReleased: {
                        parent.dragging = false
                    }

                    onPositionChanged: function(mouse) {
                        if (pressed) {
                            updateVolume(mouse)
                        }
                    }

                    onClicked: function(mouse) {
                        updateVolume(mouse)
                    }

                    onWheel: wheelEvent => {
                        const step = Math.max(0.5, 100 / 100)
                        adjustVolume(wheelEvent.angleDelta.y > 0 ? step : -step)
                        wheelEvent.accepted = true
                    }

                    function updateVolume(mouse) {
                        if (defaultSink) {
                            const ratio = 1.0 - (mouse.y / height)
                            const volume = Math.max(0, Math.min(1, ratio))
                            defaultSink.audio.volume = volume
                            if (volume > 0 && defaultSink.audio.muted) {
                                defaultSink.audio.muted = false
                            }
                        }
                    }
                }
            }

            StyledText {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: Theme.spacingL
                text: defaultSink ? Math.round(defaultSink.audio.volume * 100) + "%" : "0%"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                font.weight: Font.Medium
            }
        }
    }
}