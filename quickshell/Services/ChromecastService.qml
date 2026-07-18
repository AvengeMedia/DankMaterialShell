pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

Singleton {
    id: root
    readonly property var log: Log.scoped("ChromecastService")

    // refCount tracks interest in the service's *state* (e.g. a collapsed widget
    // showing connection status) and drives the subscription. discoveryRefCount
    // tracks interest in the *device list* and additionally drives the mDNS
    // browse, which is more expensive — so it only runs while a detail UI is open.
    property int refCount: 0
    property int discoveryRefCount: 0

    property bool available: false
    property bool stateInitialized: false

    property bool discovering: false
    property var devices: []

    // Connection / playback state, mirrored from the core service.
    property bool connected: false
    property var activeDevice: null
    property var playback: null
    property bool screencasting: false
    property string preferredId: ""

    readonly property int deviceCount: devices.length
    readonly property bool isPlaying: playback && playback.state === "PLAYING"

    readonly property string socketPath: Quickshell.env("DMS_SOCKET")

    readonly property bool wantSubscription: refCount > 0 || discoveryRefCount > 0

    onRefCountChanged: updateSubscription()

    onDiscoveryRefCountChanged: {
        updateSubscription();
        if (discoveryRefCount > 0)
            startDiscovery();
        else if (discoveryRefCount === 0)
            stopDiscovery();
    }

    function updateSubscription() {
        if (wantSubscription) {
            ensureSubscription();
        } else if (DMSService.activeSubscriptions.includes("chromecast")) {
            DMSService.removeSubscription("chromecast");
        }
    }

    function ensureSubscription() {
        if (!wantSubscription)
            return;
        if (!DMSService.isConnected)
            return;
        if (DMSService.activeSubscriptions.includes("chromecast"))
            return;
        if (DMSService.activeSubscriptions.includes("all"))
            return;
        DMSService.addSubscription("chromecast");
        if (available)
            getState();
    }

    Component.onCompleted: {
        if (socketPath && socketPath.length > 0)
            checkDMSCapabilities();
    }

    Connections {
        target: DMSService

        function onConnectionStateChanged() {
            if (DMSService.isConnected) {
                checkDMSCapabilities();
                ensureSubscription();
                if (root.discoveryRefCount > 0)
                    root.startDiscovery();
            }
        }
    }

    Connections {
        target: DMSService
        enabled: DMSService.isConnected

        function onChromecastStateUpdate(data) {
            root.log.debug("Subscription update received");
            root.updateState(data);
        }

        function onCapabilitiesReceived() {
            root.checkDMSCapabilities();
        }
    }

    function checkDMSCapabilities() {
        if (!DMSService.isConnected)
            return;
        if (DMSService.capabilities.length === 0)
            return;
        const wasAvailable = available;
        available = DMSService.capabilities.includes("chromecast");

        if (!available)
            return;
        if (!stateInitialized) {
            stateInitialized = true;
            getState();
        }
        if (!wasAvailable)
            ensureSubscription();
    }

    function getState() {
        if (!available)
            return;
        DMSService.sendRequest("chromecast.getState", null, response => {
            if (response.result)
                updateState(response.result);
        });
    }

    function devicesEqual(a, b) {
        if (a.length !== b.length)
            return false;
        for (var i = 0; i < a.length; i++) {
            const x = a[i], y = b[i];
            if (x.id !== y.id || x.name !== y.name || x.model !== y.model || x.host !== y.host || x.port !== y.port || x.protocol !== y.protocol)
                return false;
        }
        return true;
    }

    function updateState(data) {
        if (!data)
            return;
        discovering = data.discovering || false;
        // The core pushes the full state on every playback tick; only reassign
        // the devices array (which re-evaluates list bindings and rebuilds
        // delegates) when it actually changed.
        const newDevices = data.devices || [];
        if (!devicesEqual(devices, newDevices))
            devices = newDevices;
        connected = data.connected || false;
        activeDevice = data.activeDevice || null;
        playback = data.playback || null;
        screencasting = data.screencasting || false;
        preferredId = data.preferredId || "";
    }

    // sendAction issues a state-changing request; the core refreshes and
    // broadcasts on success, so subscribers update without an extra getState.
    function sendAction(method, params) {
        if (!available)
            return;
        DMSService.sendRequest(method, params, response => {
            if (response.error) {
                root.log.warn(method + " failed: " + response.error);
                ToastService.showError(I18n.tr("Cast action failed", "Toast shown when a Cast control action is rejected"), response.error);
            }
        });
    }

    // cast loads a media URL or local file path on the connected device.
    function cast(url, contentType) {
        if (!url)
            return;
        sendAction("chromecast.cast", {
            "url": url,
            "contentType": contentType || ""
        });
    }

    function play() {
        sendAction("chromecast.play", null);
    }

    function pause() {
        sendAction("chromecast.pause", null);
    }

    function stop() {
        sendAction("chromecast.stop", null);
    }

    function seek(position) {
        sendAction("chromecast.seek", {
            "position": position
        });
    }

    function setVolume(level) {
        sendAction("chromecast.setVolume", {
            "level": level
        });
    }

    function setMuted(muted) {
        sendAction("chromecast.setMuted", {
            "muted": muted
        });
    }

    // castScreen mirrors the local screen to the connected device (buffered HLS
    // path — expect multi-second latency, not real-time mirroring).
    function castScreen() {
        sendAction("chromecast.castScreen", null);
    }

    function stopScreen() {
        sendAction("chromecast.stopScreen", null);
    }

    // setPreferred marks a device as the auto-reconnect target. Passing the
    // already-preferred id (or empty) clears the preference.
    function setPreferred(id) {
        if (!id || id === preferredId)
            sendAction("chromecast.clearPreferred", null);
        else
            sendAction("chromecast.setPreferred", {
                "id": id
            });
    }

    function connect(id) {
        if (!available || !id)
            return;
        DMSService.sendRequest("chromecast.connect", {
            "id": id
        }, response => {
            if (response.error) {
                root.log.warn("connect failed: " + response.error);
                ToastService.showError(I18n.tr("Cast failed", "Toast shown when connecting to a Cast device fails"), response.error);
            }
        });
    }

    function disconnect() {
        if (!available)
            return;
        DMSService.sendRequest("chromecast.disconnect", null, response => {
            if (response.error)
                root.log.warn("disconnect failed: " + response.error);
        });
    }

    function startDiscovery() {
        if (!available)
            return;
        DMSService.sendRequest("chromecast.startDiscovery", null, response => {
            if (response.error)
                root.log.warn("startDiscovery failed: " + response.error);
        });
    }

    function stopDiscovery() {
        if (!available)
            return;
        DMSService.sendRequest("chromecast.stopDiscovery", null, response => {
            if (response.error)
                root.log.warn("stopDiscovery failed: " + response.error);
        });
    }
}
