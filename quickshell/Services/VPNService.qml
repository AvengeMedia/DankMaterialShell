pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

Singleton {
    id: root

    readonly property bool available: DMSNetworkService.vpnAvailable

    property var plugins: []
    property var allExtensions: []
    property bool importing: false
    property string importError: ""

    property var editConfig: null
    property bool configLoading: false

    property bool pluginsLoading: false

    signal importComplete(string uuid, string name)
    signal configLoaded(var config)
    signal configUpdated
    signal vpnDeleted(string uuid)

    Component.onCompleted: {
        if (available) {
            fetchPlugins();
        }
    }

    Connections {
        target: DMSNetworkService
        function onVpnAvailableChanged() {
            if (DMSNetworkService.vpnAvailable && plugins.length === 0) {
                fetchPlugins();
            }
        }
    }

    function fetchPlugins() {
        if (!available || pluginsLoading)
            return;
        pluginsLoading = true;

        DMSService.sendRequest("network.vpn.plugins", null, response => {
            pluginsLoading = false;
            if (response.error) {
                console.warn("VPNService: Failed to fetch plugins:", response.error);
                return;
            }
            if (!response.result)
                return;
            plugins = response.result;
            const extSet = new Set();
            for (const plugin of response.result) {
                for (const ext of plugin.fileExtensions || []) {
                    extSet.add(ext);
                }
            }
            allExtensions = Array.from(extSet);
        });
    }

    function importVpn(filePath, name = "") {
        if (!available || importing)
            return;
        importing = true;
        importError = "";

        const params = {
            file: filePath
        };
        if (name)
            params.name = name;

        DMSService.sendRequest("network.vpn.import", params, response => {
            importing = false;

            if (response.error) {
                importError = response.error;
                ToastService.showError(I18n.tr("Failed to import VPN"));
                return;
            }

            if (!response.result)
                return;
            if (response.result.success) {
                ToastService.showInfo(I18n.tr("VPN imported: ") + (response.result.name || ""));
                DMSNetworkService.refreshVpnProfiles();
                importComplete(response.result.uuid || "", response.result.name || "");
                return;
            }

            importError = response.result.error || "Import failed";
            ToastService.showError(importError);
        });
    }

    function getConfig(uuidOrName) {
        if (!available)
            return;
        configLoading = true;
        editConfig = null;

        DMSService.sendRequest("network.vpn.getConfig", {
            uuid: uuidOrName
        }, response => {
            configLoading = false;

            if (response.error) {
                ToastService.showError(I18n.tr("Failed to load VPN config"));
                return;
            }

            if (response.result) {
                editConfig = response.result;
                configLoaded(response.result);
            }
        });
    }

    function updateConfig(uuid, updates) {
        if (!available)
            return;
        const params = {
            uuid: uuid
        };
        if (updates.name !== undefined)
            params.name = updates.name;
        if (updates.autoconnect !== undefined)
            params.autoconnect = updates.autoconnect;
        if (updates.data !== undefined)
            params.data = updates.data;

        DMSService.sendRequest("network.vpn.updateConfig", params, response => {
            if (response.error) {
                ToastService.showError(I18n.tr("Failed to update VPN"));
                return;
            }
            ToastService.showInfo(I18n.tr("VPN configuration updated"));
            DMSNetworkService.refreshVpnProfiles();
            configUpdated();
        });
    }

    function deleteVpn(uuidOrName) {
        if (!available)
            return;
        DMSService.sendRequest("network.vpn.delete", {
            uuid: uuidOrName
        }, response => {
            if (response.error) {
                ToastService.showError(I18n.tr("Failed to delete VPN"));
                return;
            }
            ToastService.showInfo(I18n.tr("VPN deleted"));
            DMSNetworkService.refreshVpnProfiles();
            vpnDeleted(uuidOrName);
        });
    }

    function getFileFilter() {
        if (allExtensions.length === 0) {
            return ["*.ovpn", "*.conf"];
        }
        return allExtensions.map(e => "*" + e);
    }

    function getExtensionsForPlugin(serviceType) {
        const plugin = plugins.find(p => p.serviceType === serviceType);
        if (!plugin)
            return ["*.conf"];
        return (plugin.fileExtensions || [".conf"]).map(e => "*" + e);
    }

    function getPluginName(serviceType) {
        if (!serviceType)
            return "VPN";

        const plugin = plugins.find(p => p.serviceType === serviceType);
        if (plugin)
            return plugin.name;

        const svc = serviceType.toLowerCase();
        if (svc.includes("openvpn"))
            return "OpenVPN";
        if (svc.includes("wireguard"))
            return "WireGuard";
        if (svc.includes("openconnect"))
            return "OpenConnect";
        if (svc.includes("fortissl") || svc.includes("forti"))
            return "Fortinet";
        if (svc.includes("strongswan"))
            return "IPsec (strongSwan)";
        if (svc.includes("libreswan"))
            return "IPsec (Libreswan)";
        if (svc.includes("l2tp"))
            return "L2TP/IPsec";
        if (svc.includes("pptp"))
            return "PPTP";
        if (svc.includes("vpnc"))
            return "Cisco (vpnc)";
        if (svc.includes("sstp"))
            return "SSTP";

        const parts = serviceType.split('.');
        return parts[parts.length - 1] || "VPN";
    }

    function getVpnTypeFromProfile(profile) {
        if (!profile)
            return "VPN";
        if (profile.type === "wireguard")
            return "WireGuard";
        return getPluginName(profile.serviceType);
    }
}
