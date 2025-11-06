pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property bool networkAvailable: activeService !== null
    property string backend: activeService?.backend ?? ""
    property string networkStatus: activeService?.networkStatus ?? "disconnected"
    property string primaryConnection: activeService?.primaryConnection ?? ""

    property string ethernetIP: activeService?.ethernetIP ?? ""
    property string ethernetInterface: activeService?.ethernetInterface ?? ""
    property bool ethernetConnected: activeService?.ethernetConnected ?? false
    property string ethernetConnectionUuid: activeService?.ethernetConnectionUuid ?? ""

    property var wiredConnections: activeService?.wiredConnections ?? []

    property string wifiIP: activeService?.wifiIP ?? ""
    property string wifiInterface: activeService?.wifiInterface ?? ""
    property bool wifiConnected: activeService?.wifiConnected ?? false
    property bool wifiEnabled: activeService?.wifiEnabled ?? true
    property string wifiConnectionUuid: activeService?.wifiConnectionUuid ?? ""
    property string wifiDevicePath: activeService?.wifiDevicePath ?? ""
    property string activeAccessPointPath: activeService?.activeAccessPointPath ?? ""

    property string currentWifiSSID: activeService?.currentWifiSSID ?? ""
    property int wifiSignalStrength: activeService?.wifiSignalStrength ?? 0
    property var wifiNetworks: activeService?.wifiNetworks ?? []
    property var savedConnections: activeService?.savedConnections ?? []
    property var ssidToConnectionName: activeService?.ssidToConnectionName ?? ({})
    property var wifiSignalIcon: activeService?.wifiSignalIcon ?? "wifi_off"

    property string userPreference: activeService?.userPreference ?? "auto"
    property bool isConnecting: activeService?.isConnecting ?? false
    property string connectingSSID: activeService?.connectingSSID ?? ""
    property string connectionError: activeService?.connectionError ?? ""

    property bool isScanning: activeService?.isScanning ?? false
    property bool autoScan: activeService?.autoScan ?? false

    property bool wifiAvailable: activeService?.wifiAvailable ?? true
    property bool wifiToggling: activeService?.wifiToggling ?? false
    property bool changingPreference: activeService?.changingPreference ?? false
    property string targetPreference: activeService?.targetPreference ?? ""
    property var savedWifiNetworks: activeService?.savedWifiNetworks ?? []
    property string connectionStatus: activeService?.connectionStatus ?? ""
    property string lastConnectionError: activeService?.lastConnectionError ?? ""
    property bool passwordDialogShouldReopen: activeService?.passwordDialogShouldReopen ?? false
    property bool autoRefreshEnabled: activeService?.autoRefreshEnabled ?? false
    property string wifiPassword: activeService?.wifiPassword ?? ""
    property string forgetSSID: activeService?.forgetSSID ?? ""

    property string networkInfoSSID: activeService?.networkInfoSSID ?? ""
    property string networkInfoDetails: activeService?.networkInfoDetails ?? ""
    property bool networkInfoLoading: activeService?.networkInfoLoading ?? false

    property string networkWiredInfoUUID: activeService?.networkWiredInfoUUID ?? ""
    property string networkWiredInfoDetails: activeService?.networkWiredInfoDetails ?? ""
    property bool networkWiredInfoLoading: activeService?.networkWiredInfoLoading ?? false

    property int refCount: activeService?.refCount ?? 0
    property bool stateInitialized: activeService?.stateInitialized ?? false

    property bool subscriptionConnected: activeService?.subscriptionConnected ?? false

    property string credentialsToken: activeService?.credentialsToken ?? ""
    property string credentialsSSID: activeService?.credentialsSSID ?? ""
    property string credentialsSetting: activeService?.credentialsSetting ?? ""
    property var credentialsFields: activeService?.credentialsFields ?? []
    property var credentialsHints: activeService?.credentialsHints ?? []
    property string credentialsReason: activeService?.credentialsReason ?? ""
    property bool credentialsRequested: activeService?.credentialsRequested ?? false

    signal networksUpdated
    signal connectionChanged
    signal credentialsNeeded(string token, string ssid, string setting, var fields, var hints, string reason, string connType, string connName, string vpnService)

    property bool usingLegacy: false
    property var activeService: null

    readonly property string socketPath: Quickshell.env("DMS_SOCKET")

    Component.onCompleted: {
        console.info("NetworkService: Initializing...")
        if (!socketPath || socketPath.length === 0) {
            console.info("NetworkService: DMS_SOCKET not set, using LegacyNetworkService")
            useLegacyService()
        } else {
            console.log("NetworkService: DMS_SOCKET found, waiting for capabilities...")
        }
    }

    Connections {
        target: DMSNetworkService

        function onNetworkAvailableChanged() {
            if (!activeService && DMSNetworkService.networkAvailable) {
                console.info("NetworkService: Network capability detected, using DMSNetworkService")
                activeService = DMSNetworkService
                usingLegacy = false
                console.info("NetworkService: Switched to DMSNetworkService, networkAvailable:", networkAvailable)
                connectSignals()
            } else if (!activeService && !DMSNetworkService.networkAvailable && socketPath && socketPath.length > 0) {
                console.info("NetworkService: Network capability not available in DMS, using LegacyNetworkService")
                useLegacyService()
            }
        }
    }

    function useLegacyService() {
        activeService = LegacyNetworkService
        usingLegacy = true
        console.info("NetworkService: Switched to LegacyNetworkService, networkAvailable:", networkAvailable)
        if (LegacyNetworkService.activate) {
            LegacyNetworkService.activate()
        }
        connectSignals()
    }

    function connectSignals() {
        if (activeService) {
            if (activeService.networksUpdated) {
                activeService.networksUpdated.connect(root.networksUpdated)
            }
            if (activeService.connectionChanged) {
                activeService.connectionChanged.connect(root.connectionChanged)
            }
            if (activeService.credentialsNeeded) {
                activeService.credentialsNeeded.connect(root.credentialsNeeded)
            }
        }
    }

    function addRef() {
        if (activeService && activeService.addRef) {
            activeService.addRef()
        }
    }

    function removeRef() {
        if (activeService && activeService.removeRef) {
            activeService.removeRef()
        }
    }

    function getState() {
        if (activeService && activeService.getState) {
            activeService.getState()
        }
    }

    function scanWifi() {
        if (activeService && activeService.scanWifi) {
            activeService.scanWifi()
        }
    }

    function scanWifiNetworks() {
        if (activeService && activeService.scanWifiNetworks) {
            activeService.scanWifiNetworks()
        }
    }

    function connectToWifi(ssid, password = "", username = "", anonymousIdentity = "", domainSuffixMatch = "") {
        if (activeService && activeService.connectToWifi) {
            activeService.connectToWifi(ssid, password, username, anonymousIdentity, domainSuffixMatch)
        }
    }

    function disconnectWifi() {
        if (activeService && activeService.disconnectWifi) {
            activeService.disconnectWifi()
        }
    }

    function forgetWifiNetwork(ssid) {
        if (activeService && activeService.forgetWifiNetwork) {
            activeService.forgetWifiNetwork(ssid)
        }
    }

    function toggleWifiRadio() {
        if (activeService && activeService.toggleWifiRadio) {
            activeService.toggleWifiRadio()
        }
    }

    function enableWifiDevice() {
        if (activeService && activeService.enableWifiDevice) {
            activeService.enableWifiDevice()
        }
    }

    function setNetworkPreference(preference) {
        if (activeService && activeService.setNetworkPreference) {
            activeService.setNetworkPreference(preference)
        }
    }

    function setConnectionPriority(type) {
        if (activeService && activeService.setConnectionPriority) {
            activeService.setConnectionPriority(type)
        }
    }

    function connectToWifiAndSetPreference(ssid, password, username = "", anonymousIdentity = "", domainSuffixMatch = "") {
        if (activeService && activeService.connectToWifiAndSetPreference) {
            activeService.connectToWifiAndSetPreference(ssid, password, username, anonymousIdentity, domainSuffixMatch)
        }
    }

    function toggleNetworkConnection(type) {
        if (activeService && activeService.toggleNetworkConnection) {
            activeService.toggleNetworkConnection(type)
        }
    }

    function startAutoScan() {
        if (activeService && activeService.startAutoScan) {
            activeService.startAutoScan()
        }
    }

    function stopAutoScan() {
        if (activeService && activeService.stopAutoScan) {
            activeService.stopAutoScan()
        }
    }

    function fetchNetworkInfo(ssid) {
        if (activeService && activeService.fetchNetworkInfo) {
            activeService.fetchNetworkInfo(ssid)
        }
    }

    function fetchWiredNetworkInfo(uuid) {
        if (activeService && activeService.fetchWiredNetworkInfo) {
            activeService.fetchWiredNetworkInfo(uuid)
        }
    }

    function getNetworkInfo(ssid) {
        if (activeService && activeService.getNetworkInfo) {
            return activeService.getNetworkInfo(ssid)
        }
        return null
    }

    function getWiredNetworkInfo(uuid) {
        if (activeService && activeService.getWiredNetworkInfo) {
            return activeService.getWiredNetworkInfo(uuid)
        }
        return null
    }

    function refreshNetworkState() {
        if (activeService && activeService.refreshNetworkState) {
            activeService.refreshNetworkState()
        }
    }

    function connectToSpecificWiredConfig(uuid) {
        if (activeService && activeService.connectToSpecificWiredConfig) {
            activeService.connectToSpecificWiredConfig(uuid)
        }
    }

    function submitCredentials(token, secrets, save) {
        if (activeService && activeService.submitCredentials) {
            activeService.submitCredentials(token, secrets, save)
        }
    }

    function cancelCredentials(token) {
        if (activeService && activeService.cancelCredentials) {
            activeService.cancelCredentials(token)
        }
    }

    function setWifiAutoconnect(ssid, autoconnect) {
        if (activeService && activeService.setWifiAutoconnect) {
            activeService.setWifiAutoconnect(ssid, autoconnect)
        }
    }
}
