pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property list<MprisPlayer> availablePlayers: Mpris.players.values
    property MprisPlayer activePlayer: availablePlayers.find(p => p.isPlaying) ?? availablePlayers.find(p => p.canControl && p.canPlay) ?? null

    function isFirefoxYoutubeHoverPreview(player: MprisPlayer): bool {
        if (!player)
            return false;
        const id = (player.identity || "").toLowerCase();
        if (!id.includes("firefox"))
            return false;
        const url = (player.metadata?.["xesam:url"] || "").toString();
        return /^https?:\/\/(www\.)?youtube\.com\/?($|\?|#)/i.test(url);
    }
}
