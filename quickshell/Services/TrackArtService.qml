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
    // sha1s of placeholder art to reject (Chrome's own logo, shown before real cover).
    readonly property var _artHashDenylist: ["764a730860c5b8a7bbee690ee5a443672ae37dc8"]

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

    function _commit(u) {
        resolvedArtUrl = u;
        _committedArtKey = u !== "" ? _pendingArtKey : "";
    }

    function loadArtwork(url) {
        if (!url || url === "") {
            // Keep stale art; only blank once the empty url debounce settles.
            _lastArtUrl = "";
            loading = false;
            _clearDebounce.restart();
            return;
        }
        _clearDebounce.stop();
        if (url === _lastArtUrl)
            return;
        _lastArtUrl = url;

        if (url.startsWith("http://") || url.startsWith("https://")) {
            loading = true;
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
                    _commit(localFileUrl);
                    loading = false;
                } else {
                    const dlCmd = "mkdir -p \"$(dirname \"$1\")\" && curl -f -s -L -o \"$1\" \"$2\" && mv \"$1\" \"$3\" || { rm -f \"$1\"; exit 1; }";

                    // 2. Check if this is a YouTube URL to do high quality 16:9 fallback
                    if (targetUrl.includes("img.youtube.com/vi/")) {
                        const videoId = targetUrl.split("/vi/")[1].split("/")[0];
                        const maxresUrl = "https://img.youtube.com/vi/" + videoId + "/maxresdefault.jpg";
                        const mqUrl = "https://img.youtube.com/vi/" + videoId + "/mqdefault.jpg";
                        const tmpPath = filePath + ".tmp";

                        Proc.runCommand(null, ["sh", "-c", dlCmd, "sh", tmpPath, maxresUrl, filePath], (maxOutput, maxExitCode) => {
                            if (_lastArtUrl !== targetUrl)
                                return;

                            if (maxExitCode === 0) {
                                _commit(localFileUrl);
                                loading = false;
                            } else {
                                Proc.runCommand(null, ["sh", "-c", dlCmd, "sh", tmpPath, mqUrl, filePath], (mqOutput, mqExitCode) => {
                                    if (_lastArtUrl !== targetUrl)
                                        return;

                                    _commit(mqExitCode === 0 ? localFileUrl : targetUrl);
                                    loading = false;
                                }, 50, 15000);
                            }
                        }, 50, 15000);
                    } else {
                        // Standard curl download for other remote URLs (e.g. SoundCloud)
                        const tmpPath = filePath + ".tmp";
                        Proc.runCommand(null, ["sh", "-c", dlCmd, "sh", tmpPath, targetUrl, filePath], (dlOutput, dlExitCode) => {
                            if (_lastArtUrl !== targetUrl)
                                return;

                            _commit(dlExitCode === 0 ? localFileUrl : targetUrl);
                            loading = false;
                        }, 50, 15000);
                    }
                }
            }, 50, 5000);
            return;
        }

        loading = true;
        const localUrl = url;
        const filePath = url.startsWith("file://") ? url.substring(7) : url;
        // Cover lands after metadata, so poll; hash only to reject placeholder art.
        const script = "f=\"$1\"; for i in $(seq 20); do [ -f \"$f\" ] && break; sleep 0.15; done; [ -f \"$f\" ] || exit 1; sha1sum \"$f\" | cut -c1-40";
        Proc.runCommand(null, ["sh", "-c", script, "sh", filePath], (output, exitCode) => {
            if (_lastArtUrl !== localUrl)
                return;
            if (exitCode !== 0) {
                // Keep current art rather than blanking (avoids an accent/art flash).
                loading = false;
                return;
            }
            // Placeholder (Chrome logo): skip without committing so the real cover still resolves.
            if (_artHashDenylist.indexOf((output || "").trim()) !== -1) {
                loading = false;
                return;
            }
            _commit(localUrl);
            loading = false;
        }, 50, 5000);
    }

    Timer {
        id: _clearDebounce
        interval: 800
        onTriggered: {
            if (root._lastArtUrl === "")
                root._commit("");
        }
    }

    property MprisPlayer activePlayer: MprisController.activePlayer

    property string _committedArtKey: ""
    property string _pendingArtKey: ""

    onActivePlayerChanged: _updateArtUrl()

    Connections {
        target: root.activePlayer
        ignoreUnknownSignals: true
        function onTrackTitleChanged() { root._updateArtUrl(); }
        function onTrackArtUrlChanged() { root._updateArtUrl(); }
        function onMetadataChanged() { root._updateArtUrl(); }
    }

    function _trackKey() {
        const p = activePlayer;
        if (!p)
            return "";
        // Prefer the stable track id; title/artist/album fill in progressively (Chrome).
        const tid = p.metadata && p.metadata["mpris:trackid"] ? p.metadata["mpris:trackid"].toString() : "";
        if (tid !== "")
            return tid;
        return (p.trackTitle || "") + "" + (p.trackArtist || "") + "" + (p.trackAlbum || "");
    }

    function artReadyFor(player) {
        const url = getArtworkUrl(player);
        return url !== "" && url === _lastArtUrl && !loading && resolvedArtUrl !== "";
    }

    function _updateArtUrl() {
        const key = _trackKey();
        // Skip once real art is committed for this track (dedup Chrome's multi-size
        // re-publish). The lock is set in _commit(), never optimistically, so a rejected
        // placeholder or a short-circuited duplicate url can't wedge the real cover out.
        if (key !== "" && key === _committedArtKey)
            return;
        _pendingArtKey = key;
        loadArtwork(getArtworkUrl(activePlayer));
    }
}
