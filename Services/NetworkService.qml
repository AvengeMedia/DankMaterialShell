pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root
    
    property int refCount: 0
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
    
    // WiFi-specific properties
    property string currentWifiSSID: ""
    property string wifiSignalStrength: "excellent" // "excellent", "good", "fair", "poor"
    property var wifiNetworks: []
    property var savedWifiNetworks: []
    property bool isScanning: false
    property string connectionStatus: "" // "connecting", "connected", "failed", "invalid_password", ""
    property string connectingSSID: ""
    property string lastConnectionError: ""
    property bool passwordDialogShouldReopen: false
    property bool autoRefreshEnabled: false
    property string wifiPassword: ""
    property string forgetSSID: ""
    
    // Network info properties
    property string networkInfoSSID: ""
    property string networkInfoDetails: ""
    property bool networkInfoLoading: false
    
    signal networksUpdated()
    
    function addRef() {
        refCount++;
        console.log("NetworkService: addRef, refCount now:", refCount);
        // Reference counting affects WiFi scanning operations only
        // Basic network status monitoring always runs
    }
    
    function removeRef() {
        refCount = Math.max(0, refCount - 1);
        console.log("NetworkService: removeRef, refCount now:", refCount);
        // Stop intensive WiFi operations when no consumers
        if (refCount === 0) {
            autoRefreshTimer.running = false;
        }
    }
    
    // Load saved preference on startup
    Component.onCompleted: {
        // Load preference from Prefs system
        root.userPreference = Prefs.networkPreference
        console.log("NetworkService: Loaded network preference from Prefs:", root.userPreference)
        
        // Trigger immediate WiFi info update if WiFi is connected and enabled
        if (root.networkStatus === "wifi" && root.wifiEnabled) {
            updateCurrentWifiInfo()
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
                                updateCurrentWifiInfo()
                            }
                        } else if (root.userPreference === "ethernet") {
                            root.networkStatus = "ethernet"
                            console.log("User prefers Ethernet, setting status to ethernet")
                        } else {
                            // Auto mode - check which interface has the default route
                            defaultRouteChecker.running = true
                        }
                    } else if (hasWifi) {
                        root.networkStatus = "wifi"
                        console.log("Only WiFi connected, setting status to wifi")
                        // Trigger WiFi SSID update
                        if (root.wifiEnabled) {
                            updateCurrentWifiInfo()
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
        id: defaultRouteChecker
        command: ["sh", "-c", "ip route show default | head -1 | cut -d' ' -f5"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(data) {
                let defaultInterface = data.trim()
                console.log("Default route interface:", defaultInterface)
                // Check if the interface is wifi or ethernet
                if (defaultInterface.startsWith("wl") || defaultInterface.includes("wifi")) {
                    root.networkStatus = "wifi"
                    console.log("WiFi interface has default route, setting status to wifi")
                    // Trigger WiFi SSID update
                    if (root.wifiEnabled) {
                        updateCurrentWifiInfo()
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
                    ethernetInterfaceChecker.running = true
                } else {
                    console.log("No ethernet IP found")
                    root.ethernetIP = ""
                    root.ethernetInterface = ""
                }
            }
        }
    }
    
    Process {
        id: ethernetInterfaceChecker
        command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE device | grep ethernet | grep connected | cut -d: -f1 | head -1"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
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
    
    // Static processes for network operations
    Process {
        id: ethernetDisconnector
        command: ["sh", "-c", "nmcli device disconnect $(nmcli -t -f DEVICE,TYPE device | grep ethernet | cut -d: -f1 | head -1)"]
        running: false
        
        onExited: function(exitCode) {
            console.log("Ethernet disconnect result:", exitCode)
            delayedRefreshNetworkStatus()
        }
        
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: function(data) {
                console.log("Ethernet disconnect stderr:", data)
            }
        }
    }
    
    Process {
        id: ethernetConnector
        command: ["sh", "-c", "ETH_DEV=$(nmcli -t -f DEVICE,TYPE device | grep ethernet | cut -d: -f1 | head -1); if [ -n \"$ETH_DEV\" ]; then nmcli device connect \"$ETH_DEV\"; ETH_CONN=$(nmcli -t -f NAME,DEVICE connection show --active | grep \"$ETH_DEV\" | cut -d: -f1); if [ -n \"$ETH_CONN\" ]; then nmcli connection modify \"$ETH_CONN\" connection.autoconnect-priority 100; nmcli connection down \"$ETH_CONN\"; nmcli connection up \"$ETH_CONN\"; fi; else echo \"No ethernet device found\"; exit 1; fi"]
        running: false
        
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
            splitMarker: "\n"
            onRead: function(data) {
                console.log("Ethernet connect stderr:", data)
            }
        }
    }
    
    
    
    Process {
        id: ethernetSwitcher
        command: ["sh", "-c", "WIFI_DEV=$(nmcli -t -f DEVICE,TYPE device | grep wifi | cut -d: -f1 | head -1); ETH_DEV=$(nmcli -t -f DEVICE,TYPE device | grep ethernet | cut -d: -f1 | head -1); [ -n \"$WIFI_DEV\" ] && nmcli device disconnect \"$WIFI_DEV\" 2>/dev/null; [ -n \"$ETH_DEV\" ] && nmcli device connect \"$ETH_DEV\" 2>/dev/null || true"]
        running: false
        
        onExited: function(exitCode) {
            console.log("Switch to ethernet result:", exitCode)
            delayedRefreshNetworkStatus()
        }
        
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: function(data) {
                console.log("Switch to ethernet stderr:", data)
            }
        }
    }
    
    Process {
        id: wifiRadioToggler
        command: ["nmcli", "radio", "wifi", root.wifiEnabled ? "off" : "on"]
        running: false
        
        onExited: {
            root.wifiToggling = false
            networkStatusChecker.running = true
        }
    }
    
    Process {
        id: wifiPriorityChanger
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show | grep 802-11-wireless | cut -d: -f1 | while read conn; do nmcli connection modify \"$conn\" ipv4.route-metric 50; done; nmcli -t -f NAME,TYPE connection show | grep 802-3-ethernet | cut -d: -f1 | while read conn; do nmcli connection modify \"$conn\" ipv4.route-metric 200; done; nmcli -t -f NAME,TYPE connection show --active | grep -E \"(802-11-wireless|802-3-ethernet)\" | cut -d: -f1 | while read conn; do nmcli connection down \"$conn\" && nmcli connection up \"$conn\"; done"]
        running: false
        
        onExited: function(exitCode) {
            console.log("WiFi route metric set to 50, ethernet to 200, connections restarted, exit code:", exitCode)
            // Don't reset changingPreference here - let network status check handle it
            delayedRefreshNetworkStatus()
        }
    }
    
    Process {
        id: ethernetPriorityChanger
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show | grep 802-3-ethernet | cut -d: -f1 | while read conn; do nmcli connection modify \"$conn\" ipv4.route-metric 50; done; nmcli -t -f NAME,TYPE connection show | grep 802-11-wireless | cut -d: -f1 | while read conn; do nmcli connection modify \"$conn\" ipv4.route-metric 200; done; nmcli -t -f NAME,TYPE connection show --active | grep -E \"(802-11-wireless|802-3-ethernet)\" | cut -d: -f1 | while read conn; do nmcli connection down \"$conn\" && nmcli connection up \"$conn\"; done"]
        running: false
        
        onExited: function(exitCode) {
            console.log("Ethernet route metric set to 50, WiFi to 200, connections restarted, exit code:", exitCode)
            // Don't reset changingPreference here - let network status check handle it
            delayedRefreshNetworkStatus()
        }
    }
    
    function toggleNetworkConnection(type) {
        if (type === "ethernet") {
            // Toggle ethernet connection
            if (root.networkStatus === "ethernet") {
                // Disconnect ethernet
                console.log("Disconnecting ethernet...")
                ethernetDisconnector.running = true
            } else {
                // Connect ethernet and set higher priority
                console.log("Connecting ethernet...")
                ethernetConnector.running = true
            }
        }
    }
    
    function toggleWifiRadio() {
        if (root.wifiToggling) return
        
        root.wifiToggling = true
        wifiRadioToggler.command = ["nmcli", "radio", "wifi", root.wifiEnabled ? "off" : "on"]
        wifiRadioToggler.running = true
    }
    
    function refreshNetworkStatus() {
        console.log("Refreshing network status...")
        networkStatusChecker.running = true
    }
    
    function delayedRefreshNetworkStatus() {
        console.log("Refreshing network status immediately...")
        refreshNetworkStatus()
    }
    
    function setNetworkPreference(preference) {
        console.log("Setting network preference to:", preference)
        root.userPreference = preference
        root.changingPreference = true
        root.targetPreference = preference
        Prefs.setNetworkPreference(preference)
        
        if (preference === "wifi") {
            // Set WiFi to low route metric (high priority), ethernet to high route metric (low priority)
            wifiPriorityChanger.running = true
        } else if (preference === "ethernet") {
            // Set ethernet to low route metric (high priority), WiFi to high route metric (low priority)
            ethernetPriorityChanger.running = true
        }
    }
    
    // WiFi-specific functions
    function scanWifi() {
        if (root.isScanning)
            return

        root.isScanning = true
        wifiScanner.running = true
        savedWifiScanner.running = true
        currentWifiInfo.running = true
        fallbackTimer.start()
    }

    function connectToWifi(ssid) {
        console.log("Connecting to WiFi:", ssid)
        root.connectionStatus = "connecting"
        root.connectingSSID = ssid
        ToastService.showInfo("Connecting to " + ssid + "...")
        wifiConnector.running = true
    }

    function connectToWifiWithPassword(ssid, password) {
        console.log("Connecting to WiFi with password:", ssid)
        root.connectionStatus = "connecting"
        root.connectingSSID = ssid
        root.wifiPassword = password
        root.lastConnectionError = ""
        root.passwordDialogShouldReopen = false
        ToastService.showInfo("Connecting to " + ssid + "...")
        wifiPasswordConnector.running = true
    }

    function disconnectWifi() {
        console.log("Disconnecting from current WiFi network")
        wifiDisconnector.running = true
    }

    function forgetWifiNetwork(ssid) {
        console.log("Forgetting WiFi network:", ssid)
        root.forgetSSID = ssid
        wifiForget.running = true
    }

    function fetchNetworkInfo(ssid) {
        console.log("Fetching network info for:", ssid)
        root.networkInfoSSID = ssid
        root.networkInfoLoading = true
        root.networkInfoDetails = "Loading network information..."
        wifiInfoFetcher.running = true
    }

    function updateCurrentWifiInfo() {
        currentWifiInfo.running = true
    }

    function enableWifiDevice() {
        console.log("Enabling WiFi device...")
        wifiDeviceEnabler.running = true
    }

    function connectToWifiAndSetPreference(ssid, password) {
        console.log("Connecting to WiFi and setting network preference:", ssid)
        connectToWifiWithPassword(ssid, password)
        setNetworkPreference("wifi")
    }

    // WiFi Process Components
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
                        if (signal >= 75)
                            root.wifiSignalStrength = "excellent"
                        else if (signal >= 50)
                            root.wifiSignalStrength = "good"
                        else if (signal >= 25)
                            root.wifiSignalStrength = "fair"
                        else
                            root.wifiSignalStrength = "poor"
                        console.log("Active WiFi:", root.currentWifiSSID, "Signal:", signal + "%")
                    }
                }
            }
        }
    }

    Timer {
        id: fallbackTimer
        interval: 5000
        onTriggered: {
            root.isScanning = false
        }
    }

    Timer {
        id: statusResetTimer
        interval: 3000
        onTriggered: {
            root.connectionStatus = ""
            root.connectingSSID = ""
        }
    }

    Timer {
        id: autoRefreshTimer
        interval: 20000
        running: root.autoRefreshEnabled && root.refCount > 0
        repeat: true
        onTriggered: scanWifi()
    }

    Process {
        id: wifiScanner

        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "dev", "wifi"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    let networks = [];
                    let lines = text.trim().split('\n');
                    for (let line of lines) {
                        let parts = line.split(':');
                        if (parts.length >= 3 && parts[0].trim() !== "") {
                            let ssid = parts[0].trim();
                            let signal = parseInt(parts[1]) || 0;
                            let security = parts[2].trim();
                            // Skip duplicates
                            if (!networks.find((n) => {
                                return n.ssid === ssid;
                            })) {
                                // Check if this network is saved
                                let isSaved = root.savedWifiNetworks.some((saved) => {
                                    return saved.ssid === ssid;
                                });
                                networks.push({
                                    "ssid": ssid,
                                    "signal": signal,
                                    "secured": security !== "",
                                    "connected": ssid === root.currentWifiSSID,
                                    "saved": isSaved,
                                    "signalStrength": signal >= 75 ? "excellent" : signal >= 50 ? "good" : signal >= 25 ? "fair" : "poor"
                                });
                            }
                        }
                    }
                    // Sort by signal strength
                    networks.sort((a, b) => {
                        return b.signal - a.signal;
                    });
                    root.wifiNetworks = networks;
                    console.log("Found", networks.length, "WiFi networks");
                    // Stop scanning once we have results
                    if (networks.length > 0) {
                        root.isScanning = false;
                        fallbackTimer.stop();
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
                    let saved = [];
                    let lines = text.trim().split('\n');
                    for (let line of lines) {
                        let connectionName = line.trim();
                        if (connectionName && !connectionName.includes("ethernet") && !connectionName.includes("lo") && !connectionName.includes("Wired") && !connectionName.toLowerCase().includes("eth"))
                            saved.push({
                            "ssid": connectionName,
                            "saved": true
                        });

                    }
                    root.savedWifiNetworks = saved;
                    console.log("Found", saved.length, "saved WiFi networks");
                }
            }
        }

    }

    // WiFi Connection Process
    Process {
        id: wifiConnector
        command: ["bash", "-c", "timeout 30 nmcli dev wifi connect \"" + root.connectingSSID + "\" || nmcli connection up \"" + root.connectingSSID + "\"; exit_code=$?; echo \"nmcli exit code: $exit_code\" >&2; if [ $exit_code -eq 0 ]; then nmcli connection modify \"" + root.connectingSSID + "\" connection.autoconnect-priority 50; sleep 2; if nmcli -t -f ACTIVE,SSID dev wifi | grep -q \"^yes:" + root.connectingSSID + "\"; then echo \"Connection verified\" >&2; exit 0; else echo \"Connection failed verification\" >&2; exit 4; fi; else exit $exit_code; fi"]
        running: false
        
        stderr: StdioCollector {
            onStreamFinished: {
                console.log("WiFi connection debug output:", text.trim())
            }
        }
        
        onExited: (exitCode) => {
            console.log("WiFi connection result:", exitCode)
            if (exitCode === 0) {
                root.connectionStatus = "connected"
                root.passwordDialogShouldReopen = false
                console.log("Connected to WiFi successfully")
                ToastService.showInfo("Connected to " + root.connectingSSID)
                setNetworkPreference("wifi")
                delayedRefreshNetworkStatus()
                
                // Immediately update savedWifiNetworks to include the new connection
                if (!root.savedWifiNetworks.some((saved) => saved.ssid === root.connectingSSID)) {
                    let updatedSaved = [...root.savedWifiNetworks];
                    updatedSaved.push({"ssid": root.connectingSSID, "saved": true});
                    root.savedWifiNetworks = updatedSaved;
                }
                
                // Update wifiNetworks to reflect the change
                let updatedNetworks = [...root.wifiNetworks];
                for (let i = 0; i < updatedNetworks.length; i++) {
                    if (updatedNetworks[i].ssid === root.connectingSSID) {
                        updatedNetworks[i].saved = true;
                        updatedNetworks[i].connected = true;
                        break;
                    }
                }
                root.wifiNetworks = updatedNetworks;
            } else if (exitCode === 4) {
                // Connection failed - likely needs password for saved network
                root.connectionStatus = "invalid_password"
                root.passwordDialogShouldReopen = true
                console.log("Saved network connection failed - password required")
                ToastService.showError("Authentication failed for " + root.connectingSSID)
            } else {
                root.connectionStatus = "failed"
                console.log("WiFi connection failed")
                ToastService.showError("Failed to connect to " + root.connectingSSID)
            }
            scanWifi()
            statusResetTimer.start()
        }

    }

    // WiFi Connection with Password Process
    Process {
        id: wifiPasswordConnector
        command: ["bash", "-c", "nmcli connection delete \"" + root.connectingSSID + "\" 2>/dev/null || true; timeout 30 nmcli dev wifi connect \"" + root.connectingSSID + "\" password \"" + root.wifiPassword + "\"; exit_code=$?; echo \"nmcli exit code: $exit_code\" >&2; if [ $exit_code -eq 0 ]; then nmcli connection modify \"" + root.connectingSSID + "\" connection.autoconnect-priority 50; sleep 2; if nmcli -t -f ACTIVE,SSID dev wifi | grep -q \"^yes:" + root.connectingSSID + "\"; then echo \"Connection verified\" >&2; exit 0; else echo \"Connection failed verification\" >&2; exit 4; fi; else exit $exit_code; fi"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    console.log("WiFi connection stdout:", text.trim())
                }
            }
        }
        
        stderr: StdioCollector {
            onStreamFinished: {
                root.lastConnectionError = text.trim()
                console.log("WiFi connection debug output:", text.trim())
            }
        }
        
        onExited: (exitCode) => {
            console.log("WiFi connection with password result:", exitCode)
            console.log("Error output:", root.lastConnectionError)
            
            if (exitCode === 0) {
                root.connectionStatus = "connected"
                root.passwordDialogShouldReopen = false
                console.log("Connected to WiFi with password successfully")
                ToastService.showInfo("Connected to " + root.connectingSSID)
                setNetworkPreference("wifi")
                delayedRefreshNetworkStatus()
                
                // Immediately update savedWifiNetworks to include the new connection
                if (!root.savedWifiNetworks.some((saved) => saved.ssid === root.connectingSSID)) {
                    let updatedSaved = [...root.savedWifiNetworks];
                    updatedSaved.push({"ssid": root.connectingSSID, "saved": true});
                    root.savedWifiNetworks = updatedSaved;
                }
                
                // Update wifiNetworks to reflect the change
                let updatedNetworks = [...root.wifiNetworks];
                for (let i = 0; i < updatedNetworks.length; i++) {
                    if (updatedNetworks[i].ssid === root.connectingSSID) {
                        updatedNetworks[i].saved = true;
                        updatedNetworks[i].connected = true;
                        break;
                    }
                }
                root.wifiNetworks = updatedNetworks;
            } else if (exitCode === 4) {
                // Connection activation failed - likely invalid credentials
                if (root.lastConnectionError.includes("Secrets were required") || 
                    root.lastConnectionError.includes("authentication") ||
                    root.lastConnectionError.includes("AUTH_TIMED_OUT")) {
                    root.connectionStatus = "invalid_password"
                    root.passwordDialogShouldReopen = true
                    console.log("Invalid password detected")
                    ToastService.showError("Invalid password for " + root.connectingSSID)
                } else {
                    root.connectionStatus = "failed"
                    console.log("Connection failed - not password related")
                    ToastService.showError("Failed to connect to " + root.connectingSSID)
                }
            } else if (exitCode === 3 || exitCode === 124) {
                root.connectionStatus = "failed"
                console.log("Connection timed out")
                ToastService.showError("Connection to " + root.connectingSSID + " timed out")
            } else {
                root.connectionStatus = "failed"
                console.log("WiFi connection with password failed")
                ToastService.showError("Failed to connect to " + root.connectingSSID)
            }
            root.wifiPassword = "" // Clear password
            scanWifi()
            statusResetTimer.start()
        }

    }

    // WiFi Disconnect Process
    Process {
        id: wifiDisconnector
        command: ["bash", "-c", "WIFI_DEV=$(nmcli -t -f DEVICE,TYPE device | grep wifi | cut -d: -f1 | head -1); [ -n \"$WIFI_DEV\" ] && nmcli device disconnect \"$WIFI_DEV\""]
        running: false
        
        onExited: (exitCode) => {
            console.log("WiFi disconnect result:", exitCode)
            if (exitCode === 0) {
                console.log("Successfully disconnected from WiFi")
                ToastService.showInfo("Disconnected from WiFi")
                root.currentWifiSSID = ""
                root.connectionStatus = ""
                refreshNetworkStatus()
            } else {
                console.log("Failed to disconnect from WiFi")
                ToastService.showError("Failed to disconnect from WiFi")
            }
        }

        stderr: SplitParser {
            splitMarker: "\\n"
            onRead: (data) => {
                console.log("WiFi disconnect stderr:", data)
            }
        }
    }

    // WiFi Forget Network Process
    Process {
        id: wifiForget
        command: ["bash", "-c", "nmcli connection delete \"" + root.forgetSSID + "\" || nmcli connection delete id \"" + root.forgetSSID + "\""]
        running: false
        
        onExited: (exitCode) => {
            console.log("WiFi forget result:", exitCode)
            if (exitCode === 0) {
                console.log("Successfully forgot WiFi network:", root.forgetSSID)
                ToastService.showInfo("Forgot network \"" + root.forgetSSID + "\"")
                
                // If we forgot the currently connected network, clear connection status
                if (root.forgetSSID === root.currentWifiSSID) {
                    root.currentWifiSSID = "";
                    root.connectionStatus = "";
                    refreshNetworkStatus();
                }
                
                // Update savedWifiNetworks to remove the forgotten network
                root.savedWifiNetworks = root.savedWifiNetworks.filter((saved) => {
                    return saved.ssid !== root.forgetSSID;
                });
                
                // Update wifiNetworks - create new array with updated objects
                let updatedNetworks = [];
                for (let i = 0; i < root.wifiNetworks.length; i++) {
                    let network = root.wifiNetworks[i];
                    if (network.ssid === root.forgetSSID) {
                        let updatedNetwork = Object.assign({}, network);
                        updatedNetwork.saved = false;
                        updatedNetwork.connected = false;
                        updatedNetworks.push(updatedNetwork);
                    } else {
                        updatedNetworks.push(network);
                    }
                }
                root.wifiNetworks = updatedNetworks;
                root.networksUpdated();
            } else {
                console.log("Failed to forget WiFi network:", root.forgetSSID)
                ToastService.showError("Failed to forget network \"" + root.forgetSSID + "\"")
            }
            root.forgetSSID = "" // Clear SSID
        }

        stderr: SplitParser {
            splitMarker: "\\n"
            onRead: (data) => {
                console.log("WiFi forget stderr:", data)
            }
        }
    }

    // WiFi Network Info Fetcher Process - Using detailed nmcli output
    Process {
        id: wifiInfoFetcher
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,FREQ,RATE,MODE,CHAN,WPA-FLAGS,RSN-FLAGS", "dev", "wifi", "list"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                let details = "";
                if (text.trim()) {
                    let lines = text.trim().split('\n');
                    for (let line of lines) {
                        let parts = line.split(':');
                        if (parts.length >= 9 && parts[0] === root.networkInfoSSID) {
                            let ssid = parts[0] || "Unknown";
                            let signal = parts[1] || "0";
                            let security = parts[2] || "Open";
                            let freq = parts[3] || "Unknown";
                            let rate = parts[4] || "Unknown";
                            let mode = parts[5] || "Unknown";
                            let channel = parts[6] || "Unknown";
                            let wpaFlags = parts[7] || "";
                            let rsnFlags = parts[8] || "";
                            
                            // Determine band from frequency
                            let band = "Unknown";
                            let freqNum = parseInt(freq);
                            if (freqNum >= 2400 && freqNum <= 2500) {
                                band = "2.4 GHz";
                            } else if (freqNum >= 5000 && freqNum <= 6000) {
                                band = "5 GHz";
                            } else if (freqNum >= 6000) {
                                band = "6 GHz";
                            }
                            
                            details = "Network Name: " + ssid + "\\n";
                            details += "Signal Strength: " + signal + "%\\n";
                            details += "Security: " + (security === "" ? "Open" : security) + "\\n";
                            details += "Frequency: " + freq + " MHz\\n";
                            details += "Band: " + band + "\\n";
                            details += "Channel: " + channel + "\\n";
                            details += "Mode: " + mode + "\\n";
                            details += "Max Rate: " + rate + " Mbit/s\\n";
                            
                            if (wpaFlags !== "") {
                                details += "WPA Flags: " + wpaFlags + "\\n";
                            }
                            if (rsnFlags !== "") {
                                details += "RSN Flags: " + rsnFlags + "\\n";
                            }
                            
                            break;
                        }
                    }
                }
                
                if (details === "") {
                    details = "Network information not found or network not available.";
                }
                
                root.networkInfoDetails = details;
                root.networkInfoLoading = false;
                console.log("Network info fetched for:", root.networkInfoSSID);
            }
        }
        
        onExited: (exitCode) => {
            root.networkInfoLoading = false;
            if (exitCode !== 0) {
                console.log("Failed to fetch network info, exit code:", exitCode);
                root.networkInfoDetails = "Failed to fetch network information";
            }
        }
        
        stderr: SplitParser {
            splitMarker: "\\n"
            onRead: (data) => {
                console.log("WiFi info stderr:", data);
            }
        }
    }

    // WiFi Device Enabler Process
    Process {
        id: wifiDeviceEnabler
        command: ["sh", "-c", "WIFI_DEV=$(nmcli -t -f DEVICE,TYPE device | grep wifi | cut -d: -f1 | head -1); if [ -n \"$WIFI_DEV\" ]; then nmcli device connect \"$WIFI_DEV\"; else echo \"No WiFi device found\"; exit 1; fi"]
        running: false
        
        onExited: (exitCode) => {
            console.log("WiFi device enable result:", exitCode)
            if (exitCode === 0) {
                console.log("WiFi device enabled successfully")
                ToastService.showInfo("WiFi enabled")
            } else {
                console.log("Failed to enable WiFi device")
                ToastService.showError("Failed to enable WiFi")
            }
            delayedRefreshNetworkStatus()
        }
        
        stderr: SplitParser {
            splitMarker: "\\n"
            onRead: (data) => {
                console.log("WiFi device enable stderr:", data)
            }
        }
    }
    
}