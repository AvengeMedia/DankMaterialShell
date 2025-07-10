import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    property string osLogo: ""
    property string osName: ""
    
    // OS Detection
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
                    
                    // Set OS-specific Nerd Font icons and names
                    if (osId.includes("arch")) {
                        root.osLogo = "\uf303"  // Arch Linux Nerd Font icon
                        root.osName = "Arch Linux"
                        console.log("Set Arch logo:", root.osLogo)
                    } else if (osId.includes("ubuntu")) {
                        root.osLogo = "\uf31b"  // Ubuntu Nerd Font icon
                        root.osName = "Ubuntu"
                    } else if (osId.includes("fedora")) {
                        root.osLogo = "\uf30a"  // Fedora Nerd Font icon
                        root.osName = "Fedora"
                    } else if (osId.includes("debian")) {
                        root.osLogo = "\uf306"  // Debian Nerd Font icon
                        root.osName = "Debian"
                    } else if (osId.includes("opensuse")) {
                        root.osLogo = "\uef6d"  // openSUSE Nerd Font icon
                        root.osName = "openSUSE"
                    } else if (osId.includes("manjaro")) {
                        root.osLogo = "\uf312"  // Manjaro Nerd Font icon
                        root.osName = "Manjaro"
                    } else {
                        root.osLogo = "\uf033"  // Generic Linux Nerd Font icon
                        root.osName = "Linux"
                    }
                }
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                // Fallback: try checking /etc/os-release
                osDetectorFallback.running = true
            }
        }
    }
    
    // Fallback OS detection
    Process {
        id: osDetectorFallback
        command: ["sh", "-c", "grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '\"'"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    let osId = data.trim().toLowerCase()
                    console.log("Detected OS (fallback):", osId)
                    
                    if (osId.includes("arch")) {
                        root.osLogo = "\uf303"
                        root.osName = "Arch Linux"
                    } else if (osId.includes("ubuntu")) {
                        root.osLogo = "\uf31b"
                        root.osName = "Ubuntu"
                    } else if (osId.includes("fedora")) {
                        root.osLogo = "\uf30a"
                        root.osName = "Fedora"
                    } else if (osId.includes("debian")) {
                        root.osLogo = "\uf306"
                        root.osName = "Debian"
                    } else if (osId.includes("opensuse")) {
                        root.osLogo = "\uef6d"
                        root.osName = "openSUSE"
                    } else if (osId.includes("manjaro")) {
                        root.osLogo = "\uf312"
                        root.osName = "Manjaro"
                    } else {
                        root.osLogo = "\uf033"
                        root.osName = "Linux"
                    }
                }
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                // Ultimate fallback - use generic apps icon (empty logo means fallback to "apps")
                root.osLogo = ""
                root.osName = "Linux"
                console.log("OS detection failed, using generic icon")
            }
        }
    }
}