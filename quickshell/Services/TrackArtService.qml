pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    property string _lastArtUrl: ""
    property string _bgArtSource: ""

    property string activeTrackArtFile: ""

    function loadArtwork(url) {
        if (!url || url == "") {
            _bgArtSource = "";
            _lastArtUrl = "";
            return;
        }
        if (url == _lastArtUrl)
            return;
        _lastArtUrl = url;
        if (url.startsWith("http://") || url.startsWith("https://")) {
            const filename = "/tmp/.dankshell/trackart_" + Date.now() + ".jpg";
            activeTrackArtFile = filename;

            cleanupProcess.command = ["sh", "-c", "mkdir -p /tmp/.dankshell && find /tmp/.dankshell -name 'trackart_*' ! -name '" + filename.split('/').pop() + "' -delete"];
            cleanupProcess.running = true;

            imageDownloader.command = ["curl", "-L", "-s", "--user-agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36", "-o", filename, url];
            imageDownloader.targetFile = filename;
            imageDownloader.running = true;
            return;
        }
        // otherwise
        _bgArtSource = url;
    }

    property MprisPlayer activePlayer: MprisController.activePlayer

    onActivePlayerChanged: {
        loadArtwork(activePlayer.trackArtUrl);
    }

    Process {
        id: imageDownloader
        running: false
        property string targetFile: ""

        onExited: exitCode => {
            if (exitCode === 0 && targetFile)
                _bgArtSource = "file://" + targetFile;
        }
    }

    Process {
        id: cleanupProcess
        running: false
    }
}
