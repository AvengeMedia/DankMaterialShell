import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    property int brightnessLevel: 75
    property bool brightnessAvailable: false
    
    // Check if brightness control is available
    Process {
        id: brightnessAvailabilityChecker
        command: ["bash", "-c", "if command -v brightnessctl > /dev/null; then echo 'brightnessctl'; elif command -v xbacklight > /dev/null; then echo 'xbacklight'; else echo 'none'; fi"]
        running: true
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    let method = data.trim()
                    if (method === "brightnessctl" || method === "xbacklight") {
                        root.brightnessAvailable = true
                        brightnessChecker.running = true
                    } else {
                        root.brightnessAvailable = false
                        console.log("Brightness control not available - no brightnessctl or xbacklight found")
                    }
                }
            }
        }
    }
    
    // Brightness Control
    Process {
        id: brightnessChecker
        command: ["bash", "-c", "if command -v brightnessctl > /dev/null; then brightnessctl get; elif command -v xbacklight > /dev/null; then xbacklight -get | cut -d. -f1; else echo 75; fi"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    let brightness = parseInt(data.trim()) || 75
                    // brightnessctl returns absolute value, need to convert to percentage
                    if (brightness > 100) {
                        brightnessMaxChecker.running = true
                    } else {
                        root.brightnessLevel = brightness
                    }
                }
            }
        }
    }
    
    Process {
        id: brightnessMaxChecker
        command: ["brightnessctl", "max"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    let maxBrightness = parseInt(data.trim()) || 100
                    brightnessCurrentChecker.property("maxBrightness", maxBrightness)
                    brightnessCurrentChecker.running = true
                }
            }
        }
    }
    
    Process {
        id: brightnessCurrentChecker
        property int maxBrightness: 100
        command: ["brightnessctl", "get"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    let currentBrightness = parseInt(data.trim()) || 75
                    root.brightnessLevel = Math.round((currentBrightness / maxBrightness) * 100)
                }
            }
        }
    }
    
    function setBrightness(percentage) {
        if (!root.brightnessAvailable) {
            console.warn("Brightness control not available")
            return
        }
        
        let brightnessSetProcess = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["bash", "-c", "if command -v brightnessctl > /dev/null; then brightnessctl set ' + percentage + '%; elif command -v xbacklight > /dev/null; then xbacklight -set ' + percentage + '; fi"]
                running: true
                onExited: brightnessChecker.running = true
            }
        ', root)
    }
}