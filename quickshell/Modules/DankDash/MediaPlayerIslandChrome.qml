pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
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

    property string panel: ""

    readonly property var activePlayer: root.player.activePlayer
    readonly property bool playing: root.activePlayer?.playbackState === MprisPlaybackState.Playing
    readonly property color accent: root.player.accent
    readonly property color onAccent: root.player.onAccent
    readonly property string title: MprisController.stableTitle || I18n.tr("Unknown Track")
    readonly property string artist: MprisController.stableArtist || I18n.tr("Unknown Artist")
    readonly property string album: MprisController.stableAlbum || ""
    readonly property string artUrl: TrackArtService.resolvedArtUrl || root.activePlayer?.trackArtUrl || ""
    readonly property var sinks: {
        Pipewire.nodes.values;
        return root.panel === "devices" ? AudioService.getAvailableSinks() : [];
    }
    readonly property var players: root.panel === "players" ? (root.player.allPlayers || []).filter(p => p && !MprisController.isIdle(p)) : []
    readonly property real cardMargin: 18
    readonly property real artSize: 150
    readonly property real seekBlockHeight: 42
    readonly property real seekbarHeight: 22
    readonly property real seekWidthRatio: 0.9
    readonly property real seekGapTop: 32
    readonly property real seekGapBottom: 16
    readonly property real seekTopMargin: root.seekGapTop - root.seekbarHeight / 2
    readonly property real transportHeight: 56
    readonly property real groupButtonSize: 44
    readonly property real groupOuterRadius: root.groupButtonSize / 2
    readonly property real groupInnerRadius: 8
    readonly property real panelPadding: Theme.spacingS
    readonly property real rowHeight: 44
    readonly property int maxRows: 4
    readonly property real panelHeight: {
        switch (root.panel) {
        case "volume":
            return 64;
        case "devices":
            return root.listHeight(root.sinks.length);
        case "players":
            return root.listHeight(root.players.length);
        }
        return 0;
    }
    readonly property real baseHeight: root.cardMargin * 2 + root.artSize + root.seekTopMargin + root.seekBlockHeight + root.seekGapBottom + root.transportHeight

    implicitHeight: root.baseHeight + (root.panel !== "" ? Theme.spacingM + root.panelHeight : 0)

    function listHeight(count) {
        const rows = Math.max(1, Math.min(root.maxRows, count));
        return root.panelPadding * 2 + rows * root.rowHeight + (rows - 1) * Theme.spacingXXS;
    }

    function togglePanel(panelId) {
        root.panel = root.panel === panelId ? "" : panelId;
    }

    readonly property bool live: root.player.live

    onLiveChanged: {
        if (root.live)
            root.panel = "";
    }

    Loader {
        anchors.fill: parent
        active: root.player.wallpaperEnabled

        sourceComponent: MediaArtBackdrop {
            radius: 30
            stableHeight: root.baseHeight
            activePlayer: root.activePlayer
            onArtReady: root.player.maybeFinishSwitch()
        }
    }

    MediaPlayerEmptyState {
        anchors.centerIn: parent
        visible: root.player.showNoPlayerNow
    }

    Item {
        id: cardBody

        anchors {
            fill: parent
            margins: root.cardMargin
        }
        visible: !root.player.noneAvailable && !root.player.showNoPlayerNow

        Item {
            id: header

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: root.artSize

            MediaArtwork {
                id: art

                anchors {
                    left: parent.left
                    top: parent.top
                }
                width: root.artSize
                height: root.artSize
                cornerRadius: 28
                placeholderIconSize: 56
                artUrl: root.artUrl
            }

            ClippingRectangle {
                id: buttonGroup

                anchors {
                    right: parent.right
                    top: parent.top
                }
                width: buttonRow.width
                height: root.groupButtonSize
                color: "transparent"
                radius: root.groupOuterRadius

                Row {
                    id: buttonRow

                    spacing: Theme.spacingXXS

                    GroupButton {
                        id: volumeButton

                        panelId: "volume"
                        iconName: root.player.getVolumeIcon()
                        enabled: root.player.volumeAvailable

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: wheelEvent => {
                                wheelEvent.accepted = true;
                                root.player.adjustVolume((wheelEvent.angleDelta.y > 0 ? 1 : -1) * AudioService.wheelVolumeStep);
                            }
                        }
                    }

                    GroupButton {
                        id: outputButton

                        panelId: "devices"
                        iconName: root.player.getAudioDeviceIcon(AudioService.sink)

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: wheelEvent => {
                                wheelEvent.accepted = true;
                                AudioService.cycleAudioOutputDirection(wheelEvent.angleDelta.y < 0);
                            }
                        }
                    }

                    GroupButton {
                        id: sourceButton

                        panelId: "players"
                        visible: (root.player.allPlayers?.length || 0) > 0
                        iconName: "assistant_device"
                    }
                }
            }

            Column {
                anchors {
                    left: art.right
                    leftMargin: Theme.spacingL
                    right: buttonGroup.left
                    rightMargin: Theme.spacingM
                    top: parent.top
                    topMargin: Theme.spacingXS
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
            id: seekBlock

            anchors {
                horizontalCenter: parent.horizontalCenter
                top: header.bottom
                topMargin: root.seekTopMargin
            }
            width: Math.round(parent.width * root.seekWidthRatio)
            height: root.seekBlockHeight

            DankSeekbar {
                anchors.top: parent.top
                width: parent.width
                height: root.seekbarHeight
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
            id: transport

            anchors {
                horizontalCenter: parent.horizontalCenter
                top: seekBlock.bottom
                topMargin: root.seekGapBottom
            }
            height: root.transportHeight
            spacing: Theme.spacingS

            DankActionButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: !!root.activePlayer?.shuffleSupported
                buttonSize: 48
                radius: 24
                iconName: "shuffle"
                iconSize: 20
                iconColor: root.activePlayer?.shuffle ? root.accent : Theme.surfaceText
                backgroundColor: Theme.withAlpha(root.accent, root.activePlayer?.shuffle ? 0.2 : 0)
                onClicked: {
                    if (root.activePlayer?.canControl && root.activePlayer?.shuffleSupported)
                        root.activePlayer.shuffle = !root.activePlayer.shuffle;
                }
            }

            TransportButton {
                iconName: "skip_previous"
                enabled: !!root.activePlayer?.canGoPrevious || !!root.activePlayer?.canSeek
                onClicked: MprisController.previousOrRewind()
            }

            DankActionButton {
                anchors.verticalCenter: parent.verticalCenter
                width: 96
                height: root.transportHeight
                radius: root.playing ? 16 : root.transportHeight / 2
                iconName: root.playing ? "pause" : "play_arrow"
                iconSize: 32
                iconColor: root.onAccent
                backgroundColor: root.accent
                enabled: !!root.activePlayer?.canTogglePlaying
                opacity: enabled ? 1 : 0.38
                onClicked: root.activePlayer.togglePlaying()
            }

            TransportButton {
                iconName: "skip_next"
                enabled: !!root.activePlayer?.canGoNext
                onClicked: MprisController.next()
            }

            DankActionButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: !!root.activePlayer?.loopSupported
                buttonSize: 48
                radius: 24
                iconName: root.activePlayer?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                iconSize: 20
                iconColor: root.activePlayer && root.activePlayer.loopState !== MprisLoopState.None ? root.accent : Theme.surfaceText
                backgroundColor: Theme.withAlpha(root.accent, root.activePlayer && root.activePlayer.loopState !== MprisLoopState.None ? 0.2 : 0)
                onClicked: root.player.cycleLoopState()
            }
        }

        Rectangle {
            id: panelBox

            anchors {
                left: parent.left
                right: parent.right
                top: transport.bottom
                topMargin: Theme.spacingM
            }
            height: root.panelHeight
            radius: 20
            color: Theme.withAlpha(Theme.surfaceText, 0.08)
            visible: root.panel !== ""

            Loader {
                anchors {
                    fill: parent
                    margins: root.panelPadding
                }
                sourceComponent: {
                    switch (root.panel) {
                    case "volume":
                        return volumePanel;
                    case "devices":
                        return devicesPanel;
                    case "players":
                        return playersPanel;
                    }
                    return null;
                }
            }
        }
    }

    Component {
        id: volumePanel

        Row {
            spacing: Theme.spacingS

            DankActionButton {
                anchors.verticalCenter: parent.verticalCenter
                buttonSize: 40
                radius: 20
                iconName: root.player.getVolumeIcon()
                iconSize: 20
                iconColor: root.player.currentVolume > 0 ? root.accent : Theme.surfaceTextMedium
                backgroundColor: Theme.withAlpha(root.accent, 0.14)
                onClicked: root.player.toggleMute()
            }

            DankSlider {
                id: volumeSlider

                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 40 - parent.spacing
                height: 40
                minimum: 0
                maximum: Math.max(1, Math.round(root.player.maxVolumePercent))
                enabled: root.player.volumeAvailable
                unit: "%"
                thumbOutlineColor: Theme.surfaceContainerHigh
                valueOverride: Math.round(root.player.currentVolume * 100)
                onSliderValueChanged: newValue => root.player.setVolume(newValue / 100)

                Binding on value {
                    value: Math.round(root.player.currentVolume * 100)
                    when: !volumeSlider.isDragging
                }
            }
        }
    }

    Component {
        id: devicesPanel

        DankListView {
            clip: true
            spacing: Theme.spacingXXS
            model: root.sinks

            delegate: PanelRow {
                required property var modelData

                readonly property bool isCurrent: modelData === AudioService.sink

                width: ListView.view.width
                iconName: root.player.getAudioDeviceIcon(modelData)
                title: AudioService.displayName(modelData)
                subtitle: {
                    if (!modelData?.audio)
                        return isCurrent ? I18n.tr("Active") : I18n.tr("Available");
                    if (modelData.audio.muted)
                        return I18n.tr("Muted");
                    return Math.round(modelData.audio.volume * 100) + "%";
                }
                selected: isCurrent
                onActivated: AudioService.setSink(modelData)
            }
        }
    }

    Component {
        id: playersPanel

        DankListView {
            clip: true
            spacing: Theme.spacingXXS
            model: root.players

            delegate: PanelRow {
                required property var modelData

                width: ListView.view.width
                iconName: "music_note"
                title: {
                    const identity = modelData?.identity || "";
                    const trackTitle = modelData?.trackTitle || "";
                    return trackTitle.length > 0 ? identity + " - " + trackTitle : identity;
                }
                subtitle: modelData?.trackArtist || ""
                selected: modelData === root.activePlayer
                onActivated: MprisController.switchActivePlayer(modelData)
            }
        }
    }

    component GroupButton: DankActionButton {
        required property string panelId

        readonly property bool active: root.panel === panelId

        buttonSize: root.groupButtonSize
        radius: root.groupInnerRadius
        iconSize: 20
        iconColor: active ? root.accent : Theme.surfaceText
        backgroundColor: active ? Theme.withAlpha(root.accent, 0.2) : Theme.withAlpha(Theme.surfaceText, 0.1)
        opacity: enabled ? 1 : 0.38
        onClicked: root.togglePanel(panelId)
    }

    component TransportButton: DankActionButton {
        anchors.verticalCenter: parent.verticalCenter
        width: 64
        height: root.transportHeight
        radius: 16
        iconSize: 26
        backgroundColor: Theme.withAlpha(root.accent, 0.14)
        opacity: enabled ? 1 : 0.38
    }

    component PanelRow: Rectangle {
        id: row

        property string iconName: "speaker"
        property string title: ""
        property string subtitle: ""
        property bool selected: false

        signal activated

        height: root.rowHeight
        radius: 14
        color: row.selected ? Theme.withAlpha(root.accent, 0.2) : "transparent"

        Row {
            anchors {
                left: parent.left
                right: checkIcon.left
                leftMargin: Theme.spacingM
                rightMargin: Theme.spacingS
                verticalCenter: parent.verticalCenter
            }
            spacing: Theme.spacingS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: row.iconName
                size: 20
                color: row.selected ? root.accent : Theme.surfaceText
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 20 - parent.spacing

                StyledText {
                    width: parent.width
                    text: row.title
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: row.selected ? Font.DemiBold : Font.Medium
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    text: row.subtitle
                    color: Theme.surfaceTextSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }
        }

        DankIcon {
            id: checkIcon

            anchors {
                right: parent.right
                rightMargin: Theme.spacingM
                verticalCenter: parent.verticalCenter
            }
            name: "check"
            size: 20
            color: root.accent
            visible: row.selected
            width: row.selected ? 20 : 0
        }

        StateLayer {
            stateColor: row.selected ? root.accent : Theme.surfaceText
            onClicked: row.activated()
        }
    }
}
