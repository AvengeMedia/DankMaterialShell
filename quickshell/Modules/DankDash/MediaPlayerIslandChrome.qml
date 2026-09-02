pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets
import "../../Common/Format.js" as Format

Item {
    id: root

    required property var player

    property alias volumeButton: volumeButton
    property alias playerSelectorButton: sourceButton
    property alias audioDevicesButton: outputButton

    readonly property var activePlayer: root.player.activePlayer
    readonly property bool playing: root.activePlayer?.playbackState === MprisPlaybackState.Playing
    readonly property color accent: root.player.accent
    readonly property color onAccent: root.player.onAccent
    readonly property string title: MprisController.stableTitle || I18n.tr("Unknown Track")
    readonly property string artist: MprisController.stableArtist || I18n.tr("Unknown Artist")
    readonly property string album: MprisController.stableAlbum || ""
    readonly property string artUrl: TrackArtService.resolvedArtUrl || root.activePlayer?.trackArtUrl || ""
    readonly property real railWidth: 44
    readonly property real railInset: root.railWidth + Theme.spacingM

    implicitHeight: 352

    MediaArtBackdrop {
        anchors.fill: parent
        radius: 30
        activePlayer: root.activePlayer
        onArtReady: root.player.maybeFinishSwitch()
    }

    MediaPlayerEmptyState {
        anchors.centerIn: parent
        visible: root.player.showNoPlayerNow
    }

    Item {
        id: cardBody

        anchors {
            fill: parent
            margins: 18
        }
        visible: !root.player.noneAvailable && !root.player.showNoPlayerNow

        Item {
            id: headerRow

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: 132

            Item {
                id: artCluster

                anchors {
                    left: parent.left
                    top: parent.top
                }
                width: 120
                height: 120

                MediaBlobHalo {
                    anchors.centerIn: parent
                    width: 136
                    height: 136
                    accentColor: root.accent
                    playing: root.player.live && root.playing
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 30
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.withAlpha(root.accent, 0.3)

                    MediaArtwork {
                        anchors {
                            fill: parent
                            margins: 2
                        }
                        cornerRadius: 28
                        placeholderIconSize: 46
                        artUrl: root.artUrl
                    }
                }
            }

            Column {
                anchors {
                    left: artCluster.right
                    leftMargin: Theme.spacingL
                    right: parent.right
                    top: parent.top
                    topMargin: 2
                }
                spacing: Theme.spacingXS

                StyledText {
                    width: parent.width
                    text: root.title
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeXLarge
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    lineHeight: 1.08
                }

                StyledText {
                    width: parent.width
                    text: root.artist
                    color: Theme.surfaceTextMedium
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                StyledText {
                    width: parent.width
                    text: root.album
                    color: Theme.surfaceTextSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: text.length > 0
                }
            }
        }

        Column {
            id: iconRail

            anchors {
                right: parent.right
                top: headerRow.bottom
                topMargin: Theme.spacingL
                bottom: parent.bottom
            }
            width: root.railWidth
            spacing: Theme.spacingS

            RailButton {
                id: volumeButton

                iconName: root.player.getVolumeIcon()
                iconColor: root.player.volumeAvailable && root.player.currentVolume > 0 ? root.accent : Theme.surfaceTextMedium
                enabled: root.player.volumeAvailable
                onClicked: root.player.toggleMute()
                onEntered: root.player.triggerVolumeDropdown()
                onExited: {
                    if (root.player.volumeExpanded)
                        root.player.dropdownButtonExited();
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: wheelEvent => {
                        wheelEvent.accepted = true;
                        root.player.adjustVolume((wheelEvent.angleDelta.y > 0 ? 1 : -1) * AudioService.wheelVolumeStep);
                    }
                }
            }

            RailButton {
                id: outputButton

                iconName: root.player.getAudioDeviceIcon(AudioService.sink)
                onClicked: {
                    if (root.player.devicesExpanded) {
                        root.player.cycleNextSink();
                        return;
                    }
                    root.player.triggerDevicesDropdown();
                }
                onEntered: root.player.triggerDevicesDropdown()
                onExited: {
                    if (root.player.devicesExpanded)
                        root.player.dropdownButtonExited();
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: wheelEvent => {
                        wheelEvent.accepted = true;
                        AudioService.cycleAudioOutputDirection(wheelEvent.angleDelta.y < 0);
                    }
                }
            }

            RailButton {
                id: sourceButton

                visible: (root.player.allPlayers?.length || 0) > 0
                iconName: "assistant_device"
                iconColor: root.player.playersExpanded ? root.accent : Theme.surfaceText
                backgroundColor: Theme.withAlpha(root.accent, root.player.playersExpanded ? 0.16 : 0.08)
                onClicked: {
                    if (root.player.playersExpanded) {
                        root.player.cycleNextPlayer();
                        return;
                    }
                    root.player.triggerPlayersDropdown();
                }
                onEntered: root.player.triggerPlayersDropdown()
                onExited: {
                    if (root.player.playersExpanded)
                        root.player.dropdownButtonExited();
                }
            }
        }

        Item {
            id: playColumn

            anchors {
                left: parent.left
                right: iconRail.left
                rightMargin: Theme.spacingM
                top: headerRow.bottom
                topMargin: Theme.spacingL
                bottom: parent.bottom
            }

            Item {
                id: seekBlock

                anchors {
                    left: parent.left
                    leftMargin: root.railInset
                    right: parent.right
                    bottom: parent.bottom
                    bottomMargin: 76
                }
                height: 40

                DankSeekbar {
                    anchors.top: parent.top
                    width: parent.width
                    height: 22
                    activePlayer: root.activePlayer
                    stableLength: root.player.stableLength
                    accentColor: root.accent
                    accentTrackColor: MediaAccentService.accentTrack
                    accentSubtleColor: MediaAccentService.accentSubtle
                    isSeeking: root.player.isSeeking
                    onIsSeekingChanged: root.player.isSeeking = isSeeking
                }

                StyledText {
                    anchors {
                        left: parent.left
                        bottom: parent.bottom
                    }
                    text: {
                        const rawPos = Math.max(0, root.activePlayer?.position || 0);
                        const length = root.player.stableLength;
                        return Format.formatDuration(length ? rawPos % Math.max(1, length) : rawPos);
                    }
                    color: root.accent
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                }

                StyledText {
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                    }
                    text: root.player.stableLength > 0 ? Format.formatDuration(root.player.stableLength) : "--:--"
                    color: Theme.surfaceTextSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                }
            }

            Row {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    horizontalCenterOffset: root.railInset / 2
                    bottom: parent.bottom
                    bottomMargin: 2
                }
                spacing: Theme.spacingS

                DankActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!root.activePlayer?.shuffleSupported
                    buttonSize: 40
                    radius: 20
                    iconName: "shuffle"
                    iconSize: 18
                    iconColor: root.activePlayer?.shuffle ? root.accent : Theme.surfaceText
                    backgroundColor: Theme.withAlpha(root.accent, root.activePlayer?.shuffle ? 0.16 : 0)
                    onClicked: {
                        if (root.activePlayer?.canControl && root.activePlayer?.shuffleSupported)
                            root.activePlayer.shuffle = !root.activePlayer.shuffle;
                    }
                }

                DankActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    buttonSize: 52
                    radius: 18
                    iconName: "skip_previous"
                    iconSize: 26
                    backgroundColor: Theme.withAlpha(root.accent, 0.14)
                    enabled: !!root.activePlayer?.canGoPrevious || !!root.activePlayer?.canSeek
                    opacity: enabled ? 1 : 0.38
                    onClicked: MprisController.previousOrRewind()
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 68
                    height: 68
                    radius: root.playing ? 22 : 34
                    color: root.accent
                    opacity: root.activePlayer?.canTogglePlaying ? 1 : 0.38

                    DankIcon {
                        anchors.centerIn: parent
                        name: root.playing ? "pause" : "play_arrow"
                        size: 34
                        color: root.onAccent
                        weight: 500
                    }

                    StateLayer {
                        stateColor: root.onAccent
                        disabled: !root.activePlayer?.canTogglePlaying
                        onClicked: root.activePlayer.togglePlaying()
                    }
                }

                DankActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    buttonSize: 52
                    radius: 18
                    iconName: "skip_next"
                    iconSize: 26
                    backgroundColor: Theme.withAlpha(root.accent, 0.14)
                    enabled: !!root.activePlayer?.canGoNext
                    opacity: enabled ? 1 : 0.38
                    onClicked: MprisController.next()
                }

                DankActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!root.activePlayer?.loopSupported
                    buttonSize: 40
                    radius: 20
                    iconName: root.activePlayer?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                    iconSize: 18
                    iconColor: root.activePlayer && root.activePlayer.loopState !== MprisLoopState.None ? root.accent : Theme.surfaceText
                    backgroundColor: Theme.withAlpha(root.accent, root.activePlayer && root.activePlayer.loopState !== MprisLoopState.None ? 0.16 : 0)
                    onClicked: root.player.cycleLoopState()
                }
            }
        }
    }

    component RailButton: DankActionButton {
        buttonSize: root.railWidth
        radius: root.railWidth / 2
        iconSize: 20
        iconColor: Theme.surfaceText
        backgroundColor: Theme.withAlpha(Theme.surfaceText, 0.08)
        opacity: enabled ? 1 : 0.38
    }
}
