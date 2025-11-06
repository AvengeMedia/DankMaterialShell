pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property bool isActive: false
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
    property var ssidToConnectionName: {

    }
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

    property string userPreference: "auto" // "auto", "wifi", "ethernet"
    property bool isConnecting: false
    property string connectingSSID: ""
    property string connectionError: ""

    property bool isScanning: false
    property bool wifiAvailable: true
    property bool wifiToggling: false
    property bool changingPreference: false
    property string targetPreference: ""
    property var savedWifiNetworks: []
    property string connectionStatus: ""
    property string lastConnectionError: ""
    property bool passwordDialogShouldReopen: false
    property string wifiPassword: ""
    property string forgetSSID: ""

    readonly property var lowPriorityCmd: ["nice", "-n", "19", "ionice", "-c3"]

    property string networkInfoSSID: ""
    property string networkInfoDetails: ""
    property bool networkInfoLoading: false

    property string networkWiredInfoUUID: ""
    property string networkWiredInfoDetails: ""
    property bool networkWiredInfoLoading: false

    signal networksUpdated
    signal connectionChanged

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

    Component.onCompleted: {
        root.userPreference = SettingsData.networkPreference
    }

    function activate() {
        if (!isActive) {
            isActive = true
            console.info("LegacyNetworkService: Activating...")
            doRefreshNetworkState()
        }
    }


    function doRefreshNetworkState() {
        updatePrimaryConnection()
        updateDeviceStates()
        updateActiveConnections()
        updateWifiState()
    }

    function updatePrimaryConnection() {
        primaryConnectionQuery.running = true
    }

    Process {
        id: primaryConnectionQuery
        command: lowPriorityCmd.concat(["gdbus", "call", "--system", "--dest", "org.freedesktop.NetworkManager", "--object-path", "/org/freedesktop/NetworkManager", "--method", "org.freedesktop.DBus.Properties.Get", "org.freedesktop.NetworkManager", "PrimaryConnection"])
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
        command: root.primaryConnection ? lowPriorityCmd.concat(["gdbus", "call", "--system", "--dest", "org.freedesktop.NetworkManager", "--object-path", root.primaryConnection, "--method", "org.freedesktop.DBus.Properties.Get", "org.freedesktop.NetworkManager.Connection.Active", "Type"]) : []
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
        command: lowPriorityCmd.concat(["nmcli", "-t", "-f", "DEVICE,TYPE", "device"])
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
                    getEthernetDevicePath.command = lowPriorityCmd.concat(["gdbus", "call", "--system", "--dest", "org.freedesktop.NetworkManager", "--object-path", "/org/freedesktop/NetworkManager", "--method", "org.freedesktop.NetworkManager.GetDeviceByIpIface", ethernetInterface])
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
                    checkEthernetState.command = lowPriorityCmd.concat(["gdbus", "call", "--system", "--dest", "org.freedesktop.NetworkManager", "--object-path", match[1], "--method", "org.freedesktop.DBus.Properties.Get", "org.freedesktop.NetworkManager.Device", "State"])
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
                }
            }
        }
    }

    Process {
        id: getEthernetIP
        command: root.ethernetInterface ? lowPriorityCmd.concat(["ip", "-4", "addr", "show", root.ethernetInterface]) : []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/inet (\d+\.\d+\.\d+\.\d+)/)
                if (match) {
                    root.ethernetIP = match[1]
                }
            }
        }
    }

    Process {
        id: getWifiDevice
        command: lowPriorityCmd.concat(["nmcli", "-t", "-f", "DEVICE,TYPE", "device"])
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
                    getWifiDevicePath.command = lowPriorityCmd.concat(["gdbus", "call", "--system", "--dest", "org.freedesktop.NetworkManager", "--object-path", "/org/freedesktop/NetworkManager", "--method", "org.freedesktop.NetworkManager.GetDeviceByIpIface", wifiInterface])
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
                    root.wifiDevicePath = match[1]
                    checkWifiState.command = lowPriorityCmd.concat(["gdbus", "call", "--system", "--dest", "org.freedesktop.NetworkManager", "--object-path", match[1], "--method", "org.freedesktop.DBus.Properties.Get", "org.freedesktop.NetworkManager.Device", "State"])
                    checkWifiState.running = true
                } else {
                    root.wifiInterface = ""
                    root.wifiConnected = false
                    root.wifiDevicePath = ""
                    root.activeAccessPointPath = ""
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
                    getActiveAccessPoint.running = true
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
                    root.activeAccessPointPath = ""
                }
            }
        }
    }

    Process {
        id: getWifiIP
        command: root.wifiInterface ? lowPriorityCmd.concat(["ip", "-4", "addr", "show", root.wifiInterface]) : []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/inet (\d+\.\d+\.\d+\.\d+)/)
                if (match) {
                    root.wifiIP = match[1]
                }
            }
        }
    }

    Process {
        id: getActiveAccessPoint
        command: root.wifiDevicePath ? lowPriorityCmd.concat(["gdbus", "call", "--system", "--dest", "org.freedesktop.NetworkManager", "--object-path", root.wifiDevicePath, "--method", "org.freedesktop.DBus.Properties.Get", "org.freedesktop.NetworkManager.Device.Wireless", "ActiveAccessPoint"]) : []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/objectpath '([^']+)'/)
                if (match && match[1] !== '/') {
                    root.activeAccessPointPath = match[1]
                } else {
                    root.activeAccessPointPath = ""
                }
            }
        }
    }

    Process {
        id: getCurrentWifiInfo
        command: root.wifiInterface ? lowPriorityCmd.concat(["nmcli", "-t", "-f", "ACTIVE,SIGNAL,SSID", "device", "wifi", "list", "ifname", root.wifiInterface, "--rescan", "no"]) : []
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (line.startsWith("yes:")) {
                    const rest = line.substring(4)
                    const parts = root.splitNmcliFields(rest)
                    if (parts.length >= 2) {
                        const signal = parseInt(parts[0])
                        console.log("Current WiFi signal strength:", signal)
                        root.wifiSignalStrength = isNaN(signal) ? 0 : signal
                        root.currentWifiSSID = parts[1]
                        console.log("Current WiFi SSID:", root.currentWifiSSID)
                    }
                    return
                }
            }
        }
    }

    function updateActiveConnections() {
        getActiveConnections.running = true
    }

    Process {
        id: getActiveConnections
        command: lowPriorityCmd.concat(["nmcli", "-t", "-f", "UUID,TYPE,DEVICE,STATE", "connection", "show", "--active"])
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
                        if (type === "802-3-ethernet" && state === "activated") {
                            root.ethernetConnectionUuid = uuid
                        } else if (type === "802-11-wireless" && state === "activated") {
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
        command: root.wifiConnectionUuid ? lowPriorityCmd.concat(["nmcli", "-g", "802-11-wireless.ssid", "connection", "show", "uuid", root.wifiConnectionUuid]) : []
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
        command: root.wifiInterface ? lowPriorityCmd.concat(["nmcli", "-t", "-f", "GENERAL.CONNECTION", "device", "show", root.wifiInterface]) : []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.currentWifiSSID) {
                    const name = text.trim()
                    if (name) {
                        root.currentWifiSSID = name
                    }
                }
            }
        }
    }

    function updateWifiState() {
        checkWifiEnabled.running = true
    }

    Process {
        id: checkWifiEnabled
        command: lowPriorityCmd.concat(["gdbus", "call", "--system", "--dest", "org.freedesktop.NetworkManager", "--object-path", "/org/freedesktop/NetworkManager", "--method", "org.freedesktop.DBus.Properties.Get", "org.freedesktop.NetworkManager", "WirelessEnabled"])
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled = text.includes("true")
                root.wifiAvailable = true // Always available if we can check it
            }
        }
    }

    function scanWifi() {
        if (root.isScanning || !root.wifiEnabled) {
            return
        }

        root.isScanning = true
        requestWifiScan.running = true
    }

    Process {
        id: requestWifiScan
        command: root.wifiInterface ? lowPriorityCmd.concat(["nmcli", "dev", "wifi", "rescan", "ifname", root.wifiInterface]) : []
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
        command: lowPriorityCmd.concat(["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,BSSID", "dev", "wifi", "list", "ifname", root.wifiInterface])
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const networks = []
                const lines = text.trim().split('\n')
                const seen = new Set()

                for (const line of lines) {
                    const parts = root.splitNmcliFields(line)
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
                                              "saved": false
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
        command: lowPriorityCmd.concat(["bash", "-c", "nmcli -t -f NAME,TYPE connection show | grep ':802-11-wireless$' | cut -d: -f1 | while read name; do ssid=$(nmcli -g 802-11-wireless.ssid connection show \"$name\"); echo \"$ssid:$name\"; done"])
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const saved = []
                const mapping = {}
                const lines = text.trim().split('\n')

                for (const line of lines) {
                    const parts = line.trim().split(':')
                    if (parts.length >= 2) {
                        const ssid = parts[0]
                        const connectionName = parts[1]
                        if (ssid && ssid.length > 0 && connectionName && connectionName.length > 0) {
                            saved.push({
                                           "ssid": ssid,
                                           "saved": true
                                       })
                            mapping[ssid] = connectionName
                        }
                    }
                }

                root.savedConnections = saved
                root.savedWifiNetworks = saved
                root.ssidToConnectionName = mapping

                const updated = [...root.wifiNetworks]
                for (const network of updated) {
                    network.saved = saved.some(s => s.ssid === network.ssid)
                }
                root.wifiNetworks = updated
            }
        }
    }

    function connectToWifi(ssid, password = "", username = "") {
        if (root.isConnecting) {
            return
        }

        root.isConnecting = true
        root.connectingSSID = ssid
        root.connectionError = ""
        root.connectionStatus = "connecting"

        if (!password && root.ssidToConnectionName[ssid]) {
            const connectionName = root.ssidToConnectionName[ssid]
            wifiConnector.command = lowPriorityCmd.concat(["nmcli", "connection", "up", connectionName])
        } else if (password) {
            wifiConnector.command = lowPriorityCmd.concat(["nmcli", "dev", "wifi", "connect", ssid, "password", password])
        } else {
            wifiConnector.command = lowPriorityCmd.concat(["nmcli", "dev", "wifi", "connect", ssid])
        }
        wifiConnector.running = true
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

                    if (root.userPreference === "wifi" || root.userPreference === "auto") {
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
                    if (text.includes("password") || text.includes("authentication")) {
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
                    ToastService.showInfo(`Connected to ${root.connectingSSID}`)
                    root.connectionStatus = "connected"
                }
            } else {
                if (root.connectionStatus === "") {
                    root.connectionStatus = "failed"
                }
                if (root.connectionStatus === "invalid_password") {
                    ToastService.showError(`Invalid password for ${root.connectingSSID}`)
                } else {
                    ToastService.showError(`Failed to connect to ${root.connectingSSID}`)
                }
            }

            wifiConnector.connectionSucceeded = false
            root.isConnecting = false
            root.connectingSSID = ""
            refreshNetworkState()
        }
    }

    function disconnectWifi() {
        if (!root.wifiInterface) {
            return
        }

        wifiDisconnector.command = lowPriorityCmd.concat(["nmcli", "dev", "disconnect", root.wifiInterface])
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
        const connectionName = root.ssidToConnectionName[ssid] || ssid
        networkForgetter.command = lowPriorityCmd.concat(["nmcli", "connection", "delete", connectionName])
        networkForgetter.running = true
    }

    Process {
        id: networkForgetter
        running: false

        onExited: exitCode => {
            if (exitCode === 0) {
                ToastService.showInfo(`Forgot network ${root.forgetSSID}`)

                root.savedConnections = root.savedConnections.filter(s => s.ssid !== root.forgetSSID)
                root.savedWifiNetworks = root.savedWifiNetworks.filter(s => s.ssid !== root.forgetSSID)

                const updated = [...root.wifiNetworks]
                for (const network of updated) {
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
        if (root.wifiToggling) {
            return
        }

        root.wifiToggling = true
        const targetState = root.wifiEnabled ? "off" : "on"
        wifiRadioToggler.targetState = targetState
        wifiRadioToggler.command = lowPriorityCmd.concat(["nmcli", "radio", "wifi", targetState])
        wifiRadioToggler.running = true
    }

    Process {
        id: wifiRadioToggler
        running: false

        property string targetState: ""

        onExited: exitCode => {
            root.wifiToggling = false
            if (exitCode === 0) {
                ToastService.showInfo(targetState === "on" ? "WiFi enabled" : "WiFi disabled")
            }
            refreshNetworkState()
        }
    }

    function setNetworkPreference(preference) {
        root.userPreference = preference
        root.changingPreference = true
        root.targetPreference = preference
        SettingsData.set("networkPreference", preference)

        if (preference === "wifi") {
            setConnectionPriority("wifi")
        } else if (preference === "ethernet") {
            setConnectionPriority("ethernet")
        }
    }

    function setConnectionPriority(type) {
        if (type === "wifi") {
            setRouteMetrics.command = lowPriorityCmd.concat(["bash", "-c", "nmcli -t -f NAME,TYPE connection show | grep 802-11-wireless | cut -d: -f1 | " + "xargs -I {} bash -c 'nmcli connection modify \"{}\" ipv4.route-metric 50 ipv6.route-metric 50'; " + "nmcli -t -f NAME,TYPE connection show | grep 802-3-ethernet | cut -d: -f1 | " + "xargs -I {} bash -c 'nmcli connection modify \"{}\" ipv4.route-metric 100 ipv6.route-metric 100'"])
        } else if (type === "ethernet") {
            setRouteMetrics.command = lowPriorityCmd.concat(["bash", "-c", "nmcli -t -f NAME,TYPE connection show | grep 802-3-ethernet | cut -d: -f1 | " + "xargs -I {} bash -c 'nmcli connection modify \"{}\" ipv4.route-metric 50 ipv6.route-metric 50'; " + "nmcli -t -f NAME,TYPE connection show | grep 802-11-wireless | cut -d: -f1 | " + "xargs -I {} bash -c 'nmcli connection modify \"{}\" ipv4.route-metric 100 ipv6.route-metric 100'"])
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
        command: lowPriorityCmd.concat(["bash", "-c", "nmcli -t -f UUID,TYPE connection show --active | " + "grep -E '802-11-wireless|802-3-ethernet' | cut -d: -f1 | " + "xargs -I {} sh -c 'nmcli connection down {} && nmcli connection up {}'"])
        running: false

        onExited: {
            root.changingPreference = false
            root.targetPreference = ""
            refreshNetworkState()
        }
    }


    function fetchNetworkInfo(ssid) {
        root.networkInfoSSID = ssid
        root.networkInfoLoading = true
        root.networkInfoDetails = "Loading network information..."
        wifiInfoFetcher.running = true
    }

    Process {
        id: wifiInfoFetcher
        command: lowPriorityCmd.concat(["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,FREQ,RATE,MODE,CHAN,WPA-FLAGS,RSN-FLAGS,ACTIVE,BSSID", "dev", "wifi", "list"])
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let details = ""
                if (text.trim()) {
                    const lines = text.trim().split('\n')
                    const bands = []

                    for (const line of lines) {
                        const parts = line.split(':')
                        if (parts.length >= 11 && parts[0] === root.networkInfoSSID) {
                            const signal = parts[1] || "0"
                            const security = parts[2] || "Open"
                            const freq = parts[3] || "Unknown"
                            const rate = parts[4] || "Unknown"
                            const channel = parts[6] || "Unknown"
                            const isActive = parts[9] === "yes"
                            let colonCount = 0
                            let bssidStart = -1
                            for (var i = 0; i < line.length; i++) {
                                if (line[i] === ':') {
                                    colonCount++
                                    if (colonCount === 10) {
                                        bssidStart = i + 1
                                        break
                                    }
                                }
                            }
                            const bssid = bssidStart >= 0 ? line.substring(bssidStart).replace(/\\:/g, ":") : ""

                            let band = "Unknown"
                            const freqNum = parseInt(freq)
                            if (freqNum >= 2400 && freqNum <= 2500) {
                                band = "2.4 GHz"
                            } else if (freqNum >= 5000 && freqNum <= 6000) {
                                band = "5 GHz"
                            } else if (freqNum >= 6000) {
                                band = "6 GHz"
                            }

                            bands.push({
                                           "band": band,
                                           "freq": freq,
                                           "channel": channel,
                                           "signal": signal,
                                           "rate": rate,
                                           "security": security,
                                           "isActive": isActive,
                                           "bssid": bssid
                                       })
                        }
                    }

                    if (bands.length > 0) {
                        bands.sort((a, b) => {
                                       if (a.isActive && !b.isActive) {
                                           return -1
                                       }
                                       if (!a.isActive && b.isActive) {
                                           return 1
                                       }
                                       return parseInt(b.signal) - parseInt(a.signal)
                                   })

                        for (var i = 0; i < bands.length; i++) {
                            const b = bands[i]
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

    function enableWifiDevice() {
        wifiDeviceEnabler.running = true
    }

    Process {
        id: wifiDeviceEnabler
        command: lowPriorityCmd.concat(["sh", "-c", "WIFI_DEV=$(nmcli -t -f DEVICE,TYPE device | grep wifi | cut -d: -f1 | head -1); if [ -n \"$WIFI_DEV\" ]; then nmcli device connect \"$WIFI_DEV\"; else echo \"No WiFi device found\"; exit 1; fi"])
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
        connectToWifi(ssid, password)
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
        command: lowPriorityCmd.concat(["sh", "-c", "nmcli device disconnect $(nmcli -t -f DEVICE,TYPE device | grep ethernet | cut -d: -f1 | head -1)"])
        running: false

        onExited: function (exitCode) {
            refreshNetworkState()
        }
    }

    Process {
        id: ethernetConnector
        command: lowPriorityCmd.concat(["sh", "-c", "ETH_DEV=$(nmcli -t -f DEVICE,TYPE device | grep ethernet | cut -d: -f1 | head -1); if [ -n \"$ETH_DEV\" ]; then nmcli device connect \"$ETH_DEV\"; else echo \"No ethernet device found\"; exit 1; fi"])
        running: false

        onExited: function (exitCode) {
            refreshNetworkState()
        }
    }

    function getNetworkInfo(ssid) {
        const network = root.wifiNetworks.find(n => n.ssid === ssid)
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
}