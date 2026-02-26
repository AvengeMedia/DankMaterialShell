pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool available: false

    function detectAvailability() {
        try {
            const testObj = Qt.createQmlObject(`
                import QtQuick
                import QtMultimedia
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
            console.warn("MultimediaService: QtMultimedia not available");
        }
    }
}
