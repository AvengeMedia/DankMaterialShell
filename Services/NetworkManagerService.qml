pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property bool networkAvailable: false

    property string networkStatus: "disconnected"
    property string primaryConnection: ""

    property string ethernetIP: ""
    property string ethernetInterface: ""
    property bool ethernetConnected: false
    property string ethernetConnectionUuid: ""

    property string wifiIP: ""
    property string wifiInterface: ""
    property bool wifiConnected: false
    property bool wifiEnabled: true
    property string wifiConnectionUuid: ""
    property string wifiDevicePath: ""
    property string activeAccessPointPath: ""

    property string currentWifiSSID: ""
    property int wifiSignalStrength: 0
    property var wifiNetworks: []
    property var savedConnections: []
    property var ssidToConnectionName: ({})
    property var wifiSignalIcon: {
        if (!wifiConnected || networkStatus !== "wifi") {
            return "wifi_off"
        }
        if (wifiSignalStrength >= 50) {
            return "wifi"
        }
        if (wifiSignalStrength >= 25) {
            return "wifi_2_bar"
        }
        return "wifi_1_bar"
    }

    property string userPreference: "auto"
    property bool isConnecting: false
    property string connectingSSID: ""
    property string connectionError: ""

    property bool isScanning: false
    property bool autoScan: false

    property bool wifiAvailable: true
    property bool wifiToggling: false
    property bool changingPreference: false
    property string targetPreference: ""
    property var savedWifiNetworks: []
    property string connectionStatus: ""
    property string lastConnectionError: ""
    property bool passwordDialogShouldReopen: false
    property bool autoRefreshEnabled: false
    property string wifiPassword: ""
    property string forgetSSID: ""

    property string networkInfoSSID: ""
    property string networkInfoDetails: ""
    property bool networkInfoLoading: false

    property int refCount: 0
    property bool stateInitialized: false

    signal networksUpdated
    signal connectionChanged

    property bool subscriptionConnected: false

    readonly property string socketPath: Quickshell.env("DMS_SOCKET")

    Component.onCompleted: {
        root.userPreference = SettingsData.networkPreference
        if (socketPath && socketPath.length > 0) {
            checkDMSCapabilities()
        }
    }

    DankSocket {
        id: subscriptionSocket
        path: root.socketPath
        connected: networkAvailable

        onConnectionStateChanged: {
            root.subscriptionConnected = connected
            if (connected) {
                console.log("NetworkManagerService: Subscription socket connected")
            }
        }

        parser: SplitParser {
            onRead: line => {
                if (!line || line.length === 0) {
                    return
                }

                try {
                    const response = JSON.parse(line)

                    if (response.capabilities) {
                        console.log("NetworkManagerService: Subscription socket received capabilities")
                        Qt.callLater(() => sendSubscribeRequest())
                        return
                    }

                    if (response.result && response.result.type === "state_changed" && response.result.data) {
                        const networksCount = response.result.data.wifiNetworks?.length ?? "null"
                        console.log("NetworkManagerService: Subscription update received, networks:", networksCount)
                        updateState(response.result.data)
                    }
                } catch (e) {
                    console.warn("NetworkManagerService: Failed to parse subscription response:", line, e)
                }
            }
        }
    }

    function sendSubscribeRequest() {
        subscriptionSocket.send({
            "id": 1,
            "method": "network.subscribe"
        })
        console.log("NetworkManagerService: Sent network.subscribe request")
    }

    Connections {
        target: DMSService

        function onConnectionStateChanged() {
            if (DMSService.isConnected) {
                checkDMSCapabilities()
            }
        }
    }

    Connections {
        target: DMSService
        enabled: DMSService.isConnected

        function onCapabilitiesChanged() {
            checkDMSCapabilities()
        }
    }

    function checkDMSCapabilities() {
        if (!DMSService.isConnected) {
            return
        }

        if (DMSService.capabilities.length === 0) {
            return
        }

        console.log("NetworkManagerService: Capabilities:", JSON.stringify(DMSService.capabilities))
        networkAvailable = DMSService.capabilities.includes("network")
        console.log("NetworkManagerService: Network available:", networkAvailable)

        if (networkAvailable && !stateInitialized) {
            console.log("NetworkManagerService: Requesting network state and starting subscription socket...")
            stateInitialized = true
            getState()
            subscriptionSocket.connected = true
        }
    }

    function addRef() {
        refCount++
        if (refCount === 1 && networkAvailable) {
            startAutoScan()
        }
    }

    function removeRef() {
        refCount = Math.max(0, refCount - 1)
        if (refCount === 0) {
            stopAutoScan()
        }
    }

    property bool initialStateFetched: false

    function getState() {
        if (!networkAvailable) return

        DMSService.sendRequest("network.getState", null, response => {
            if (response.result) {
                updateState(response.result)
                if (!initialStateFetched && response.result.wifiEnabled && (!response.result.wifiNetworks || response.result.wifiNetworks.length === 0)) {
                    console.log("NetworkManagerService: Initial state has no networks, triggering scan")
                    initialStateFetched = true
                    Qt.callLater(() => scanWifi())
                }
            }
        })
    }

    function updateState(state) {
        networkStatus = state.networkStatus || "disconnected"
        primaryConnection = state.primaryConnection || ""

        ethernetIP = state.ethernetIP || ""
        ethernetInterface = state.ethernetDevice || ""
        ethernetConnected = state.ethernetConnected || false
        ethernetConnectionUuid = state.ethernetConnectionUuid || ""

        wifiIP = state.wifiIP || ""
        wifiInterface = state.wifiDevice || ""
        wifiConnected = state.wifiConnected || false
        wifiEnabled = state.wifiEnabled !== undefined ? state.wifiEnabled : true
        wifiConnectionUuid = state.wifiConnectionUuid || ""
        wifiDevicePath = state.wifiDevicePath || ""
        activeAccessPointPath = state.activeAccessPointPath || ""

        currentWifiSSID = state.wifiSSID || ""
        wifiSignalStrength = state.wifiSignal || 0

        if (state.wifiNetworks) {
            wifiNetworks = state.wifiNetworks

            const saved = []
            const mapping = {}
            for (const network of state.wifiNetworks) {
                if (network.saved) {
                    saved.push({
                        ssid: network.ssid,
                        saved: true
                    })
                    mapping[network.ssid] = network.ssid
                }
            }
            savedConnections = saved
            savedWifiNetworks = saved
            ssidToConnectionName = mapping

            networksUpdated()
        }

        userPreference = state.preference || "auto"
        isConnecting = state.isConnecting || false
        connectingSSID = state.connectingSSID || ""
        connectionError = state.lastError || ""
        lastConnectionError = state.lastError || ""

        connectionChanged()
    }

    function scanWifi() {
        if (!networkAvailable || isScanning || !wifiEnabled) return

        console.log("NetworkManagerService: Starting WiFi scan...")
        isScanning = true
        DMSService.sendRequest("network.wifi.scan", null, response => {
            isScanning = false
            if (response.error) {
                console.warn("NetworkManagerService: WiFi scan failed:", response.error)
            } else {
                console.log("NetworkManagerService: Scan completed, requesting fresh state...")
                Qt.callLater(() => getState())
            }
        })
    }

    function scanWifiNetworks() {
        scanWifi()
    }

    function connectToWifi(ssid, password = "", username = "") {
        if (!networkAvailable || isConnecting) return

        isConnecting = true
        connectingSSID = ssid
        connectionError = ""
        connectionStatus = "connecting"

        const params = { ssid: ssid }
        if (password) params.password = password
        if (username) params.username = username

        DMSService.sendRequest("network.wifi.connect", params, response => {
            if (response.error) {
                connectionError = response.error
                lastConnectionError = response.error
                connectionStatus = response.error.includes("password") || response.error.includes("authentication")
                    ? "invalid_password"
                    : "failed"

                if (connectionStatus === "invalid_password") {
                    passwordDialogShouldReopen = true
                    ToastService.showError(`Invalid password for ${ssid}`)
                } else {
                    ToastService.showError(`Failed to connect to ${ssid}`)
                }
            } else {
                connectionError = ""
                connectionStatus = "connected"
                ToastService.showInfo(`Connected to ${ssid}`)

                if (userPreference === "wifi" || userPreference === "auto") {
                    setConnectionPriority("wifi")
                }
            }

            isConnecting = false
            connectingSSID = ""
        })
    }

    function disconnectWifi() {
        if (!networkAvailable || !wifiInterface) return

        DMSService.sendRequest("network.wifi.disconnect", null, response => {
            if (response.error) {
                ToastService.showError("Failed to disconnect WiFi")
            } else {
                ToastService.showInfo("Disconnected from WiFi")
                currentWifiSSID = ""
                connectionStatus = ""
            }
        })
    }

    function forgetWifiNetwork(ssid) {
        if (!networkAvailable) return

        forgetSSID = ssid
        DMSService.sendRequest("network.wifi.forget", { ssid: ssid }, response => {
            if (response.error) {
                console.warn("Failed to forget network:", response.error)
            } else {
                ToastService.showInfo(`Forgot network ${ssid}`)

                savedConnections = savedConnections.filter(s => s.ssid !== ssid)
                savedWifiNetworks = savedWifiNetworks.filter(s => s.ssid !== ssid)

                const updated = [...wifiNetworks]
                for (const network of updated) {
                    if (network.ssid === ssid) {
                        network.saved = false
                        if (network.connected) {
                            network.connected = false
                            currentWifiSSID = ""
                        }
                    }
                }
                wifiNetworks = updated
                networksUpdated()
            }
            forgetSSID = ""
        })
    }

    function toggleWifiRadio() {
        if (!networkAvailable || wifiToggling) return

        wifiToggling = true
        DMSService.sendRequest("network.wifi.toggle", null, response => {
            wifiToggling = false

            if (response.error) {
                console.warn("Failed to toggle WiFi:", response.error)
            } else if (response.result) {
                wifiEnabled = response.result.enabled
                ToastService.showInfo(wifiEnabled ? "WiFi enabled" : "WiFi disabled")
            }
        })
    }

    function enableWifiDevice() {
        if (!networkAvailable) return

        DMSService.sendRequest("network.wifi.enable", null, response => {
            if (response.error) {
                ToastService.showError("Failed to enable WiFi")
            } else {
                ToastService.showInfo("WiFi enabled")
            }
        })
    }

    function setNetworkPreference(preference) {
        if (!networkAvailable) return

        userPreference = preference
        changingPreference = true
        targetPreference = preference
        SettingsData.setNetworkPreference(preference)

        DMSService.sendRequest("network.preference.set", { preference: preference }, response => {
            changingPreference = false
            targetPreference = ""

            if (response.error) {
                console.warn("Failed to set network preference:", response.error)
            }
        })
    }

    function setConnectionPriority(type) {
        if (type === "wifi") {
            setNetworkPreference("wifi")
        } else if (type === "ethernet") {
            setNetworkPreference("ethernet")
        }
    }

    function connectToWifiAndSetPreference(ssid, password, username = "") {
        connectToWifi(ssid, password, username)
        setNetworkPreference("wifi")
    }

    function toggleNetworkConnection(type) {
        if (!networkAvailable) return

        if (type === "ethernet") {
            if (networkStatus === "ethernet") {
                DMSService.sendRequest("network.ethernet.disconnect", null, null)
            } else {
                DMSService.sendRequest("network.ethernet.connect", null, null)
            }
        }
    }

    function startAutoScan() {
        autoScan = true
        autoRefreshEnabled = true
        if (networkAvailable && wifiEnabled) {
            scanWifi()
        }
    }

    function stopAutoScan() {
        autoScan = false
        autoRefreshEnabled = false
    }

    function fetchNetworkInfo(ssid) {
        if (!networkAvailable) return

        networkInfoSSID = ssid
        networkInfoLoading = true
        networkInfoDetails = "Loading network information..."

        DMSService.sendRequest("network.info", { ssid: ssid }, response => {
            networkInfoLoading = false

            if (response.error) {
                networkInfoDetails = "Failed to fetch network information"
            } else if (response.result) {
                formatNetworkInfo(response.result)
            }
        })
    }

    function formatNetworkInfo(info) {
        let details = ""

        if (!info || !info.bands || info.bands.length === 0) {
            details = "Network information not found or network not available."
        } else {
            for (const band of info.bands) {
                const freqGHz = band.frequency / 1000
                let bandName = "Unknown"
                if (band.frequency >= 2400 && band.frequency <= 2500) {
                    bandName = "2.4 GHz"
                } else if (band.frequency >= 5000 && band.frequency <= 6000) {
                    bandName = "5 GHz"
                } else if (band.frequency >= 6000) {
                    bandName = "6 GHz"
                }

                const statusPrefix = band.connected ? "● " : "  "
                const statusSuffix = band.connected ? " (Connected)" : ""

                details += statusPrefix + bandName + statusSuffix + " - " + band.signal + "%\\n"
                details += "  Channel " + band.channel + " (" + freqGHz.toFixed(1) + " GHz) • " + band.rate + " Mbit/s\\n"
                details += "  BSSID: " + band.bssid + "\\n"
                details += "  Mode: " + band.mode + "\\n"
                details += "  Security: " + (band.secured ? "Secured" : "Open") + "\\n"
                if (band.saved) {
                    details += "  Status: Saved network\\n"
                }
                details += "\\n"
            }
        }

        networkInfoDetails = details
    }

    function getNetworkInfo(ssid) {
        const network = wifiNetworks.find(n => n.ssid === ssid)
        if (!network) {
            return null
        }

        return {
            "ssid": network.ssid,
            "signal": network.signal,
            "secured": network.secured,
            "saved": network.saved,
            "connected": network.connected,
            "bssid": network.bssid
        }
    }

    function refreshNetworkState() {
        if (networkAvailable) {
            getState()
        }
    }

    function splitNmcliFields(line) {
        const parts = []
        let cur = ""
        let escape = false
        for (var i = 0; i < line.length; i++) {
            const ch = line[i]
            if (escape) {
                cur += ch
                escape = false
            } else if (ch === '\\') {
                escape = true
            } else if (ch === ':') {
                parts.push(cur)
                cur = ""
            } else {
                cur += ch
            }
        }
        parts.push(cur)
        return parts
    }
}
