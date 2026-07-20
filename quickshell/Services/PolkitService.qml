pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root
    readonly property var log: Log.scoped("PolkitService")

    readonly property bool disablePolkitIntegration: Quickshell.env("DMS_DISABLE_POLKIT") === "1"

    readonly property bool polkitAvailable: !disablePolkitIntegration
    readonly property var agent: polkitAgentLoader.item

    Loader {
        id: polkitAgentLoader
        active: root.polkitAvailable
        asynchronous: false
        source: "PolkitAgentInstance.qml"
    }

    Component.onCompleted: {
        if (!disablePolkitIntegration)
            log.info("Initialized successfully");
    }
}
