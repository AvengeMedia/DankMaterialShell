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
}