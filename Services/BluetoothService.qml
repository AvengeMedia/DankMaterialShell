import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    property bool bluetoothEnabled: false
    property bool bluetoothAvailable: false
    property var bluetoothDevices: []
    property var availableDevices: []
    property bool scanning: false
    property bool discoverable: false
    
    // Real Bluetooth Management
    Process {
        id: bluetoothStatusChecker
        command: ["bluetoothctl", "show"]   // Use default controller
        running: true
        
        stdout: StdioCollector {
            onStreamFinished: {
                root.bluetoothAvailable = text.trim() !== "" && !text.includes("No default controller")
                root.bluetoothEnabled = text.includes("Powered: yes")
                
                if (root.bluetoothEnabled && root.bluetoothAvailable) {
                    bluetoothDeviceScanner.running = true
                } else {
                    root.bluetoothDevices = []
                }
            }
        }
    }
    
    Process {
        id: bluetoothDeviceScanner
        command: ["bash", "-c", "bluetoothctl devices | while read -r line; do if [[ $line =~ Device\\ ([0-9A-F:]+)\\ (.+) ]]; then mac=\"${BASH_REMATCH[1]}\"; name=\"${BASH_REMATCH[2]}\"; if [[ ! $name =~ ^/org/bluez ]]; then info=$(bluetoothctl info $mac); connected=$(echo \"$info\" | grep -m1 'Connected:' | awk '{print $2}'); battery=$(echo \"$info\" | grep -m1 'Battery Percentage:' | grep -o '[0-9]\\+'); echo \"$mac|$name|$connected|${battery:-}\"; fi; fi; done"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    let devices = []
                    let lines = text.trim().split('\n')
                    
                    for (let line of lines) {
                        if (line.trim()) {
                            let parts = line.split('|')
                            if (parts.length >= 3) {
                                let mac = parts[0].trim()
                                let name = parts[1].trim()
                                let connected = parts[2].trim() === 'yes'
                                let battery = parts[3] ? parseInt(parts[3]) : -1
                                
                                // Skip if name is still a technical path
                                if (name.startsWith('/org/bluez') || name.includes('hci0')) {
                                    continue
                                }
                                
                                // Determine device type from name
                                let type = "bluetooth"
                                let nameLower = name.toLowerCase()
                                if (nameLower.includes("headphone") || nameLower.includes("airpod") || nameLower.includes("headset") || nameLower.includes("arctis")) type = "headset"
                                else if (nameLower.includes("mouse")) type = "mouse"
                                else if (nameLower.includes("keyboard")) type = "keyboard"
                                else if (nameLower.includes("phone") || nameLower.includes("iphone") || nameLower.includes("samsung")) type = "phone"
                                else if (nameLower.includes("watch")) type = "watch"
                                else if (nameLower.includes("speaker")) type = "speaker"
                                
                                devices.push({
                                    mac: mac,
                                    name: name,
                                    type: type,
                                    connected: connected,
                                    battery: battery
                                })
                            }
                        }
                    }
                    
                    root.bluetoothDevices = devices
                }
            }
        }
    }
    
    function scanDevices() {
        if (root.bluetoothEnabled && root.bluetoothAvailable) {
            bluetoothDeviceScanner.running = true
        }
    }
    
    function startDiscovery() {
        root.scanning = true
        // Run comprehensive scan that gets all devices
        discoveryScanner.running = true
    }
    
    function stopDiscovery() {
        let stopDiscoveryProcess = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["bluetoothctl", "scan", "off"]
                running: true
                onExited: {
                    root.scanning = false
                }
            }
        ', root)
    }
    
    function pairDevice(mac) {
        console.log("Pairing device:", mac)
        let pairProcess = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["bluetoothctl", "pair", "' + mac + '"]
                running: true
                onExited: (exitCode) => {
                    if (exitCode === 0) {
                        console.log("Pairing successful")
                        connectDevice("' + mac + '")
                    } else {
                        console.warn("Pairing failed with exit code:", exitCode)
                    }
                    availableDeviceScanner.running = true
                    bluetoothDeviceScanner.running = true
                }
            }
        ', root)
    }
    
    function connectDevice(mac) {
        console.log("Connecting to device:", mac)
        let connectProcess = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["bluetoothctl", "connect", "' + mac + '"]
                running: true
                onExited: (exitCode) => {
                    if (exitCode === 0) {
                        console.log("Connection successful")
                    } else {
                        console.warn("Connection failed with exit code:", exitCode)
                    }
                    bluetoothDeviceScanner.running = true
                }
            }
        ', root)
    }
    
    function removeDevice(mac) {
        console.log("Removing device:", mac)
        let removeProcess = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["bluetoothctl", "remove", "' + mac + '"]
                running: true
                onExited: {
                    bluetoothDeviceScanner.running = true
                    availableDeviceScanner.running = true
                }
            }
        ', root)
    }
    
    function toggleBluetoothDevice(mac) {
        let device = root.bluetoothDevices.find(d => d.mac === mac)
        if (device) {
            let action = device.connected ? "disconnect" : "connect"
            let toggleProcess = Qt.createQmlObject('
                import Quickshell.Io
                Process {
                    command: ["bluetoothctl", "' + action + '", "' + mac + '"]
                    running: true
                    onExited: bluetoothDeviceScanner.running = true
                }
            ', root)
        }
    }
    
    function toggleBluetooth() {
        let action = root.bluetoothEnabled ? "off" : "on"
        let toggleProcess = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["bluetoothctl", "power", "' + action + '"]
                running: true
                onExited: bluetoothStatusChecker.running = true
            }
        ', root)
    }
    
    Timer {
        id: bluetoothMonitorTimer
        interval: 5000
        running: false; repeat: true
        onTriggered: {
            bluetoothStatusChecker.running = true
            if (root.bluetoothEnabled) {
                bluetoothDeviceScanner.running = true
                // Also refresh paired devices to get current connection status
                pairedDeviceChecker.discoveredToMerge = []
                pairedDeviceChecker.running = true
            }
        }
    }
    
    function enableMonitoring(enabled) {
        bluetoothMonitorTimer.running = enabled
        if (enabled) {
            // Immediately update when enabled
            bluetoothStatusChecker.running = true
        }
    }
    
    property var discoveredDevices: []
    
    // Handle discovered devices
    function _handleDiscovered(found) {
        
        let discoveredDevices = []
        for (let device of found) {
            let type = "bluetooth"
            let nameLower = device.name.toLowerCase()
            if (nameLower.includes("headphone") || nameLower.includes("airpod") || nameLower.includes("headset") || nameLower.includes("arctis") || nameLower.includes("audio")) type = "headset"
            else if (nameLower.includes("mouse")) type = "mouse"
            else if (nameLower.includes("keyboard")) type = "keyboard"
            else if (nameLower.includes("phone") || nameLower.includes("iphone") || nameLower.includes("samsung") || nameLower.includes("android")) type = "phone"
            else if (nameLower.includes("watch")) type = "watch"
            else if (nameLower.includes("speaker")) type = "speaker"
            else if (nameLower.includes("tv") || nameLower.includes("display")) type = "tv"
            
            discoveredDevices.push({
                mac: device.mac,
                name: device.name,
                type: type,
                paired: false,
                connected: false,
                rssi: -70,
                signalStrength: "fair",
                canPair: true
            })
            
            console.log("  -", device.name, "(", device.mac, ")")
        }
        
        // Get paired devices first, then merge with discovered
        pairedDeviceChecker.discoveredToMerge = discoveredDevices
        pairedDeviceChecker.running = true
    }
    
    // Get only currently connected/paired devices that matter
    Process {
        id: availableDeviceScanner
        command: ["bash", "-c", "bluetoothctl devices | while read -r line; do if [[ $line =~ Device\\ ([A-F0-9:]+)\\ (.+) ]]; then mac=\"${BASH_REMATCH[1]}\"; name=\"${BASH_REMATCH[2]}\"; info=$(bluetoothctl info \"$mac\" 2>/dev/null); paired=$(echo \"$info\" | grep -m1 'Paired:' | awk '{print $2}'); connected=$(echo \"$info\" | grep -m1 'Connected:' | awk '{print $2}'); if [[ \"$paired\" == \"yes\" ]] || [[ \"$connected\" == \"yes\" ]]; then echo \"$mac|$name|$paired|$connected\"; fi; fi; done"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                
                let devices = []
                if (text.trim()) {
                    let lines = text.trim().split('\n')
                    
                    for (let line of lines) {
                        if (line.trim()) {
                            let parts = line.split('|')
                            if (parts.length >= 4) {
                                let mac = parts[0].trim()
                                let name = parts[1].trim()
                                let paired = parts[2].trim() === 'yes'
                                let connected = parts[3].trim() === 'yes'
                                
                                // Skip technical names
                                if (name.startsWith('/org/bluez') || name.includes('hci0') || name.length < 3) {
                                    continue
                                }
                                
                                // Determine device type
                                let type = "bluetooth"
                                let nameLower = name.toLowerCase()
                                if (nameLower.includes("headphone") || nameLower.includes("airpod") || nameLower.includes("headset") || nameLower.includes("arctis") || nameLower.includes("audio")) type = "headset"
                                else if (nameLower.includes("mouse")) type = "mouse"
                                else if (nameLower.includes("keyboard")) type = "keyboard"
                                else if (nameLower.includes("phone") || nameLower.includes("iphone") || nameLower.includes("samsung") || nameLower.includes("android")) type = "phone"
                                else if (nameLower.includes("watch")) type = "watch"
                                else if (nameLower.includes("speaker")) type = "speaker"
                                else if (nameLower.includes("tv") || nameLower.includes("display")) type = "tv"
                                
                                devices.push({
                                    mac: mac,
                                    name: name,
                                    type: type,
                                    paired: paired,
                                    connected: connected,
                                    rssi: 0,
                                    signalStrength: "unknown",
                                    canPair: false  // Already paired
                                })
                            }
                        }
                    }
                }
                
                root.availableDevices = devices
            }
        }
    }
    
    // Discovery scanner using bluetoothctl --timeout
    Process {
        id: discoveryScanner
        // Discover for 8 s in non-interactive mode, then auto-exit
        command: ["bluetoothctl",
                  "--timeout", "8",
                  "--monitor",        // keeps stdout unbuffered
                  "scan", "on"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                /*
                 * bluetoothctl prints lines like:
                 *   [NEW] Device 12:34:56:78:9A:BC My-Headphones
                 */
                const rx = /^\[NEW\] Device ([0-9A-F:]+)\s+(.+)$/i;
                const found = text.split('\n')
                                  .filter(l => rx.test(l))
                                  .map(l  => {
                                      const [,mac,name] = l.match(rx);
                                      return { mac, name };
                                  });
                root._handleDiscovered(found);
            }
        }
        
        onExited: {
            root.scanning = false
        }
    }
    
    // Get paired devices and merge with discovered ones
    Process {
        id: pairedDeviceChecker
        command: ["bash", "-c", "bluetoothctl devices | while read -r line; do if [[ $line =~ Device\\ ([A-F0-9:]+)\\ (.+) ]]; then mac=\"${BASH_REMATCH[1]}\"; name=\"${BASH_REMATCH[2]}\"; if [[ ${#name} -gt 3 ]] && [[ ! $name =~ ^/org/bluez ]] && [[ ! $name =~ hci0 ]]; then info=$(bluetoothctl info \"$mac\" 2>/dev/null); paired=$(echo \"$info\" | grep -m1 'Paired:' | awk '{print $2}'); connected=$(echo \"$info\" | grep -m1 'Connected:' | awk '{print $2}'); echo \"$mac|$name|$paired|$connected\"; fi; fi; done"]
        running: false
        property var discoveredToMerge: []
        
        stdout: StdioCollector {
            onStreamFinished: {
                // Start with discovered devices (unpaired, available to pair)
                let allDevices = [...pairedDeviceChecker.discoveredToMerge]
                let seenMacs = new Set(allDevices.map(d => d.mac))
                
                // Add only actually paired devices from bluetoothctl
                if (text.trim()) {
                    let lines = text.trim().split('\n')
                    
                    for (let line of lines) {
                        if (line.trim()) {
                            let parts = line.split('|')
                            if (parts.length >= 4) {
                                let mac = parts[0].trim()
                                let name = parts[1].trim()
                                let paired = parts[2].trim() === 'yes'
                                let connected = parts[3].trim() === 'yes'
                                
                                // Only include if actually paired
                                if (!paired) continue
                                
                                // Check if already in discovered list
                                if (seenMacs.has(mac)) {
                                    // Update existing device to show it's paired
                                    let existing = allDevices.find(d => d.mac === mac)
                                    if (existing) {
                                        existing.paired = true
                                        existing.connected = connected
                                        existing.canPair = false
                                    }
                                    continue
                                }
                                
                                // Add paired device not found during scan
                                let type = "bluetooth"
                                let nameLower = name.toLowerCase()
                                if (nameLower.includes("headphone") || nameLower.includes("airpod") || nameLower.includes("headset") || nameLower.includes("arctis") || nameLower.includes("audio")) type = "headset"
                                else if (nameLower.includes("mouse")) type = "mouse"
                                else if (nameLower.includes("keyboard")) type = "keyboard"
                                else if (nameLower.includes("phone") || nameLower.includes("iphone") || nameLower.includes("samsung") || nameLower.includes("android")) type = "phone"
                                else if (nameLower.includes("watch")) type = "watch"
                                else if (nameLower.includes("speaker")) type = "speaker"
                                else if (nameLower.includes("tv") || nameLower.includes("display")) type = "tv"
                                
                                allDevices.push({
                                    mac: mac,
                                    name: name,
                                    type: type,
                                    paired: true,
                                    connected: connected,
                                    rssi: -100,
                                    signalStrength: "unknown",
                                    canPair: false
                                })
                            }
                        }
                    }
                }
                
                root.availableDevices = allDevices
                root.scanning = false
                
            }
        }
    }
}