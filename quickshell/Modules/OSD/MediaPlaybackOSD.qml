import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets
import Quickshell.Services.Mpris
import Quickshell.Widgets

DankOSD {
    id: root

    readonly property bool useVertical: isVerticalLayout
    readonly property var player: MprisController.activePlayer

    osdWidth: useVertical ? (40 + Theme.spacingS * 2) : Math.min(280, screenWidth - Theme.spacingM * 2)
    osdHeight: useVertical ? (Theme.iconSize * 2) : (40 + Theme.spacingS * 2)
    autoHideInterval: 3000
    enableMouseInteraction: true

    property string _displayIcon: "music_note"

    function updatePlaybackIcon() {
        if (!player) {
            _displayIcon = "music_note";
            iconDebounce.stop();
            return false;
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
        if (icon === _displayIcon) {
            iconDebounce.stop();
            return false;
        }
        iconDebounce.pendingIcon = icon;
        iconDebounce.restart();
        return true;
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

    function _showPending() {
        _pendingShow = false;
        pendingShowFallback.stop();
        show();
    }

    function _evaluateShow() {
        // art url can land in a later metadata update than the title
        if (TrackArtService.getArtworkUrl(player) === "") {
            _pendingShow = true;
            pendingShowFallback.interval = 600;
            pendingShowFallback.restart();
            return;
        }
        if (TrackArtService.artReadyFor(player) && artPreloader.status === Image.Ready) {
            _showPending();
            return;
        }
        _pendingShow = true;
        pendingShowFallback.interval = 1500;
        pendingShowFallback.restart();
    }

    Timer {
        id: iconDebounce
        interval: 150
        property string pendingIcon: "music_note"
        onTriggered: root._displayIcon = pendingIcon
    }

    Timer {
        id: pendingShowFallback
        interval: 1500
        onTriggered: {
            if (!root._pendingShow)
                return;
            root._pendingShow = false;
            root.show();
        }
    }

    Image {
        id: artPreloader
        source: TrackArtService.resolvedArtUrl
        visible: false
        asynchronous: true
        cache: true
    }

    onPlayerChanged: {
        if (!player) {
            _pendingShow = false;
            pendingShowFallback.stop();
            hide();
        }
    }

    Connections {
        target: TrackArtService
        function onLoadingChanged() {
            if (!root._pendingShow)
                return;
            if (TrackArtService.loading) {
                pendingShowFallback.interval = 1500;
                pendingShowFallback.restart();
                return;
            }
            if (!TrackArtService.resolvedArtUrl) {
                root._showPending();
                return;
            }
            if (TrackArtService.artReadyFor(root.player) && artPreloader.status === Image.Ready)
                root._showPending();
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
                root._showPending();
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

            const newTitle = player.trackTitle || "";
            const newArtist = player.trackArtist || "";
            const newAlbum = player.trackAlbum || "";
            const trackChanged = newTitle !== root._displayTitle || newArtist !== root._displayArtist || newAlbum !== root._displayAlbum;

            root._displayTitle = newTitle;
            root._displayArtist = newArtist;
            root._displayAlbum = newAlbum;

            const iconChanged = root.updatePlaybackIcon();

            // live streams re-emit metadata as mpris:length grows - ignore churn
            if (!trackChanged && !iconChanged)
                return;

            // vertical layout has no art background
            if (root.useVertical) {
                root.show();
                return;
            }
            if (trackChanged) {
                root._evaluateShow();
                return;
            }
            if (!root._pendingShow)
                root.show();
        }

        function onTrackArtUrlChanged() {
            handleUpdate();
        }
        function onMetadataChanged() {
            handleUpdate();
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
                visible: TrackArtService.resolvedArtUrl !== ""

                Image {
                    id: bgImage
                    anchors.centerIn: parent
                    width: Math.max(parent.width, parent.height)
                    height: width
                    source: TrackArtService.resolvedArtUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: false
                }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: Theme.cornerRadius
                    color: "transparent"
                    opacity: 0.7

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
                spacing: Theme.spacingXXS

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
