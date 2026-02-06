import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import Quickshell.Services.Mpris

DankOSD {
    id: root

    readonly property bool useVertical: isVerticalLayout
    readonly property var player: MprisController.activePlayer

    osdWidth: useVertical ? (40 + Theme.spacingS * 2) : Math.min(260, Screen.width - Theme.spacingM * 2)
    osdHeight: useVertical ? (Theme.iconSize * 2) : (40 + Theme.spacingS * 2)
    autoHideInterval: 3000
    enableMouseInteraction: true

    function getPlaybackIcon() {
        if (player.playbackState === MprisPlaybackState.Playing)
            return "play_arrow"
        if (player.playbackState === MprisPlaybackState.Paused || player.playbackState === MprisPlaybackState.Stopped)
            return "pause"
        return "music_note"
    }

    function togglePlaying() {
        if (player?.canTogglePlaying) {
            player.togglePlaying();
        }
    }

    Connections {
        target: player

        function handleUpdate() {
            if (SettingsData.osdMediaPlaybackEnabled) {
                root.show()
            }
        }

        function onIsPlayingChanged() { handleUpdate() }
        // Not enough room to show track name vertically - skip it
        function onTrackChanged() { if (!useVertical) handleUpdate() }
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

            Rectangle {
                width: Theme.iconSize
                height: Theme.iconSize
                radius: Theme.iconSize / 2
                color: "transparent"
                x: parent.gap
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    anchors.centerIn: parent
                    name: getPlaybackIcon()
                    size: Theme.iconSize
                    color: playPauseButton.containsMouse ? Theme.primary : Theme.surfaceText
                }

                MouseArea {
                    id: playPauseButton

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: togglePlaying()
                }
            }

            StyledText {
                id: textItem
                x: parent.gap * 2 + Theme.iconSize
                width: parent.width - Theme.iconSize - parent.gap * 3
                anchors.verticalCenter: parent.verticalCenter
                text: (`${player.trackTitle || I18n.tr("Unknown Title")} • ${player.trackArtist || I18n.tr("Unknown Artist")}`)
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                elide: Text.ElideRight
            }
        }
    }

    Component {
        id: verticalContent

        Item {
            property int gap: Theme.spacingS

            Rectangle {
                width: Theme.iconSize
                height: Theme.iconSize
                radius: Theme.iconSize / 2
                color: "transparent"
                anchors.centerIn: parent
                y: gap

                DankIcon {
                    anchors.centerIn: parent
                    name: getPlaybackIcon()
                    size: Theme.iconSize
                    color: playPauseButtonVert.containsMouse ? Theme.primary : Theme.surfaceText
                }

                MouseArea {
                    id: playPauseButtonVert

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: togglePlaying()
                }
            }
        }
    }
}
