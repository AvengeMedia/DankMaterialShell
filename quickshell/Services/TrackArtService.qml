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
    property string activeTrackArtFile: ""
    property bool loading: false

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

        _bgArtSource = "";
        loading = true;

        if (!url.startsWith("http://") && !url.startsWith("https://")) {
            const localUrl = url;
            const filePath = url.startsWith("file://") ? url.substring(7) : url;
            Proc.runCommand("trackart", ["test", "-f", filePath], (output, exitCode) => {
                if (_lastArtUrl !== localUrl)
                    return;
                if (exitCode === 0)
                    _bgArtSource = localUrl;
                loading = false;
            }, 200);
            return;
        }

        const filename = "/tmp/.dankshell/trackart_" + Date.now() + ".jpg";
        activeTrackArtFile = filename;

        Proc.runCommand("trackart_cleanup", ["sh", "-c", "mkdir -p /tmp/.dankshell && find /tmp/.dankshell -name 'trackart_*' ! -name '" + filename.split('/').pop() + "' -delete"], null, 0);

        Proc.runCommand("trackart", ["dms", "dl", "-o", filename, "--user-agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36", url], (output, exitCode) => {
            const resultPath = output.trim();
            if (resultPath !== filename)
                return;
            if (exitCode === 0)
                _bgArtSource = "file://" + resultPath;
            loading = false;
        }, 200);
    }

    property MprisPlayer activePlayer: MprisController.activePlayer

    onActivePlayerChanged: {
        loadArtwork(activePlayer?.trackArtUrl ?? "");
    }
}
