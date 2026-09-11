pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Services

Singleton {
    id: root
    readonly property var log: Log.scoped("PolkitService")

    readonly property bool disablePolkitIntegration: Quickshell.env("DMS_DISABLE_POLKIT") === "1"

    readonly property bool polkitAvailable: !disablePolkitIntegration
    readonly property var agent: polkitAgentLoader.item

    property bool authFailed: false
    property bool _switchingIdentity: false

    function currentUserIdentity(flow) {
        const identities = flow?.identities;
        if (!identities || identities.length < 2)
            return null;
        const uid = UserInfoService.uid;
        const username = Quickshell.env("USER");
        for (let i = 0; i < identities.length; i++) {
            const identity = identities[i];
            if (identity.isGroup)
                continue;
            if (uid >= 0 && identity.id === uid)
                return identity;
            if (username && identity.string === username)
                return identity;
        }
        return null;
    }

    function selectCurrentUserIdentity() {
        const flow = agent?.flow;
        const identity = currentUserIdentity(flow);
        if (!identity || identity === flow.selectedIdentity)
            return;
        log.info(`Selecting identity ${identity.string} over default ${flow.selectedIdentity?.string}`);
        // selectedIdentity assignment cancels the running session, which polkit
        // reports as a synchronous auth failure; swallow it via _switchingIdentity
        _switchingIdentity = true;
        flow.selectedIdentity = identity;
        _switchingIdentity = false;
    }

    Connections {
        target: root.agent
        enabled: root.agent !== null

        function onAuthenticationRequestStarted() {
            root.authFailed = false;
            root.selectCurrentUserIdentity();
        }
    }

    Connections {
        target: root.agent?.flow ?? null

        function onAuthenticationFailed() {
            if (root._switchingIdentity)
                return;
            root.authFailed = true;
        }
    }

    Loader {
        id: polkitAgentLoader
        active: root.polkitAvailable
        asynchronous: false
        source: "PolkitAgentInstance.qml"
    }

    Component.onCompleted: {
        if (!disablePolkitIntegration)
            log.info("Initialized successfully");
    }
}
