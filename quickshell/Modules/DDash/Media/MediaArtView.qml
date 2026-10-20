pragma ComponentBehavior: Bound

import QtQuick
import qs.Widgets
import qs.Modules.DDash

Item {
    id: root

    required property var player
    property bool showLyrics: true
    property bool holdArt: false

    readonly property real artRadius: surface.contentRadius
    readonly property real artInset: surface.contentInset

    MediaArtSurface {
        id: surface
        anchors.fill: parent
        artStyle: root.player.options?.artStyle ?? "rounded"
        player: root.player

        MediaArtwork {
            id: art
            anchors.fill: parent
            cornerRadius: 0
            placeholderIconSize: DashMetrics.mediaArtPlaceholderIcon
            artUrl: root.holdArt ? "" : root.player.presentation?.artUrl ?? ""
        }
    }

    Loader {
        anchors.fill: parent
        active: root.showLyrics && root.player.lyricsOpen && root.player.live
        onLoaded: item.forceActiveFocus(Qt.PopupFocusReason)

        sourceComponent: LyricsOverlay {
            player: root.player
            radius: root.artRadius
            contentInset: root.artInset
            backgroundParent: surface.contentItem
            backgroundRadius: 0
            blurSource: art
        }
    }
}
