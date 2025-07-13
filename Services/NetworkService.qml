import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    property string networkStatus: "disconnected" // "ethernet", "wifi", "disconnected"
    property string ethernetIP: ""
    property string ethernetInterface: ""
    property string wifiIP: ""
    property bool wifiAvailable: false
    property bool wifiEnabled: true
    
    // Real Network Management
    Process {
        id: networkStatusChecker
        command: ["bash", "-c", "nmcli -t -f DEVICE,TYPE,STATE device | grep -E '(ethernet|wifi)' && echo '---' && ip link show | grep -E '^[0-9]+:.*ethernet.*state UP'"]
        running: true
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    console.log("Network status full output:", text.trim())
                    
                    let hasEthernet = text.includes("ethernet:connected")
                    let hasWifi = text.includes("wifi:connected")
                    let ethernetCableUp = text.includes("state UP")
                    
                    // Check if ethernet cable is physically connected but not managed
                    if (hasEthernet || ethernetCableUp) {
                        root.networkStatus = "ethernet"
                        ethernetIPChecker.running = true
                        console.log("Setting network status to ethernet (cable connected)")
                    } else if (hasWifi) {
                        root.networkStatus = "wifi"
                        wifiIPChecker.running = true
                        console.log("Setting network status to wifi")
                    } else {
                        root.networkStatus = "disconnected"
                        root.ethernetIP = ""
                        root.ethernetInterface = ""
                        root.wifiIP = ""
                        console.log("Setting network status to disconnected")
                    }
                    
                    // Always check WiFi radio status
                    wifiRadioChecker.running = true
                } else {
                    root.networkStatus = "disconnected"
                    root.ethernetIP = ""
                    root.ethernetInterface = ""
                    root.wifiIP = ""
                    console.log("No network output, setting to disconnected")
                }
            }
        }
    }
    
    Process {
        id: wifiRadioChecker
        command: ["nmcli", "radio", "wifi"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                let response = data.trim()
                root.wifiAvailable = response === "enabled" || response === "disabled"
                root.wifiEnabled = response === "enabled"
                console.log("WiFi available:", root.wifiAvailable, "enabled:", root.wifiEnabled)
            }
        }
    }
    
    Process {
        id: ethernetIPChecker
        command: ["bash", "-c", "ip route get 1.1.1.1 | grep -oP '(dev \\K\\S+|src \\K\\S+)' | tr '\\n' ' '"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    const parts = data.trim().split(' ')
                    if (parts.length >= 2) {
                        root.ethernetInterface = parts[0]
                        root.ethernetIP = parts[1]
                        console.log("Ethernet Interface:", root.ethernetInterface, "IP:", root.ethernetIP)
                    } else if (parts.length === 1) {
                        // Fallback if only IP is found
                        root.ethernetIP = parts[0]
                        console.log("Ethernet IP:", root.ethernetIP)
                    }
                }
            }
        }
    }
    
    Process {
        id: wifiIPChecker
        command: ["bash", "-c", "nmcli -t -f IP4.ADDRESS dev show $(nmcli -t -f DEVICE,TYPE device | grep wifi | cut -d: -f1 | head -1) | cut -d: -f2 | cut -d/ -f1"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    root.wifiIP = data.trim()
                    console.log("WiFi IP:", root.wifiIP)
                }
            }
        }
    }
    
    function toggleNetworkConnection(type) {
        if (type === "ethernet") {
            // Toggle ethernet connection
            if (root.networkStatus === "ethernet") {
                // Disconnect ethernet
                let disconnectProcess = Qt.createQmlObject('
                    import Quickshell.Io
                    Process {
                        command: ["bash", "-c", "nmcli device disconnect $(nmcli -t -f DEVICE,TYPE device | grep ethernet | cut -d: -f1 | head -1)"]
                        running: true
                        onExited: networkStatusChecker.running = true
                    }
                ', root)
            } else {
                // Connect ethernet with proper nmcli device connect
                let connectProcess = Qt.createQmlObject('
                    import Quickshell.Io
                    Process {
                        command: ["bash", "-c", "nmcli device connect $(nmcli -t -f DEVICE,TYPE device | grep ethernet | cut -d: -f1 | head -1)"]
                        running: true
                        onExited: networkStatusChecker.running = true
                    }
                ', root)
            }
        } else if (type === "wifi") {
            // Connect to WiFi if disconnected
            if (root.networkStatus !== "wifi" && root.wifiEnabled) {
                let connectProcess = Qt.createQmlObject('
                    import Quickshell.Io
                    Process {
                        command: ["bash", "-c", "nmcli device connect $(nmcli -t -f DEVICE,TYPE device | grep wifi | cut -d: -f1 | head -1)"]
                        running: true
                        onExited: networkStatusChecker.running = true
                    }
                ', root)
            }
        }
    }
    
    function toggleWifiRadio() {
        let action = root.wifiEnabled ? "off" : "on"
        let toggleProcess = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["nmcli", "radio", "wifi", "' + action + '"]
                running: true
                onExited: {
                    networkStatusChecker.running = true
                }
            }
        ', root)
    }
}