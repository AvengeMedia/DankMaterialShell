pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

Singleton {
    id: root

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

    readonly property int onlinePeerCount: {
        if (!peers || peers.length === 0)
            return 0;
        let count = 0;
        for (let i = 0; i < peers.length; i++) {
            if (peers[i].online)
                count++;
        }
        return count;
    }

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
            console.log("TailscaleService: Subscription update received");
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
        available = DMSService.capabilities.includes("tailscale");

        if (available && !stateInitialized) {
            stateInitialized = true;
            getStatus();
        }
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

    // All filter functions prepend selfNode so it appears first in lists
    function allPeersWithSelf() {
        if (!available) return [];
        const result = [];
        if (selfNode) result.push(selfNode);
        if (peers) result.push(...peers);
        return result;
    }

    function isMine(peer) {
        const myOwner = selfNode ? (selfNode.owner || "") : "";
        if (peer.owner === myOwner && myOwner !== "") return true;
        // Tagged devices belong to the tailnet but have a different UserID
        if (peer.tags && peer.tags.length > 0) return true;
        return false;
    }

    function getMyPeers() {
        if (!available || !selfNode) return allPeersWithSelf();
        return allPeersWithSelf().filter(p => isMine(p));
    }

    function getOnlinePeers() {
        return allPeersWithSelf().filter(p => p.online);
    }

    function getMyOnlinePeers() {
        if (!available || !selfNode) return getOnlinePeers();
        return allPeersWithSelf().filter(p => p.online && isMine(p));
    }

    function searchPeers(query, peers) {
        const list = peers || allPeersWithSelf();
        if (!query || query.length === 0) return list;
        const q = query.toLowerCase();
        return list.filter(p => {
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
