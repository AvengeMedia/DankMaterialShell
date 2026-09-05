import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets
import "../../Common/Format.js" as Format

Item {
    id: root

    required property var player

    property alias volumeButton: volumeButton
    property alias playerSelectorButton: playerSelectorButton
    property alias audioDevicesButton: audioDevicesButton

    implicitHeight: playerContent.height + playerContent.anchors.topMargin * 2

    Loader {
        anchors.fill: parent
        active: root.player.wallpaperEnabled

        sourceComponent: MediaArtBackdrop {
            activePlayer: root.player.activePlayer
            onArtReady: root.player.maybeFinishSwitch()
        }
    }

    MediaPlayerEmptyState {
        anchors.centerIn: parent
        visible: player.showNoPlayerNow
    }

    Item {
        anchors.fill: parent
        clip: false
        visible: !player.noneAvailable && (!player.showNoPlayerNow)
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
                    activePlayer: player.activePlayer
                    artUrl: TrackArtService.resolvedArtUrl
                    accentColor: MediaAccentService.accent
                    showAnimation: SettingsData.audioVisualizerEnabled
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
                        text: MprisController.stableAlbum
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
                            activePlayer: player.activePlayer
                            stableLength: MprisController.activePlayerStableLength
                            accentColor: MediaAccentService.accent
                            accentTrackColor: MediaAccentService.accentTrack
                            accentSubtleColor: MediaAccentService.accentSubtle
                            isSeeking: player.isSeeking
                            onIsSeekingChanged: player.isSeeking = isSeeking
                        }

                        Item {
                            width: parent.width * 0.8
                            height: 16
                            anchors.horizontalCenter: parent.horizontalCenter

                            StyledText {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    if (!player.activePlayer)
                                        return "0:00";
                                    const rawPos = Math.max(0, player.activePlayer.position || 0);
                                    return Format.formatDuration(player.stableLength ? rawPos % Math.max(1, player.stableLength) : rawPos);
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    if (!player.activePlayer || player.stableLength <= 0)
                                        return "--:--";
                                    return Format.formatDuration(player.stableLength);
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
                            visible: player.activePlayer && player.activePlayer.shuffleSupported

                            Rectangle {
                                width: 40
                                height: 40
                                radius: 20
                                anchors.centerIn: parent
                                color: shuffleArea.containsMouse ? player.accentHover : Theme.withAlpha(player.accent, 0)

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "shuffle"
                                    size: 20
                                    color: player.activePlayer && player.activePlayer.shuffle ? player.accent : Theme.surfaceText
                                }

                                MouseArea {
                                    id: shuffleArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (player.activePlayer && player.activePlayer.canControl && player.activePlayer.shuffleSupported) {
                                            player.activePlayer.shuffle = !player.activePlayer.shuffle;
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
                                color: player.accent

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: player.activePlayer && player.activePlayer.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                                    size: 28
                                    color: player.onAccent
                                    weight: 500
                                }

                                StateLayer {
                                    id: playPauseArea
                                    disabled: !player.activePlayer || !player.activePlayer.canTogglePlaying
                                    stateColor: player.onAccent
                                    cornerRadius: parent.radius
                                    onClicked: player.activePlayer.togglePlaying()
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
                            visible: player.activePlayer && player.activePlayer.loopSupported

                            Rectangle {
                                width: 40
                                height: 40
                                radius: 20
                                anchors.centerIn: parent
                                color: repeatArea.containsMouse ? player.accentHover : Theme.withAlpha(player.accent, 0)

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: {
                                        if (!player.activePlayer)
                                            return "repeat";
                                        switch (player.activePlayer.loopState) {
                                        case MprisLoopState.Track:
                                            return "repeat_one";
                                        case MprisLoopState.Playlist:
                                            return "repeat";
                                        default:
                                            return "repeat";
                                        }
                                    }
                                    size: 20
                                    color: player.activePlayer && player.activePlayer.loopState !== MprisLoopState.None ? player.accent : Theme.surfaceText
                                }

                                MouseArea {
                                    id: repeatArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: player.cycleLoopState()
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
        x: player.isRightEdge ? Theme.spacingM : parent.width - 40 - Theme.spacingM
        y: 185
        color: playerSelectorArea.containsMouse || player.playersExpanded ? player.accentPressed : Theme.withAlpha(player.accentPressed, 0)
        border.color: Theme.outlineStrong
        border.width: 1
        z: 100
        visible: (player.allPlayers?.length || 0) >= 1

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
                if (player.playersExpanded) {
                    player.cycleNextPlayer();
                    return;
                }
                player.triggerPlayersDropdown();
            }
            onEntered: {
                player.dropdownButtonEntered();
                player.triggerPlayersDropdown();
            }
            onExited: {
                if (player.playersExpanded)
                    player.dropdownButtonExited();
            }
        }
    }

    Rectangle {
        id: volumeButton
        width: 40
        height: 40
        radius: 20
        x: player.isRightEdge ? Theme.spacingM : parent.width - 40 - Theme.spacingM
        y: 130
        color: volumeButtonArea.containsMouse && player.volumeAvailable || player.volumeExpanded ? player.accentPressed : Theme.withAlpha(player.accentPressed, 0)
        border.color: player.volumeAvailable ? Theme.outlineStrong : Theme.outlineMedium
        border.width: 1
        z: 101
        enabled: player.volumeAvailable

        DankIcon {
            anchors.centerIn: parent
            name: player.getVolumeIcon()
            size: 18
            color: player.volumeAvailable && player.currentVolume > 0 ? player.accent : Theme.withAlpha(Theme.surfaceText, player.volumeAvailable ? 1.0 : 0.5)
        }

        MouseArea {
            id: volumeButtonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: {
                player.dropdownButtonEntered();
                player.triggerVolumeDropdown();
            }
            onExited: {
                if (player.volumeExpanded)
                    player.dropdownButtonExited();
            }
            onClicked: player.toggleMute()
            property real wheelAccum: 0
            onWheel: wheelEvent => {
                wheelEvent.accepted = true;
                wheelAccum += wheelEvent.angleDelta.y;
                const notches = wheelAccum > 0 ? Math.floor(wheelAccum / 120) : Math.ceil(wheelAccum / 120);
                if (notches === 0)
                    return;
                wheelAccum -= notches * 120;
                player.adjustVolume(notches * AudioService.wheelVolumeStep);
            }
        }
    }

    Rectangle {
        id: audioDevicesButton
        width: 40
        height: 40
        radius: 20
        x: player.isRightEdge ? Theme.spacingM : parent.width - 40 - Theme.spacingM
        y: 240
        color: audioDevicesArea.containsMouse || player.devicesExpanded ? player.accentPressed : Theme.withAlpha(player.accentPressed, 0)
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
            onWheel: wheelEvent => {
                const delta = wheelEvent.angleDelta.y;
                if (delta === 0)
                    return;
                AudioService.cycleAudioOutputDirection(delta < 0);
                wheelEvent.accepted = true;
            }
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    if (!AudioService.sink?.audio)
                        return;
                    SessionData.suppressOSDTemporarily();
                    AudioService.sink.audio.muted = !AudioService.sink.audio.muted;
                    return;
                }
                if (player.devicesExpanded) {
                    player.cycleNextSink();
                    return;
                }
                player.triggerDevicesDropdown();
            }
            onEntered: {
                player.dropdownButtonEntered();
                player.triggerDevicesDropdown();
            }
            onExited: {
                if (player.devicesExpanded)
                    player.dropdownButtonExited();
            }
        }
    }
}
