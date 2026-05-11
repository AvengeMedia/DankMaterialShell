pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.Common
import qs.Services

Singleton {
    id: root
    readonly property var log: Log.scoped("LegacyNetworkService")

    property bool isActive: false

    readonly property string backend: Networking.backend === NetworkBackendType.NetworkManager ? "networkmanager" : ""
    readonly property string primaryConnection: ""

    readonly property var allDevices: Networking.devices?.values ?? []

    readonly property var wifiDevices: allDevices.filter(d => d.type === DeviceType.Wifi).map(d => ({
                "name": d.name
            }))
    readonly property var ethernetDevices: allDevices.filter(d => d.type === DeviceType.Wired).map(d => ({
                "name": d.name
            }))

    property string wifiDeviceOverride: SessionData.wifiDeviceOverride || ""

    readonly property var wifiDevice: {
        const list = allDevices.filter(d => d.type === DeviceType.Wifi);
        if (wifiDeviceOverride) {
            const match = list.find(d => d.name === wifiDeviceOverride);
            if (match) {
                return match;
            }
        }
        return list[0] ?? null;
    }

    readonly property var wiredDevice: allDevices.find(d => d.type === DeviceType.Wired) ?? null

    readonly property bool ethernetConnected: wiredDevice?.connected ?? false
    readonly property string ethernetInterface: wiredDevice?.name ?? ""
    property string ethernetIP: ""
    readonly property string ethernetConnectionUuid: {
        const net = wiredDevice?.network;
        if (!net) {
            return "";
        }
        const settings = net.nmSettings;
        return settings.length > 0 ? settings[0].uuid : "";
    }
    readonly property var wiredConnections: []

    readonly property bool wifiAvailable: wifiDevice !== null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property string wifiInterface: wifiDevice?.name ?? ""
    readonly property bool wifiConnected: wifiDevice?.connected ?? false
    property string wifiIP: ""
    readonly property string wifiDevicePath: wifiDevice?.name ?? ""
    readonly property string activeAccessPointPath: ""
    readonly property string connectingDevice: ""

    readonly property var connectedWifiNetwork: {
        const dev = wifiDevice;
        if (!dev) {
            return null;
        }
        const list = dev.networks?.values ?? [];
        for (const net of list) {
            if (net.connected) {
                return net;
            }
        }
        return null;
    }

    readonly property string currentWifiSSID: connectedWifiNetwork?.name ?? ""
    readonly property int wifiSignalStrength: Math.round((connectedWifiNetwork?.signalStrength ?? 0) * 100)
    readonly property string wifiConnectionUuid: {
        const net = connectedWifiNetwork;
        if (!net) {
            return "";
        }
        const settings = net.nmSettings;
        return settings.length > 0 ? settings[0].uuid : "";
    }

    readonly property string networkStatus: {
        if (ethernetConnected) {
            return "ethernet";
        }
        if (wifiConnected) {
            return "wifi";
        }
        return "disconnected";
    }

    readonly property string wifiSignalIcon: {
        if (!wifiConnected || networkStatus !== "wifi") {
            return "wifi_off";
        }
        if (wifiSignalStrength >= 50) {
            return "wifi";
        }
        if (wifiSignalStrength >= 25) {
            return "wifi_2_bar";
        }
        return "wifi_1_bar";
    }

    readonly property var wifiNetworks: {
        const dev = wifiDevice;
        if (!dev) {
            return [];
        }
        const list = dev.networks?.values ?? [];
        const result = [];
        const seen = new Set();
        for (const net of list) {
            if (!net?.name || seen.has(net.name)) {
                continue;
            }
            seen.add(net.name);
            result.push({
                "ssid": net.name,
                "signal": Math.round(net.signalStrength * 100),
                "secured": net.security !== WifiSecurityType.Open,
                "bssid": "",
                "connected": net.connected,
                "saved": net.known
            });
        }
        result.sort((a, b) => b.signal - a.signal);
        return result;
    }

    readonly property var savedConnections: wifiNetworks.filter(n => n.saved).map(n => ({
                "ssid": n.ssid,
                "saved": true
            }))
    readonly property var savedWifiNetworks: savedConnections
    readonly property var ssidToConnectionName: {
        const map = {};
        for (const n of wifiNetworks) {
            if (n.saved) {
                map[n.ssid] = n.ssid;
            }
        }
        return map;
    }

    property string userPreference: "auto"
    property bool isConnecting: false
    property string connectingSSID: ""
    property string connectionError: ""
    property string lastConnectionError: ""
    property string connectionStatus: ""
    property bool passwordDialogShouldReopen: false

    readonly property bool isScanning: wifiDevice?.scannerEnabled ?? false
    property bool autoScan: false
    property bool autoRefreshEnabled: false
    property bool wifiToggling: false
    property bool changingPreference: false
    property string targetPreference: ""
    property string wifiPassword: ""
    property string forgetSSID: ""
    property int refCount: 0

    property string networkInfoSSID: ""
    property string networkInfoDetails: ""
    property bool networkInfoLoading: false
    property string networkWiredInfoUUID: ""
    property string networkWiredInfoDetails: ""
    property bool networkWiredInfoLoading: false

    signal networksUpdated
    signal connectionChanged

    readonly property var lowPriorityCmd: ["nice", "-n", "19", "ionice", "-c3"]

    property var _pendingNetwork: null
    property string _pendingSSID: ""
    property bool _pendingWithPsk: false

    onWifiNetworksChanged: networksUpdated()
    onNetworkStatusChanged: {
        connectionChanged();
        refreshIPs();
    }
    onCurrentWifiSSIDChanged: {
        connectionChanged();
        refreshIPs();
    }
    onEthernetInterfaceChanged: refreshIPs()
    onWifiInterfaceChanged: refreshIPs()
    onWifiEnabledChanged: {
        if (wifiEnabled && autoScan && wifiDevice) {
            wifiDevice.scannerEnabled = true;
        }
        if (wifiToggling) {
            wifiToggling = false;
            ToastService.showInfo(wifiEnabled ? I18n.tr("WiFi enabled") : I18n.tr("WiFi disabled"));
        }
    }

    Component.onCompleted: {
        userPreference = SettingsData.networkPreference;
    }

    Connections {
        target: root._pendingNetwork
        enabled: root._pendingNetwork !== null

        function onConnectionFailed(reason) {
            root._handleConnectionFailed(reason);
        }

        function onConnectedChanged() {
            if (root._pendingNetwork?.connected) {
                root._handleConnectionSuccess();
            }
        }
    }

    function activate() {
        if (isActive) {
            return;
        }
        isActive = true;
        log.info("Activating...");
        refreshIPs();
        if (wifiDevice && wifiEnabled) {
            wifiDevice.scannerEnabled = true;
        }
    }

    function addRef() {
        refCount++;
        if (refCount === 1) {
            startAutoScan();
        }
    }

    function removeRef() {
        refCount = Math.max(0, refCount - 1);
        if (refCount === 0) {
            stopAutoScan();
        }
    }

    function startAutoScan() {
        autoScan = true;
        autoRefreshEnabled = true;
        if (wifiDevice && wifiEnabled) {
            wifiDevice.scannerEnabled = true;
        }
    }

    function stopAutoScan() {
        autoScan = false;
        autoRefreshEnabled = false;
        if (wifiDevice) {
            wifiDevice.scannerEnabled = false;
        }
    }

    function scanWifi() {
        if (!wifiDevice || !wifiEnabled) {
            return;
        }
        wifiDevice.scannerEnabled = true;
    }

    function scanWifiNetworks() {
        scanWifi();
    }

    function _findNetworkBySSID(ssid) {
        const dev = wifiDevice;
        if (!dev) {
            return null;
        }
        return dev.networks?.values?.find(n => n.name === ssid) ?? null;
    }

    function _handleConnectionFailed(reason) {
        const ssid = _pendingSSID;
        let invalidPsk = false;

        switch (reason) {
        case ConnectionFailReason.NoSecrets:
            invalidPsk = _pendingWithPsk;
            break;
        case ConnectionFailReason.WifiAuthTimeout:
            invalidPsk = true;
            break;
        }

        connectionStatus = invalidPsk ? "invalid_password" : "failed";
        connectionError = ConnectionFailReason.toString(reason);
        lastConnectionError = connectionError;
        passwordDialogShouldReopen = invalidPsk;
        isConnecting = false;
        connectingSSID = "";

        if (invalidPsk) {
            ToastService.showError(I18n.tr("Invalid password for %1").arg(ssid));
        } else {
            ToastService.showError(I18n.tr("Failed to connect to %1").arg(ssid));
        }

        _pendingNetwork = null;
        _pendingSSID = "";
        _pendingWithPsk = false;
    }

    function _handleConnectionSuccess() {
        const ssid = _pendingSSID;
        connectionStatus = "connected";
        connectionError = "";
        isConnecting = false;
        connectingSSID = "";
        passwordDialogShouldReopen = false;

        ToastService.showInfo(I18n.tr("Connected to %1").arg(ssid));

        if (userPreference === "wifi" || userPreference === "auto") {
            setConnectionPriority("wifi");
        }

        _pendingNetwork = null;
        _pendingSSID = "";
        _pendingWithPsk = false;
    }

    function connectToWifi(ssid, password = "", username = "", anonymousIdentity = "", domainSuffixMatch = "") {
        if (isConnecting) {
            return;
        }

        const network = _findNetworkBySSID(ssid);
        if (!network) {
            log.warn("SSID not found in scan results:", ssid);
            ToastService.showError(I18n.tr("Network not found"), ssid);
            return;
        }

        isConnecting = true;
        connectingSSID = ssid;
        connectionError = "";
        connectionStatus = "connecting";
        passwordDialogShouldReopen = false;

        _pendingNetwork = network;
        _pendingSSID = ssid;

        if (password) {
            const sec = network.security;
            switch (sec) {
            case WifiSecurityType.WpaPsk:
            case WifiSecurityType.Wpa2Psk:
            case WifiSecurityType.Sae:
                _pendingWithPsk = true;
                network.connectWithPsk(password);
                return;
            default:
                log.warn("Security type not supported with PSK, falling back to connect():", WifiSecurityType.toString(sec));
            }
        }

        _pendingWithPsk = false;
        network.connect();
    }

    function disconnectWifi() {
        if (!wifiDevice) {
            return;
        }
        wifiDevice.disconnect();
        connectionStatus = "";
        ToastService.showInfo(I18n.tr("Disconnected from WiFi"));
    }

    function forgetWifiNetwork(ssid) {
        forgetSSID = ssid;
        const network = _findNetworkBySSID(ssid);
        if (network) {
            network.forget();
            ToastService.showInfo(I18n.tr("Forgot network %1").arg(ssid));
        } else {
            log.warn("Cannot forget, SSID not found:", ssid);
        }
        forgetSSID = "";
    }

    function toggleWifiRadio() {
        if (wifiToggling) {
            return;
        }
        wifiToggling = true;
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function enableWifiDevice() {
        if (!Networking.wifiEnabled) {
            Networking.wifiEnabled = true;
            ToastService.showInfo(I18n.tr("WiFi enabled"));
        }
    }

    function setNetworkPreference(preference) {
        userPreference = preference;
        targetPreference = preference;
        changingPreference = true;
        SettingsData.set("networkPreference", preference);
        setConnectionPriority(preference);
        changingPreference = false;
        targetPreference = "";
    }

    function setConnectionPriority(type) {
        const wifiMetric = type === "wifi" ? 50 : 100;
        const wiredMetric = type === "ethernet" ? 50 : 100;

        for (const device of allDevices) {
            let metric = -1;
            switch (device.type) {
            case DeviceType.Wifi:
                metric = wifiMetric;
                break;
            case DeviceType.Wired:
                metric = wiredMetric;
                break;
            default:
                continue;
            }

            for (const net of device.networks?.values ?? []) {
                for (const settings of net.nmSettings) {
                    settings.write({
                        "ipv4": {
                            "route-metric": metric
                        },
                        "ipv6": {
                            "route-metric": metric
                        }
                    });
                }
            }
        }
    }

    function connectToWifiAndSetPreference(ssid, password, username = "", anonymousIdentity = "", domainSuffixMatch = "") {
        connectToWifi(ssid, password, username, anonymousIdentity, domainSuffixMatch);
        setNetworkPreference("wifi");
    }

    function toggleNetworkConnection(type) {
        if (type !== "ethernet" || !wiredDevice) {
            return;
        }
        if (ethernetConnected) {
            wiredDevice.disconnect();
        } else if (wiredDevice.network) {
            wiredDevice.network.connect();
        }
    }

    function disconnectEthernetDevice(deviceName) {
        for (const dev of allDevices) {
            if (dev.type === DeviceType.Wired && dev.name === deviceName) {
                dev.disconnect();
                return;
            }
        }
    }

    function setWifiDeviceOverride(deviceName) {
        SessionData.setWifiDeviceOverride(deviceName || "");
        if (wifiEnabled) {
            scanWifi();
        }
    }

    function setWifiAutoconnect(ssid, autoconnect) {
        const network = _findNetworkBySSID(ssid);
        if (!network) {
            return;
        }
        for (const settings of network.nmSettings) {
            settings.write({
                "connection": {
                    "autoconnect": autoconnect
                }
            });
        }
        ToastService.showInfo(autoconnect ? I18n.tr("Autoconnect enabled") : I18n.tr("Autoconnect disabled"));
    }

    function fetchNetworkInfo(ssid) {
        networkInfoSSID = ssid;
        networkInfoLoading = false;

        const network = _findNetworkBySSID(ssid);
        if (!network) {
            networkInfoDetails = "Network information not found or network not available.";
            return;
        }

        const signalPct = Math.round(network.signalStrength * 100);
        const secLabel = WifiSecurityType.toString(network.security);
        const statusPrefix = network.connected ? "● " : "  ";
        const statusSuffix = network.connected ? " (Connected)" : "";

        let details = statusPrefix + signalPct + "%" + statusSuffix + "\\n";
        details += "  Security: " + secLabel + "\\n";
        if (network.known) {
            details += "  Status: Saved network\\n";
        }
        networkInfoDetails = details;
    }

    function fetchWiredNetworkInfo(uuid) {
        networkWiredInfoUUID = uuid;
        networkWiredInfoLoading = false;

        const dev = wiredDevice;
        if (!dev) {
            networkWiredInfoDetails = "Network information not found or network not available.";
            return;
        }

        let details = "";
        details += "Interface: " + (dev.name || "-") + "\\n";
        details += "MAC Addr: " + (dev.address || "-") + "\\n";
        details += "Speed: " + (dev.linkSpeed || 0) + " Mb/s\\n\\n";

        details += "IPv4 information:\\n";
        details += "    IPv4 address: " + (ethernetIP || "-") + "\\n";

        networkWiredInfoDetails = details;
    }

    function getNetworkInfo(ssid) {
        const network = wifiNetworks.find(n => n.ssid === ssid);
        if (!network) {
            return null;
        }
        return {
            "ssid": network.ssid,
            "signal": network.signal,
            "secured": network.secured,
            "saved": network.saved,
            "connected": network.connected,
            "bssid": network.bssid
        };
    }

    function getWiredNetworkInfo(uuid) {
        return {
            "uuid": uuid
        };
    }

    function refreshNetworkState() {
        refreshIPs();
    }

    function connectToSpecificWiredConfig(uuid) {
    }

    function submitCredentials(token, secrets, save) {
    }

    function cancelCredentials(token) {
    }

    function refreshIPs() {
        getEthernetIP.running = false;
        getWifiIP.running = false;

        if (ethernetInterface && ethernetConnected) {
            getEthernetIP.command = lowPriorityCmd.concat(["ip", "-4", "addr", "show", ethernetInterface]);
            getEthernetIP.running = true;
        } else {
            ethernetIP = "";
        }

        if (wifiInterface && wifiConnected) {
            getWifiIP.command = lowPriorityCmd.concat(["ip", "-4", "addr", "show", wifiInterface]);
            getWifiIP.running = true;
        } else {
            wifiIP = "";
        }
    }

    Process {
        id: getEthernetIP
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/inet (\d+\.\d+\.\d+\.\d+)/);
                root.ethernetIP = match ? match[1] : "";
            }
        }
    }

    Process {
        id: getWifiIP
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/inet (\d+\.\d+\.\d+\.\d+)/);
                root.wifiIP = match ? match[1] : "";
            }
        }
    }
}
