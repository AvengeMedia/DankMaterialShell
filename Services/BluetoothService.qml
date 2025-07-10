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
        command: ["bluetoothctl", "show"]
        running: true
        
        stdout: StdioCollector {
            onStreamFinished: {
                root.bluetoothAvailable = text.trim() !== "" && !text.includes("No default controller")
                root.bluetoothEnabled = text.includes("Powered: yes")
                console.log("Bluetooth available:", root.bluetoothAvailable, "enabled:", root.bluetoothEnabled)
                
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
        command: ["bash", "-c", "bluetoothctl devices | while read -r line; do if [[ $line =~ Device\\ ([0-9A-F:]+)\\ (.+) ]]; then mac=\"${BASH_REMATCH[1]}\"; name=\"${BASH_REMATCH[2]}\"; if [[ ! $name =~ ^/org/bluez ]]; then info=$(bluetoothctl info $mac); connected=$(echo \"$info\" | grep 'Connected:' | grep -q 'yes' && echo 'true' || echo 'false'); battery=$(echo \"$info\" | grep 'Battery Percentage' | grep -o '([0-9]*)' | tr -d '()'); echo \"$mac|$name|$connected|${battery:-}\"; fi; fi; done"]
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
                                let connected = parts[2].trim() === 'true'
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
                    console.log("Found", devices.length, "Bluetooth devices")
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
        console.log("Starting Bluetooth discovery...")
        let discoveryProcess = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["bluetoothctl", "scan", "on"]
                running: true
                onExited: {
                    root.scanning = true
                    // Scan for 10 seconds then get discovered devices
                    discoveryScanTimer.start()
                }
            }
        ', root)
    }
    
    function stopDiscovery() {
        console.log("Stopping Bluetooth discovery...")
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
        console.log("Toggling Bluetooth device:", mac)
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
    
    // Timer for discovery scanning
    Timer {
        id: discoveryScanTimer
        interval: 8000  // 8 seconds
        repeat: false
        onTriggered: {
            availableDeviceScanner.running = true
        }
    }
    
    // Scan for available/discoverable devices
    Process {
        id: availableDeviceScanner
        command: ["bash", "-c", "timeout 5 bluetoothctl devices | grep -v 'Device.*/' | while read -r line; do if [[ $line =~ Device\ ([0-9A-F:]+)\ (.+) ]]; then mac=\"${BASH_REMATCH[1]}\"; name=\"${BASH_REMATCH[2]}\"; if [[ ! $name =~ ^/org/bluez ]] && [[ ! $name =~ hci0 ]]; then info=$(timeout 3 bluetoothctl info $mac 2>/dev/null); paired=$(echo \"$info\" | grep 'Paired:' | grep -q 'yes' && echo 'true' || echo 'false'); connected=$(echo \"$info\" | grep 'Connected:' | grep -q 'yes' && echo 'true' || echo 'false'); rssi=$(echo \"$info\" | grep 'RSSI:' | awk '{print $2}' | head -n1); echo \"$mac|$name|$paired|$connected|${rssi:-}\"; fi; fi; done"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    let devices = []
                    let lines = text.trim().split('\n')
                    
                    for (let line of lines) {
                        if (line.trim()) {
                            let parts = line.split('|')
                            if (parts.length >= 4) {
                                let mac = parts[0].trim()
                                let name = parts[1].trim()
                                let paired = parts[2].trim() === 'true'
                                let connected = parts[3].trim() === 'true'
                                let rssi = parts[4] ? parseInt(parts[4]) : 0
                                
                                // Skip if name is still a technical path
                                if (name.startsWith('/org/bluez') || name.includes('hci0')) {
                                    continue
                                }
                                
                                // Determine device type from name
                                let type = "bluetooth"
                                let nameLower = name.toLowerCase()
                                if (nameLower.includes("headphone") || nameLower.includes("airpod") || nameLower.includes("headset") || nameLower.includes("arctis") || nameLower.includes("audio")) type = "headset"
                                else if (nameLower.includes("mouse")) type = "mouse"
                                else if (nameLower.includes("keyboard")) type = "keyboard"
                                else if (nameLower.includes("phone") || nameLower.includes("iphone") || nameLower.includes("samsung") || nameLower.includes("android")) type = "phone"
                                else if (nameLower.includes("watch")) type = "watch"
                                else if (nameLower.includes("speaker")) type = "speaker"
                                else if (nameLower.includes("tv") || nameLower.includes("display")) type = "tv"
                                
                                // Signal strength assessment
                                let signalStrength = "unknown"
                                if (rssi !== 0) {
                                    if (rssi >= -50) signalStrength = "excellent"
                                    else if (rssi >= -60) signalStrength = "good"
                                    else if (rssi >= -70) signalStrength = "fair"
                                    else signalStrength = "weak"
                                }
                                
                                devices.push({
                                    mac: mac,
                                    name: name,
                                    type: type,
                                    paired: paired,
                                    connected: connected,
                                    rssi: rssi,
                                    signalStrength: signalStrength,
                                    canPair: !paired
                                })
                            }
                        }
                    }
                    
                    root.availableDevices = devices
                    console.log("Found", devices.length, "available Bluetooth devices")
                }
            }
        }
    }
}