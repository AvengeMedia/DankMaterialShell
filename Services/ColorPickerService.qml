import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    // Color Picker Process
    Process {
        id: colorPickerProcess
        command: ["hyprpicker", "-a"]
        running: false
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("Color picker failed. Make sure hyprpicker is installed: yay -S hyprpicker")
            }
        }
    }
    
    function pickColor() {
        colorPickerProcess.running = true
    }
}