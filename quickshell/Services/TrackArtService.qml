pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import Quickshell.Services.Mpris
import qs.Common

Singleton {
    id: root

    property string _lastArtUrl: ""
    property string _bgArtSource: ""
    property bool loading: false
    property string activePlayerArtUrl: ""

    function getArtworkUrl(player) {
        if (!player) return "";
        
        // 1. If native trackArtUrl is present and valid
        let artUrl = player.trackArtUrl || "";
        if (artUrl !== "") {
            return artUrl;
        }

        // 2. Fallback to raw metadata mpris:artUrl if present
        if (player.metadata && player.metadata["mpris:artUrl"]) {
            artUrl = player.metadata["mpris:artUrl"].toString();
            if (artUrl !== "") return artUrl;
        }

        // 3. Fallback for YouTube from xesam:url
        if (player.metadata && player.metadata["xesam:url"]) {
            const url = player.metadata["xesam:url"].toString();
            if (url.includes("youtube.com") || url.includes("youtu.be")) {
                const regExp = /^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*/;
                const match = url.match(regExp);
                if (match && match[2].length === 11) {
                    return "https://img.youtube.com/vi/" + match[2] + "/hqdefault.jpg";
                }
            }
        }

        return "";
    }

    function loadArtwork(url) {
        if (!url || url === "") {
            _bgArtSource = "";
            _lastArtUrl = "";
            loading = false;
            return;
        }
        if (url === _lastArtUrl)
            return;
        _lastArtUrl = url;

        if (url.startsWith("http://") || url.startsWith("https://")) {
            _bgArtSource = url;
            loading = false;
            return;
        }

        loading = true;
        const localUrl = url;
        const filePath = url.startsWith("file://") ? url.substring(7) : url;
        Proc.runCommand("trackart", ["test", "-f", filePath], (output, exitCode) => {
            if (_lastArtUrl !== localUrl)
                return;
            _bgArtSource = exitCode === 0 ? localUrl : "";
            loading = false;
        }, 200);
    }

    property MprisPlayer activePlayer: MprisController.activePlayer

    onActivePlayerChanged: _updateArtUrl()

    Connections {
        target: root.activePlayer
        ignoreUnknownSignals: true
        function onTrackTitleChanged() { root._updateArtUrl(); }
        function onTrackArtUrlChanged() { root._updateArtUrl(); }
        function onMetadataChanged() { root._updateArtUrl(); }
    }

    function _updateArtUrl() {
        const url = getArtworkUrl(activePlayer);
        activePlayerArtUrl = url;
        loadArtwork(url);
    }
}
