import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    property string networkStatus: "disconnected" // "ethernet", "wifi", "disconnected"
    property string ethernetIP: ""
    property string ethernetInterface: ""
    property bool ethernetConnected: false
    property string wifiIP: ""
    property bool wifiAvailable: false
    property bool wifiEnabled: true
    property bool wifiToggling: false
    property string userPreference: "auto" // "auto", "wifi", "ethernet"
    property bool changingPreference: false
    property string targetPreference: "" // Track what preference we're switching to
    
    // Load saved preference on startup
    Component.onCompleted: {
        // Load preference from Prefs system
        root.userPreference = Prefs.networkPreference
        console.log("NetworkService: Loaded network preference from Prefs:", root.userPreference)
        
        // Trigger immediate WiFi info update if WiFi is connected and enabled
        if (root.networkStatus === "wifi" && root.wifiEnabled) {
            WifiService.updateCurrentWifiInfo()
        }
    }
    
    // Real Network Management
    Process {
        id: networkStatusChecker
        command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE,STATE device | grep -E '(ethernet|wifi)' && echo '---' && ip link show | grep -E '^[0-9]+:.*ethernet.*state UP'"]
        running: true
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    console.log("Network status full output:", text.trim())
                    
                    let hasEthernet = text.includes("ethernet:connected")
                    let hasWifi = text.includes("wifi:connected")
                    let ethernetCableUp = text.includes("state UP")
                    
                    // Update connection status properties
                    root.ethernetConnected = hasEthernet || ethernetCableUp
                    
                    // Always check both IPs when available
                    if (hasWifi) {
                        wifiIPChecker.running = true
                    }
                    if (hasEthernet || ethernetCableUp) {
                        ethernetIPChecker.running = true
                    }
                    
                    // Check connection priorities when both are active
                    if (hasWifi && hasEthernet) {
                        console.log("Both WiFi and Ethernet connected, user preference:", root.userPreference)
                        
                        // Use user preference if set, otherwise check default route
                        if (root.userPreference === "wifi") {
                            root.networkStatus = "wifi"
                            console.log("User prefers WiFi, setting status to wifi")
                            if (root.wifiEnabled) {
                                WifiService.updateCurrentWifiInfo()
                            }
                        } else if (root.userPreference === "ethernet") {
                            root.networkStatus = "ethernet"
                            console.log("User prefers Ethernet, setting status to ethernet")
                        } else {
                            // Auto mode - check which interface has the default route
                            let priorityChecker = Qt.createQmlObject(`
                                import Quickshell.Io
                                Process {
                                    command: ["sh", "-c", "ip route show default | head -1 | cut -d\\\" \\\" -f5"]
                                    running: true
                                    stdout: SplitParser {
                                        splitMarker: "\\n"
                                        onRead: function(data) {
                                            let defaultInterface = data.trim()
                                            console.log("Default route interface:", defaultInterface)
                                            // Check if the interface is wifi or ethernet
                                            if (defaultInterface.startsWith("wl") || defaultInterface.includes("wifi")) {
                                                root.networkStatus = "wifi"
                                                console.log("WiFi interface has default route, setting status to wifi")
                                                // Trigger WiFi SSID update
                                                if (root.wifiEnabled) {
                                                    WifiService.updateCurrentWifiInfo()
                                                }
                                            } else if (defaultInterface.startsWith("en") || defaultInterface.includes("eth")) {
                                                root.networkStatus = "ethernet"
                                                console.log("Ethernet interface has default route, setting status to ethernet")
                                            } else {
                                                root.networkStatus = "disconnected"
                                                console.log("Unknown interface type:", defaultInterface)
                                            }
                                        }
                                    }
                                }
                            `, root)
                        }
                    } else if (hasWifi) {
                        root.networkStatus = "wifi"
                        console.log("Only WiFi connected, setting status to wifi")
                        // Trigger WiFi SSID update
                        if (root.wifiEnabled) {
                            WifiService.updateCurrentWifiInfo()
                        }
                    } else if (hasEthernet || ethernetCableUp) {
                        root.networkStatus = "ethernet"
                        console.log("Only Ethernet connected, setting status to ethernet")
                    } else {
                        root.networkStatus = "disconnected"
                        root.ethernetIP = ""
                        root.ethernetInterface = ""
                        root.ethernetConnected = false
                        root.wifiIP = ""
                        console.log("Setting network status to disconnected")
                    }
                    
                    // Check if we're done changing preferences
                    if (root.changingPreference && root.targetPreference !== "") {
                        let preferenceComplete = false
                        
                        if (root.targetPreference === "wifi" && root.networkStatus === "wifi") {
                            preferenceComplete = true
                            console.log("WiFi preference change complete - network is now using WiFi")
                        } else if (root.targetPreference === "ethernet" && root.networkStatus === "ethernet") {
                            preferenceComplete = true
                            console.log("Ethernet preference change complete - network is now using Ethernet")
                        }
                        
                        if (preferenceComplete) {
                            root.changingPreference = false
                            root.targetPreference = ""
                            preferenceTimeoutTimer.stop()
                            console.log("Network preference change completed successfully")
                        }
                    }
                    
                    // Always check WiFi radio status
                    wifiRadioChecker.running = true
                } else {
                    root.networkStatus = "disconnected"
                    root.ethernetIP = ""
                    root.ethernetInterface = ""
                    root.ethernetConnected = false
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
            onRead: function(data) {
                let response = data.trim()
                root.wifiAvailable = response === "enabled" || response === "disabled"
                root.wifiEnabled = response === "enabled"
                console.log("WiFi available:", root.wifiAvailable, "enabled:", root.wifiEnabled)
            }
        }
    }
    
    Process {
        id: ethernetIPChecker
        command: ["sh", "-c", "ETH_DEV=$(nmcli -t -f DEVICE,TYPE device | grep ethernet | grep connected | cut -d: -f1 | head -1); if [ -n \"$ETH_DEV\" ]; then nmcli -t -f IP4.ADDRESS dev show \"$ETH_DEV\" | cut -d: -f2 | cut -d/ -f1 | head -1; fi"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(data) {
                if (data.trim()) {
                    root.ethernetIP = data.trim()
                    console.log("Ethernet IP:", root.ethernetIP)
                    
                    // Get the ethernet interface name
                    let ethInterfaceProcess = Qt.createQmlObject(`
                        import Quickshell.Io
                        Process {
                            command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE device | grep ethernet | grep connected | cut -d: -f1 | head -1"]
                            running: true
                            stdout: SplitParser {
                                splitMarker: "\\n"
                                onRead: function(interfaceData) {
                                    if (interfaceData.trim()) {
                                        root.ethernetInterface = interfaceData.trim()
                                        console.log("Ethernet Interface:", root.ethernetInterface)
                                        
                                        // Ethernet interface detected - status will be determined by route checking
                                        console.log("Ethernet interface detected:", root.ethernetInterface)
                                    }
                                }
                            }
                        }
                    `, root)
                } else {
                    console.log("No ethernet IP found")
                    root.ethernetIP = ""
                    root.ethernetInterface = ""
                }
            }
        }
    }
    
    Process {
        id: wifiIPChecker
        command: ["sh", "-c", "WIFI_DEV=$(nmcli -t -f DEVICE,TYPE device | grep wifi | grep connected | cut -d: -f1 | head -1); if [ -n \"$WIFI_DEV\" ]; then nmcli -t -f IP4.ADDRESS dev show \"$WIFI_DEV\" | cut -d: -f2 | cut -d/ -f1 | head -1; fi"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(data) {
                if (data.trim()) {
                    root.wifiIP = data.trim()
                    console.log("WiFi IP:", root.wifiIP)
                    
                    // WiFi IP detected - status will be determined by route checking
                    console.log("WiFi has IP:", root.wifiIP)
                } else {
                    console.log("No WiFi IP found")
                    root.wifiIP = ""
                }
            }
        }
    }
    
    function toggleNetworkConnection(type) {
        if (type === "ethernet") {
            // Toggle ethernet connection
            if (root.networkStatus === "ethernet") {
                // Disconnect ethernet
                console.log("Disconnecting ethernet...")
                let disconnectProcess = Qt.createQmlObject(`
                    import Quickshell.Io
                    Process {
                        command: ["sh", "-c", "nmcli device disconnect $(nmcli -t -f DEVICE,TYPE device | grep ethernet | cut -d: -f1 | head -1)"]
                        running: true
                        onExited: function(exitCode) {
                            console.log("Ethernet disconnect result:", exitCode)
                            delayedRefreshNetworkStatus()
                        }
                        stderr: SplitParser {
                            splitMarker: "\\n"
                            onRead: function(data) {
                                console.log("Ethernet disconnect stderr:", data)
                            }
                        }
                    }
                `, root)
            } else {
                // Connect ethernet and set higher priority
                console.log("Connecting ethernet...")
                let connectProcess = Qt.createQmlObject(`
                    import Quickshell.Io
                    Process {
                        command: ["sh", "-c", "ETH_DEV=$(nmcli -t -f DEVICE,TYPE device | grep ethernet | cut -d: -f1 | head -1); if [ -n \\"$ETH_DEV\\" ]; then nmcli device connect \\"$ETH_DEV\\"; ETH_CONN=$(nmcli -t -f NAME,DEVICE connection show --active | grep \\"$ETH_DEV\\" | cut -d: -f1); if [ -n \\"$ETH_CONN\\" ]; then nmcli connection modify \\"$ETH_CONN\\" connection.autoconnect-priority 100; nmcli connection down \\"$ETH_CONN\\"; nmcli connection up \\"$ETH_CONN\\"; fi; else echo \\"No ethernet device found\\"; exit 1; fi"]
                        running: true
                        onExited: function(exitCode) {
                            console.log("Ethernet connect result:", exitCode)
                            if (exitCode === 0) {
                                console.log("Ethernet connected successfully with higher priority")
                            } else {
                                console.log("Ethernet connection failed")
                            }
                            delayedRefreshNetworkStatus()
                        }
                        stderr: SplitParser {
                            splitMarker: "\\n"
                            onRead: function(data) {
                                console.log("Ethernet connect stderr:", data)
                            }
                        }
                    }
                `, root)
            }
        } else if (type === "wifi") {
            // Connect to WiFi if disconnected
            if (root.networkStatus !== "wifi" && root.wifiEnabled) {
                console.log("Connecting to WiFi device...")
                let connectProcess = Qt.createQmlObject(`
                    import Quickshell.Io
                    Process {
                        command: ["sh", "-c", "WIFI_DEV=$(nmcli -t -f DEVICE,TYPE device | grep wifi | cut -d: -f1 | head -1); if [ -n \\"$WIFI_DEV\\" ]; then nmcli device connect \\"$WIFI_DEV\\"; else echo \\"No WiFi device found\\"; exit 1; fi"]
                        running: true
                        onExited: function(exitCode) {
                            console.log("WiFi device connect result:", exitCode)
                            delayedRefreshNetworkStatus()
                        }
                        stderr: SplitParser {
                            splitMarker: "\\n"
                            onRead: function(data) {
                                console.log("WiFi device connect stderr:", data)
                            }
                        }
                    }
                `, root)
            }
        }
    }
    
    function switchToWifi() {
        console.log("Switching to WiFi")
        // Disconnect ethernet first, then try to connect to a known WiFi network
        let switchProcess = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["sh", "-c", "ETH_DEV=$(nmcli -t -f DEVICE,TYPE device | grep ethernet | cut -d: -f1 | head -1); WIFI_DEV=$(nmcli -t -f DEVICE,TYPE device | grep wifi | cut -d: -f1 | head -1); [ -n \\"$ETH_DEV\\" ] && nmcli device disconnect \\"$ETH_DEV\\" 2>/dev/null; [ -n \\"$WIFI_DEV\\" ] && nmcli device connect \\"$WIFI_DEV\\" 2>/dev/null || true"]
                running: true
                onExited: function(exitCode) {
                    console.log("Switch to wifi result:", exitCode)
                    delayedRefreshNetworkStatus()
                }
                stderr: SplitParser {
                    splitMarker: "\\n"
                    onRead: function(data) {
                        console.log("Switch to wifi stderr:", data)
                    }
                }
            }
        `, root)
    }
    
    function switchToEthernet() {
        console.log("Switching to Ethernet")
        // Disconnect WiFi first, then connect ethernet
        let switchProcess = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["sh", "-c", "WIFI_DEV=$(nmcli -t -f DEVICE,TYPE device | grep wifi | cut -d: -f1 | head -1); ETH_DEV=$(nmcli -t -f DEVICE,TYPE device | grep ethernet | cut -d: -f1 | head -1); [ -n \\"$WIFI_DEV\\" ] && nmcli device disconnect \\"$WIFI_DEV\\" 2>/dev/null; [ -n \\"$ETH_DEV\\" ] && nmcli device connect \\"$ETH_DEV\\" 2>/dev/null || true"]
                running: true
                onExited: function(exitCode) {
                    console.log("Switch to ethernet result:", exitCode)
                    delayedRefreshNetworkStatus()
                }
                stderr: SplitParser {
                    splitMarker: "\\n"
                    onRead: function(data) {
                        console.log("Switch to ethernet stderr:", data)
                    }
                }
            }
        `, root)
    }
    
    function toggleWifiRadio() {
        if (root.wifiToggling) return
        
        root.wifiToggling = true
        let action = root.wifiEnabled ? "off" : "on"
        let toggleProcess = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["nmcli", "radio", "wifi", "${action}"]
                running: true
                onExited: {
                    root.wifiToggling = false
                    networkStatusChecker.running = true
                }
            }
        `, root)
    }
    
    function refreshNetworkStatus() {
        console.log("Refreshing network status...")
        networkStatusChecker.running = true
    }
    
    function delayedRefreshNetworkStatus() {
        console.log("Delayed network status refresh...")
        refreshTimer.start()
    }
    
    Timer {
        id: refreshTimer
        interval: 1000
        onTriggered: {
            refreshNetworkStatus()
        }
    }
    
    Timer {
        id: preferenceTimeoutTimer
        interval: 15000 // 15 seconds timeout
        onTriggered: {
            console.log("Network preference change timeout - resetting changingPreference state")
            root.changingPreference = false
            root.targetPreference = ""
        }
    }
    
    function setNetworkPreference(preference) {
        console.log("Setting network preference to:", preference)
        root.userPreference = preference
        root.changingPreference = true
        root.targetPreference = preference
        preferenceTimeoutTimer.start()
        Prefs.setNetworkPreference(preference)
        
        if (preference === "wifi") {
            // Set WiFi to low route metric (high priority), ethernet to high route metric (low priority)
            let wifiPriorityProcess = Qt.createQmlObject(`
                import Quickshell.Io
                Process {
                    command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show | grep 802-11-wireless | cut -d: -f1 | while read conn; do nmcli connection modify \\\\\\"$conn\\\\\\" ipv4.route-metric 50; done; nmcli -t -f NAME,TYPE connection show | grep 802-3-ethernet | cut -d: -f1 | while read conn; do nmcli connection modify \\\\\\"$conn\\\\\\" ipv4.route-metric 200; done; nmcli -t -f NAME,TYPE connection show --active | grep -E \\\\\\"(802-11-wireless|802-3-ethernet)\\\\\\" | cut -d: -f1 | while read conn; do nmcli connection down \\\\\\"$conn\\\\\\" && nmcli connection up \\\\\\"$conn\\\\\\"; done"]
                    running: true
                    onExited: function(exitCode) {
                        console.log("WiFi route metric set to 50, ethernet to 200, connections restarted, exit code:", exitCode)
                        // Don't reset changingPreference here - let network status check handle it
                        delayedRefreshNetworkStatus()
                    }
                }
            `, root)
        } else if (preference === "ethernet") {
            // Set ethernet to low route metric (high priority), WiFi to high route metric (low priority)
            let ethernetPriorityProcess = Qt.createQmlObject(`
                import Quickshell.Io
                Process {
                    command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show | grep 802-3-ethernet | cut -d: -f1 | while read conn; do nmcli connection modify \\\\\\"$conn\\\\\\" ipv4.route-metric 50; done; nmcli -t -f NAME,TYPE connection show | grep 802-11-wireless | cut -d: -f1 | while read conn; do nmcli connection modify \\\\\\"$conn\\\\\\" ipv4.route-metric 200; done; nmcli -t -f NAME,TYPE connection show --active | grep -E \\\\\\"(802-11-wireless|802-3-ethernet)\\\\\\" | cut -d: -f1 | while read conn; do nmcli connection down \\\\\\"$conn\\\\\\" && nmcli connection up \\\\\\"$conn\\\\\\"; done"]
                    running: true
                    onExited: function(exitCode) {
                        console.log("Ethernet route metric set to 50, WiFi to 200, connections restarted, exit code:", exitCode)
                        // Don't reset changingPreference here - let network status check handle it
                        delayedRefreshNetworkStatus()
                    }
                }
            `, root)
        }
    }
    
    
    function connectToWifiAndSetPreference(ssid, password) {
        console.log("Connecting to WiFi and setting preference:", ssid)
        if (!root.wifiEnabled) {
            console.log("WiFi is disabled, cannot connect to network")
            return
        }
        root.userPreference = "wifi"
        Prefs.setNetworkPreference("wifi")
        WifiService.connectToWifiWithPassword(ssid, password)
    }
}