pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    
    property string osLogo: ""
    property string osName: ""
    
    // OS Detection using /etc/os-release
    Process {
        id: osDetector
        command: ["sh", "-c", "grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '\"'"]
        running: true
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    let osId = data.trim().toLowerCase()
                    console.log("Detected OS from /etc/os-release:", osId)
                    
                    // Set OS-specific Nerd Font icons and names
                    switch(osId) {
                        case "arch":
                            root.osLogo = "\uf303"  // Arch Linux Nerd Font icon
                            root.osName = "Arch Linux"
                            break
                        case "ubuntu":
                            root.osLogo = "\uf31b"  // Ubuntu Nerd Font icon
                            root.osName = "Ubuntu"
                            break
                        case "fedora":
                            root.osLogo = "\uf30a"  // Fedora Nerd Font icon
                            root.osName = "Fedora"
                            break
                        case "debian":
                            root.osLogo = "\uf306"  // Debian Nerd Font icon
                            root.osName = "Debian"
                            break
                        case "opensuse":
                        case "opensuse-leap":
                        case "opensuse-tumbleweed":
                            root.osLogo = "\uef6d"  // openSUSE Nerd Font icon
                            root.osName = "openSUSE"
                            break
                        case "manjaro":
                            root.osLogo = "\uf312"  // Manjaro Nerd Font icon
                            root.osName = "Manjaro"
                            break
                        case "nixos":
                            root.osLogo = "\uf313"  // NixOS Nerd Font icon
                            root.osName = "NixOS"
                            break
                        case "rocky":
                            root.osLogo = "\uf32b"  // Rocky Linux Nerd Font icon
                            root.osName = "Rocky Linux"
                            break
                        case "almalinux":
                            root.osLogo = "\uf31d"  // AlmaLinux Nerd Font icon
                            root.osName = "AlmaLinux"
                            break
                        case "centos":
                            root.osLogo = "\uf304"  // CentOS Nerd Font icon
                            root.osName = "CentOS"
                            break
                        case "rhel":
                        case "redhat":
                            root.osLogo = "\uf316"  // Red Hat Nerd Font icon
                            root.osName = "Red Hat"
                            break
                        case "gentoo":
                            root.osLogo = "\uf30d"  // Gentoo Nerd Font icon
                            root.osName = "Gentoo"
                            break
                        case "mint":
                        case "linuxmint":
                            root.osLogo = "\uf30e"  // Linux Mint Nerd Font icon
                            root.osName = "Linux Mint"
                            break
                        case "elementary":
                            root.osLogo = "\uf309"  // Elementary OS Nerd Font icon
                            root.osName = "Elementary OS"
                            break
                        case "pop":
                            root.osLogo = "\uf32a"  // Pop!_OS Nerd Font icon
                            root.osName = "Pop!_OS"
                            break
                        default:
                            root.osLogo = "\uf17c"  // Generic Linux Nerd Font icon
                            root.osName = "Linux"
                    }
                    
                    console.log("Set OS logo:", root.osLogo, "Name:", root.osName)
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