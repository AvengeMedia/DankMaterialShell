pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property bool locationAvailable: DMSService.isConnected && (DMSService.capabilities.length === 0 || DMSService.capabilities.includes("location"))
    readonly property bool valid: latitude !== 0 || longitude !== 0

    property var latitude: 0.0
    property var longitude: 0.0

    signal locationChanged(var data)

    onLocationAvailableChanged: {
        if (locationAvailable && !valid)
            getState();
    }

    Connections {
        target: DMSService

        function onLocationStateUpdate(data) {
            if (!locationAvailable)
                return;
            handleStateUpdate(data);
        }
    }

    function handleStateUpdate(data) {
        const lat = data.latitude;
        const lon = data.longitude;
        if (lat === 0 && lon === 0)
            return;

        root.latitude = lat;
        root.longitude = lon;
        root.locationChanged(data);
    }

    function getState() {
        if (!locationAvailable)
            return;

        DMSService.sendRequest("location.getState", null, response => {
            if (response.result)
                handleStateUpdate(response.result);
        });
    }
}
