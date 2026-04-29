pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root
    readonly property var log: Log.scoped("MultimediaService")

    property bool available: false

    function detectAvailability() {
        try {
            const testObj = Qt.createQmlObject(`
                import QtQuick
                import QtMultimedia
import qs.Services
                Item {}
            `, root, "MultimediaService.TestComponent");
            if (testObj) {
                testObj.destroy();
            }
            available = true;
            return true;
        } catch (e) {
            available = false;
            return false;
        }
    }

    Component.onCompleted: {
        if (!detectAvailability()) {
            log.warn("QtMultimedia not available");
        }
    }
}
