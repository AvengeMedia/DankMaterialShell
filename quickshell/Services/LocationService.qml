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

    readonly property var lowPriorityCmd: ["nice", "-n", "19", "ionice", "-c3"]
    readonly property var curlBaseCmd: ["curl", "-sS", "--fail", "--connect-timeout", "3", "--max-time", "6", "--limit-rate", "100k", "--compressed"]

    Component.onCompleted: {
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
        if (!locationAvailable) {
            fetchIPLocation();
            return;
        }

        DMSService.sendRequest("location.getState", null, response => {
            if (response.result && (response.result.latitude !== 0 || response.result.longitude !== 0)) {
                handleStateUpdate(response.result);
                return;
            }
            fetchIPLocation();
        });
    }

    function fetchIPLocation() {
        if (root.valid)
            return;
        ipLocationFetcher.running = true;
    }

    Process {
        id: ipLocationFetcher
        command: root.lowPriorityCmd.concat(root.curlBaseCmd).concat(["http://ip-api.com/json/"])
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim();
                if (!raw || raw[0] !== "{")
                    return;

                try {
                    const data = JSON.parse(raw);
                    if (data.status === "fail")
                        return;

                    const lat = parseFloat(data.lat);
                    const lon = parseFloat(data.lon);
                    if (isNaN(lat) || isNaN(lon) || (lat === 0 && lon === 0))
                        return;

                    root.handleStateUpdate({ latitude: lat, longitude: lon });
                } catch (e) {}
            }
        }
    }
}
