pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool connected: backend.connected && backend.subscribed
    readonly property bool initialized: backend.initialized
    readonly property int apiVersion: backend.apiVersion
    readonly property var capabilities: backend.capabilities
    readonly property var devices: backend.devices
    readonly property var devicesById: backend.devicesById
    readonly property string lastError: backend.lastError
    readonly property var primaryDevice: _selectPrimaryDevice()
    property var pairingRequest: null
    property bool _openAppPending: false

    Component.onCompleted: backend.launch()

    onConnectedChanged: {
        if (!connected) {
            pairingRequest = null;
            return;
        }
        if (_openAppPending) {
            _openAppPending = false;
            _launchAttachedApp();
        }
    }

    function _selectPrimaryDevice() {
        let selected = null;
        let selectedScore = -1;
        for (const device of devices) {
            const score = (device.isPaired ? 2 : 0) + (device.isReachable ? 1 : 0);
            if (score <= selectedScore)
                continue;
            selected = device;
            selectedScore = score;
        }
        return selected;
    }

    function _syncPairingRequest() {
        for (const device of devices) {
            if (!device.isPairRequestedByPeer)
                continue;
            pairingRequest = {
                "deviceId": device.id,
                "name": device.name || "",
                "verificationKey": device.verificationKey || ""
            };
            return;
        }
        if (initialized)
            pairingRequest = null;
    }

    function _handleEvent(topic, data) {
        if (topic !== "pairing" || !data?.deviceId)
            return;
        pairingRequest = {
            "deviceId": data.deviceId,
            "name": data.name || "",
            "verificationKey": data.verificationKey || ""
        };
    }

    function supports(deviceOrId, packetType) {
        return backend.supports(deviceOrId, packetType);
    }

    function canRing(deviceOrId) {
        const device = typeof deviceOrId === "string" ? backend.getDevice(deviceOrId) : deviceOrId;
        return connected && !!device?.isPaired && !!device?.isReachable && backend.hasCapability("device") && supports(device, "kdeconnect.findmyphone.request");
    }

    function canPing(deviceOrId) {
        const device = typeof deviceOrId === "string" ? backend.getDevice(deviceOrId) : deviceOrId;
        return connected && !!device?.isPaired && !!device?.isReachable && backend.hasCapability("ping") && supports(device, "kdeconnect.ping");
    }

    function canSendClipboard(deviceOrId) {
        const device = typeof deviceOrId === "string" ? backend.getDevice(deviceOrId) : deviceOrId;
        return connected && !!device?.isPaired && !!device?.isReachable && backend.hasCapability("clipboard") && supports(device, "kdeconnect.clipboard");
    }

    function ringDevice(deviceId, callback) {
        if (!canRing(deviceId)) {
            callback?.({
                "error": "ring unavailable"
            });
            return -1;
        }
        return backend.request("device.ring", {
            "deviceId": deviceId
        }, callback);
    }

    function pingDevice(deviceId, callback) {
        if (!canPing(deviceId)) {
            callback?.({
                "error": "ping unavailable"
            });
            return -1;
        }
        return backend.request("ping.send", {
            "deviceId": deviceId
        }, callback);
    }

    function sendClipboard(deviceId, callback) {
        if (!canSendClipboard(deviceId)) {
            callback?.({
                "error": "clipboard unavailable"
            });
            return -1;
        }
        return backend.request("clipboard.send", {
            "deviceId": deviceId,
            "content": ""
        }, callback);
    }

    function acceptPairing(deviceId, callback) {
        return _respondToPairing("pairing.accept", deviceId, callback);
    }

    function rejectPairing(deviceId, callback) {
        return _respondToPairing("pairing.reject", deviceId, callback);
    }

    function openApp() {
        if (!connected) {
            _openAppPending = true;
            backend.launch();
            return;
        }
        _launchAttachedApp();
    }

    function _launchAttachedApp() {
        Quickshell.execDetached(["sh", "-c", "if command -v dankconnect >/dev/null 2>&1; then exec dankconnect app; elif command -v flatpak >/dev/null 2>&1 && flatpak info com.danklinux.dankconnect >/dev/null 2>&1; then exec flatpak run --command=dankconnect com.danklinux.dankconnect app; fi"]);
    }

    function _respondToPairing(method, deviceId, callback) {
        if (!connected || !backend.hasCapability("pairing") || !deviceId) {
            callback?.({
                "error": "pairing unavailable"
            });
            return -1;
        }
        return backend.request(method, {
            "deviceId": deviceId
        }, response => {
            if (!response.error && pairingRequest?.deviceId === deviceId)
                pairingRequest = null;
            callback?.(response);
        });
    }

    DankConnectBackend {
        id: backend

        enabled: true
        onDevicesChanged: root._syncPairingRequest()
        onEventReceived: (topic, data) => root._handleEvent(topic, data)
    }
}
