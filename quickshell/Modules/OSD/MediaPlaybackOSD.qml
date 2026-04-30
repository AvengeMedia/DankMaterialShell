import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets
import Quickshell.Services.Mpris

DankOSD {
    id: root

    readonly property bool useVertical: isVerticalLayout
    readonly property var player: MprisController.activePlayer

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
        case MprisPlaybackState.Playing:
            icon = "pause";
            break;
        case MprisPlaybackState.Paused:
        case MprisPlaybackState.Stopped:
            icon = "play_arrow";
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
    property string _displayTitle: ""
    property string _displayArtist: ""
    property string _displayAlbum: ""

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

    Connections {
        target: player

        function handleUpdate() {
            if (!root.player?.trackTitle)
                return;
            if (!SettingsData.osdMediaPlaybackEnabled)
                return;
            if (MprisController.isFirefoxYoutubeHoverPreview(player))
                return;

            root._displayTitle = player.trackTitle || "";
            root._displayArtist = player.trackArtist || "";
            root._displayAlbum = player.trackAlbum || "";

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

        function onTrackArtUrlChanged() {
            TrackArtService.loadArtwork(player.trackArtUrl);
        }
        function onIsPlayingChanged() {
            handleUpdate();
        }
        function onTrackChanged() {
            if (!useVertical)
                handleUpdate();
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
                    text: player ? (root._displayTitle || I18n.tr("Unknown Title")) : ""
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }

                StyledText {
                    id: bottomText
                    width: parent.width
                    text: player ? ((root._displayArtist || I18n.tr("Unknown Artist")) + (root._displayAlbum ? ` • ${root._displayAlbum}` : "")) : ""
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
