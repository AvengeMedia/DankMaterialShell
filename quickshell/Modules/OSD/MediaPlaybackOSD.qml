import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets
import Quickshell.Services.Mpris

DankOSD {
    id: root

    readonly property bool useVertical: isVerticalLayout
    readonly property var player: MprisController.currentPlayer
    readonly property bool isCustomSource: MprisController.useCustomSource

    osdWidth: useVertical ? (40 + Theme.spacingS * 2) : Math.min(280, Screen.width - Theme.spacingM * 2)
    osdHeight: useVertical ? (Theme.iconSize * 2) : (40 + Theme.spacingS * 2)
    autoHideInterval: 3000
    enableMouseInteraction: true

    property string _displayIcon: "music_note"

    function updatePlaybackIcon() {
        if (!player) {
            _displayIcon = "music_note";
            iconDebounce.stop();
            return;
        }
        let icon = "music_note";
        switch (player.playbackState) {
        case CustomMediaSource.statePlaying:
            icon = "play_arrow";
            break;
        case CustomMediaSource.statePaused:
        case CustomMediaSource.stateStopped:
            icon = "pause";
            break;
        }
        if (icon === _displayIcon)
            return;
        iconDebounce.pendingIcon = icon;
        iconDebounce.restart();
    }

    function togglePlaying() {
        if (player?.canTogglePlaying) {
            player.togglePlaying();
        }
    }

    property bool _pendingShow: false

    Timer {
        id: iconDebounce
        interval: 150
        property string pendingIcon: "music_note"
        onTriggered: root._displayIcon = pendingIcon
    }

    Image {
        id: artPreloader
        source: TrackArtService._bgArtSource
        visible: false
        asynchronous: true
        cache: true
    }

    onPlayerChanged: {
        if (!player) {
            _pendingShow = false;
            hide();
        }
    }

    Connections {
        target: TrackArtService
        function onLoadingChanged() {
            if (TrackArtService.loading || !root._pendingShow)
                return;
            if (!TrackArtService._bgArtSource || artPreloader.status === Image.Ready) {
                root._pendingShow = false;
                root.show();
            }
        }
    }

    Connections {
        target: artPreloader
        function onStatusChanged() {
            if (!root._pendingShow || TrackArtService.loading)
                return;
            switch (artPreloader.status) {
            case Image.Ready:
            case Image.Error:
                root._pendingShow = false;
                root.show();
                break;
            }
        }
    }

    // Unified update handler for both MPRIS and CustomSource
    function handlePlaybackUpdate() {
        if (!root.player?.trackTitle)
            return;
        if (!SettingsData.osdMediaPlaybackEnabled)
            return;

        root.updatePlaybackIcon();
        TrackArtService.loadArtwork(player.trackArtUrl);

        if (!player.trackArtUrl || player.trackArtUrl === "") {
            root.show();
            return;
        }
        if (TrackArtService.loading) {
            root._pendingShow = true;
            return;
        }
        if (!TrackArtService._bgArtSource || artPreloader.status === Image.Ready) {
            root.show();
            return;
        }
        root._pendingShow = true;
    }

    // Connections for MPRIS player
    Connections {
        target: isCustomSource ? null : player

        function onTrackArtUrlChanged() {
            TrackArtService.loadArtwork(player.trackArtUrl);
        }
        function onIsPlayingChanged() {
            handlePlaybackUpdate();
        }
        function onTrackChanged() {
            if (!useVertical)
                handlePlaybackUpdate();
        }
    }

    // Connections for CustomMediaSource
    Connections {
        target: isCustomSource ? CustomMediaSource : null

        function onPlayingStateChanged() {
            handlePlaybackUpdate();
        }
        function onTrackInfoChanged() {
            if (!useVertical)
                handlePlaybackUpdate();
        }
        function onArtworkChanged() {
            TrackArtService.loadArtwork(player.trackArtUrl);
        }
    }

    content: Loader {
        anchors.fill: parent
        sourceComponent: useVertical ? verticalContent : horizontalContent
    }

    Component {
        id: horizontalContent

        Item {
            property int gap: Theme.spacingS

            anchors.centerIn: parent
            width: parent.width - Theme.spacingS * 2
            height: 40

            MouseArea {
                anchors.fill: parent
                onClicked: root.hide()
            }

            Item {
                id: bgContainer
                anchors.fill: parent
                visible: TrackArtService._bgArtSource !== ""

                Image {
                    id: bgImage
                    anchors.centerIn: parent
                    width: Math.max(parent.width, parent.height)
                    height: width
                    source: TrackArtService._bgArtSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: false
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
                        blur: 0.3
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

            Rectangle {
                width: Theme.iconSize
                height: Theme.iconSize
                radius: Theme.iconSize / 2
                color: "transparent"
                x: parent.gap
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    anchors.centerIn: parent
                    name: root._displayIcon
                    size: Theme.iconSize
                    color: playPauseButton.containsMouse ? Theme.primary : Theme.surfaceText
                }

                MouseArea {
                    id: playPauseButton

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        togglePlaying();
                        root.hide();
                    }
                }
            }

            Column {
                x: parent.gap * 2 + Theme.iconSize
                width: parent.width - Theme.iconSize - parent.gap * 3
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                StyledText {
                    id: topText
                    width: parent.width
                    text: player ? `${player.trackTitle || I18n.tr("Unknown Title")}` : ""
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }

                StyledText {
                    id: bottomText
                    width: parent.width
                    text: player ? ((player.trackArtist || I18n.tr("Unknown Artist")) + (player.trackAlbum ? ` • ${player.trackAlbum}` : "")) : ""
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Light
                    color: Theme.surfaceText
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }
            }
        }
    }

    Component {
        id: verticalContent

        Item {
            property int gap: Theme.spacingS

            MouseArea {
                anchors.fill: parent
                onClicked: root.hide()
            }

            Rectangle {
                width: Theme.iconSize
                height: Theme.iconSize
                radius: Theme.iconSize / 2
                color: "transparent"
                anchors.centerIn: parent
                y: gap

                DankIcon {
                    anchors.centerIn: parent
                    name: root._displayIcon
                    size: Theme.iconSize
                    color: playPauseButtonVert.containsMouse ? Theme.primary : Theme.surfaceText
                }

                MouseArea {
                    id: playPauseButtonVert

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        togglePlaying();
                        root.hide();
                    }
                }
            }
        }
    }
}
