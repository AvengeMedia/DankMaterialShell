pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property bool geoclueAvailable: DMSService.isConnected && (DMSService.capabilities.length === 0 || DMSService.capabilities.includes("geoclue"))

    property var latitude: 0.0
    property var longitude: 0.0

    signal locationChanged(var data)

    Component.onCompleted: {
        console.info("LocationService: Initializing...");
        getState();
    }

    Connections {
        target: DMSService

        function onGeoclueStateUpdate(data) {
            if (geoclueAvailable) {
                handleStateUpdate(data);
            }
        }
    }

    function handleStateUpdate(data) {
        root.latitude = data.latitude;
        root.longitude = data.longitude;

        root.locationChanged(data)
    }

    function getState() {
        if (!geoclueAvailable)
            return;

        DMSService.sendRequest("geoclue.getState", null, response => {
            if (response.result) {
                handleStateUpdate(response.result);
            }
        });
    }
}
