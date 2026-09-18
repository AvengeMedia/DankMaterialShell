import QtQuick
import qs.Common
import qs.Services

CcTile {
    id: root

    readonly property string status: NetworkService.networkStatus
    readonly property bool wifiConnecting: NetworkService.isConnecting && !NetworkService.ethernetConnected

    iconBlinking: NetworkService.isWifiConnecting
    iconName: {
        if (NetworkService.wifiToggling)
            return "sync";
        if (wifiConnecting)
            return NetworkService.wifiSignalIcon;
        switch (status) {
        case "ethernet":
            return "settings_ethernet";
        case "cellular":
            return "network_cell";
        case "vpn":
            if (NetworkService.ethernetConnected)
                return "settings_ethernet";
            return NetworkService.cellularConnected ? "network_cell" : NetworkService.wifiSignalIcon;
        case "wifi":
            return NetworkService.wifiSignalIcon;
        default:
            return "wifi";
        }
    }
    title: {
        if (NetworkService.wifiToggling)
            return NetworkService.wifiEnabled ? I18n.tr("Disabling WiFi...", "network status") : I18n.tr("Enabling WiFi...", "network status");
        if (wifiConnecting)
            return NetworkService.connectingSSID || I18n.tr("Connecting...", "network status");
        switch (status) {
        case "ethernet":
            return I18n.tr("Ethernet", "network status");
        case "cellular":
            return I18n.tr("Cellular", "network status");
        case "vpn":
            if (NetworkService.ethernetConnected)
                return I18n.tr("Ethernet", "network status");
            if (NetworkService.cellularConnected)
                return I18n.tr("Cellular", "network status");
            if (NetworkService.wifiConnected && NetworkService.currentWifiSSID)
                return NetworkService.currentWifiSSID;
            break;
        case "wifi":
            if (NetworkService.currentWifiSSID)
                return NetworkService.currentWifiSSID;
            break;
        }
        return NetworkService.wifiEnabled ? I18n.tr("Not connected", "network status") : I18n.tr("WiFi is off", "network status");
    }
    subtitle: {
        if (NetworkService.wifiToggling)
            return I18n.tr("Please wait...", "network status");
        if (wifiConnecting)
            return I18n.tr("Connecting...", "network status");
        const signal = NetworkService.wifiSignalStrength > 0 ? NetworkService.wifiSignalStrength + "%" : I18n.tr("Connected", "network status");
        switch (status) {
        case "ethernet":
            return I18n.tr("Connected", "network status");
        case "cellular":
            return NetworkService.cellularIP || I18n.tr("Connected", "network status");
        case "vpn":
            if (NetworkService.ethernetConnected)
                return I18n.tr("Connected", "network status");
            if (NetworkService.cellularConnected)
                return NetworkService.cellularIP || I18n.tr("Connected", "network status");
            if (NetworkService.wifiConnected)
                return signal;
            break;
        case "wifi":
            return signal;
        }
        return NetworkService.wifiEnabled ? I18n.tr("Select network", "network status") : "";
    }
    active: {
        if (NetworkService.wifiToggling)
            return false;
        switch (status) {
        case "ethernet":
        case "cellular":
        case "wifi":
            return true;
        case "vpn":
            return NetworkService.ethernetConnected || NetworkService.wifiConnected || NetworkService.cellularConnected;
        default:
            return NetworkService.wifiEnabled;
        }
    }
    showExpand: true
    enabled: widgetDef?.enabled ?? true

    onClicked: {
        if (status === "ethernet" || status === "cellular" || NetworkService.wifiToggling)
            return;
        NetworkService.toggleWifiRadio();
    }
}
