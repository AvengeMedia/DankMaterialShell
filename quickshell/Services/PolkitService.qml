pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root
    readonly property var log: Log.scoped("PolkitService")

    readonly property bool disablePolkitIntegration: Quickshell.env("DMS_DISABLE_POLKIT") === "1"

    property bool polkitAvailable: false
    property var agent: null

    function createPolkitAgent() {
        try {
            const qmlString = `
                import QtQuick
                import Quickshell.Services.Polkit
import qs.Services

                PolkitAgent {
                }
            `

            agent = Qt.createQmlObject(qmlString, root, "PolkitService.Agent")
            polkitAvailable = true
            log.info("Initialized successfully")
        } catch (e) {
            polkitAvailable = false
            log.warn("Polkit not available - authentication prompts disabled. This requires a newer version of Quickshell.")
        }
    }

    Component.onCompleted: {
        if (disablePolkitIntegration) {
            return
        }
        createPolkitAgent()
    }
}
