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
        // Remove query parameters for file existence check
        const filePath = url.startsWith("file://") ? url.substring(7).split("?")[0] : url.split("?")[0];
        Proc.runCommand("trackart", ["test", "-f", filePath], (output, exitCode) => {
            if (_lastArtUrl !== localUrl)
                return;
            _bgArtSource = exitCode === 0 ? localUrl : "";
            loading = false;
        }, 200);
    }

    property var activePlayer: MprisController.currentPlayer

    onActivePlayerChanged: {
        loadArtwork(activePlayer?.trackArtUrl ?? "");
    }

    // Watch for artwork changes on CustomMediaSource
    Connections {
        target: MprisController.useCustomSource ? CustomMediaSource : null
        function onArtworkChanged() {
            loadArtwork(CustomMediaSource.trackArtUrl);
        }
    }
}
