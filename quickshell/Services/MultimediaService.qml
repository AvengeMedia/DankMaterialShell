pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root
    readonly property var log: Log.scoped("MultimediaService")

    readonly property bool available: probeLoader.status === Loader.Ready
    property bool probeRequested: false

    function ensureProbed() {
        probeRequested = true;
    }

    Loader {
        id: probeLoader
        source: "MultimediaProbe.qml"
        active: root.probeRequested
        onStatusChanged: {
            if (status === Loader.Error)
                log.warn("QtMultimedia not available");
        }
    }
}
