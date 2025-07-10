import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    property string currentWifiSSID: ""
    property string wifiSignalStrength: "excellent" // "excellent", "good", "fair", "poor"
    property var wifiNetworks: []
    property var savedWifiNetworks: []
    
    Process {
        id: currentWifiInfo
        command: ["bash", "-c", "nmcli -t -f ssid,signal connection show --active | grep -v '^--' | grep -v '^$'"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    let parts = data.split(":")
                    if (parts.length >= 2 && parts[0].trim() !== "") {
                        root.currentWifiSSID = parts[0].trim()
                        let signal = parseInt(parts[1]) || 100
                        
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
                                networks.push({
                                    ssid: ssid,
                                    signal: signal,
                                    secured: security !== "",
                                    connected: ssid === root.currentWifiSSID,
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
                        if (line.trim() && !line.includes("ethernet") && !line.includes("lo")) {
                            saved.push({
                                ssid: line.trim(),
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
        wifiScanner.running = true
        savedWifiScanner.running = true
        currentWifiInfo.running = true
    }
    
    function connectToWifi(ssid) {
        console.log("Connecting to WiFi:", ssid)
        
        let connectProcess = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["nmcli", "dev", "wifi", "connect", "' + ssid + '"]
                running: true
                onExited: (exitCode) => {
                    console.log("WiFi connection result:", exitCode)
                    if (exitCode === 0) {
                        console.log("Connected to WiFi successfully")
                    } else {
                        console.log("WiFi connection failed")
                    }
                    scanWifi()
                }
            }
        ', root)
    }
    
    function connectToWifiWithPassword(ssid, password) {
        console.log("Connecting to WiFi with password:", ssid)
        
        let connectProcess = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["nmcli", "dev", "wifi", "connect", "' + ssid + '", "password", "' + password + '"]
                running: true
                onExited: (exitCode) => {
                    console.log("WiFi connection with password result:", exitCode)
                    if (exitCode === 0) {
                        console.log("Connected to WiFi with password successfully")
                    } else {
                        console.log("WiFi connection with password failed")
                    }
                    scanWifi()
                }
            }
        ', root)
    }
    
    function forgetWifiNetwork(ssid) {
        console.log("Forgetting WiFi network:", ssid)
        let forgetProcess = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["nmcli", "connection", "delete", "' + ssid + '"]
                running: true
                onExited: (exitCode) => {
                    console.log("WiFi forget result:", exitCode)
                    scanWifi()
                }
            }
        ', root)
    }
}