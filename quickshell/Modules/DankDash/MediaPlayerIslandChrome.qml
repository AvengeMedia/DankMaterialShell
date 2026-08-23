pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Widgets
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

    implicitHeight: 352

    readonly property var activePlayer: root.player.activePlayer
    readonly property color accent: root.player.accent
    readonly property color onAccent: root.player.onAccent
    readonly property string artUrl: TrackArtService.resolvedArtUrl
    readonly property string title: MprisController.stableTitle || I18n.tr("Unknown Track", "island media player: fallback title")
    readonly property string artist: MprisController.stableArtist || I18n.tr("Unknown Artist", "island media player: fallback artist")
    readonly property string album: MprisController.stableAlbum || ""

    Component {
        id: artBlobComponent

        MediaBlobHalo {
            accentColor: root.accent
            playing: root.activePlayer?.playbackState === MprisPlaybackState.Playing
        }
    }

    function volumeIcon() {
        return root.player.getVolumeIcon();
    }

    function outputIcon() {
        return root.player.getAudioDeviceIcon(AudioService.sink);
    }

    ClippingRectangle {
        anchors {
            fill: parent
            margins: 1
        }
        radius: 30
        color: Theme.surfaceContainerHigh
        antialiasing: true

        Image {
            id: backdropImage

            anchors.fill: parent
            source: root.visible ? root.artUrl : ""
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(320, 320)
            visible: backdropImage.status === Image.Ready
            opacity: 0.62
        }

        Rectangle {
            anchors.fill: parent
            visible: backdropImage.status === Image.Ready

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.9)
                }

                GradientStop {
                    position: 0.4
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.46)
                }

                GradientStop {
                    position: 1
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.95)
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.surfaceContainerHigh
            visible: backdropImage.status !== Image.Ready
        }

        Rectangle {
            anchors.fill: parent
            visible: backdropImage.status !== Image.Ready

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.withAlpha(root.accent, 0.16)
                }

                GradientStop {
                    position: 0.55
                    color: Theme.withAlpha(root.accent, 0.04)
                }

                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }

        DankIcon {
            anchors.centerIn: parent
            name: "music_note"
            size: 120
            color: Theme.withAlpha(root.accent, 0.10)
            visible: backdropImage.status !== Image.Ready
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingM
        visible: root.player.showNoPlayerNow
        z: 2

        DankIcon {
            name: "music_note"
            size: Theme.iconSize * 3
            color: Theme.surfaceTextSecondary
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: I18n.tr("No Active Players", "island media player: empty state")
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.surfaceTextMedium
            anchors.horizontalCenter: parent.horizontalCenter
        }
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
            clip: false

            Item {
                id: artCluster

                anchors {
                    left: parent.left
                    top: parent.top
                }
                width: 120
                height: 120
                clip: false
                z: 1

                Loader {
                    anchors.centerIn: parent
                    width: 136
                    height: 136
                    z: 0
                    active: root.visible && root.player.live && SettingsData.audioVisualizerEnabled
                    sourceComponent: artBlobComponent
                }

                Rectangle {
                    id: artFrame

                    anchors.fill: parent
                    z: 1
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

        Item {
            id: iconRail

            anchors {
                right: parent.right
                top: headerRow.bottom
                topMargin: Theme.spacingL
                bottom: parent.bottom
            }
            width: 44
            z: 4

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingS

                TonalIconButton {
                    id: volumeButton

                    width: 44
                    height: 44
                    radius: 22
                    iconName: root.volumeIcon()
                    iconSize: 20
                    iconColor: root.player.volumeAvailable && root.player.currentVolume > 0 ? root.accent : Theme.surfaceTextMedium
                    containerColor: Theme.withAlpha(Theme.surfaceText, 0.08)
                    interactive: root.player.volumeAvailable
                    onTriggered: root.player.toggleMute()
                    onScrolled: notches => root.player.adjustVolume(notches * AudioService.wheelVolumeStep)

                    HoverHandler {
                        enabled: root.player.menusEnabled && root.player.volumeAvailable
                        onHoveredChanged: {
                            if (hovered)
                                root.player.triggerVolumeDropdown();
                            else
                                root.player.dropdownButtonExited();
                        }
                    }
                }

                TonalIconButton {
                    id: outputButton

                    width: 44
                    height: 44
                    radius: 22
                    iconName: root.outputIcon()
                    iconSize: 20
                    iconColor: Theme.surfaceText
                    containerColor: Theme.withAlpha(Theme.surfaceText, 0.08)
                    onTriggered: root.player.cycleNextSink()
                    onScrolled: notches => AudioService.cycleAudioOutputDirection(notches < 0)

                    HoverHandler {
                        enabled: root.player.menusEnabled
                        onHoveredChanged: {
                            if (hovered)
                                root.player.triggerDevicesDropdown();
                            else
                                root.player.dropdownButtonExited();
                        }
                    }
                }

                TonalIconButton {
                    id: sourceButton

                    width: 44
                    height: 44
                    radius: 22
                    visible: (root.player.allPlayers?.length || 0) > 0
                    iconName: "assistant_device"
                    iconSize: 20
                    iconColor: root.player.playersExpanded ? root.accent : Theme.surfaceText
                    containerColor: Theme.withAlpha(root.accent, root.player.playersExpanded ? 0.16 : 0.08)
                    onTriggered: {
                        if (root.player.playersExpanded) {
                            root.player.cycleNextPlayer();
                            return;
                        }
                        root.player.triggerPlayersDropdown();
                    }

                    HoverHandler {
                        enabled: root.player.menusEnabled && sourceButton.visible
                        onHoveredChanged: {
                            if (hovered)
                                root.player.triggerPlayersDropdown();
                            else
                                root.player.dropdownButtonExited();
                        }
                    }
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
                    leftMargin: iconRail.width + Theme.spacingM
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
                    text: Format.formatDuration(root.activePlayer?.position || 0)
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
                    horizontalCenterOffset: (iconRail.width + Theme.spacingM) / 2
                    bottom: parent.bottom
                    bottomMargin: 2
                }
                spacing: Theme.spacingS

                TonalIconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 40
                    radius: 20
                    visible: !!root.activePlayer?.shuffleSupported
                    iconName: "shuffle"
                    iconSize: 18
                    iconColor: root.activePlayer?.shuffle ? root.accent : Theme.surfaceText
                    containerColor: Theme.withAlpha(root.accent, root.activePlayer?.shuffle ? 0.16 : 0)
                    onTriggered: {
                        if (root.activePlayer?.canControl && root.activePlayer?.shuffleSupported)
                            root.activePlayer.shuffle = !root.activePlayer.shuffle;
                    }
                }

                TonalIconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 52
                    height: 52
                    radius: 18
                    iconName: "skip_previous"
                    iconSize: 26
                    containerColor: Theme.withAlpha(root.accent, 0.14)
                    interactive: !!root.activePlayer?.canGoPrevious || !!root.activePlayer?.canSeek
                    onTriggered: MprisController.previousOrRewind()
                }

                Rectangle {
                    id: playHero

                    anchors.verticalCenter: parent.verticalCenter
                    width: 68
                    height: 68
                    radius: root.activePlayer?.playbackState === MprisPlaybackState.Playing ? 22 : 34
                    color: root.accent
                    opacity: root.activePlayer?.canTogglePlaying ? 1 : 0.38

                    DankIcon {
                        anchors.centerIn: parent
                        name: root.activePlayer?.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                        size: 34
                        color: root.onAccent
                        weight: 500
                    }

                    StateLayer {
                        stateColor: root.onAccent
                        disabled: !root.activePlayer || !root.activePlayer.canTogglePlaying
                        onClicked: root.activePlayer.togglePlaying()
                    }
                }

                TonalIconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 52
                    height: 52
                    radius: 18
                    iconName: "skip_next"
                    iconSize: 26
                    containerColor: Theme.withAlpha(root.accent, 0.14)
                    interactive: !!root.activePlayer?.canGoNext
                    onTriggered: MprisController.next()
                }

                TonalIconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 40
                    radius: 20
                    visible: !!root.activePlayer?.loopSupported
                    iconName: {
                        if (!root.activePlayer)
                            return "repeat";
                        return root.activePlayer.loopState === MprisLoopState.Track ? "repeat_one" : "repeat";
                    }
                    iconSize: 18
                    iconColor: root.activePlayer && root.activePlayer.loopState !== MprisLoopState.None ? root.accent : Theme.surfaceText
                    containerColor: Theme.withAlpha(root.accent, root.activePlayer && root.activePlayer.loopState !== MprisLoopState.None ? 0.16 : 0)
                    onTriggered: root.player.cycleLoopState()
                }
            }
        }
    }

    component TonalIconButton: Rectangle {
        id: tonal

        property string iconName: ""
        property real iconSize: 22
        property color iconColor: Theme.surfaceText
        property color containerColor: Theme.withAlpha(Theme.surfaceText, 0.08)
        property bool interactive: true

        signal triggered
        signal scrolled(int notches)

        color: tonal.containerColor
        opacity: tonal.interactive ? 1 : 0.38

        DankIcon {
            anchors.centerIn: parent
            name: tonal.iconName
            size: tonal.iconSize
            color: tonal.iconColor
        }

        StateLayer {
            stateColor: tonal.iconColor
            disabled: !tonal.interactive
            enabled: tonal.interactive
            onClicked: tonal.triggered()
            onWheel: wheelEvent => {
                wheelEvent.accepted = true;
                tonal.scrolled(wheelEvent.angleDelta.y > 0 ? 1 : -1);
            }
        }
    }
}
