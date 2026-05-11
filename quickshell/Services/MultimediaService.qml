pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root
    readonly property var log: Log.scoped("MultimediaService")

    readonly property bool available: probeLoader.status === Loader.Ready

    Loader {
        id: probeLoader
        source: "MultimediaProbe.qml"
        active: true
        onStatusChanged: {
            if (status === Loader.Error)
                log.warn("QtMultimedia not available");
        }
    }
}
