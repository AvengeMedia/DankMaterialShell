pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

Singleton {
    id: root
    readonly property var log: Log.scoped("TailscaleService")

    property int refCount: 0

    onRefCountChanged: {
        if (refCount > 0) {
            ensureSubscription();
        } else if (refCount === 0 && DMSService.activeSubscriptions.includes("tailscale")) {
            DMSService.removeSubscription("tailscale");
        }
    }

    function ensureSubscription() {
        if (refCount <= 0)
            return;
        if (!DMSService.isConnected)
            return;
        if (DMSService.activeSubscriptions.includes("tailscale"))
            return;
        if (DMSService.activeSubscriptions.includes("all"))
            return;
        DMSService.addSubscription("tailscale");
        if (available) {
            getStatus();
        }
    }

    property bool connected: false
    property string version: ""
    property string backendState: ""
    property string magicDnsSuffix: ""
    property string tailnetName: ""
    property var selfNode: null
    property var peers: []

    property bool available: false
    property bool stateInitialized: false

    readonly property var allPeersList: {
        const result = [];
        if (selfNode)
            result.push(selfNode);
        if (peers)
            result.push(...peers);
        return result;
    }

    readonly property var onlinePeers: allPeersList.filter(p => p.online)

    readonly property var myPeers: {
        if (!selfNode)
            return allPeersList;
        return allPeersList.filter(p => isMine(p));
    }

    readonly property var myOnlinePeers: {
        if (!selfNode)
            return onlinePeers;
        return allPeersList.filter(p => p.online && isMine(p));
    }

    readonly property int onlinePeerCount: onlinePeers.length

    readonly property string socketPath: Quickshell.env("DMS_SOCKET")

    Component.onCompleted: {
        if (socketPath && socketPath.length > 0) {
            checkDMSCapabilities();
        }
    }

    Connections {
        target: DMSService

        function onConnectionStateChanged() {
            if (DMSService.isConnected) {
                checkDMSCapabilities();
                ensureSubscription();
            }
        }
    }

    Connections {
        target: DMSService
        enabled: DMSService.isConnected

        function onTailscaleStateUpdate(data) {
            root.log.debug("Subscription update received");
            updateState(data);
        }

        function onCapabilitiesReceived() {
            checkDMSCapabilities();
        }
    }

    function checkDMSCapabilities() {
        if (!DMSService.isConnected)
            return;
        if (DMSService.capabilities.length === 0)
            return;
        const wasAvailable = available;
        available = DMSService.capabilities.includes("tailscale");

        if (!available)
            return;
        if (!stateInitialized) {
            stateInitialized = true;
            getStatus();
        }
        if (!wasAvailable)
            ensureSubscription();
    }

    function getStatus() {
        if (!available)
            return;
        DMSService.sendRequest("tailscale.getStatus", null, response => {
            if (response.result) {
                updateState(response.result);
            }
        });
    }

    function updateState(data) {
        if (!data)
            return;
        connected = data.connected || false;
        version = data.version || "";
        backendState = data.backendState || "";
        magicDnsSuffix = data.magicDnsSuffix || "";
        tailnetName = data.tailnetName || "";
        selfNode = data.self || null;
        peers = data.peers || [];
    }

    function refresh(callback) {
        if (!available)
            return;
        DMSService.sendRequest("tailscale.refresh", null, response => {
            if (callback)
                callback(response);
        });
    }

    function isMine(peer) {
        const myOwner = selfNode ? (selfNode.owner || "") : "";
        if (peer.owner === myOwner && myOwner !== "")
            return true;
        if (peer.tags && peer.tags.length > 0)
            return true;
        return false;
    }

    function searchPeers(query, list) {
        const base = list || allPeersList;
        if (!query || query.length === 0)
            return base;
        const q = query.toLowerCase();
        return base.filter(p => {
            if (p.hostname && p.hostname.toLowerCase().includes(q))
                return true;
            if (p.dnsName && p.dnsName.toLowerCase().includes(q))
                return true;
            if (p.tailscaleIp && p.tailscaleIp.includes(q))
                return true;
            if (p.os && p.os.toLowerCase().includes(q))
                return true;
            return false;
        });
    }
}
