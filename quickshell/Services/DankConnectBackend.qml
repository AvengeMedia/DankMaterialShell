pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

// Canonical DankConnect IPC client. Targets daemon apiVersion 1.
Item {
    id: root

    // dankgo omits zero-valued response IDs, so the subscription handshake
    // must use a non-zero ID that can be matched in the response.
    readonly property int subscriptionRequestId: 1

    property string socketPath: {
        const override = Quickshell.env("DANKCONNECT_SOCKET");
        if (override && override.length > 0)
            return override;
        const runtimeDir = Quickshell.env("XDG_RUNTIME_DIR");
        return runtimeDir ? runtimeDir + "/dankconnect.sock" : "";
    }

    readonly property bool connected: requestSocket.linkUp && ready
    property bool ready: false
    property bool initialized: false
    property bool subscribed: false
    property int apiVersion: 0
    property var capabilities: []
    property var subscribedTopics: []
    property var devices: []
    property var devicesById: ({})
    property string lastError: ""
    property bool launchPending: false

    property int _requestId: 0
    property var _pendingRequests: ({})

    signal eventReceived(string topic, var data)

    function _nextId() {
        _requestId = _requestId >= 2147483647 ? 1 : _requestId + 1;
        return _requestId;
    }

    function _parse(line) {
        if (!line || line.length === 0)
            return null;
        try {
            return JSON.parse(line);
        } catch (error) {
            return null;
        }
    }

    function _isHello(message) {
        return message && message.id === undefined && message.apiVersion !== undefined && Array.isArray(message.capabilities);
    }

    function _acceptHello(message) {
        apiVersion = Number(message.apiVersion) || 0;
        capabilities = message.capabilities.slice();
        ready = apiVersion === 1;
        if (!ready) {
            lastError = "Unsupported DankConnect API version " + apiVersion;
            return;
        }
        lastError = "";
        launchDelayTimer.stop();
        launchPending = false;
        refreshDevices();
    }

    function _flushPending(message) {
        const callbacks = _pendingRequests;
        _pendingRequests = {};
        for (const id in callbacks) {
            const callback = callbacks[id];
            if (!callback)
                continue;
            callback({
                "id": Number(id),
                "error": message
            });
        }
    }

    function _applyDevices(snapshots) {
        const nextDevices = [];
        const nextById = {};
        for (const device of (snapshots || [])) {
            if (!device?.id)
                continue;
            nextDevices.push(device);
            nextById[device.id] = device;
        }
        devicesById = nextById;
        devices = nextDevices;
        initialized = true;
    }

    function _resolveDevice(deviceOrId) {
        if (typeof deviceOrId === "string")
            return devicesById[deviceOrId] || null;
        return deviceOrId || null;
    }

    function getDevice(deviceId) {
        return devicesById[deviceId] || null;
    }

    // supportedPlugins is the peer's incoming view: actions this client sends.
    function supports(deviceOrId, packetType) {
        const device = _resolveDevice(deviceOrId);
        return !!device && (device.supportedPlugins || []).includes(packetType);
    }

    // outgoingCapabilities is the peer's producing view: data this client consumes.
    function produces(deviceOrId, packetType) {
        const device = _resolveDevice(deviceOrId);
        return !!device && (device.outgoingCapabilities || []).includes(packetType);
    }

    function hasCapability(family) {
        return capabilities.includes(family);
    }

    function request(method, params, callback) {
        if (!connected) {
            callback?.({
                "error": "daemon not connected"
            });
            return -1;
        }
        const family = method.split(".")[0];
        if (!hasCapability(family)) {
            callback?.({
                "error": "daemon does not support " + family
            });
            return -1;
        }

        const id = _nextId();
        const message = {
            "id": id,
            "method": method,
            "params": params || {}
        };
        if (callback)
            _pendingRequests[id] = callback;
        requestSocket.send(message);
        return id;
    }

    function refreshDevices(callback) {
        return request("device.list", {}, response => {
            if (!response.error)
                _applyDevices(response.result || []);
            callback?.(response);
        });
    }

    function launch() {
        if (connected || requestSocket.linkUp || launchPending)
            return;
        launchPending = true;
        launchDelayTimer.restart();
    }

    function _handleRequestLine(line) {
        const message = _parse(line);
        if (!message)
            return;
        if (_isHello(message)) {
            _acceptHello(message);
            return;
        }
        if (message.id === undefined)
            return;

        const callback = _pendingRequests[message.id];
        if (!callback)
            return;
        delete _pendingRequests[message.id];
        callback(message);
    }

    function _handleSubscriptionLine(line) {
        const message = _parse(line);
        if (!message)
            return;
        if (_isHello(message)) {
            if (Number(message.apiVersion) !== 1) {
                lastError = "Unsupported DankConnect subscription API version " + message.apiVersion;
                return;
            }
            subscriptionSocket.send({
                "id": root.subscriptionRequestId,
                "method": "subscribe",
                "params": {}
            });
            return;
        }
        if (message.id === root.subscriptionRequestId) {
            subscribed = !message.error;
            subscribedTopics = message.result?.topics || [];
            if (message.error)
                lastError = message.error;
            return;
        }
        const topic = message.event || message.topic || "";
        if (!topic)
            return;
        if (topic === "devices")
            _applyDevices(message.data || []);
        eventReceived(topic, message.data);
    }

    DankSocket {
        id: requestSocket

        path: root.socketPath
        connected: root.enabled && root.socketPath.length > 0
        reconnectBaseMs: 3000
        reconnectMaxMs: 3000

        onConnectionStateChanged: {
            if (linkUp)
                return;
            root.ready = false;
            root.initialized = false;
            root.subscribed = false;
            root.subscribedTopics = [];
            root.apiVersion = 0;
            root.capabilities = [];
            root._flushPending("daemon disconnected");
        }

        parser: SplitParser {
            onRead: line => root._handleRequestLine(line)
        }
    }

    DankSocket {
        id: subscriptionSocket

        path: root.socketPath
        connected: root.enabled && root.ready
        reconnectBaseMs: 3000
        reconnectMaxMs: 3000

        onConnectionStateChanged: {
            root.subscribed = false;
            root.subscribedTopics = [];
        }

        parser: SplitParser {
            onRead: line => root._handleSubscriptionLine(line)
        }
    }

    Timer {
        id: launchDelayTimer

        interval: 1000
        repeat: false
        onTriggered: {
            if (root.connected || requestSocket.linkUp) {
                root.launchPending = false;
                return;
            }
            Quickshell.execDetached(["sh", "-c", "if command -v dankconnect >/dev/null 2>&1; then exec dankconnect daemon; elif command -v flatpak >/dev/null 2>&1 && flatpak info com.danklinux.dankconnect >/dev/null 2>&1; then exec flatpak run --command=dankconnect com.danklinux.dankconnect daemon; fi"]);
            launchResetTimer.restart();
        }
    }

    Timer {
        id: launchResetTimer

        interval: 5000
        repeat: false
        onTriggered: root.launchPending = false
    }
}
