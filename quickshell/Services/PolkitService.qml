pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Polkit

Singleton {
    id: root
    readonly property var log: Log.scoped("PolkitService")

    readonly property bool disablePolkitIntegration: Quickshell.env("DMS_DISABLE_POLKIT") === "1"

    readonly property bool polkitAvailable: !disablePolkitIntegration
    readonly property alias agent: polkitAgentInstance

    PolkitAgent {
        id: polkitAgentInstance
    }

    Component.onCompleted: {
        if (!disablePolkitIntegration)
            log.info("Initialized successfully");
    }
}
