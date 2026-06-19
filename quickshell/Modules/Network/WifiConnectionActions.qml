pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import qs.Services

Singleton {
    id: root

    function connectToNetwork(network, options) {
        if (!network)
            return;

        const actionOptions = options || {};
        const ssid = network.ssid || "";
        if (!ssid)
            return;

        const connected = actionOptions.connected ?? network.connected ?? (ssid === NetworkService.currentWifiSSID);
        if (connected) {
            if (actionOptions.disconnectWhenConnected ?? false)
                NetworkService.disconnectWifi();
            return;
        }

        if (shouldPromptForCredentials(network)) {
            PopoutService.showWifiPasswordModal(ssid);
            return;
        }

        NetworkService.connectToWifi(ssid);
    }

    function connectToNetworkFromDetails(ssid, secured, saved, enterprise, connected, options) {
        connectToNetwork({
            ssid: ssid,
            secured: secured,
            saved: saved,
            enterprise: enterprise,
            connected: connected
        }, options);
    }

    function shouldPromptForCredentials(network) {
        return (network.secured ?? false) && !(network.saved ?? false);
    }
}
