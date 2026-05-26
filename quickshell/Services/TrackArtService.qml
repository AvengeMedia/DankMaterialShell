pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import Quickshell.Services.Mpris
import qs.Common

Singleton {
    id: root

    property string _lastArtUrl: ""
    property string resolvedArtUrl: ""
    property alias _bgArtSource: root.resolvedArtUrl
    property bool loading: false

    function djb2Hash(str) {
        if (!str) return "";
        let hash = 5381;
        for (let i = 0; i < str.length; i++) {
            hash = ((hash << 5) + hash) + str.charCodeAt(i);
            hash = hash & 0x7FFFFFFF;
        }
        return hash.toString(16).padStart(8, '0');
    }

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
            resolvedArtUrl = "";
            _lastArtUrl = "";
            loading = false;
            return;
        }
        if (url === _lastArtUrl)
            return;
        _lastArtUrl = url;

        if (url.startsWith("http://") || url.startsWith("https://")) {
            loading = true;
            resolvedArtUrl = ""; // Clear stale artwork immediately while loading
            const targetUrl = url;
            const hash = djb2Hash(url);
            const cacheDir = Paths.strip(Paths.imagecache);
            const filePath = cacheDir + "/remote_" + hash;
            const localFileUrl = "file://" + filePath;

            // 1. First, check if the file already exists locally
            Proc.runCommand(null, ["test", "-f", filePath], (output, exitCode) => {
                if (_lastArtUrl !== targetUrl)
                    return;

                if (exitCode === 0) {
                    resolvedArtUrl = localFileUrl;
                    loading = false;
                } else {
                    Paths.mkdir(Paths.imagecache);

                    // 2. Check if this is a YouTube URL to do high quality 16:9 fallback
                    if (targetUrl.includes("img.youtube.com/vi/")) {
                        const videoId = targetUrl.split("/vi/")[1].split("/")[0];
                        const maxresUrl = "https://img.youtube.com/vi/" + videoId + "/maxresdefault.jpg";
                        const mqUrl = "https://img.youtube.com/vi/" + videoId + "/mqdefault.jpg";
                        const tmpPath = filePath + ".tmp";

                        const maxresCmd = "curl -f -s -L -o '" + tmpPath + "' '" + maxresUrl + "' && mv '" + tmpPath + "' '" + filePath + "' || { rm -f '" + tmpPath + "'; exit 1; }";
                        Proc.runCommand(null, ["sh", "-c", maxresCmd], (maxOutput, maxExitCode) => {
                            if (_lastArtUrl !== targetUrl)
                                return;

                            if (maxExitCode === 0) {
                                resolvedArtUrl = localFileUrl;
                                loading = false;
                            } else {
                                const mqCmd = "curl -f -s -L -o '" + tmpPath + "' '" + mqUrl + "' && mv '" + tmpPath + "' '" + filePath + "' || { rm -f '" + tmpPath + "'; exit 1; }";
                                Proc.runCommand(null, ["sh", "-c", mqCmd], (mqOutput, mqExitCode) => {
                                    if (_lastArtUrl !== targetUrl)
                                        return;

                                    if (mqExitCode === 0) {
                                        resolvedArtUrl = localFileUrl;
                                    } else {
                                        resolvedArtUrl = targetUrl; // Ultimate fallback
                                    }
                                    loading = false;
                                }, 50, 15000);
                            }
                        }, 50, 15000);
                    } else {
                        // Standard curl download for other remote URLs (e.g. SoundCloud)
                        const tmpPath = filePath + ".tmp";
                        const dlCmd = "curl -f -s -L -o '" + tmpPath + "' '" + targetUrl + "' && mv '" + tmpPath + "' '" + filePath + "' || { rm -f '" + tmpPath + "'; exit 1; }";
                        Proc.runCommand(null, ["sh", "-c", dlCmd], (dlOutput, dlExitCode) => {
                            if (_lastArtUrl !== targetUrl)
                                return;

                            if (dlExitCode === 0) {
                                resolvedArtUrl = localFileUrl;
                            } else {
                                resolvedArtUrl = targetUrl; // Fallback to raw URL
                            }
                            loading = false;
                        }, 50, 15000);
                    }
                }
            }, 50, 5000);
            return;
        }

        loading = true;
        resolvedArtUrl = ""; // Clear stale artwork immediately while verifying local file
        const localUrl = url;
        const filePath = url.startsWith("file://") ? url.substring(7) : url;
        Proc.runCommand(null, ["test", "-f", filePath], (output, exitCode) => {
            if (_lastArtUrl !== localUrl)
                return;
            resolvedArtUrl = exitCode === 0 ? localUrl : "";
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
        loadArtwork(url);
    }
}
