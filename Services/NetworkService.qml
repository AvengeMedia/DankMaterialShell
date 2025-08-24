pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    // Core network state
    property int refCount: 0
    property string networkStatus: "disconnected" // "ethernet", "wifi", "disconnected"
    property string primaryConnection: "" // Active connection UUID

    // Ethernet properties
    property string ethernetIP: ""
    property string ethernetInterface: ""
    property bool ethernetConnected: false
    property string ethernetConnectionUuid: ""

    // WiFi properties
    property string wifiIP: ""
    property string wifiInterface: ""
    property bool wifiConnected: false
    property bool wifiEnabled: true
    property string wifiConnectionUuid: ""

    // WiFi details
    property string currentWifiSSID: ""
    property int wifiSignalStrength: 0
    property var wifiNetworks: []
    property var savedConnections: []
    property var wifiSignalIcon: {
        // If WiFi radio is disabled, show the off icon
        if (!wifiEnabled) {
            return "signal_wifi_off"
        }
        if (wifiConnected || networkStatus === "wifi") {
            if (wifiSignalStrength >= 70) {
                return "signal_wifi_4_bar"
            }
            if (wifiSignalStrength >= 50) {
                return "network_wifi_3_bar"
            }
            if (wifiSignalStrength >= 25) {
                return "network_wifi_2_bar"
            }
            if (wifiSignalStrength >= 10) {
                return "network_wifi_1_bar"
            }
            return "network_wifi_1_bar"
        }
        // WiFi enabled but not connected
        return "signal_wifi_bad"
    }

    // Connection management
    property string userPreference: "auto" // "auto", "wifi", "ethernet"
    property bool isConnecting: false
    property string connectingSSID: ""
    property string connectionError: ""

    // Scanning
    property bool isScanning: false
    property bool autoScan: false

    // Legacy compatibility properties
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

    // Network info properties
    property string networkInfoSSID: ""
    property string networkInfoDetails: ""
    property bool networkInfoLoading: false

    signal networksUpdated
    signal connectionChanged

    Component.onCompleted: {
        root.userPreference = SettingsData.networkPreference
        initializeDBusMonitors()
    }

    function addRef() {
        refCount++
        if (refCount === 1) {
            startAutoScan()
        }
    }

    function removeRef() {
        refCount = Math.max(0, refCount - 1)
        if (refCount === 0) {
            stopAutoScan()
        }
    }

    function initializeDBusMonitors() {
        nmStateMonitor.running = true
        doRefreshNetworkState()
    }

    Process {
        id: nmStateMonitor
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.NetworkManager"]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (line.includes("StateChanged") || line.includes(
                        "PrimaryConnectionChanged") || line.includes(
                        "WirelessEnabled") || line.includes(
                        "ActiveConnection") || line.includes(
                        "PropertiesChanged")) {
                    refreshNetworkState()
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0 && !restartTimer.running) {
                console.warn("NetworkManager monitor failed, restarting in 5s")
                restartTimer.start()
            }
        }
    }

    Timer {
        id: restartTimer
        interval: 5000
        running: false
        onTriggered: nmStateMonitor.running = true
    }

    Timer {
        id: refreshDebounceTimer
        interval: 100
        running: false
        onTriggered: doRefreshNetworkState()
    }

    function refreshNetworkState() {
        refreshDebounceTimer.restart()
    }

    function doRefreshNetworkState() {
        updatePrimaryConnection()
        updateDeviceStates()
        updateActiveConnections()
        updateWifiState()
        if (root.refCount > 0 && root.wifiEnabled) {
            scanWifiNetworks()
        }
    }

    function updatePrimaryConnection() {
        primaryConnectionQuery.running = true
    }

    Process {
        id: primaryConnectionQuery
        command: ["gdbus", "call", "--system", "--dest", "org.freedesktop.NetworkManager", "--object-path", "/org/freedesktop/NetworkManager", "--method", "org.freedesktop.DBus.Properties.Get", "org.freedesktop.NetworkManager", "PrimaryConnection"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/objectpath '([^']+)'/)
                if (match && match[1] !== '/') {
                    root.primaryConnection = match[1]
                    getPrimaryConnectionType.running = true
                } else {
                    root.primaryConnection = ""
                    root.networkStatus = "disconnected"
                }
            }
        }
    }

    Process {
        id: getPrimaryConnectionType
        command: root.primaryConnection ? ["gdbus", "call", "--system", "--dest", "org.freedesktop.NetworkManager", "--object-path", root.primaryConnection, "--method", "org.freedesktop.DBus.Properties.Get", "org.freedesktop.NetworkManager.Connection.Active", "Type"] : []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.includes("802-3-ethernet")) {
                    root.networkStatus = "ethernet"
                } else if (text.includes("802-11-wireless")) {
                    root.networkStatus = "wifi"
                }
                root.connectionChanged()
            }
        }
    }

    function updateDeviceStates() {
        getEthernetDevice.running = true
        getWifiDevice.running = true
    }

    Process {
        id: getEthernetDevice
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE", "device"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split('\n')
                let ethernetInterface = ""

                for (const line of lines) {
                    const splitParts = line.split(':')
                    const device = splitParts[0]
                    const type = splitParts.length > 1 ? splitParts[1] : ""
                    if (type === "ethernet") {
                        ethernetInterface = device
                        break
                    }
                }

                if (ethernetInterface) {
                    root.ethernetInterface = ethernetInterface
                    getEthernetDevicePath.command = ["gdbus", "call", "--system", "--dest", "org.freedesktop.NetworkManager", "--object-path", "/org/freedesktop/NetworkManager", "--method", "org.freedesktop.NetworkManager.GetDeviceByIpIface", ethernetInterface]
                    getEthernetDevicePath.running = true
                } else {
                    root.ethernetInterface = ""
                    root.ethernetConnected = false
                }
            }
        }
    }

    Process {
        id: getEthernetDevicePath
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/objectpath '([^']+)'/)
                if (match && match[1] !== '/') {
                    checkEthernetState.command = ["gdbus", "call", "--system", "--dest", "org.freedesktop.NetworkManager", "--object-path", match[1], "--method", "org.freedesktop.DBus.Properties.Get", "org.freedesktop.NetworkManager.Device", "State"]
                    checkEthernetState.running = true
                } else {
                    root.ethernetInterface = ""
                    root.ethernetConnected = false
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.ethernetInterface = ""
                root.ethernetConnected = false
            }
        }
    }

    Process {
        id: checkEthernetState
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const isConnected = text.includes("uint32 100")
                root.ethernetConnected = isConnected
                if (isConnected) {
                    getEthernetIP.running = true
                } else {
                    root.ethernetIP = ""
                    if (root.networkStatus === "ethernet") {
                        updatePrimaryConnection()
                    }
                }
            }
        }
    }

    Process {
        id: getEthernetIP
        command: root.ethernetInterface ? ["ip", "-4", "addr", "show", root.ethernetInterface] : []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/inet (\d+\.\d+\.\d+\.\d+)/)
                if (match)
                root.ethernetIP = match[1]
            }
        }
    }

    Process {
        id: getWifiDevice
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE", "device"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split('\n')
                let wifiInterface = ""

                for (const line of lines) {
                    const splitParts = line.split(':')
                    const device = splitParts[0]
                    const type = splitParts.length > 1 ? splitParts[1] : ""
                    if (type === "wifi") {
                        wifiInterface = device
                        break
                    }
                }

                if (wifiInterface) {
                    root.wifiInterface = wifiInterface
                    getWifiDevicePath.command = ["gdbus", "call", "--system", "--dest", "org.freedesktop.NetworkManager", "--object-path", "/org/freedesktop/NetworkManager", "--method", "org.freedesktop.NetworkManager.GetDeviceByIpIface", wifiInterface]
                    getWifiDevicePath.running = true
                } else {
                    root.wifiInterface = ""
                    root.wifiConnected = false
                }
            }
        }
    }

    Process {
        id: getWifiDevicePath
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/objectpath '([^']+)'/)
                if (match && match[1] !== '/') {
                    checkWifiState.command = ["gdbus", "call", "--system", "--dest", "org.freedesktop.NetworkManager", "--object-path", match[1], "--method", "org.freedesktop.DBus.Properties.Get", "org.freedesktop.NetworkManager.Device", "State"]
                    checkWifiState.running = true
                } else {
                    root.wifiInterface = ""
                    root.wifiConnected = false
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.wifiInterface = ""
                root.wifiConnected = false
            }
        }
    }

    Process {
        id: checkWifiState
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiConnected = text.includes("uint32 100")
                if (root.wifiConnected) {
                    getWifiIP.running = true
                    getCurrentWifiInfo.running = true
                    // Ensure SSID is resolved even if scan output lacks ACTIVE marker
                    if (root.currentWifiSSID === "") {
                        if (root.wifiConnectionUuid) {
                            resolveWifiSSID.running = true
                        }
                        if (root.wifiInterface) {
                            resolveWifiSSIDFromDevice.running = true
                        }
                    }
                } else {
                    root.wifiIP = ""
                    root.currentWifiSSID = ""
                    root.wifiSignalStrength = 0
                }
            }
        }
    }

    Process {
        id: getWifiIP
        command: root.wifiInterface ? ["ip", "-4", "addr", "show", root.wifiInterface] : []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/inet (\d+\.\d+\.\d+\.\d+)/)
                if (match)
                root.wifiIP = match[1]
            }
        }
    }

    Process {
        id: getCurrentWifiInfo
        command: root.wifiInterface ? ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL", "dev", "wifi", "list", "ifname", root.wifiInterface] : []
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (line.startsWith("yes:")) {
                    const parts = line.substring(4).split(":")
                    if (parts.length >= 2) {
                        root.currentWifiSSID = parts[0]
                        root.wifiSignalStrength = parseInt(parts[1]) || 0
                    }
                }
            }
        }
    }


    function updateActiveConnections() {
        getActiveConnections.running = true
    }

    Process {
        id: getActiveConnections
        command: ["nmcli", "-t", "-f", "UUID,TYPE,DEVICE,STATE", "connection", "show", "--active"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split('\n')
                for (const line of lines) {
                    const parts = line.split(':')
                    if (parts.length >= 4) {
                        const uuid = parts[0]
                        const type = parts[1]
                        const device = parts[2]
                        const state = parts[3]
                        if (type === "802-3-ethernet"
                            && state === "activated") {
                            root.ethernetConnectionUuid = uuid
                        } else if (type === "802-11-wireless"
                                   && state === "activated") {
                            root.wifiConnectionUuid = uuid
                        }
                    }
                }
            }
        }
    }

    // Resolve SSID from active WiFi connection UUID when scans don't mark any row as ACTIVE.
    Process {
        id: resolveWifiSSID
        command: root.wifiConnectionUuid ? ["nmcli", "-g", "802-11-wireless.ssid", "connection", "show", "uuid", root.wifiConnectionUuid] : []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const ssid = text.trim()
                if (ssid) {
                    root.currentWifiSSID = ssid
                }
            }
        }
    }

    // Fallback 2: Resolve SSID from device info (GENERAL.CONNECTION usually matches SSID for WiFi)
    Process {
        id: resolveWifiSSIDFromDevice
        command: root.wifiInterface ? ["nmcli", "-t", "-f", "GENERAL.CONNECTION", "device", "show", root.wifiInterface] : []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.currentWifiSSID) {
                    const name = text.trim()
                    if (name)
                    root.currentWifiSSID = name
                }
            }
        }
    }

    function updateWifiState() {
        checkWifiEnabled.running = true
    }

    Process {
        id: checkWifiEnabled
        command: ["gdbus", "call", "--system", "--dest", "org.freedesktop.NetworkManager", "--object-path", "/org/freedesktop/NetworkManager", "--method", "org.freedesktop.DBus.Properties.Get", "org.freedesktop.NetworkManager", "WirelessEnabled"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled = text.includes("true")
                root.wifiAvailable = true // Always available if we can check it
            }
        }
    }

    function scanWifi() {
        if (root.isScanning || !root.wifiEnabled)
            return

        root.isScanning = true
        requestWifiScan.running = true
    }

    Process {
        id: requestWifiScan
        command: root.wifiInterface ? ["nmcli", "dev", "wifi", "rescan", "ifname", root.wifiInterface] : []
        running: false

        onExited: exitCode => {
            if (exitCode === 0) {
                scanWifiNetworks()
            } else {
                console.warn("WiFi scan request failed")
                root.isScanning = false
            }
        }
    }

    function scanWifiNetworks() {
        if (!root.wifiInterface) {
            root.isScanning = false
            return
        }

        getWifiNetworks.running = true
        getSavedConnections.running = true
    }

    Process {
        id: getWifiNetworks
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,BSSID", "dev", "wifi", "list", "ifname", root.wifiInterface]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let networks = []
                const lines = text.trim().split('\n')
                const seen = new Set()

                for (const line of lines) {
                    const parts = line.split(':')
                    if (parts.length >= 4 && parts[0]) {
                        const ssid = parts[0]
                        if (!seen.has(ssid)) {
                            seen.add(ssid)
                            const signal = parseInt(parts[1]) || 0

                            networks.push({
                                              "ssid": ssid,
                                              "signal": signal,
                                              "secured": parts[2] !== "",
                                              "bssid": parts[3],
                                              "connected": ssid === root.currentWifiSSID,
                                              "saved": false // Will be updated by saved connections check
                                          })
                        }
                    }
                }

                networks.sort((a, b) => b.signal - a.signal)
                root.wifiNetworks = networks
                root.isScanning = false
                root.networksUpdated()
            }
        }
    }

    Process {
        id: getSavedConnections
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let saved = []
                const lines = text.trim().split('\n')

                for (const line of lines) {
                    const parts = line.split(':')
                    if (parts.length >= 2 && parts[1] === "802-11-wireless") {
                        saved.push({
                                       "ssid": parts[0],
                                       "saved": true
                                   })
                    }
                }

                root.savedConnections = saved
                root.savedWifiNetworks = saved

                let updated = [...root.wifiNetworks]
                for (let network of updated) {
                    network.saved = saved.some(s => s.ssid === network.ssid)
                }
                root.wifiNetworks = updated
            }
        }
    }

    function connectToWifi(ssid, password = "") {
        if (root.isConnecting)
            return

        root.isConnecting = true
        root.connectingSSID = ssid
        root.connectionError = ""
        root.connectionStatus = "connecting"

        if (password) {
            wifiConnector.command = ["nmcli", "dev", "wifi", "connect", ssid, "password", password]
        } else {
            wifiConnector.command = ["nmcli", "dev", "wifi", "connect", ssid]
        }
        wifiConnector.running = true
    }

    function connectToWifiWithPassword(ssid, password) {
        connectToWifi(ssid, password)
    }

    Process {
        id: wifiConnector
        running: false

        property bool connectionSucceeded: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.includes("successfully")) {
                    wifiConnector.connectionSucceeded = true
                    ToastService.showInfo(`Connected to ${root.connectingSSID}`)
                    root.connectionError = ""
                    root.connectionStatus = "connected"

                    if (root.userPreference === "wifi"
                        || root.userPreference === "auto") {
                        setConnectionPriority("wifi")
                    }
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                root.connectionError = text
                root.lastConnectionError = text
                if (!wifiConnector.connectionSucceeded && text.trim() !== "") {
                    if (text.includes("password") || text.includes(
                            "authentication")) {
                        root.connectionStatus = "invalid_password"
                        root.passwordDialogShouldReopen = true
                    } else {
                        root.connectionStatus = "failed"
                    }
                }
            }
        }

        onExited: exitCode => {
            if (exitCode === 0 || wifiConnector.connectionSucceeded) {
                if (!wifiConnector.connectionSucceeded) {
                    // Command succeeded but we didn't see "successfully" - still mark as success
                    ToastService.showInfo(`Connected to ${root.connectingSSID}`)
                    root.connectionStatus = "connected"
                }
            } else {
                if (root.connectionStatus === "") {
                    root.connectionStatus = "failed"
                }
                if (root.connectionStatus === "invalid_password") {
                    ToastService.showError(
                        `Invalid password for ${root.connectingSSID}`)
                } else {
                    ToastService.showError(
                        `Failed to connect to ${root.connectingSSID}`)
                }
            }

            wifiConnector.connectionSucceeded = false
            root.isConnecting = false
            root.connectingSSID = ""
            refreshNetworkState()
        }
    }

    function disconnectWifi() {
        if (!root.wifiInterface)
            return

        wifiDisconnector.command = ["nmcli", "dev", "disconnect", root.wifiInterface]
        wifiDisconnector.running = true
    }

    Process {
        id: wifiDisconnector
        running: false

        onExited: exitCode => {
            if (exitCode === 0) {
                ToastService.showInfo("Disconnected from WiFi")
                root.currentWifiSSID = ""
                root.connectionStatus = ""
            }
            refreshNetworkState()
        }
    }

    function forgetWifiNetwork(ssid) {
        root.forgetSSID = ssid
        networkForgetter.command = ["nmcli", "connection", "delete", ssid]
        networkForgetter.running = true
    }

    Process {
        id: networkForgetter
        running: false

        onExited: exitCode => {
            if (exitCode === 0) {
                ToastService.showInfo(`Forgot network ${root.forgetSSID}`)

                root.savedConnections = root.savedConnections.filter(
                    s => s.ssid !== root.forgetSSID)
                root.savedWifiNetworks = root.savedWifiNetworks.filter(
                    s => s.ssid !== root.forgetSSID)

                let updated = [...root.wifiNetworks]
                for (let network of updated) {
                    if (network.ssid === root.forgetSSID) {
                        network.saved = false
                        if (network.connected) {
                            network.connected = false
                            root.currentWifiSSID = ""
                        }
                    }
                }
                root.wifiNetworks = updated
                root.networksUpdated()
                refreshNetworkState()
            }
            root.forgetSSID = ""
        }
    }

    function toggleWifiRadio() {
        if (root.wifiToggling)
            return

        root.wifiToggling = true
        const targetState = root.wifiEnabled ? "off" : "on"
        wifiRadioToggler.targetState = targetState
        wifiRadioToggler.command = ["nmcli", "radio", "wifi", targetState]
        wifiRadioToggler.running = true
    }

    Process {
        id: wifiRadioToggler
        running: false

        property string targetState: ""

        onExited: exitCode => {
            root.wifiToggling = false
            if (exitCode === 0) {
                // Don't manually toggle wifiEnabled - let DBus monitoring handle it
                ToastService.showInfo(
                    targetState === "on" ? "WiFi enabled" : "WiFi disabled")
            }
            refreshNetworkState()
        }
    }

    // ===== Network Preference Management =====
    function setNetworkPreference(preference) {
        root.userPreference = preference
        root.changingPreference = true
        root.targetPreference = preference
        SettingsData.setNetworkPreference(preference)

        if (preference === "wifi") {
            setConnectionPriority("wifi")
        } else if (preference === "ethernet") {
            setConnectionPriority("ethernet")
        }
        // "auto" uses default NetworkManager behavior
    }

    function setConnectionPriority(type) {
        if (type === "wifi") {
            setRouteMetrics.command = ["bash", "-c", "nmcli -t -f NAME,TYPE connection show | grep 802-11-wireless | cut -d: -f1 | " + "xargs -I {} bash -c 'nmcli connection modify \"{}\" ipv4.route-metric 50 ipv6.route-metric 50'; " + "nmcli -t -f NAME,TYPE connection show | grep 802-3-ethernet | cut -d: -f1 | " + "xargs -I {} bash -c 'nmcli connection modify \"{}\" ipv4.route-metric 100 ipv6.route-metric 100'"]
        } else if (type === "ethernet") {
            setRouteMetrics.command = ["bash", "-c", "nmcli -t -f NAME,TYPE connection show | grep 802-3-ethernet | cut -d: -f1 | " + "xargs -I {} bash -c 'nmcli connection modify \"{}\" ipv4.route-metric 50 ipv6.route-metric 50'; " + "nmcli -t -f NAME,TYPE connection show | grep 802-11-wireless | cut -d: -f1 | " + "xargs -I {} bash -c 'nmcli connection modify \"{}\" ipv4.route-metric 100 ipv6.route-metric 100'"]
        }
        setRouteMetrics.running = true
    }

    Process {
        id: setRouteMetrics
        running: false

        onExited: exitCode => {
            console.log("Set route metrics process exited with code:", exitCode)
            if (exitCode === 0) {
                restartConnections.running = true
            }
        }
    }

    Process {
        id: restartConnections
        command: ["bash", "-c", "nmcli -t -f UUID,TYPE connection show --active | "
            + "grep -E '802-11-wireless|802-3-ethernet' | cut -d: -f1 | "
            + "xargs -I {} sh -c 'nmcli connection down {} && nmcli connection up {}'"]
        running: false

        onExited: {
            root.changingPreference = false
            root.targetPreference = ""
            refreshNetworkState()
        }
    }

    function startAutoScan() {
        root.autoScan = true
        root.autoRefreshEnabled = true
        if (root.wifiEnabled) {
            scanWifi()
        }
    }

    function stopAutoScan() {
        root.autoScan = false
        root.autoRefreshEnabled = false
    }

    // ===== Network Info =====
    function fetchNetworkInfo(ssid) {
        root.networkInfoSSID = ssid
        root.networkInfoLoading = true
        root.networkInfoDetails = "Loading network information..."
        wifiInfoFetcher.running = true
    }

    Process {
        id: wifiInfoFetcher
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,FREQ,RATE,MODE,CHAN,WPA-FLAGS,RSN-FLAGS,ACTIVE,BSSID", "dev", "wifi", "list"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let details = ""
                if (text.trim()) {
                    let lines = text.trim().split('\n')
                    let bands = []
                    
                    // Collect all access points for this SSID
                    for (let line of lines) {
                        let parts = line.split(':')
                        if (parts.length >= 11 && parts[0] === root.networkInfoSSID) {
                            let signal = parts[1] || "0"
                            let security = parts[2] || "Open"
                            let freq = parts[3] || "Unknown"
                            let rate = parts[4] || "Unknown"
                            let channel = parts[6] || "Unknown"
                            let isActive = parts[9] === "yes"
                            // BSSID is the last field, find it by counting colons
                            let colonCount = 0
                            let bssidStart = -1
                            for (let i = 0; i < line.length; i++) {
                                if (line[i] === ':') {
                                    colonCount++
                                    if (colonCount === 10) {
                                        bssidStart = i + 1
                                        break
                                    }
                                }
                            }
                            let bssid = bssidStart >= 0 ? line.substring(bssidStart).replace(/\\:/g, ":") : ""

                            let band = "Unknown"
                            let freqNum = parseInt(freq)
                            if (freqNum >= 2400 && freqNum <= 2500) {
                                band = "2.4 GHz"
                            } else if (freqNum >= 5000 && freqNum <= 6000) {
                                band = "5 GHz"
                            } else if (freqNum >= 6000) {
                                band = "6 GHz"
                            }

                            bands.push({
                                band: band,
                                freq: freq,
                                channel: channel,
                                signal: signal,
                                rate: rate,
                                security: security,
                                isActive: isActive,
                                bssid: bssid
                            })
                        }
                    }
                    
                    if (bands.length > 0) {
                        // Sort bands: active first, then by signal strength
                        bands.sort((a, b) => {
                            if (a.isActive && !b.isActive) return -1
                            if (!a.isActive && b.isActive) return 1
                            return parseInt(b.signal) - parseInt(a.signal)
                        })
                        
                        for (let i = 0; i < bands.length; i++) {
                            let b = bands[i]
                            if (b.isActive) {
                                details += "● " + b.band + " (Connected) - " + b.signal + "%\\n"
                            } else {
                                details += "  " + b.band + " - " + b.signal + "%\\n"
                            }
                            details += "  Channel " + b.channel + " (" + b.freq + " MHz) • " + b.rate + " Mbit/s\\n"
                            details += "  " + b.bssid
                            if (i < bands.length - 1) {
                                details += "\\n\\n"
                            }
                        }
                    }
                }

                if (details === "") {
                    details = "Network information not found or network not available."
                }

                root.networkInfoDetails = details
                root.networkInfoLoading = false
            }
        }

        onExited: exitCode => {
            root.networkInfoLoading = false
            if (exitCode !== 0) {
                root.networkInfoDetails = "Failed to fetch network information"
            }
        }
    }

    function refreshNetworkStatus() {
        refreshNetworkState()
    }

    function delayedRefreshNetworkStatus() {
        refreshNetworkState()
    }

    function updateCurrentWifiInfo() {
        getCurrentWifiInfo.running = true
    }

    function enableWifiDevice() {
        wifiDeviceEnabler.running = true
    }

    Process {
        id: wifiDeviceEnabler
        command: ["sh", "-c", "WIFI_DEV=$(nmcli -t -f DEVICE,TYPE device | grep wifi | cut -d: -f1 | head -1); if [ -n \"$WIFI_DEV\" ]; then nmcli device connect \"$WIFI_DEV\"; else echo \"No WiFi device found\"; exit 1; fi"]
        running: false

        onExited: exitCode => {
            if (exitCode === 0) {
                ToastService.showInfo("WiFi enabled")
            } else {
                ToastService.showError("Failed to enable WiFi")
            }
            refreshNetworkState()
        }
    }

    function connectToWifiAndSetPreference(ssid, password) {
        connectToWifiWithPassword(ssid, password)
        setNetworkPreference("wifi")
    }

    function toggleNetworkConnection(type) {
        if (type === "ethernet") {
            if (root.networkStatus === "ethernet") {
                ethernetDisconnector.running = true
            } else {
                ethernetConnector.running = true
            }
        }
    }

    Process {
        id: ethernetDisconnector
        command: ["sh", "-c", "nmcli device disconnect $(nmcli -t -f DEVICE,TYPE device | grep ethernet | cut -d: -f1 | head -1)"]
        running: false

        onExited: function (exitCode) {
            refreshNetworkState()
        }
    }

    Process {
        id: ethernetConnector
        command: ["sh", "-c", "ETH_DEV=$(nmcli -t -f DEVICE,TYPE device | grep ethernet | cut -d: -f1 | head -1); if [ -n \"$ETH_DEV\" ]; then nmcli device connect \"$ETH_DEV\"; else echo \"No ethernet device found\"; exit 1; fi"]
        running: false

        onExited: function (exitCode) {
            refreshNetworkState()
        }
    }

    function getNetworkInfo(ssid) {
        const network = root.wifiNetworks.find(n => n.ssid === ssid)
        if (!network)
            return null

        return {
            "ssid": network.ssid,
            "signal": network.signal,
            "secured": network.secured,
            "saved": network.saved,
            "connected": network.connected,
            "bssid": network.bssid
        }
    }
}
