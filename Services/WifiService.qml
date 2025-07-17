pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    
    property string currentWifiSSID: ""
    property string wifiSignalStrength: "excellent" // "excellent", "good", "fair", "poor"
    property var wifiNetworks: []
    property var savedWifiNetworks: []
    property bool isScanning: false
    property string connectionStatus: "" // "connecting", "connected", "failed", ""
    property string connectingSSID: ""
    
    Process {
        id: currentWifiInfo
        command: ["bash", "-c", "nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi | grep '^yes' | head -1"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    let parts = data.split(":")
                    if (parts.length >= 3 && parts[1].trim() !== "") {
                        root.currentWifiSSID = parts[1].trim()
                        let signal = parseInt(parts[2]) || 100
                        
                        if (signal >= 75) root.wifiSignalStrength = "excellent"
                        else if (signal >= 50) root.wifiSignalStrength = "good"
                        else if (signal >= 25) root.wifiSignalStrength = "fair"
                        else root.wifiSignalStrength = "poor"
                        
                        console.log("Active WiFi:", root.currentWifiSSID, "Signal:", signal + "%")
                    }
                }
            }
        }
    }
    
    Process {
        id: wifiScanner
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "dev", "wifi"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    let networks = []
                    let lines = text.trim().split('\n')
                    
                    for (let line of lines) {
                        let parts = line.split(':')
                        if (parts.length >= 3 && parts[0].trim() !== "") {
                            let ssid = parts[0].trim()
                            let signal = parseInt(parts[1]) || 0
                            let security = parts[2].trim()
                            
                            // Skip duplicates
                            if (!networks.find(n => n.ssid === ssid)) {
                                // Check if this network is saved
                                let isSaved = root.savedWifiNetworks.some(saved => saved.ssid === ssid)
                                
                                networks.push({
                                    ssid: ssid,
                                    signal: signal,
                                    secured: security !== "",
                                    connected: ssid === root.currentWifiSSID,
                                    saved: isSaved,
                                    signalStrength: signal >= 75 ? "excellent" : 
                                                   signal >= 50 ? "good" : 
                                                   signal >= 25 ? "fair" : "poor"
                                })
                            }
                        }
                    }
                    
                    // Sort by signal strength
                    networks.sort((a, b) => b.signal - a.signal)
                    root.wifiNetworks = networks
                    console.log("Found", networks.length, "WiFi networks")
                    
                    // Stop scanning once we have results
                    if (networks.length > 0) {
                        root.isScanning = false
                        fallbackTimer.stop()
                    }
                }
            }
        }
    }
    
    Process {
        id: savedWifiScanner
        command: ["nmcli", "-t", "-f", "NAME", "connection", "show"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    let saved = []
                    let lines = text.trim().split('\n')
                    
                    for (let line of lines) {
                        let connectionName = line.trim()
                        if (connectionName && 
                            !connectionName.includes("ethernet") && 
                            !connectionName.includes("lo") && 
                            !connectionName.includes("Wired") &&
                            !connectionName.toLowerCase().includes("eth")) {
                            saved.push({
                                ssid: connectionName,
                                saved: true
                            })
                        }
                    }
                    
                    root.savedWifiNetworks = saved
                    console.log("Found", saved.length, "saved WiFi networks")
                }
            }
        }
    }
    
    function scanWifi() {
        if (root.isScanning) return
        
        root.isScanning = true
        console.log("Starting WiFi scan...")
        
        wifiScanner.running = true
        savedWifiScanner.running = true
        currentWifiInfo.running = true
        
        // Fallback timer in case no networks are found
        fallbackTimer.start()
    }
    
    Timer {
        id: fallbackTimer
        interval: 5000
        onTriggered: {
            root.isScanning = false
            console.log("WiFi scan timeout - no networks found")
        }
    }
    
    function connectToWifi(ssid) {
        console.log("Connecting to WiFi:", ssid)
        
        root.connectionStatus = "connecting"
        root.connectingSSID = ssid
        
        let connectProcess = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["bash", "-c", "nmcli dev wifi connect \\"' + ssid + '\\" || nmcli connection up \\"' + ssid + '\\"; if [ $? -eq 0 ]; then nmcli connection modify \\"' + ssid + '\\" connection.autoconnect-priority 50; nmcli connection down \\"' + ssid + '\\"; nmcli connection up \\"' + ssid + '\\"; fi"]
                running: true
                onExited: (exitCode) => {
                    console.log("WiFi connection result:", exitCode)
                    if (exitCode === 0) {
                        root.connectionStatus = "connected"
                        console.log("Connected to WiFi successfully")
                        // Set user preference to WiFi when manually connecting
                        NetworkService.setNetworkPreference("wifi")
                        // Force network status refresh after successful connection
                        NetworkService.delayedRefreshNetworkStatus()
                    } else {
                        root.connectionStatus = "failed"
                        console.log("WiFi connection failed")
                    }
                    scanWifi()
                    
                    statusResetTimer.start()
                }
                
                stderr: SplitParser {
                    splitMarker: "\\n"
                    onRead: (data) => {
                        console.log("WiFi connection stderr:", data)
                    }
                }
            }
        `, root)
    }
    
    function connectToWifiWithPassword(ssid, password) {
        console.log("Connecting to WiFi with password:", ssid)
        
        root.connectionStatus = "connecting"
        root.connectingSSID = ssid
        
        let connectProcess = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["bash", "-c", "nmcli dev wifi connect \\"' + ssid + '\\" password \\"' + password + '\\"; if [ $? -eq 0 ]; then nmcli connection modify \\"' + ssid + '\\" connection.autoconnect-priority 50; nmcli connection down \\"' + ssid + '\\"; nmcli connection up \\"' + ssid + '\\"; fi"]
                running: true
                onExited: (exitCode) => {
                    console.log("WiFi connection with password result:", exitCode)
                    if (exitCode === 0) {
                        root.connectionStatus = "connected"
                        console.log("Connected to WiFi with password successfully")
                        // Set user preference to WiFi when manually connecting
                        NetworkService.setNetworkPreference("wifi")
                        // Force network status refresh after successful connection
                        NetworkService.delayedRefreshNetworkStatus()
                    } else {
                        root.connectionStatus = "failed"
                        console.log("WiFi connection with password failed")
                    }
                    scanWifi()
                    
                    statusResetTimer.start()
                }
                
                stderr: SplitParser {
                    splitMarker: "\\n"
                    onRead: (data) => {
                        console.log("WiFi connection with password stderr:", data)
                    }
                }
            }
        `, root)
    }
    
    function forgetWifiNetwork(ssid) {
        console.log("Forgetting WiFi network:", ssid)
        let forgetProcess = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["bash", "-c", "nmcli connection delete \\"' + ssid + '\\" || nmcli connection delete id \\"' + ssid + '\\""]
                running: true
                onExited: (exitCode) => {
                    console.log("WiFi forget result:", exitCode)
                    if (exitCode === 0) {
                        console.log("Successfully forgot WiFi network:", "' + ssid + '")
                    } else {
                        console.log("Failed to forget WiFi network:", "' + ssid + '")
                    }
                    scanWifi()
                }
                
                stderr: SplitParser {
                    splitMarker: "\\n"
                    onRead: (data) => {
                        console.log("WiFi forget stderr:", data)
                    }
                }
            }
        `, root)
    }
    
    Timer {
        id: statusResetTimer
        interval: 3000
        onTriggered: {
            root.connectionStatus = ""
            root.connectingSSID = ""
        }
    }
    
    // Auto-refresh timer for when control center is open
    property bool autoRefreshEnabled: false
    
    Timer {
        id: autoRefreshTimer
        interval: 20000
        running: root.autoRefreshEnabled
        repeat: true
        onTriggered: {
            if (root.autoRefreshEnabled) {
                root.scanWifi()
            }
        }
    }
    
    function updateCurrentWifiInfo() {
        console.log("Updating current WiFi info...")
        currentWifiInfo.running = true
    }
}