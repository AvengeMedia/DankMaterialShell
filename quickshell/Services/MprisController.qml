pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property list<MprisPlayer> availablePlayers: Mpris.players.values
    property MprisPlayer activePlayer: availablePlayers.find(p => p.isPlaying) ?? availablePlayers.find(p => p.canControl && p.canPlay) ?? null

    Timer {
        interval: 1000
        running: root.activePlayer?.playbackState === MprisPlaybackState.Playing
        repeat: true
        onTriggered: root.activePlayer?.positionChanged()
    }

    function previousOrRewind(): void {
        if (!activePlayer)
            return;
        if (activePlayer.position > 8 && activePlayer.canSeek)
            activePlayer.position = 0;
        else if (activePlayer.canGoPrevious)
            activePlayer.previous();
    }
}
