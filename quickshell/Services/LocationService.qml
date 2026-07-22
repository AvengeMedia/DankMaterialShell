pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services

Singleton {
    id: root

    readonly property bool wantsLocation: SettingsData.weatherEnabled && SettingsData.useAutoLocation
    readonly property bool locationAvailable: DMSService.isConnected && DMSService.capabilities.includes("location")
    readonly property bool valid: latitude !== 0 || longitude !== 0

    property var latitude: 0.0
    property var longitude: 0.0

    signal locationChanged(var data)

    onWantsLocationChanged: {
        if (wantsLocation) {
            ensureSubscription();
        } else if (DMSService.activeSubscriptions.includes("location")) {
            DMSService.removeSubscription("location");
        }
    }

    onLocationAvailableChanged: ensureSubscription()

    Component.onCompleted: ensureSubscription()

    Connections {
        target: DMSService

        function onConnectionStateChanged() {
            if (DMSService.isConnected)
                root.ensureSubscription();
        }

        function onLocationStateUpdate(data) {
            if (!root.wantsLocation)
                return;
            root.handleStateUpdate(data);
        }
    }

    function ensureSubscription() {
        if (!wantsLocation)
            return;
        if (!locationAvailable)
            return;
        if (DMSService.activeSubscriptions.includes("location"))
            return;
        if (DMSService.activeSubscriptions.includes("all"))
            return;

        DMSService.addSubscription("location");
        if (!valid)
            getState();
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
        if (!wantsLocation)
            return;
        if (!locationAvailable)
            return;

        DMSService.sendRequest("location.getState", null, response => {
            if (response.result)
                handleStateUpdate(response.result);
        });
    }
}
