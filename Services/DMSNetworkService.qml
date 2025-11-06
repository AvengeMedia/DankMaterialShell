pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property bool networkAvailable: false
    property string backend: ""

    property string networkStatus: "disconnected"
    property string primaryConnection: ""

    property string ethernetIP: ""
    property string ethernetInterface: ""
    property bool ethernetConnected: false
    property string ethernetConnectionUuid: ""

    property var wiredConnections: []

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
        if (!wifiConnected) {
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

    property var vpnProfiles: []
    property var vpnActive: []
    property bool vpnAvailable: false
    property bool vpnIsBusy: false
    property string lastConnectedVpnUuid: ""
    property string pendingVpnUuid: ""
    property var vpnBusyStartTime: 0

    property alias profiles: root.vpnProfiles
    property alias activeConnections: root.vpnActive
    property var activeUuids: vpnActive.map(v => v.uuid).filter(u => !!u)
    property var activeNames: vpnActive.map(v => v.name).filter(n => !!n)
    property string activeUuid: activeUuids.length > 0 ? activeUuids[0] : ""
    property string activeName: activeNames.length > 0 ? activeNames[0] : ""
    property string activeDevice: vpnActive.length > 0 ? (vpnActive[0].device || "") : ""
    property string activeState: vpnActive.length > 0 ? (vpnActive[0].state || "") : ""
    property bool vpnConnected: activeUuids.length > 0
    property alias available: root.vpnAvailable
    property alias isBusy: root.vpnIsBusy
    property alias connected: root.vpnConnected

    property string networkInfoSSID: ""
    property string networkInfoDetails: ""
    property bool networkInfoLoading: false

    property string networkWiredInfoUUID: ""
    property string networkWiredInfoDetails: ""
    property bool networkWiredInfoLoading: false

    property int refCount: 0
    property bool stateInitialized: false

    property string credentialsToken: ""
    property string credentialsSSID: ""
    property string credentialsSetting: ""
    property var credentialsFields: []
    property var credentialsHints: []
    property string credentialsReason: ""
    property bool credentialsRequested: false

    property string pendingConnectionSSID: ""
    property var pendingConnectionStartTime: 0
    property bool wasConnecting: false

    signal networksUpdated
    signal connectionChanged
    signal credentialsNeeded(string token, string ssid, string setting, var fields, var hints, string reason, string connType, string connName, string vpnService)

    readonly property string socketPath: Quickshell.env("DMS_SOCKET")

    Component.onCompleted: {
        root.userPreference = SettingsData.networkPreference
        lastConnectedVpnUuid = SettingsData.vpnLastConnected || ""
        if (socketPath && socketPath.length > 0) {
            checkDMSCapabilities()
        }
    }

    Connections {
        target: DMSService

        function onNetworkStateUpdate(data) {
            const networksCount = data.wifiNetworks?.length ?? "null"
            console.log("DMSNetworkService: Subscription update received, networks:", networksCount)
            updateState(data)
        }
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

        function onCredentialsRequest(data) {
            handleCredentialsRequest(data)
        }
    }

    function checkDMSCapabilities() {
        if (!DMSService.isConnected) {
            return
        }

        if (DMSService.capabilities.length === 0) {
            return
        }

        networkAvailable = DMSService.capabilities.includes("network")

        if (networkAvailable && !stateInitialized) {
            stateInitialized = true
            getState()
        }
    }

    function handleCredentialsRequest(data) {
        credentialsToken = data.token || ""
        credentialsSSID = data.ssid || ""
        credentialsSetting = data.setting || "802-11-wireless-security"
        credentialsFields = data.fields || ["psk"]
        credentialsHints = data.hints || []
        credentialsReason = data.reason || "Credentials required"
        credentialsRequested = true

        const connType = data.connType || ""
        const connName = data.name || data.connectionId || ""
        const vpnService = data.vpnService || ""

        credentialsNeeded(credentialsToken, credentialsSSID, credentialsSetting, credentialsFields, credentialsHints, credentialsReason, connType, connName, vpnService)
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
                    initialStateFetched = true
                    Qt.callLater(() => scanWifi())
                }
            }
        })
    }

    function updateState(state) {
        const previousConnecting = isConnecting
        const previousConnectingSSID = connectingSSID

        backend = state.backend || ""
        vpnAvailable = networkAvailable && backend === "networkmanager"
        networkStatus = state.networkStatus || "disconnected"
        primaryConnection = state.primaryConnection || ""

        ethernetIP = state.ethernetIP || ""
        ethernetInterface = state.ethernetDevice || ""
        ethernetConnected = state.ethernetConnected || false
        ethernetConnectionUuid = state.ethernetConnectionUuid || ""

        wiredConnections = state.wiredConnections || []

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

        if (state.vpnProfiles) {
            vpnProfiles = state.vpnProfiles
        }

        const previousVpnActive = vpnActive
        vpnActive = state.vpnActive || []

        if (vpnConnected && activeUuid) {
            lastConnectedVpnUuid = activeUuid
            SettingsData.set("vpnLastConnected", activeUuid)
        }

        if (vpnIsBusy) {
            const busyDuration = Date.now() - vpnBusyStartTime
            const timeout = 30000

            if (busyDuration > timeout) {
                console.warn("DMSNetworkService: VPN operation timed out after", timeout, "ms")
                vpnIsBusy = false
                pendingVpnUuid = ""
                vpnBusyStartTime = 0
            } else if (pendingVpnUuid) {
                const isPendingVpnActive = activeUuids.includes(pendingVpnUuid)
                if (isPendingVpnActive) {
                    vpnIsBusy = false
                    pendingVpnUuid = ""
                    vpnBusyStartTime = 0
                }
            } else {
                const previousCount = previousVpnActive ? previousVpnActive.length : 0
                const currentCount = vpnActive ? vpnActive.length : 0

                if (previousCount !== currentCount) {
                    vpnIsBusy = false
                    vpnBusyStartTime = 0
                }
            }
        }

        userPreference = state.preference || "auto"
        isConnecting = state.isConnecting || false
        connectingSSID = state.connectingSSID || ""
        connectionError = state.lastError || ""
        lastConnectionError = state.lastError || ""

        if (pendingConnectionSSID) {
            if (wifiConnected && currentWifiSSID === pendingConnectionSSID && wifiIP) {
                const elapsed = Date.now() - pendingConnectionStartTime
                console.info("DMSNetworkService: Successfully connected to", pendingConnectionSSID, "in", elapsed, "ms")
                ToastService.showInfo(`Connected to ${pendingConnectionSSID}`)

                if (userPreference === "wifi" || userPreference === "auto") {
                    setConnectionPriority("wifi")
                }

                pendingConnectionSSID = ""
                connectionStatus = "connected"
            } else if (previousConnecting && !isConnecting && !wifiConnected) {
                const isCancellationError = connectionError === "user-canceled"
                const isBadCredentials = connectionError === "bad-credentials"

                if (isCancellationError) {
                    connectionStatus = "cancelled"
                    pendingConnectionSSID = ""
                } else if (isBadCredentials) {
                    connectionStatus = "invalid_password"
                    pendingConnectionSSID = ""
                } else {
                    if (connectionError) {
                        ToastService.showError(I18n.tr("Failed to connect to ") + pendingConnectionSSID)
                    }
                    connectionStatus = "failed"
                    pendingConnectionSSID = ""
                }
            }
        }

        wasConnecting = isConnecting

        connectionChanged()
    }

    function connectToSpecificWiredConfig(uuid) {
        if (!networkAvailable || isConnecting) return

        isConnecting = true
        connectionError = ""
        connectionStatus = "connecting"

        const params = { uuid: uuid }

        DMSService.sendRequest("network.ethernet.connect.config", params, response => {
            if (response.error) {
                connectionError = response.error
                lastConnectionError = response.error
                connectionStatus = "failed"
                ToastService.showError(I18n.tr("Failed to activate configuration"))
            } else {
                connectionError = ""
                connectionStatus = "connected"
                ToastService.showInfo(I18n.tr("Configuration activated"))
            }

            isConnecting = false
        })
    }

    function scanWifi() {
        if (!networkAvailable || isScanning || !wifiEnabled) return

        isScanning = true
        DMSService.sendRequest("network.wifi.scan", null, response => {
            isScanning = false
            if (response.error) {
                console.warn("DMSNetworkService: WiFi scan failed:", response.error)
            } else {
                Qt.callLater(() => getState())
            }
        })
    }

    function scanWifiNetworks() {
        scanWifi()
    }

    function connectToWifi(ssid, password = "", username = "", anonymousIdentity = "", domainSuffixMatch = "") {
        if (!networkAvailable || isConnecting) return

        pendingConnectionSSID = ssid
        pendingConnectionStartTime = Date.now()
        connectionError = ""
        connectionStatus = "connecting"
        credentialsRequested = false

        const params = { ssid: ssid }

        if (DMSService.apiVersion >= 7) {
            if (password || username) {
                params.password = password
                if (username) params.username = username
                if (anonymousIdentity) params.anonymousIdentity = anonymousIdentity
                if (domainSuffixMatch) params.domainSuffixMatch = domainSuffixMatch
                params.interactive = false
            } else {
                params.interactive = true
            }
        } else {
            if (password) params.password = password
            if (username) params.username = username
            if (anonymousIdentity) params.anonymousIdentity = anonymousIdentity
            if (domainSuffixMatch) params.domainSuffixMatch = domainSuffixMatch
        }

        DMSService.sendRequest("network.wifi.connect", params, response => {
            if (response.error) {
                if (connectionStatus === "cancelled") {
                    return
                }

                connectionError = response.error
                lastConnectionError = response.error
                pendingConnectionSSID = ""
                connectionStatus = "failed"
                ToastService.showError(I18n.tr("Failed to start connection to ") + ssid)
            }
        })
    }

    function disconnectWifi() {
        if (!networkAvailable || !wifiInterface) return

        DMSService.sendRequest("network.wifi.disconnect", null, response => {
            if (response.error) {
                ToastService.showError(I18n.tr("Failed to disconnect WiFi"))
            } else {
                ToastService.showInfo(I18n.tr("Disconnected from WiFi"))
                currentWifiSSID = ""
                connectionStatus = ""
            }
        })
    }

    function submitCredentials(token, secrets, save) {
        console.log("submitCredentials: networkAvailable=" + networkAvailable + " apiVersion=" + DMSService.apiVersion)

        if (!networkAvailable || DMSService.apiVersion < 7) {
            console.warn("submitCredentials: Aborting - networkAvailable=" + networkAvailable + " apiVersion=" + DMSService.apiVersion)
            return
        }

        const params = {
            token: token,
            secrets: secrets,
            save: save || false
        }

        credentialsRequested = false

        DMSService.sendRequest("network.credentials.submit", params, response => {
            if (response.error) {
                console.warn("DMSNetworkService: Failed to submit credentials:", response.error)
            }
        })
    }

    function cancelCredentials(token) {
        if (!networkAvailable || DMSService.apiVersion < 7) return

        const params = {
            token: token
        }

        credentialsRequested = false
        pendingConnectionSSID = ""
        connectionStatus = "cancelled"

        DMSService.sendRequest("network.credentials.cancel", params, response => {
            if (response.error) {
                console.warn("DMSNetworkService: Failed to cancel credentials:", response.error)
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
                ToastService.showInfo(I18n.tr("Forgot network ") + ssid)

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
                ToastService.showInfo(wifiEnabled ? I18n.tr("WiFi enabled") : I18n.tr("WiFi disabled"))
            }
        })
    }

    function enableWifiDevice() {
        if (!networkAvailable) return

        DMSService.sendRequest("network.wifi.enable", null, response => {
            if (response.error) {
                ToastService.showError(I18n.tr("Failed to enable WiFi"))
            } else {
                ToastService.showInfo(I18n.tr("WiFi enabled"))
            }
        })
    }

    function setNetworkPreference(preference) {
        if (!networkAvailable) return

        userPreference = preference
        changingPreference = true
        targetPreference = preference
        SettingsData.set("networkPreference", preference)

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

    function connectToWifiAndSetPreference(ssid, password, username = "", anonymousIdentity = "", domainSuffixMatch = "") {
        connectToWifi(ssid, password, username, anonymousIdentity, domainSuffixMatch)
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

    function fetchWiredNetworkInfo(uuid) {
        if (!networkAvailable) return

        networkWiredInfoUUID = uuid
        networkWiredInfoLoading = true
        networkWiredInfoDetails = "Loading network information..."

        DMSService.sendRequest("network.ethernet.info", { uuid: uuid }, response => {
            networkWiredInfoLoading = false

            if (response.error) {
                networkWiredInfoDetails = "Failed to fetch network information"
            } else if (response.result) {
                formatWiredNetworkInfo(response.result)
            }
        })
    }

    function formatWiredNetworkInfo(info) {
        let details = ""

        if (!info) {
            details = "Network information not found or network not available."
        } else {
            details += "Inteface: " + info.iface + "\\n"
            details += "Driver: " + info.driver + "\\n"
            details += "MAC Addr: " + info.hwAddr + "\\n"
            details += "Speed: " + info.speed + " Mb/s\\n\\n"

            details += "IPv4 informations:\\n"

            for (const ip4 of info.IPv4s.ips) {
                details += "    IPv4 address: " + ip4 + "\\n"
            }
            details += "    Gateway: " + info.IPv4s.gateway + "\\n"
            details += "    DNS: " + info.IPv4s.dns + "\\n"

            if (info.IPv6s.ips) {
                details += "\\nIPv6 informations:\\n"

                for (const ip6 of info.IPv6s.ips) {
                    details += "    IPv6 address: " + ip6 + "\\n"
                }
                if (info.IPv6s.gateway.length > 0) {
                    details += "    Gateway: " + info.IPv6s.gateway + "\\n"
                }
                if (info.IPv6s.dns.length > 0) {
                    details += "    DNS: " + info.IPv6s.dns + "\\n"
                }
            }
        }

        networkWiredInfoDetails = details
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

    function getWiredNetworkInfo(uuid) {
        const network = wiredConnections.find(n => n.uuid === uuid)
        if (!network) {
            return null
        }

        return {
            "uuid": uuid,
        }
    }

    function refreshVpnProfiles() {
        if (!vpnAvailable) return

        DMSService.sendRequest("network.vpn.profiles", null, response => {
            if (response.result) {
                vpnProfiles = response.result
            }
        })
    }

    function refreshVpnActive() {
        if (!vpnAvailable) return

        DMSService.sendRequest("network.vpn.active", null, response => {
            if (response.result) {
                vpnActive = response.result
            }
        })
    }

    function connectVpn(uuidOrName, singleActive = false) {
        if (!vpnAvailable || vpnIsBusy) return

        vpnIsBusy = true
        pendingVpnUuid = uuidOrName
        vpnBusyStartTime = Date.now()

        const params = {
            uuidOrName: uuidOrName,
            singleActive: singleActive
        }

        DMSService.sendRequest("network.vpn.connect", params, response => {
            if (response.error) {
                vpnIsBusy = false
                pendingVpnUuid = ""
                vpnBusyStartTime = 0
                ToastService.showError(I18n.tr("Failed to connect VPN"))
            }
        })
    }

    function connect(uuidOrName, singleActive = false) {
        connectVpn(uuidOrName, singleActive)
    }

    function disconnectVpn(uuidOrName) {
        if (!vpnAvailable || vpnIsBusy) return

        vpnIsBusy = true
        pendingVpnUuid = ""
        vpnBusyStartTime = Date.now()

        const params = {
            uuidOrName: uuidOrName
        }

        DMSService.sendRequest("network.vpn.disconnect", params, response => {
            if (response.error) {
                vpnIsBusy = false
                vpnBusyStartTime = 0
                ToastService.showError(I18n.tr("Failed to disconnect VPN"))
            }
        })
    }

    function disconnect(uuidOrName) {
        disconnectVpn(uuidOrName)
    }

    function disconnectAllVpns() {
        if (!vpnAvailable || vpnIsBusy) return

        vpnIsBusy = true
        pendingVpnUuid = ""

        DMSService.sendRequest("network.vpn.disconnectAll", null, response => {
            if (response.error) {
                vpnIsBusy = false
                ToastService.showError(I18n.tr("Failed to disconnect VPNs"))
            }
        })
    }

    function disconnectAllActive() {
        disconnectAllVpns()
    }

    function toggleVpn(uuid) {
        if (uuid) {
            if (isActiveVpnUuid(uuid)) {
                disconnectVpn(uuid)
            } else {
                connectVpn(uuid)
            }
            return
        }

        if (vpnConnected) {
            disconnectAllVpns()
            return
        }

        const targetUuid = lastConnectedVpnUuid || (vpnProfiles.length > 0 ? vpnProfiles[0].uuid : "")
        if (targetUuid) {
            connectVpn(targetUuid)
        }
    }

    function toggle(uuid) {
        toggleVpn(uuid)
    }

    function isActiveVpnUuid(uuid) {
        return activeUuids && activeUuids.indexOf(uuid) !== -1
    }

    function isActiveUuid(uuid) {
        return isActiveVpnUuid(uuid)
    }

    function refreshNetworkState() {
        if (networkAvailable) {
            getState()
        }
    }

    function setWifiAutoconnect(ssid, autoconnect) {
        if (!networkAvailable || DMSService.apiVersion <= 13) return

        const params = {
            ssid: ssid,
            autoconnect: autoconnect
        }

        DMSService.sendRequest("network.wifi.setAutoconnect", params, response => {
            if (response.error) {
                ToastService.showError(I18n.tr("Failed to update autoconnect"))
            } else {
                ToastService.showInfo(autoconnect ? I18n.tr("Autoconnect enabled") : I18n.tr("Autoconnect disabled"))
                Qt.callLater(() => getState())
            }
        })
    }
}
