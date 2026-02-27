pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property bool locationAvailable: DMSService.isConnected && (DMSService.capabilities.length === 0 || DMSService.capabilities.includes("location"))

    property var latitude: 0.0
    property var longitude: 0.0

    signal locationChanged(var data)

    Component.onCompleted: {
        console.info("LocationService: Initializing...");
        getState();
    }

    Connections {
        target: DMSService

        function onLocationStateUpdate(data) {
            if (locationAvailable) {
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
        if (!locationAvailable)
            return;

        DMSService.sendRequest("location.getState", null, response => {
            if (response.result) {
                handleStateUpdate(response.result);
            }
        });
    }
}
