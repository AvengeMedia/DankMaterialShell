pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: osService
    
    property string osLogo: ""
    property string osName: ""
    
    Process {
        id: osDetector
        command: ["lsb_release", "-i", "-s"]
        running: true
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    let osId = data.trim().toLowerCase()
                    console.log("Detected OS:", osId)
                    setOSInfo(osId)
                }
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                osDetectorFallback.running = true
            }
        }
    }
    
    Process {
        id: osDetectorFallback
        command: ["sh", "-c", "cat /etc/os-release | grep '^ID=' | cut -d'=' -f2 | tr -d '\"'"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    let osId = data.trim().toLowerCase()
                    console.log("Detected OS (fallback):", osId)
                    setOSInfo(osId)
                }
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                osService.osLogo = ""
                osService.osName = "Linux"
                console.log("OS detection failed, using generic icon")
            }
        }
    }
    
    function setOSInfo(osId) {
        if (osId.includes("arch")) {
            osService.osLogo = "\uf303"
            osService.osName = "Arch Linux"
        } else if (osId.includes("ubuntu")) {
            osService.osLogo = "\uf31b"
            osService.osName = "Ubuntu"
        } else if (osId.includes("fedora")) {
            osService.osLogo = "\uf30a"
            osService.osName = "Fedora"
        } else if (osId.includes("debian")) {
            osService.osLogo = "\uf306"
            osService.osName = "Debian"
        } else if (osId.includes("opensuse")) {
            osService.osLogo = "\uef6d"
            osService.osName = "openSUSE"
        } else if (osId.includes("manjaro")) {
            osService.osLogo = "\uf312"
            osService.osName = "Manjaro"
        } else {
            osService.osLogo = "\uf033"
            osService.osName = "Linux"
        }
    }
}